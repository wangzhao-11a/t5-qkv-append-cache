import fs from 'node:fs/promises';
import path from 'node:path';
import {FileBlob, SpreadsheetFile} from '@oai/artifact-tool';
const root=path.resolve(import.meta.dirname,'..');
await fs.mkdir(path.join(root,'reports/previews'),{recursive:true});
for(const [key,file] of [['accuracy','2.1 精度自验证报告.xlsx'],['performance','3.1 性能自验证报告.xlsx'],['memory','4.1 内存自验证报告.xlsx']]){
  const wb=await SpreadsheetFile.importXlsx(await FileBlob.load(path.join(root,'research/templates',file)));
  const s=wb.worksheets.getItemAt(0);
  console.log((await wb.inspect({kind:'table',range:`'${s.name}'!A1:H5`,maxChars:1500,tableMaxRows:5,tableMaxCols:8})).ndjson);
  const blob=await wb.render({sheetName:s.name,range:key==='accuracy'?'A1:E8':'A1:H8',scale:1,format:'png'});
  await fs.writeFile(path.join(root,`reports/previews/template_${key}.png`),new Uint8Array(await blob.arrayBuffer()));
}
