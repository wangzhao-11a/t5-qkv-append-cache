#pragma once
// CPU test adapter only: no CANN execution, cache aliases, or hardware timing.
#include <algorithm>
#include <cstdint>
#include <cstring>
#include <stdexcept>
#include <vector>

#define __aicore__
#define __gm__
using GM_ADDR = uint8_t*;

namespace AscendC {
inline void require(bool condition, const char* message) {
  if (!condition) throw std::runtime_error(message);
}
struct Counts {
  uint64_t dma_read = 0, pad_read = 0, dma_write = 0, pad_write = 0;
};
inline Counts counts;
inline uint32_t block_index = 0, block_count = 1;
inline uint32_t GetBlockIdx() { return block_index; }
inline uint32_t GetBlockNum() { return block_count; }
enum class CacheMode { CACHE_MODE_DISABLE };
enum class QuePosition { VECIN, VECOUT };
template<class T> struct Span { T* data; size_t elements; };
template<class T> class GlobalTensor {
 public:
  void SetGlobalBuffer(T* data, size_t elements) { data_ = data; size_ = elements; }
  T* GetPhyAddr() const { return data_; }
  void SetL2CacheHint(CacheMode) {}  // Deliberately does not model address aliases.
  Span<T> operator[](size_t offset) {
    require(offset <= size_, "GM offset exceeds tensor");
    return {data_ + offset, size_ - offset};
  }
 private:
  T* data_ = nullptr;
  size_t size_ = 0;
};
struct QueueState {
  int stage = 0;
  size_t capacity = 0, loaded = 0;
};
template<class T> struct LocalTensor { T* data; QueueState* state; };
template<QuePosition In, QuePosition Out, uint32_t Depth> class TQueBind {
 public:
  void init(size_t bytes) {
    require(bytes > 0 && bytes % 32 == 0, "UB capacity must be 32B aligned");
    state_.capacity = bytes;
    bytes_.resize(bytes + 31);
    data_ = reinterpret_cast<uint8_t*>((reinterpret_cast<uintptr_t>(bytes_.data()) + 31) & ~uintptr_t{31});
  }
  template<class T> LocalTensor<T> AllocTensor() {
    require(state_.stage == 0, "queue allocation before previous release");
    state_.stage = 1;
    state_.loaded = 0;
    return {reinterpret_cast<T*>(data_), &state_};
  }
  template<class T> void EnQue(LocalTensor<T> tensor) {
    require(tensor.state == &state_ && state_.stage == 2, "enqueue before load completion");
    state_.stage = 3;
  }
  template<class T> LocalTensor<T> DeQue() {
    require(state_.stage == 3, "dequeue without enqueue");
    state_.stage = 4;
    return {reinterpret_cast<T*>(data_), &state_};
  }
  template<class T> void FreeTensor(LocalTensor<T> tensor) {
    require(tensor.state == &state_ && state_.stage == 5, "release before write completion");
    state_.stage = 0;
  }
 private:
  std::vector<uint8_t> bytes_;
  uint8_t* data_ = nullptr;
  QueueState state_;
};
class TPipe {
 public:
  template<class Queue> void InitBuffer(Queue& queue, uint32_t depth, uint32_t bytes) {
    require(depth == 2 && bytes <= 65536, "unexpected queue UB budget");
    queue.init(bytes);
  }
};
struct DataCopyExtParams {
  uint32_t blockCount, blockLen, srcStride, dstStride, reserved;
};
template<class T> struct DataCopyPadExtParams {
  bool isPad;
  uint32_t leftPadding, rightPadding;
  T paddingValue;
};
template<class T> void load(LocalTensor<T> dst, Span<T> src, size_t bytes, bool padded) {
  require(dst.state->stage == 1, "load outside allocated queue stage");
  require(bytes > 0 && bytes <= src.elements * sizeof(T), "G2L reads beyond tensor");
  const size_t written = padded ? (bytes + 31) / 32 * 32 : bytes;
  require(written <= dst.state->capacity, "G2L exceeds UB capacity");
  require(reinterpret_cast<uintptr_t>(dst.data) % 32 == 0, "UB start unaligned");
  if (!padded) require(bytes % 32 == 0 && reinterpret_cast<uintptr_t>(src.data) % 32 == 0, "ordinary G2L DMA unaligned");
  std::memcpy(dst.data, src.data, bytes);
  if (written > bytes) std::memset(reinterpret_cast<uint8_t*>(dst.data) + bytes, 0, written - bytes);
  dst.state->loaded = bytes;
  dst.state->stage = 2;
  (padded ? counts.pad_read : counts.dma_read)++;
}
template<class T> void store(Span<T> dst, LocalTensor<T> src, size_t bytes, bool padded) {
  require(src.state->stage == 4, "store before queue dequeue");
  require(bytes > 0 && bytes <= dst.elements * sizeof(T), "L2G writes beyond tensor");
  require(bytes == src.state->loaded && bytes <= src.state->capacity, "L2G size differs from logical load");
  require(reinterpret_cast<uintptr_t>(src.data) % 32 == 0, "UB start unaligned");
  if (!padded) require(bytes % 32 == 0 && reinterpret_cast<uintptr_t>(dst.data) % 32 == 0, "ordinary L2G DMA unaligned");
  std::memcpy(dst.data, src.data, bytes);
  src.state->stage = 5;
  (padded ? counts.pad_write : counts.dma_write)++;
}
inline void single_block(const DataCopyExtParams& p) {
  require(p.blockCount == 1 && !p.srcStride && !p.dstStride && !p.reserved, "unsupported multi-block/stride DMA in host adapter");
}
template<class T> void DataCopy(LocalTensor<T> dst, Span<T> src, uint32_t n) { load(dst, src, n * sizeof(T), false); }
template<class T> void DataCopy(Span<T> dst, LocalTensor<T> src, uint32_t n) { store(dst, src, n * sizeof(T), false); }
template<class T> void DataCopyPad(LocalTensor<T> dst, Span<T> src, DataCopyExtParams p, DataCopyPadExtParams<T> pad) {
  single_block(p);
  require(!pad.isPad && !pad.leftPadding && !pad.rightPadding, "explicit padding unsupported by test adapter");
  load(dst, src, p.blockLen, true);
}
template<class T> void DataCopyPad(Span<T> dst, LocalTensor<T> src, DataCopyExtParams p) {
  single_block(p);
  store(dst, src, p.blockLen, true);
}
}  // namespace AscendC
