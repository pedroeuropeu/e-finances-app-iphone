// Converte o catálogo de marcas da web (brands.ts) em JSON para o app: mesmas chaves, nomes, grupos, cores e caminhos SVG.
import fs from 'node:fs';
const [src, out] = process.argv.slice(2);
const ts = fs.readFileSync(src, 'utf8');
const start = ts.indexOf('export const BRANDS');
const objStart = ts.indexOf('{', ts.indexOf('=', start));
let depth = 0, end = objStart;
for (let i = objStart; i < ts.length; i++) {
  if (ts[i] === '{') depth++;
  else if (ts[i] === '}') { depth--; if (depth === 0) { end = i; break; } }
}
const brands = Function('return (' + ts.slice(objStart, end + 1) + ')')();
const groups = [...new Set(Object.values(brands).map(b => b.group))];
fs.writeFileSync(out, JSON.stringify({groups, brands}, null, 0) + '\n');
console.log(Object.keys(brands).length + ' marcas, ' + groups.length + ' grupos');
