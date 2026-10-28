#pragma once
#include "register/tilingdata_base.h"
namespace optiling {
BEGIN_TILING_DATA_DEF(T5SplitQkvAppendCacheTilingData)
  TILING_DATA_FIELD_DEF(uint32_t, batch);
  TILING_DATA_FIELD_DEF(uint32_t, heads);
  TILING_DATA_FIELD_DEF(uint32_t, length);
  TILING_DATA_FIELD_DEF(uint32_t, dim);
  TILING_DATA_FIELD_DEF(uint32_t, tileElements);
  TILING_DATA_FIELD_DEF(uint32_t, queryTiles);
  TILING_DATA_FIELD_DEF(uint32_t, cacheTiles);
  TILING_DATA_FIELD_DEF(uint32_t, totalTiles);
END_TILING_DATA_DEF;
REGISTER_TILING_DATA_CLASS(T5SplitQkvAppendCache, T5SplitQkvAppendCacheTilingData)
}
