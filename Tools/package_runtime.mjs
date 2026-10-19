import { readFileSync, readdirSync, writeFileSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';

const tag = process.argv[2];
if (!tag || !/^[a-z0-9-]+$/.test(tag)) throw new Error('A lowercase release tag is required');
const archive = `.runtime/ClassHelper-${tag}.zip`;
if (existsSync(archive)) throw new Error('Archive already exists: ' + archive);
const toc = readFileSync('ClassHelper.toc', 'utf8');
const files = ['ClassHelper.toc', ...toc.split(/\r?\n/).filter(line => line.trim() && !line.startsWith('#')).map(line => line.trim().replaceAll('\\', '/')),
  ...readdirSync('ThirdParty').map(file => 'ThirdParty/' + file)];
const result = spawnSync('zip', ['-q', archive, '-@'], { input: files.join('\n') + '\n', encoding: 'utf8' });
if (result.status !== 0) throw new Error(result.stderr || 'Packaging failed');
const manifest = files.map(path => ({ path, sha256: createHash('sha256').update(readFileSync(path)).digest('hex') }));
writeFileSync(`.runtime/ClassHelper-${tag}-manifest.json`, JSON.stringify(manifest, null, 2));
console.log(JSON.stringify({ archive, files: files.length }));
