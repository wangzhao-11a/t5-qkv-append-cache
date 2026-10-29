#pragma once
#include <cstdint>

// Plain scalar ABI shared by tiling, the direct launcher and CPU mapping tests.
namespace t5qkv {
constexpr uint32_t kTileElements = 24576;  // 48 KiB; three DMA buffers = 144 KiB UB.
constexpr uint32_t kMaxVectorCores = 48;
struct Plan {
  uint32_t batch, heads, length, dim;
  uint32_t tileElements, queryTiles, cacheTiles, totalTiles, blocks;
};
inline bool ValidShape(int64_t b, int64_t h, int64_t l, int64_t d) {
  if (b < 1 || b > 64 || h < 1 || h > 128 || l < 0 || l > 8192 || d < 1 || d > 256) return false;
  return b * h * d * (2 * l + 3) <= (int64_t{1} << 28);
}
inline Plan MakePlan(uint32_t b, uint32_t h, uint32_t l, uint32_t d,
                     uint32_t cores = kMaxVectorCores) {
  Plan p{b, h, l, d, kTileElements, 0, 0, 0, 0};
  const uint64_t q = uint64_t{b} * h * d;
  const uint64_t kv = q * (l + 1);
  p.queryTiles = (q + p.tileElements - 1) / p.tileElements;
  p.cacheTiles = (kv + p.tileElements - 1) / p.tileElements;
  p.totalTiles = p.queryTiles + 2 * p.cacheTiles;
  // Small inputs still use one block per useful tile. Tile boundaries are 32B aligned.
  p.blocks = p.totalTiles < cores ? p.totalTiles : cores;
  return p;
}
}  // namespace t5qkv
