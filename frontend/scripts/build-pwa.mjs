import { readdir, readFile, writeFile } from 'node:fs/promises';
import { join, relative, sep } from 'node:path';
import { createHash } from 'node:crypto';

const root = 'dist/SI2-Frontend/browser';
async function files(dir) {
  const entries = await readdir(dir, { withFileTypes: true });
  const lists = await Promise.all(entries.map(e => e.isDirectory() ? files(join(dir, e.name)) : [join(dir, e.name)]));
  return lists.flat();
}
const paths = (await files(root)).filter(p => /\.(?:js|css|html|png|ico|webmanifest|woff2?)$/.test(p) && !p.endsWith(`${sep}sw.js`));
const precache = paths.map(p => relative(root, p).split(sep).join('/')).sort();
const hash = createHash('sha256');
for (const p of paths.sort()) hash.update(await readFile(p));
const source = await readFile('public/sw.js', 'utf8');
await writeFile(join(root, 'sw.js'), source.replace("'__BUILD_VERSION__'", JSON.stringify(hash.digest('hex').slice(0, 16))).replace('__PRECACHE__', JSON.stringify(precache)));
console.log(`PWA preparada: ${precache.length} recursos para instalación y uso sin conexión.`);
