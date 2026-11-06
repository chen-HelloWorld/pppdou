// Usage: node tools/preview-regression.js <absolute-image-path> [preview-url]
// Connects to a local Chromium instance started with --remote-debugging-port=9333.
const imagePath = process.argv[2];
const previewUrl = process.argv[3] || 'http://127.0.0.1:4174/preview/?regression=1';
const screenshotPath = process.argv[4];
if (!imagePath) throw new Error('Missing absolute image path');

const target = await fetch(`http://127.0.0.1:9333/json/new?${encodeURIComponent(previewUrl)}`, {
  method: 'PUT',
}).then((response) => response.json());
const socket = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((resolve, reject) => {
  socket.addEventListener('open', resolve, {once: true});
  socket.addEventListener('error', reject, {once: true});
});

let nextId = 1;
const pending = new Map();
socket.addEventListener('message', (event) => {
  const message = JSON.parse(event.data);
  if (!message.id || !pending.has(message.id)) return;
  const {resolve, reject} = pending.get(message.id);
  pending.delete(message.id);
  if (message.error) reject(new Error(message.error.message));
  else resolve(message.result);
});
function send(method, params = {}) {
  const id = nextId++;
  socket.send(JSON.stringify({id, method, params}));
  return new Promise((resolve, reject) => pending.set(id, {resolve, reject}));
}
const sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));
const evaluate = async (expression) => {
  const result = await send('Runtime.evaluate', {expression, returnByValue: true, awaitPromise: true});
  if (result.exceptionDetails) throw new Error(result.exceptionDetails.text);
  return result.result.value;
};

await send('Runtime.enable');
await send('DOM.enable');
for (let attempt = 0; attempt < 100; attempt++) {
  if (await evaluate("document.readyState === 'complete' && !!document.querySelector('#file')")) break;
  await sleep(100);
}
const documentNode = await send('DOM.getDocument', {depth: 2});
const fileNode = await send('DOM.querySelector', {
  nodeId: documentNode.root.nodeId,
  selector: '#file',
});
await send('DOM.setFileInputFiles', {nodeId: fileNode.nodeId, files: [imagePath]});
for (let attempt = 0; attempt < 100; attempt++) {
  if (await evaluate("document.querySelector('#importTitle')?.textContent === '图片已准备好'")) break;
  await sleep(100);
}
await evaluate("document.querySelector('#next').click(); true");
let state;
for (let attempt = 0; attempt < 600; attempt++) {
  state = await evaluate(`({
    screen,
    title: document.querySelector('#title')?.textContent,
    button: document.querySelector('#next')?.textContent,
    beadCount,
    grid: [cols, rows],
    uncertain: uncertain?.size || 0,
    counts,
    debug: globalThis.__recognitionDebug,
  })`);
  if (state.screen === 1) break;
  await sleep(250);
}
state.orangeLines = await evaluate(`(() => {
  const canvas=document.querySelector('#source'), context=canvas.getContext('2d'), pixels=context.getImageData(0,0,canvas.width,canvas.height).data, orange=(i)=>pixels[i]>180&&pixels[i]>pixels[i+1]*1.12&&pixels[i+1]>pixels[i+2]*1.05, x=[], y=[];
  for(let column=0;column<canvas.width;column++){let count=0;for(let row=0;row<canvas.height;row++)if(orange((row*canvas.width+column)*4))count++;if(count>canvas.height*.25)x.push([column,count])}
  for(let row=0;row<canvas.height;row++){let count=0;for(let column=0;column<canvas.width;column++)if(orange((row*canvas.width+column)*4))count++;if(count>canvas.width*.25)y.push([row,count])}
  return {x,y};
})()`);
if (state.debug?.clusters) state.debug.clusters = state.debug.clusters.slice(0, 12);
if (screenshotPath) {
  const screenshot = await send('Page.captureScreenshot', {format: 'png', captureBeyondViewport: true});
  const fs = await import('node:fs/promises');
  await fs.writeFile(screenshotPath, Buffer.from(screenshot.data, 'base64'));
}
console.log(JSON.stringify(state, null, 2));
socket.close();
