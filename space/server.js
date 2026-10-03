import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import { createServer } from 'node:http';
import { extname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';

const host = '0.0.0.0';
const port = Number.parseInt(process.env.PORT ?? '7860', 10);
const publicDirectory = fileURLToPath(new URL('./public/', import.meta.url));

const contentTypes = new Map([
  ['.css', 'text/css; charset=utf-8'],
  ['.html', 'text/html; charset=utf-8'],
  ['.js', 'text/javascript; charset=utf-8'],
  ['.svg', 'image/svg+xml'],
]);

const server = createServer(async (request, response) => {
  if (request.url === '/healthz') {
    response.writeHead(200, { 'content-type': 'application/json; charset=utf-8' });
    response.end('{"status":"ok"}\n');
    return;
  }

  const pathname = new URL(request.url ?? '/', 'http://localhost').pathname;
  const requestedFile = pathname === '/' ? 'index.html' : pathname.slice(1);
  const normalizedFile = normalize(requestedFile).replace(/^(\.\.(\/|\\|$))+/, '');
  const filePath = join(publicDirectory, normalizedFile);

  try {
    const file = await stat(filePath);
    if (!file.isFile()) throw new Error('Not a file');

    response.writeHead(200, {
      'cache-control': extname(filePath) === '.html' ? 'no-cache' : 'public, max-age=3600',
      'content-type': contentTypes.get(extname(filePath)) ?? 'application/octet-stream',
      'x-content-type-options': 'nosniff',
    });
    createReadStream(filePath).pipe(response);
  } catch {
    response.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' });
    response.end('Not found\n');
  }
});

server.listen(port, host, () => {
  console.log(`Twenty Mini listening on http://${host}:${port}`);
});

const shutdown = () => server.close(() => process.exit(0));
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
