#include "t5_copy.h"
extern "C" __global__ __aicore__ void t5_split_qkv_append_cache(
    GM_ADDR qkv, GM_ADDR pk, GM_ADDR pv, GM_ADDR q, GM_ADDR k, GM_ADDR v,
    GM_ADDR workspace, GM_ADDR tiling) {
  KERNEL_TASK_TYPE_DEFAULT(KERNEL_TYPE_AIV_ONLY);
  GET_TILING_DATA(t, tiling);
  AscendC::TPipe pipe;
  T5Copy op;
  op.Init(qkv, pk, pv, q, k, v, t.batch, t.heads, t.length, t.dim,
          t.tileElements, t.queryTiles, t.cacheTiles, t.totalTiles, &pipe);
  op.Process();
}
