const http = require('http');
const fs = require('fs');
const path = require('path');

const host = '127.0.0.1';
const port = 4174;
const root = __dirname;
const localConfig = Object.fromEntries((fs.existsSync(path.join(root, '.env.local')) ? fs.readFileSync(path.join(root, '.env.local'), 'utf8') : '').split(/\r?\n/).filter(line => line && !line.trimStart().startsWith('#') && line.includes('=')).map(line => { const index = line.indexOf('='); return [line.slice(0, index).trim(), line.slice(index + 1).trim()]; }));
const aiConfig = { baseUrl: (localConfig.PINDOU_AI_BASE_URL || '').replace(/\/$/, ''), model: localConfig.PINDOU_AI_MODEL || '', apiKey: localConfig.PINDOU_AI_API_KEY || '' };
const contentTypes = {
  '.html': 'text/html; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
};

const server = http.createServer((request, response) => {
  let pathname;
  try {
    pathname = decodeURIComponent((request.url || '/').split('?')[0]);
  } catch {
    response.writeHead(400).end('Bad request');
    return;
  }
  if (pathname === '/api/ai-review') {
    if (request.method !== 'POST') { response.writeHead(405).end('Method not allowed'); return; }
    if (!aiConfig.baseUrl || !aiConfig.model || !aiConfig.apiKey) { response.writeHead(503, {'Content-Type':'application/json'}).end(JSON.stringify({error:'AI 本地配置不完整'})); return; }
    let body = '';
    request.on('data', chunk => { body += chunk; if (body.length > 8 * 1024 * 1024) request.destroy(); });
    request.on('end', async () => {
      try {
        const input = JSON.parse(body); console.log('[拼豆 AI] 收到复核请求'); const upstream = await fetch(`${aiConfig.baseUrl}/chat/completions`, {method:'POST',headers:{Authorization:`Bearer ${aiConfig.apiKey}`,'Content-Type':'application/json'},body:JSON.stringify({model:aiConfig.model,messages:input.messages,max_tokens:input.max_tokens || 1600,temperature:0})}), text = await upstream.text(); console.log(`[拼豆 AI] 上游响应：HTTP ${upstream.status}`);
        response.writeHead(upstream.status, {'Content-Type':'application/json','Cache-Control':'no-store'}).end(text);
      } catch (error) { console.error('[拼豆 AI] 复核请求失败：', error.message); response.writeHead(502, {'Content-Type':'application/json'}).end(JSON.stringify({error:`AI 复核服务请求失败：${error.message}`})); }
    });
    return;
  }
  if (pathname === '/') pathname = '/preview/';
  if (pathname.endsWith('/')) pathname += 'index.html';
  const target = path.resolve(root, `.${pathname}`);
  if (target !== root && !target.startsWith(`${root}${path.sep}`)) {
    response.writeHead(403).end('Forbidden');
    return;
  }
  fs.readFile(target, (error, content) => {
    if (error) {
      response.writeHead(error.code === 'ENOENT' ? 404 : 500).end('Not found');
      return;
    }
    if (pathname === '/preview/index.html') {
      try {
        const colorCard = JSON.stringify(JSON.parse(fs.readFileSync(path.join(root, 'color_card', 'MRAD_color.json'), 'utf8'))).replace(/</g, '\\u003c');
        content = Buffer.from(String(content).replace('</head>', `<script id="mrad-color-card" type="application/json">${colorCard}</script></head>`));
      } catch (error) {
        console.error('[拼豆预览] 色卡装载失败：', error.message);
        response.writeHead(500).end('Color card unavailable');
        return;
      }
    }
    response.setHeader('Content-Type', contentTypes[path.extname(target).toLowerCase()] || 'application/octet-stream');
    response.setHeader('Cache-Control', 'no-cache');
    response.writeHead(200).end(content);
  });
});

server.on('error', (error) => {
  if (error.code === 'EADDRINUSE') process.exit(0);
  console.error(error);
  process.exit(1);
});

server.listen(port, host, () => {
  console.log(`拼豆电脑预览服务已启动：http://${host}:${port}/preview/`);
});
