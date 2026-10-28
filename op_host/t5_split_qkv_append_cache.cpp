#include "t5_split_qkv_append_cache_tiling.h"
#include "../common/t5_plan.h"
#include "register/op_def_registry.h"
#include "tiling/platform/platform_ascendc.h"

namespace {
template <class Shape> bool ShapesOK(const Shape& q, const Shape& k, const Shape& v,
                                    int64_t hAttr, int64_t dAttr) {
  if (q.GetDimNum() != 3 || k.GetDimNum() != 4 || v.GetDimNum() != 4) return false;
  for (size_t i = 0; i < 4; ++i) if (k.GetDim(i) != v.GetDim(i)) return false;
  const int64_t b = k.GetDim(0), h = k.GetDim(1), l = k.GetDim(2), d = k.GetDim(3);
  return t5qkv::ValidShape(b, h, l, d) && h == hAttr && d == dAttr &&
         q.GetDim(0) == b && q.GetDim(1) == 1 && q.GetDim(2) == 3 * h * d;
}
}
namespace optiling {
static ge::graphStatus Tiling(gert::TilingContext* ctx) {
  const auto* qs = ctx->GetInputShape(0); const auto* ks = ctx->GetInputShape(1);
  const auto* vs = ctx->GetInputShape(2); const auto* attrs = ctx->GetAttrs();
  if (!qs || !ks || !vs || !attrs) return ge::GRAPH_FAILED;
  const auto* h = attrs->GetAttrPointer<int64_t>(0); const auto* d = attrs->GetAttrPointer<int64_t>(1);
  if (!h || !d || !ShapesOK(qs->GetStorageShape(), ks->GetStorageShape(), vs->GetStorageShape(), *h, *d))
    return ge::GRAPH_FAILED;
  auto dtype = ctx->GetInputDesc(0)->GetDataType();
  if (dtype != ge::DT_FLOAT16 && dtype != ge::DT_BF16) return ge::GRAPH_FAILED;
  for (int i = 0; i < 3; ++i) {
    if (ctx->GetInputDesc(i)->GetDataType() != dtype ||
        ctx->GetInputDesc(i)->GetStorageFormat() != ge::FORMAT_ND ||
        ctx->GetOutputDesc(i)->GetDataType() != dtype ||
        ctx->GetOutputDesc(i)->GetStorageFormat() != ge::FORMAT_ND) return ge::GRAPH_FAILED;
  }
  const auto& k = ks->GetStorageShape();
  const auto b = k.GetDim(0), l = k.GetDim(2);
  for (int i = 0; i < 3; ++i) {
    const auto* out = ctx->GetOutputShape(i);
    if (!out) return ge::GRAPH_FAILED;
    const auto& s = out->GetStorageShape();
    if (s.GetDimNum() != 4 || s.GetDim(0) != b || s.GetDim(1) != *h ||
        s.GetDim(2) != (i == 0 ? 1 : l + 1) || s.GetDim(3) != *d) return ge::GRAPH_FAILED;
  }
  auto platform = platform_ascendc::PlatformAscendC(ctx->GetPlatformInfo());
  uint32_t cores = platform.GetCoreNumAiv();
  if (!cores) return ge::GRAPH_FAILED;
  if (cores > t5qkv::kMaxVectorCores) cores = t5qkv::kMaxVectorCores;
  auto p = t5qkv::MakePlan(b, *h, l, *d, cores);
  T5SplitQkvAppendCacheTilingData t;
  t.set_batch(p.batch); t.set_heads(p.heads); t.set_length(p.length); t.set_dim(p.dim);
  t.set_tileElements(p.tileElements); t.set_queryTiles(p.queryTiles);
  t.set_cacheTiles(p.cacheTiles); t.set_totalTiles(p.totalTiles);
  ctx->SetBlockDim(p.blocks); ctx->SetTilingKey(0);
  t.SaveToBuffer(ctx->GetRawTilingData()->GetData(), ctx->GetRawTilingData()->GetCapacity());
  ctx->GetRawTilingData()->SetDataSize(t.GetDataSize());
  ctx->GetWorkspaceSizes(1)[0] = 0;
  return ge::GRAPH_SUCCESS;
}
}
namespace ge {
static graphStatus InferShape(gert::InferShapeContext* ctx) {
  const auto* q = ctx->GetInputShape(0); const auto* k = ctx->GetInputShape(1);
  const auto* v = ctx->GetInputShape(2); const auto* attrs = ctx->GetAttrs();
  if (!q || !k || !v || !attrs) return GRAPH_FAILED;
  const auto* h = attrs->GetAttrPointer<int64_t>(0); const auto* d = attrs->GetAttrPointer<int64_t>(1);
  if (!h || !d || !ShapesOK(*q, *k, *v, *h, *d)) return GRAPH_FAILED;
  for (int i = 0; i < 3; ++i) {
    auto* out = ctx->GetOutputShape(i);
    if (!out) return GRAPH_FAILED;
    *out = *k;
    out->SetDim(2, i == 0 ? 1 : k->GetDim(2) + 1);
  }
  return GRAPH_SUCCESS;
}
static graphStatus InferType(gert::InferDataTypeContext* ctx) {
  const auto type = ctx->GetInputDataType(0);
  if ((type != DT_FLOAT16 && type != DT_BF16) ||
      ctx->GetInputDataType(1) != type || ctx->GetInputDataType(2) != type) return GRAPH_FAILED;
  for (int i = 0; i < 3; ++i) ctx->SetOutputDataType(i, type);
  return GRAPH_SUCCESS;
}
}
namespace ops {
class T5SplitQkvAppendCache : public OpDef {
 public:
  explicit T5SplitQkvAppendCache(const char* name) : OpDef(name) {
    for (const char* input : {"qkv", "past_key", "past_value"})
      this->Input(input).ParamType(REQUIRED).DataType({ge::DT_FLOAT16, ge::DT_BF16})
          .Format({ge::FORMAT_ND, ge::FORMAT_ND}).UnknownShapeFormat({ge::FORMAT_ND, ge::FORMAT_ND});
    for (const char* output : {"query", "key", "value"})
      this->Output(output).ParamType(REQUIRED).DataType({ge::DT_FLOAT16, ge::DT_BF16})
          .Format({ge::FORMAT_ND, ge::FORMAT_ND}).UnknownShapeFormat({ge::FORMAT_ND, ge::FORMAT_ND});
    this->Attr("head_num").AttrType(REQUIRED).Int();
    this->Attr("head_dim").AttrType(REQUIRED).Int();
    this->SetInferShape(ge::InferShape).SetInferDataType(ge::InferType);
    this->AICore().SetTiling(optiling::Tiling).AddConfig("ascend910_93");
  }
};
OP_ADD(T5SplitQkvAppendCache);
}
