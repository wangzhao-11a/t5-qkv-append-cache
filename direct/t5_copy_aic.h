#pragma once
#include "kernel_operator.h"

// Large aligned K-cache copies use cube cores to add independent read engines.
class T5CopyAic {
 public:
  __aicore__ inline void Init(GM_ADDR packed, GM_ADDR pastKey, GM_ADDR key,
                              uint32_t b, uint32_t h, uint32_t l, uint32_t d,
                              uint32_t tile, uint32_t total, AscendC::TPipe* pipe) {
    batch_ = b; heads_ = h; length_ = l; dim_ = d; tile_ = tile; total_ = total;
    qSize_ = uint32_t(b) * h * d; cacheSize_ = qSize_ * (l + 1);
    packed_.SetGlobalBuffer((__gm__ uint16_t*)packed, 3 * qSize_);
    pk_.SetGlobalBuffer((__gm__ uint16_t*)pastKey, qSize_ * l);
    k_.SetGlobalBuffer((__gm__ uint16_t*)key, cacheSize_);
    k_.SetL2CacheHint(AscendC::CacheMode::CACHE_MODE_DISABLE);
    pipe->InitBuffer(queue_, 2, tile_ * sizeof(uint16_t));
  }

  __aicore__ inline void Process() {
    for (uint32_t work = AscendC::GetBlockIdx(); work < total_; work += AscendC::GetBlockNum())
      Cache(work);
  }

 private:
  __aicore__ inline uint32_t Min(uint32_t a, uint32_t b) { return a < b ? a : b; }

  __aicore__ inline void Copy(AscendC::GlobalTensor<uint16_t>& src, uint32_t srcOffset,
                              AscendC::GlobalTensor<uint16_t>& dst, uint32_t dstOffset, uint32_t n) {
    auto local = queue_.AllocTensor<uint16_t>();
    AscendC::DataCopy(local, src[srcOffset], n);
    queue_.EnQue(local);
    local = queue_.DeQue<uint16_t>();
    AscendC::DataCopy(dst[dstOffset], local, n);
    queue_.FreeTensor(local);
  }

  __aicore__ inline void Cache(uint32_t tileId) {
    const uint32_t hd = uint32_t(heads_) * dim_;
    const uint32_t oldRow = uint32_t(length_) * dim_, row = oldRow + dim_;
    uint32_t pos = uint32_t(tileId) * tile_, end = Min(pos + tile_, cacheSize_);
    while (pos < end) {
      const uint32_t head = pos / row, within = pos % row;
      uint32_t n;
      if (within < oldRow) {
        n = Min(end - pos, oldRow - within);
        Copy(pk_, head * oldRow + within, k_, pos, n);
      } else {
        n = Min(end - pos, row - within);
        const uint32_t b = head / heads_, h = head % heads_;
        Copy(packed_, b * 3 * hd + hd + h * dim_ + within - oldRow, k_, pos, n);
      }
      pos += n;
    }
  }

  uint32_t batch_, heads_, length_, dim_, tile_, total_, qSize_, cacheSize_;
  AscendC::GlobalTensor<uint16_t> packed_, pk_, k_;
  AscendC::TQue<AscendC::QuePosition::A1, 2> queue_;
};
