// Local Step 6A browser fault injector. It never reads database credentials.
import http from 'node:http';
import { readFile, appendFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const modeFile = path.join(root, 'evidence', 'step6a-proxy-mode.txt');
const logFile = path.join(root, 'evidence', 'step6a-proxy-requests.ndjson');
const log = (entry) => appendFile(logFile, JSON.stringify({ at: new Date().toISOString(), ...entry }) + '\n');
async function mode() {
  try { return (await readFile(modeFile, 'utf8')).trim(); }
  catch { return 'normal'; }
}

http.createServer(async (request, response) => {
  const selected = await mode();
  const pathname = new URL(request.url, 'http://127.0.0.1').pathname;
  const meta = { method: request.method, path: pathname, mode: selected };
  if (selected === 'disconnect' && pathname.startsWith('/api/')) {
    await log({ ...meta, outcome: 'socket_destroyed' });
    request.socket.destroy();
    return;
  }
  if (selected === 'stall' && pathname.startsWith('/api/')) {
    await log({ ...meta, outcome: 'held_open' });
    response.on('close', () => log({ ...meta, outcome: 'client_closed_held_request' }));
    return;
  }
  if (selected === 'delay' && !['GET', 'HEAD'].includes(request.method)) {
    await log({ ...meta, outcome: 'delayed_1800ms' });
    await new Promise(resolve => setTimeout(resolve, 1800));
  }
  const upstream = http.request({
    hostname: '127.0.0.1', port: 8080, method: request.method, path: request.url,
    headers: { ...request.headers, host: '127.0.0.1:8080' }
  }, upstreamResponse => {
    if (selected === 'drop-response' && !['GET', 'HEAD'].includes(request.method)) {
      upstreamResponse.resume();
      log({ ...meta, upstreamStatus: upstreamResponse.statusCode, outcome: 'response_dropped_after_upstream' });
      request.socket.destroy();
      return;
    }
    response.writeHead(upstreamResponse.statusCode, upstreamResponse.headers);
    upstreamResponse.pipe(response);
    log({ ...meta, upstreamStatus: upstreamResponse.statusCode, outcome: 'forwarded' });
  });
  upstream.on('error', async error => {
    await log({ ...meta, outcome: 'upstream_error', error: error.code || 'unknown' });
    if (!response.headersSent) response.writeHead(502, { 'content-type': 'text/plain' });
    response.end('Local backend unavailable');
  });
  request.pipe(upstream);
}).listen(8082, '127.0.0.1', () => console.log('Step 6A proxy: http://127.0.0.1:8082/'));
