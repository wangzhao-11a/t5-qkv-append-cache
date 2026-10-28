import {FileBlob,SpreadsheetFile} from '@oai/artifact-tool';
import path from 'node:path';
const root=path.resolve(import.meta.dirname,'..');
const wb=await SpreadsheetFile.importXlsx(await FileBlob.load(path.join(root,'research/templates/2.1 精度自验证报告.xlsx')));
console.log(wb.help('worksheet.images',{include:'index,examples,notes',maxChars:4000}).ndjson);
