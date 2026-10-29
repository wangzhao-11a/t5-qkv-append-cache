#pragma once
#include "kernel_operator.h"

// All tensors are deliberately interpreted as uint16_t. No FP arithmetic/casts.
constexpr uint32_t kQueueDepth = 2;
// Host validation bounds every tensor to <2^28 elements; all linear indices and
// products below fit uint32. Avoid software 64-bit division in per-tile loops.
class T5Copy {
 public:
  __aicore__ inline void Init(GM_ADDR packed, GM_ADDR pastKey, GM_ADDR pastValue,
                             GM_ADDR query, GM_ADDR key, GM_ADDR value,
                             uint32_t b, uint32_t h, uint32_t l, uint32_t d,
                             uint32_t tile, uint32_t qt, uint32_t kt, uint32_t total,
                             AscendC::TPipe* pipe) {
    batch_ = b; heads_ = h; length_ = l; dim_ = d;
    tile_ = tile; queryTiles_ = qt; cacheTiles_ = kt; total_ = total;
    qSize_ = uint32_t(b) * h * d; cacheSize_ = qSize_ * (l + 1);
    packed_.SetGlobalBuffer((__gm__ uint16_t*)packed, 3 * qSize_);
    // L=0 never dereferences these possibly null empty-storage pointers.
    pk_.SetGlobalBuffer((__gm__ uint16_t*)pastKey, qSize_ * l);
    pv_.SetGlobalBuffer((__gm__ uint16_t*)pastValue, qSize_ * l);
    q_.SetGlobalBuffer((__gm__ uint16_t*)query, qSize_);
    k_.SetGlobalBuffer((__gm__ uint16_t*)key, cacheSize_);
    v_.SetGlobalBuffer((__gm__ uint16_t*)value, cacheSize_);
    // Large write-only outputs otherwise compete with cache input reads in L2.
    // The default cache policy was measured at 216 us versus 94 us for bypass.
    if (cacheSize_ >= 16 * 1024 * 1024) {
      pk_.SetL2CacheHint(AscendC::CacheMode::CACHE_MODE_DISABLE);
      pv_.SetL2CacheHint(AscendC::CacheMode::CACHE_MODE_DISABLE);
      k_.SetL2CacheHint(AscendC::CacheMode::CACHE_MODE_DISABLE);
      v_.SetL2CacheHint(AscendC::CacheMode::CACHE_MODE_DISABLE);
    }
    pipe->InitBuffer(queue_, kQueueDepth, tile_ * sizeof(uint16_t));
  }

  __aicore__ inline void Process() {
    for (uint32_t work = AscendC::GetBlockIdx(); work < total_; work += AscendC::GetBlockNum()) {
      if (work < queryTiles_) Query(work);
      else if (work < queryTiles_ + cacheTiles_) Cache(work - queryTiles_, false);
      else Cache(work - queryTiles_ - cacheTiles_, true);
    }
  }

 private:
  __aicore__ inline uint32_t Min(uint32_t a, uint32_t b) { return a < b ? a : b; }

  __aicore__ inline void Copy(AscendC::GlobalTensor<uint16_t>& src, uint32_t srcOffset,
                             AscendC::GlobalTensor<uint16_t>& dst, uint32_t dstOffset, uint32_t n) {
    if (!n) return;
    auto local = queue_.AllocTensor<uint16_t>();
    // The plain DMA path requires a complete 32-byte block count. Inspect the
    // actual GM addresses too: contiguous storage-offset views may be unaligned.
    const bool aligned = ((n & 15) == 0) &&
        ((reinterpret_cast<uint64_t>(src.GetPhyAddr() + srcOffset) & 31) == 0) &&
        ((reinterpret_cast<uint64_t>(dst.GetPhyAddr() + dstOffset) & 31) == 0);
    AscendC::DataCopyExtParams params{1, n * uint32_t(sizeof(uint16_t)), 0, 0, 0};
    AscendC::DataCopyPadExtParams<uint16_t> padding{false, 0, 0, 0};
    if (aligned) AscendC::DataCopy(local, src[srcOffset], n);
    else AscendC::DataCopyPad(local, src[srcOffset], params, padding);
    queue_.EnQue(local);
    local = queue_.DeQue<uint16_t>();
    if (aligned) AscendC::DataCopy(dst[dstOffset], local, n);
    else AscendC::DataCopyPad(dst[dstOffset], local, params);
    queue_.FreeTensor(local);
  }

  __aicore__ inline void Query(uint32_t tileId) {
    uint32_t pos = uint32_t(tileId) * tile_, end = Min(pos + tile_, qSize_);
    const uint32_t hd = uint32_t(heads_) * dim_;
    while (pos < end) {
      const uint32_t b = pos / hd, within = pos % hd;
      const uint32_t n = Min(end - pos, hd - within);
      Copy(packed_, b * 3 * hd + within, q_, pos, n);
      pos += n;
    }
  }

  __aicore__ inline void Cache(uint32_t tileId, bool isValue) {
    auto& past = isValue ? pv_ : pk_;
    auto& out = isValue ? v_ : k_;
    const uint32_t hd = uint32_t(heads_) * dim_;
    const uint32_t oldRow = uint32_t(length_) * dim_, row = oldRow + dim_;
    uint32_t pos = uint32_t(tileId) * tile_, end = Min(pos + tile_, cacheSize_);
    if (length_ == 0) {
      // Empty cache is a whole HD segment per batch, not H separate tokens.
      while (pos < end) {
        const uint32_t b = pos / hd, within = pos % hd;
        const uint32_t n = Min(end - pos, hd - within);
        Copy(packed_, b * 3 * hd + (isValue ? 2 : 1) * hd + within, out, pos, n);
        pos += n;
      }
      return;
    }
    // No tile writes outside its own aligned output interval. A tile can cross
    // rows, but every fragment of the same 32B block belongs to one core.
    while (pos < end) {
      const uint32_t head = pos / row, within = pos % row;
      uint32_t n;
      if (within < oldRow) {
        n = Min(end - pos, oldRow - within);
        Copy(past, head * oldRow + within, out, pos, n);
      } else {
        n = Min(end - pos, row - within);
        const uint32_t b = head / heads_, h = head % heads_;
        const uint32_t src = b * 3 * hd + (isValue ? 2 : 1) * hd + h * dim_ + within - oldRow;
        Copy(packed_, src, out, pos, n);
      }
      pos += n;
    }
  }

  uint32_t batch_, heads_, length_, dim_, tile_, queryTiles_, cacheTiles_, total_;
  uint32_t qSize_, cacheSize_;
  AscendC::GlobalTensor<uint16_t> packed_, pk_, pv_, q_, k_, v_;
  AscendC::TQueBind<AscendC::QuePosition::VECIN, AscendC::QuePosition::VECOUT, kQueueDepth> queue_;
};
