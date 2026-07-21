import { mkdirSync, copyFileSync, readdirSync, statSync } from 'fs';
import { join } from 'path';

try {
  mkdirSync('dist', { recursive: true });
  const files = readdirSync('.');
  for (const f of files) {
    if (f === 'dist' || f === 'node_modules' || f === '.git') continue;
    const stat = statSync(f);
    if (stat.isFile()) {
      copyFileSync(f, join('dist', f));
    }
  }
  console.log('Build completed: files copied to dist/');
} catch (e) {
  console.error('Build error:', e);
  process.exit(1);
}
