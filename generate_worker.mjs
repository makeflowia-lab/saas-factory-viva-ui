import { readFileSync, writeFileSync } from 'fs';

const html = readFileSync('fabrica-viva.html', 'utf8');
const workerContent = `const HTML = ${JSON.stringify(html)};

export default {
  async fetch(request, env) {
    return new Response(HTML, {
      headers: { "content-type": "text/html;charset=utf-8" }
    });
  }
};
`;

writeFileSync('worker.js', workerContent, 'utf8');
console.log("worker.js generated successfully! Size:", workerContent.length);
