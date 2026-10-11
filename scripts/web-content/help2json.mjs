// Converte as perguntas frequentes da web (help-content.ts) no help.json do app (tópicos sem ícone, artigos sem tour).
import fs from 'node:fs';
const [src, out] = process.argv.slice(2);
const ts = fs.readFileSync(src, 'utf8');
function literal(name) {
  const at = ts.indexOf('export const ' + name);
  const open = ts.indexOf('[', ts.indexOf('=', at));
  let depth = 0;
  for (let i = open; i < ts.length; i++) {
    if (ts[i] === '[') depth++;
    else if (ts[i] === ']') { depth--; if (depth === 0) return Function('return (' + ts.slice(open, i + 1) + ')')(); }
  }
  throw new Error('não achei ' + name);
}
const topics = literal('HELP_TOPICS').map(({id, label, description}) => ({id, label, description}));
const articles = literal('HELP_ARTICLES').map(a => {
  const o = {id: a.id, topic: a.topic, title: a.title, body: a.body};
  if (a.steps) o.steps = a.steps;
  if (a.note) o.note = a.note;
  if (a.keywords) o.keywords = a.keywords;
  return o;
});
fs.writeFileSync(out, JSON.stringify({topics, articles}, null, 1) + '\n');
console.log(topics.length + ' tópicos, ' + articles.length + ' artigos');
