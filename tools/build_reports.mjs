import fs from 'node:fs/promises';
import path from 'node:path';
import {SpreadsheetFile,Workbook} from '@oai/artifact-tool';
const root=path.resolve(import.meta.dirname,'..');
const read=async name=>JSON.parse(await fs.readFile(path.join(root,name),'utf8'));
const maybe=async name=>{try{return await read(name);}catch(e){if(e.code==='ENOENT')return null;throw e;}};
const cases=await read('reference/case.json');
const req=await read('reference/coverage_requirements.json');
const targets=await read('reference/performance_targets.json');
const pub=await maybe('reports/public_accuracy.json');
const ext=await maybe('reports/extended_accuracy.json');
const eng=await maybe('reports/engineering.json');
const mem=await maybe('reports/memory.json');
const perf=await maybe('reports/performance.json');
const base=await maybe('reports/baseline_comparison.json');
const status=await maybe('reports/STATUS.json');
const sourceLabel=status?.report_source_commit?` 数据对应提交 ${status.report_source_commit.slice(0,12)}。`:'';
const out=path.join(root,'task_submission');await fs.mkdir(out,{recursive:true});
await fs.mkdir(path.join(root,'reports/previews'),{recursive:true});
const state=x=>x?.status==='passed'?'通过':x?.status==='failed'?'失败':'待实机验证';
const formatShape=c=>`(${c.input_desc[1].shape.join(', ')})`;
const dtype=c=>c.input_desc[0].data_type;
const getRecord=(report,id,entry)=>report?.records?.find(x=>x.case_name===id&&x.entry===entry);
function makeSheet(wb,name,title,summary,headers,rows,widths){
  const s=wb.worksheets.add(name); const n=headers.length;const last=String.fromCharCode(64+n);
  s.getRange(`A1:${last}${rows.length+5}`).format.font={name:'Arial',size:10};
  s.getRange('A1').values=[[title]];s.getRange('A1').format.font={name:'Arial',size:15,bold:true};
  s.getRange('A2').values=[[summary+sourceLabel]];s.getRange('A2').format.font={name:'Arial',size:10,color:'#9A3412'};
  s.getRange('A3').values=[['确认采用当前环境验收：Ascend910_9382，CANN 9.1.0，驱动 26.1.1；任务书指定驱动为 25.5.t6.b001。']];
  s.getRange('A3').format.font={name:'Arial',size:10,color:'#9A3412'};
  s.getRangeByIndexes(3,0,1,n).values=[headers];
  s.getRangeByIndexes(3,0,1,n).format={fill:'#263D59',font:{name:'Arial',size:10,bold:true,color:'#FFFFFF'},wrapText:true,rowHeight:34,verticalAlignment:'center'};
  if(rows.length)s.getRangeByIndexes(4,0,rows.length,n).values=rows;
  s.getRangeByIndexes(4,0,Math.max(rows.length,1),n).format.rowHeight=30;
  s.getRangeByIndexes(4,0,Math.max(rows.length,1),n).format.verticalAlignment='center';
  for(let i=0;i<n;i++)s.getRangeByIndexes(0,i,rows.length+5,1).format.columnWidthPx=widths[i]??130;
  s.freezePanes.freezeRows(4);
  s.getRange(`C5:C${rows.length+4}`).conditionalFormats.add('containsText',{text:'待实机',format:{fill:'#FFF3CD',font:{color:'#8A4B0F'}}});
  s.getRange(`C5:C${rows.length+4}`).conditionalFormats.add('containsText',{text:'失败',format:{fill:'#FEE2E2',font:{color:'#991B1B'}}});
  s.getRange(`C5:C${rows.length+4}`).conditionalFormats.add('containsText',{text:'通过',format:{fill:'#DCFCE7',font:{color:'#166534'}}});
  s.getRange(`C5:C${rows.length+4}`).dataValidation={rule:{type:'list',values:['通过','失败','待实机验证']}};
  return s;
}
async function save(wb,file,key){
  wb.recalculate();
  console.log((await wb.inspect({kind:'match',searchTerm:'#REF!|#DIV/0!|#VALUE!|#NAME\\?|#NUM!',options:{useRegex:true,maxResults:20},maxChars:2000})).ndjson);
  for(let i=0;i<wb.worksheets.items.length;i++){
    const s=wb.worksheets.getItemAt(i);
    console.log((await wb.inspect({kind:'table',range:`'${s.name}'!A4:H7`,include:'values,formulas',tableMaxRows:4,tableMaxCols:8,maxChars:1800})).ndjson);
    const png=await wb.render({sheetName:s.name,range:'A1:H9',scale:1,format:'png'});
    await fs.writeFile(path.join(root,`reports/previews/${key}_${i}.png`),new Uint8Array(await png.arrayBuffer()));
  }
  await(await SpreadsheetFile.exportXlsx(wb)).save(path.join(out,file));
}
const aw=Workbook.create();const ar=[];
for(const c of cases){for(const entry of ['run','run_direct']){
  const r=entry==='run'?pub?.cases?.find(x=>x.case_name===c.case_name):getRecord(ext,c.case_name,entry);
  ar.push([formatShape(c),dtype(c),state(r),'',r?'逐位检查记录见原始 JSON':'尚无 NPU 记录',c.case_name,entry,...[0,1,2].map(i=>r?.outputs?.[i]?.bit_mismatches??null)]);
}}
for(const id of req.extra_input_case_ids){const c=cases.find(x=>x.case_name===id.split('__extra_seed_')[0]);for(const entry of req.extra_entries){
  const r=getRecord(ext,id,entry);ar.push([formatShape(c),dtype(c),state(r),'','固定额外种子；存储偏移 1',id,entry,...[0,1,2].map(i=>r?.outputs?.[i]?.bit_mismatches??null)]);
}}
makeSheet(aw,'精度','T5 QKV 拆分与缓存追加：精度',`47 个有效输入，两个入口共 94 条记录；NPU 已记录 ${ar.filter(x=>x[2]!=='待实机验证').length} 条。CPU 地址模型结果不计入 NPU 通过数。`,
  ['shape (B,H,L,D)','dtype','精度是否通过','Ascend 截图','解释说明','用例 ID','入口','Q 位不一致数','K 位不一致数','V 位不一致数'],ar,[190,105,120,160,255,540,110,130,130,130]);
const er=[];
for(const id of req.negative_scenarios)for(const entry of req.negative_entries){const r=getRecord(ext,id,entry);er.push([id,entry,state(r),r?.rejection??'尚无 NPU 记录']);}
for(const id of req.verifier_checks){const r=getRecord(ext,id,'verifier');er.push([id,'verifier',state(r),'原包验证器反例检查']);}
for(const id of req.stream_case_ids){const r=getRecord(eng,id,'prepared_stream');er.push([id,'prepared_stream',state(r),'每条 stream 至少 10 次准备后调用']);}
for(const id of ['sequential_cache_append','output_lifetime','input_release_cross_stream'])for(const e of ['run','run_direct'])er.push([id,e,state(getRecord(eng,id,e)),'结果和原始记录见工程日志']);
for(let i=0;i<5;i++)er.push([`prepared_metadata_${i}`,'prepare',state(getRecord(eng,`prepared_metadata_${i}`,'prepare')),'准备元数据不匹配应拒绝']);
makeSheet(aw,'工程覆盖','非法输入和生命周期检查','28 类非法场景 × 3 个入口 = 84 条检查；stream、生命周期与连续追加另列。',
  ['场景 ID','入口','状态','解释说明'],er,[540,150,130,530]);
await save(aw,'2.1 精度自验证报告.xlsx','accuracy');

const pw=Workbook.create();const pr=[];
for(const t of targets.cases){const c=cases.find(x=>x.case_name===t.case_name);const r=perf?.cases?.find(x=>x.case_name===t.case_name)?.results?.custom;
  const b=base?.cases?.find(x=>x.case_name===t.case_name)?.results?.views_concat_q_copy;
  const paired=base?.cases?.find(x=>x.case_name===t.case_name)?.results?.custom;
  pr.push([formatShape(c),dtype(c),r?(r.wall_us_median<=t.max_wall_us?'通过':'失败'):'待实机验证','',b?.wall_us_median??null,r?.wall_us_median??null,null,'50 次预热；5 轮 × 200 次。比值=P/E。',t.case_name,t.max_wall_us,...Array.from({length:5},(_,i)=>r?.wall_us_rounds?.[i]??null),paired?.wall_us_median??null]);
}
const ps=makeSheet(pw,'性能','T5 QKV 拆分与缓存追加：性能',`固定微秒上限通过 ${pr.filter(x=>x[2]==='通过').length}/10；失败 ${pr.filter(x=>x[2]==='失败').length}/10。同机耗时比不替代固定门槛。`,
  ['shape (B,H,L,D)','dtype','性能是否通过','Ascend 截图','标杆算子耗时 (μs)','正式入口耗时 (μs)','同轮耗时比','解释说明','用例 ID','固定上限 (μs)','第 1 轮 (μs)','第 2 轮 (μs)','第 3 轮 (μs)','第 4 轮 (μs)','第 5 轮 (μs)','同机对照自定义 (μs)'],pr,[190,105,120,160,150,150,105,310,540,130,130,130,130,130,130,180]);
for(let i=0;i<pr.length;i++){const row=i+5;ps.getRange(`G${row}`).formulas=[[`=IF(COUNT(E${row},P${row})=2,P${row}/E${row},"")`]];}
ps.getRange(`E5:G${pr.length+4}`).setNumberFormat('0.000');
await save(pw,'3.1 性能自验证报告.xlsx','performance');

const mw=Workbook.create();const mr=[];
for(const id of req.performance_case_ids){const c=cases.find(x=>x.case_name===id);const [b,h,l,d]=c.input_desc[1].shape;const bytes=2*b*h*d*(2*l+3);
for(const e of ['run','run_direct']){const r=getRecord(mem,id,e);mr.push([formatShape(c),dtype(c),state(r),'',bytes,r?.peak_increment??null,null,'活跃张量字节；未实测峰值留空',id,e,r?.workspace_bytes??null,r?.before??null,r?.after_each_release?.at(-1)??null]);}}
const ms=makeSheet(mw,'内存','T5 QKV 拆分与缓存追加：内存','按任务书改用活跃张量字节数：峰值增量 ≤ 输出字节数 + 16 KiB；全局工作区须为 0。',
  ['shape (B,H,L,D)','dtype','内存是否通过','Ascend 截图','输出字节数（计算）','实测峰值增量 (字节)','允许上限 (字节)','解释说明','用例 ID','入口','工作区 (字节)','调用前活跃字节','20 次后活跃字节'],mr,[190,105,120,160,165,165,165,290,540,110,130,150,150]);
for(let i=0;i<mr.length;i++){const row=i+5;ms.getRange(`G${row}`).formulas=[[`=E${row}+16384`]];}
ms.getRange(`E5:G${mr.length+4}`).setNumberFormat('#,##0');
await save(mw,'4.1 内存自验证报告.xlsx','memory');
console.log('Exported three task report workbooks.');
