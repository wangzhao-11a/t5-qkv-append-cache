// Execute the real kernel header against a bounded CPU DMA/queue adapter.
#include <array>
#include <iostream>
#include "kernel_operator.h"
#include "common/t5_plan.h"
#include "t5_copy.h"

namespace {
constexpr uint16_t kGuard = 0xa55a;
class Buffer {
 public:
  Buffer(size_t elements, size_t offset) : size(elements), raw(elements + 64, kGuard) {
    const auto aligned = (reinterpret_cast<uintptr_t>(raw.data() + 16) + 31) & ~uintptr_t{31};
    data = reinterpret_cast<uint16_t*>(aligned) + offset;
  }
  void check_guard() const {
    for (auto p = raw.data(); p < data; ++p) AscendC::require(*p == kGuard, "prefix guard changed");
    for (auto p = data + size; p < raw.data() + raw.size(); ++p) AscendC::require(*p == kGuard, "suffix guard changed");
  }
  size_t size;
  std::vector<uint16_t> raw;
  uint16_t* data;
};
uint16_t bits(size_t i, uint32_t source, bool bf16) {
  constexpr std::array<uint16_t, 8> fp{0, 0x8000, 0x7c00, 0xfc00, 0x7c01, 0x7e00, 1, 0x03ff};
  constexpr std::array<uint16_t, 8> bf{0, 0x8000, 0x7f80, 0xff80, 0x7f81, 0x7fc0, 1, 0x007f};
  return i % 16 < 8 ? (bf16 ? bf : fp)[i % 8] : static_cast<uint16_t>(i * 997 + source * 7919);
}
void require_equal(uint16_t actual, uint16_t expected) {
  AscendC::require(actual == expected, "output bits differ from independent row-wise golden");
}
void run(uint32_t b, uint32_t h, uint32_t l, uint32_t d, uint32_t offsets, bool bf16, bool large) {
  const size_t n = size_t{b} * h * d;
  std::array<Buffer, 6> buffers{Buffer(3*n, offsets & 1), Buffer(n*l, (offsets >> 1) & 1),
    Buffer(n*l, (offsets >> 2) & 1), Buffer(n, (offsets >> 3) & 1),
    Buffer(n*(l+1), (offsets >> 4) & 1), Buffer(n*(l+1), (offsets >> 5) & 1)};
  for (uint32_t s = 0; s < 3; ++s)
    for (size_t i = 0; i < buffers[s].size; ++i) buffers[s].data[i] = bits(i, s, bf16);
  const auto plan = t5qkv::MakePlan(b, h, l, d);
  const auto before = AscendC::counts;
  AscendC::block_count = plan.blocks;
  for (AscendC::block_index = 0; AscendC::block_index < plan.blocks; ++AscendC::block_index) {
    AscendC::TPipe pipe;
    T5Copy kernel;
    kernel.Init(reinterpret_cast<GM_ADDR>(buffers[0].data), reinterpret_cast<GM_ADDR>(buffers[1].data),
      reinterpret_cast<GM_ADDR>(buffers[2].data), reinterpret_cast<GM_ADDR>(buffers[3].data),
      reinterpret_cast<GM_ADDR>(buffers[4].data), reinterpret_cast<GM_ADDR>(buffers[5].data),
      b, h, l, d, plan.tileElements, plan.queryTiles, plan.cacheTiles, plan.totalTiles, &pipe);
    kernel.Process();
  }
  // Build expected output by complete head rows, independently of kernel tiling.
  for (size_t batch = 0; batch < b; ++batch) {
    for (size_t head = 0; head < h; ++head) {
      const size_t row = batch*h + head;
      for (size_t channel = 0; channel < d; ++channel) {
        require_equal(buffers[3].data[row*d+channel], bits(batch*3*h*d+head*d+channel, 0, bf16));
        for (uint32_t s = 1; s <= 2; ++s) {
          require_equal(buffers[3+s].data[(row*(l+1)+l)*d+channel], bits(batch*3*h*d+s*h*d+head*d+channel, 0, bf16));
        }
      }
      for (size_t old = 0; old < size_t{l}*d; ++old) {
        require_equal(buffers[4].data[row*(l+1)*d+old], bits(row*l*d+old, 1, bf16));
        require_equal(buffers[5].data[row*(l+1)*d+old], bits(row*l*d+old, 2, bf16));
      }
    }
  }
  for (uint32_t s = 0; s < 3; ++s)
    for (size_t i = 0; i < buffers[s].size; ++i) require_equal(buffers[s].data[i], bits(i, s, bf16));
  for (const auto& buffer : buffers) buffer.check_guard();
  if (large) {
    std::cout << "{\"case\":\"large\",\"dtype_bits\":\"" << (bf16 ? "bf16" : "fp16")
      << "\",\"offset_mask\":" << offsets << ",\"dma_read\":" << AscendC::counts.dma_read-before.dma_read
      << ",\"pad_read\":" << AscendC::counts.pad_read-before.pad_read
      << ",\"dma_write\":" << AscendC::counts.dma_write-before.dma_write
      << ",\"pad_write\":" << AscendC::counts.pad_write-before.pad_write << "}\n";
  }
}
}  // namespace
int main() {
  try {
    const std::array<std::array<uint32_t, 4>, 6> shapes{{{2,3,0,5}, {2,3,3,16}, {3,2,5,17}, {2,3,31,64}, {1,1,1,1}, {2,3,257,64}}};
    uint32_t tested = 0;
    for (bool bf16 : {false, true}) {
      for (const auto& s : shapes)
        for (uint32_t mask = 0; mask < 64; ++mask) { run(s[0], s[1], s[2], s[3], mask, bf16, false); ++tested; }
      for (uint32_t mask : {0u, 1u, 2u, 4u}) { run(16,16,2048,64,mask,bf16,true); ++tested; }
    }
    std::cout << "{\"status\":\"passed\",\"host_semantic_cases\":" << tested
      << ",\"npu_executed\":false,\"cann_compiled\":false,\"dma_read\":" << AscendC::counts.dma_read
      << ",\"pad_read\":" << AscendC::counts.pad_read << ",\"dma_write\":" << AscendC::counts.dma_write
      << ",\"pad_write\":" << AscendC::counts.pad_write << "}\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
