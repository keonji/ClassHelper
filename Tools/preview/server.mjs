import http from 'node:http';
import { readFileSync, existsSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = fileURLToPath(new URL('../../', import.meta.url));
const artRoot = path.join(root, '.runtime', 'wow-art-png');
const types = { '.png': 'image/png', '.ttf': 'font/ttf' };

http.createServer((request, response) => {
  const url = new URL(request.url, 'http://127.0.0.1');
  response.setHeader('Cache-Control', 'no-store');
  if (url.pathname === '/') {
    response.setHeader('Content-Type', 'text/html; charset=utf-8');
    response.end(readFileSync(new URL('./index.html', import.meta.url)));
    return;
  }
  if (url.pathname.startsWith('/art/')) {
    const relative = decodeURIComponent(url.pathname.slice(5)).toLowerCase();
    const file = path.resolve(artRoot, relative);
    if (!file.startsWith(artRoot + path.sep) || !types[path.extname(file)] || !existsSync(file)) {
      response.writeHead(404).end();
      return;
    }
    response.setHeader('Cache-Control', 'max-age=3600');
    response.setHeader('Content-Type', types[path.extname(file)]);
    response.end(readFileSync(file));
    return;
  }
  if (url.pathname !== '/snapshot') {
    response.writeHead(404).end();
    return;
  }
  const locale = url.searchParams.get('locale') || 'ruRU';
  const profile = url.searchParams.get('profile') || '';
  const stage = url.searchParams.get('stage') || '';
  const tab = url.searchParams.get('tab') || '';
  const clicks = url.searchParams.get('clicks') || '';
  const loaded = url.searchParams.get('loaded') === '0' ? '0' : '1';
  if (!['ruRU', 'enUS'].includes(locale) || !/^[a-z0-9_]{0,100}$/.test(profile) || !/^[A-Za-z0-9_]{0,64}$/.test(stage)
      || !/^[a-z]{0,20}$/.test(tab) || !/^[0-9,]{0,2000}$/.test(clicks)) {
    response.writeHead(400).end('Invalid preview selection');
    return;
  }
  const result = spawnSync(process.env.CLASSHELPER_LUA || 'luajit',
    ['Tools/preview/snapshot.lua', locale, profile, stage, tab, clicks, loaded],
    { cwd: root, encoding: 'utf8', timeout: 15000, maxBuffer: 16 * 1024 * 1024 });
  response.setHeader('Content-Type', 'application/json; charset=utf-8');
  if (result.status !== 0) {
    response.writeHead(500).end(JSON.stringify({ error: result.stderr || 'snapshot failed' }));
    return;
  }
  response.end(result.stdout);
}).listen(Number(process.env.PORT || 4183), '127.0.0.1', function() {
  process.stdout.write('ClassHelper Lua preview: http://127.0.0.1:' + this.address().port + '\n');
});
