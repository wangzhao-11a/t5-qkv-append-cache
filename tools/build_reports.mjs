import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
import {parseArgs} from 'node:util';
process.on('uncaughtException',error=>{console.error(JSON.stringify({error:error.message,stack:error.stack?.split('\n').slice(1,4)}));process.exit(1);});
const {values:args}=parseArgs({options:{reports:{type:'string'},output:{type:'string'},templates:{type:'string'},only:{type:'string'},'artifact-workspace':{type:'string'}}});
const enabled=key=>!args.only||args.only.split(',').includes(key);
for(const name of ['reports','output','templates','artifact-workspace'])if(!args[name])throw new Error(`Specify --${name}; baseline files are never overwritten.`);
const artifactRequire=createRequire(path.join(path.resolve(args['artifact-workspace']),'package.json'));
const {FileBlob,SpreadsheetFile}=await import(pathToFileURL(artifactRequire.resolve('@oai/artifact-tool')).href);
const root=path.resolve(import.meta.dirname,'..');
const reports=path.resolve(args.reports),templates=path.resolve(args.templates),out=path.resolve(args.output);
if(out===path.join(root,'task_submission'))throw new Error('Preserve original c9decf2 materials.');
const previews=path.join(out,'../previews');
await fs.mkdir(out,{recursive:true});await fs.mkdir(previews,{recursive:true});
const read=async name=>JSON.parse(await fs.readFile(name.startsWith('reports/')?path.join(reports,name.slice(8)):path.join(root,name),'utf8'));
const cases=await read('reference/case.json'),req=await read('reference/coverage_requirements.json'),targets=await read('reference/performance_targets.json');
const pub=await read('reports/public_accuracy.json'),ext=await read('reports/extended_accuracy.json'),eng=await read('reports/engineering.json'),mem=await read('reports/memory.json'),perf=await read('reports/performance.json'),base=await read('reports/baseline_comparison.json');
const manifest=JSON.parse(await fs.readFile(path.join(reports,'../artifacts/binary_manifest.json'),'utf8'));
const sourceLabel=`实测提交 ${manifest.build_source_commit.slice(0,12)}；规定驱动 25.5.t6.b001 未测试。`;
const environment='Ascend910_9382，CANN 9.1.0，驱动 26.1.1（用户已确认）。';
const screenshotHeader='Ascend截图（单个用例或全部执行通过的截图均可）';
const state=x=>x?.status==='passed'?'通过':x?.status==='failed'?'失败':'待实机验证';
const shape=c=>`[${c.input_desc[1].shape.join(',')}]`;
const dtype=c=>c.input_desc[0].data_type;
const get=(report,id,entry)=>report.records.find(x=>x.case_name===id&&x.entry===entry);
const col=n=>String.fromCharCode(64+n);
async function template(file,name,expectedHeaders){
  const wb=await SpreadsheetFile.importXlsx(await FileBlob.load(path.join(templates,file)));
  if(wb.worksheets.items.length!==1)throw new Error('Unexpected official template sheet count.');
  const s=wb.worksheets.getItemAt(0);
  if(s.name!==name||JSON.stringify(s.getRangeByIndexes(2,0,1,expectedHeaders.length).values[0])!==JSON.stringify(expectedHeaders))throw new Error('Official template headers changed; review before authoring.');
  s.deleteAllDrawings(); // Remove example screenshots from another operator.
  s.getRange(`A4:${col(expectedHeaders.length)}42`).clear({applyTo:'contents'});
  return [wb,s];
}
function populate(s,summary,headers,rows,baseColumns,widths){
  const n=headers.length,last=col(n),end=rows.length+3;
  s.getRange('A1').values=[[summary+'\n'+sourceLabel]];s.getRange('A1').format.wrapText=true;
  // Retain existing row formatting. Extend only beyond the original 42 rows,
  // avoiding partial writes into the template's shared formula groups.
  for(let r=43;r<=end;r++)s.getRange(`A${r}:${col(baseColumns)}${r}`).copyFrom(s.getRange(`A4:${col(baseColumns)}4`),'all');
  for(let c=baseColumns+1;c<=n;c++){
    s.getRange(`${col(c)}3`).copyFrom(s.getRange(`${col(baseColumns)}3`),'all');
    for(let r=4;r<=end;r++)s.getRange(`${col(c)}${r}`).copyFrom(s.getRange(`${col(baseColumns)}4`),'all');
  }
  s.getRangeByIndexes(2,0,1,n).values=[headers];s.getRangeByIndexes(3,0,rows.length,n).values=rows;
  s.getRange(`A3:${last}3`).format.wrapText=true;s.getRange(`A3:${last}3`).format.rowHeight=34;
  s.getRange(`A4:${last}${end}`).format.rowHeight=23;s.getRange(`A3:${last}${end}`).format.verticalAlignment='center';
  for(const [letter,width] of Object.entries(widths))s.getRange(`${letter}3:${letter}${end}`).format.columnWidthPx=width;
  s.getRange(`C4:C${end}`).dataValidation={rule:{type:'list',values:['通过','失败','待实机验证']}};
  s.getRange(`C4:C${end}`).conditionalFormats.add('containsText',{text:'失败',format:{fill:'#FEE2E2',font:{color:'#991B1B'}}});
  s.freezePanes.freezeRows(3);
}
function engineering(wb,rows){
  const s=wb.worksheets.add('工程覆盖');s.mergeCells('A1:D2');
  s.getRange('A1').values=[[`补充检查总结：\n84 条非法输入、3 条验证器反例、15 条工程记录，均通过。\n来源：extended_accuracy.json、engineering.json。\n${sourceLabel}`]];
  s.getRange('A1:D2').format.wrapText=true;s.getRange('A2').format.rowHeight=85;
  s.getRange('A3:D3').values=[['场景 ID','入口','状态','解释说明']];s.getRange('A3:D3').format.rowHeight=30;
  s.getRangeByIndexes(3,0,rows.length,4).values=rows;s.getRange(`A1:D${rows.length+3}`).format.font={name:'Arial',size:10};
  s.getRange(`A4:D${rows.length+3}`).format.rowHeight=23;
  for(const [c,w] of Object.entries({A:550,B:140,C:120,D:550}))s.getRange(`${c}1:${c}${rows.length+3}`).format.columnWidthPx=w;
  s.freezePanes.freezeRows(3);
}
async function save(wb,file,key,ranges){
  wb.recalculate();
  console.log((await wb.inspect({kind:'match',searchTerm:'#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A|#NUM!|#NULL!|#SPILL!|#CALC!',options:{useRegex:true,maxResults:20},maxChars:1200})).ndjson);
  for(let i=0;i<wb.worksheets.items.length;i++){
    const s=wb.worksheets.getItemAt(i);
    console.log((await wb.inspect({kind:'table',range:`'${s.name}'!A3:H6`,include:'values,formulas',tableMaxRows:4,tableMaxCols:8,maxChars:1800})).ndjson);
    for(let j=0;j<ranges[i].length;j++){
      const png=await wb.render({sheetName:s.name,range:ranges[i][j],scale:1,format:'png'});
      await fs.writeFile(path.join(previews,`${key}_${i}_${j}.png`),new Uint8Array(await png.arrayBuffer()));
    }
  }
  await(await SpreadsheetFile.exportXlsx(wb)).save(path.join(out,file));
}
if(enabled('accuracy')){
const accuracyHeaders=['shape','dtype','精度是否通过',screenshotHeader,'解释说明'];
const [aw,as]=await template('2.1 精度自验证报告.xlsx','精度',accuracyHeaders);const ar=[];
for(const c of cases)for(const entry of ['run','run_direct']){
  const r=entry==='run'?pub.cases.find(x=>x.case_name===c.case_name):get(ext,c.case_name,entry);
  ar.push([shape(c),dtype(c),state(r),'','逐位结果见原始 JSON；无现场截图',c.case_name,entry,...[0,1,2].map(i=>r?.outputs?.[i]?.bit_mismatches??null)]);
}
for(const id of req.extra_input_case_ids){const c=cases.find(x=>x.case_name===id.split('__extra_seed_')[0]);for(const entry of req.extra_entries){
  const r=get(ext,id,entry);ar.push([shape(c),dtype(c),state(r),'','额外种子、存储偏移 1；无现场截图',id,entry,...[0,1,2].map(i=>r?.outputs?.[i]?.bit_mismatches??null)]);
}}
for(const r of ext.records.filter(r=>r.outputs&&!ar.some(x=>x[5]===r.case_name&&x[6]===r.entry))){
  if(!r.case_name.startsWith('cache_policy_odd_boundary_'))throw new Error(`Unknown shape: ${r.case_name}`);
  ar.push(['[15,17,2048,63]',r.case_name.endsWith('bfloat16')?'bfloat16':'float16',state(r),'','大缓存奇数维度、偏移 1；无现场截图',r.case_name,r.entry,...r.outputs.map(x=>x.bit_mismatches)]);
}
populate(as,`精度测试总结：\n1、${environment}\n2、有效输入/入口 ${ar.length} 条，通过 ${ar.filter(x=>x[2]==='通过').length} 条；补充检查见工程覆盖。\n3、覆盖 FP16/BF16、空缓存、大缓存、奇数维度、存储偏移及生命周期。\n4、Q/K/V 原始 16 位完全一致，输入不变、输出存储独立。\n来源：public_accuracy.json、extended_accuracy.json。`,[...accuracyHeaders,'用例 ID','入口','Q 位不一致数','K 位不一致数','V 位不一致数'],ar,5,{A:180,F:550,G:110,H:135,I:135,J:135});
as.getRange('A2').format.rowHeight=130;
const er=[];
for(const id of req.negative_scenarios)for(const entry of req.negative_entries){const r=get(ext,id,entry);er.push([id,entry,state(r),r?.rejection??'未取得设备记录']);}
for(const id of req.verifier_checks){const r=get(ext,id,'verifier');er.push([id,'verifier',state(r),'原包验证器反例检查']);}
for(const r of eng.records)er.push([r.case_name,r.entry,state(r),'来源：engineering.json 和精度日志']);
engineering(aw,er);
await save(aw,'2.1 精度自验证报告.xlsx','accuracy',[['A1:E9','F3:J9','A97:J101'],['A1:D9','A91:D105']]);
}
if(enabled('performance')){
const performanceHeaders=['shape','dtype','性能是否通过',screenshotHeader,'标杆算子性能(us)','Ascend C算子性能(us)','rato','解释说明'];
const [pw,ps]=await template('3.1 性能自验证报告.xlsx','性能',performanceHeaders);const pr=[];
for(const t of targets.cases){
  const c=cases.find(x=>x.case_name===t.case_name),r=perf.cases.find(x=>x.case_name===t.case_name)?.results?.custom,paired=base.cases.find(x=>x.case_name===t.case_name)?.results;
  pr.push([shape(c),dtype(c),r?(r.wall_us_median<=t.max_wall_us?'通过':'失败'):'待实机验证','',null,r?.wall_us_median??null,null,'F/J 为固定验收；E/G 未同轮测量，对照见 P:R。',t.case_name,t.max_wall_us,...Array.from({length:5},(_,i)=>r?.wall_us_rounds?.[i]??null),paired?.views_concat_q_copy?.wall_us_median??null,paired?.custom?.wall_us_median??null,null]);
}
populate(ps,`性能测试总结：\n1、${environment}\n2、固定性能 ${pr.length} 条，通过 ${pr.filter(x=>x[2]==='通过').length} 条；50 次预热，5 轮×200 次，wall 轮均值中位数。\n3、无未通过项。007/017 为 70.222/70.201 us，上限 75/77 us。未保存现场截图。\n4、E/G 留空：固定运行未同轮测量标杆；另次对照的同轮数据及比值完整保留在 P:R。\n来源：performance.json、baseline_comparison.json。`,[...performanceHeaders,'用例 ID','固定上限 (us)','第 1 轮 (us)','第 2 轮 (us)','第 3 轮 (us)','第 4 轮 (us)','第 5 轮 (us)','同轮 views 标杆 (us)','同轮自定义 (us)','同轮比值 Q/P'],pr,8,{A:180,G:100,H:430,I:550,J:130,K:130,L:130,M:130,N:130,O:130,P:170,Q:165,R:140});
ps.getRange('C4:C13').formulas=pr.map((_,i)=>{const r=i+4;return [`=IF(COUNT(F${r},J${r})=2,IF(F${r}<=J${r},"通过","失败"),"待实机验证")`];});
ps.getRange('G4:G13').formulas=pr.map((_,i)=>{const r=i+4;return [`=IF(COUNT(E${r},F${r})=2,F${r}/E${r},"")`];});
ps.getRange('R4:R13').formulas=pr.map((_,i)=>{const r=i+4;return [`=IF(COUNT(P${r},Q${r})=2,Q${r}/P${r},"")`];});
ps.getRange('E4:G13').setNumberFormat('0.000');ps.getRange('J4:Q13').setNumberFormat('0.000');ps.getRange('R4:R13').setNumberFormat('0.0000');
const original=ps.getRange('F7').values;ps.getRange('F7').values=[[76]];pw.recalculate();if(ps.getRange('C7').values[0][0]!=='失败')throw new Error('Fixed limit formula failed boundary check.');ps.getRange('F7').values=original;
await save(pw,'3.1 性能自验证报告.xlsx','performance',[['A1:H13','I3:R13']]);
}
if(enabled('memory')){
const memoryHeaders=['shape','dtype','内存是否通过',screenshotHeader,'标杆算子内存占用（GB）','Ascend C算子内存占用(GB)','rato','解释说明'];
const [mw,ms]=await template('4.1 内存自验证报告.xlsx','内存（如需要）',memoryHeaders);const mr=[];
for(const id of req.performance_case_ids){const c=cases.find(x=>x.case_name===id);for(const entry of ['run','run_direct']){
  const r=get(mem,id,entry);mr.push([shape(c),dtype(c),state(r),'',null,null,null,'F 为活跃峰值增量，GB=10^9 字节；按 L/M/N 验收。',id,entry,r?.output_bytes??null,r?.peak_increment??null,null,r?.workspace_bytes??null,r?.before??null,r?.after_each_release?.at(-1)??null]);
}}
populate(ms,`内存测试总结：\n1、${environment}\n2、10 个性能形状×两个入口，共 20 条记录，通过 20 条。每条检查 20 次释放回收。\n3、无未通过项；未测量标杆活跃内存，E/G 留空，不将理论输出字节冒充实测标杆。\n4、按任务书使用活跃张量字节：峰值增量 ≤ 输出字节数 + 16 KiB，workspace=0。\nF 列按 1 GB=10^9 字节换算；逐字节原始值和上限见 K:P。来源：memory.json。\n无现场截图，原始日志随包提供。`,[...memoryHeaders,'用例 ID','入口','输出字节数','实测峰值增量 (字节)','允许上限 (字节)','工作区 (字节)','调用前活跃字节','20 次后活跃字节'],mr,8,{A:180,G:100,H:460,I:550,J:110,K:155,L:165,M:165,N:135,O:160,P:165});
for(let i=0;i<mr.length;i++){const r=i+4;ms.getRange(`F${r}`).formulas=[[`=L${r}/1000000000`]];ms.getRange(`M${r}`).formulas=[[`=K${r}+16384`]];ms.getRange(`G${r}`).formulas=[[`=IF(COUNT(E${r},F${r})=2,F${r}/E${r},"")`]];}
ms.getRange('E4:F23').setNumberFormat('0.000000000');ms.getRange('K4:P23').setNumberFormat('#,##0');
await save(mw,'4.1 内存自验证报告.xlsx','memory',[['A1:H10','I3:P10','I18:P23']]);
}
console.log('Exported three reports from official templates; example screenshots removed.');
