#include "../op_kernel/t5_copy.h"
#include "../common/t5_plan.h"

extern "C" __global__ __aicore__ void t5_direct_kernel(
    GM_ADDR qkv, GM_ADDR pk, GM_ADDR pv, GM_ADDR q, GM_ADDR k, GM_ADDR v,
    uint32_t b, uint32_t h, uint32_t l, uint32_t d, uint32_t tile,
    uint32_t qt, uint32_t kt, uint32_t total) {
  KERNEL_TASK_TYPE_DEFAULT(KERNEL_TYPE_AIV_ONLY);
  AscendC::TPipe pipe;
  T5Copy op;
  op.Init(qkv, pk, pv, q, k, v, b, h, l, d, tile, qt, kt, total, &pipe);
  op.Process();
}

#ifndef ASCENDC_CPU_DEBUG
extern "C" void t5LaunchDirect(void* stream, void* qkv, void* pk, void* pv,
                               void* q, void* k, void* v, uint32_t b,
                               uint32_t h, uint32_t l, uint32_t d) {
  const auto p = t5qkv::MakePlan(b, h, l, d);
  t5_direct_kernel<<<p.blocks, nullptr, stream>>>(
      (uint8_t*)qkv, (uint8_t*)pk, (uint8_t*)pv, (uint8_t*)q, (uint8_t*)k, (uint8_t*)v,
      b, h, l, d, p.tileElements, p.queryTiles, p.cacheTiles, p.totalTiles);
}
#endif
