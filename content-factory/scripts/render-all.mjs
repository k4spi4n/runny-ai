import {execFileSync} from 'node:child_process';
import {copyFileSync, mkdirSync, readdirSync, rmSync, writeFileSync} from 'node:fs';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');
const repoRoot = resolve(root, '..');
const sourceDir = join(repoRoot, 'context', 'RUNNY_AI_DEMO');
const publicScreenshots = join(root, 'public', 'screenshots');
const outDir = join(root, 'out');
const propsDir = join(root, '.tmp-props');

const slides = [
  'overview-metrics',
  'chatbot',
  'personalized-training',
  'smart-nutrition',
];

mkdirSync(publicScreenshots, {recursive: true});
mkdirSync(outDir, {recursive: true});
mkdirSync(propsDir, {recursive: true});

for (const file of readdirSync(outDir)) {
  if (file.endsWith('.png')) {
    rmSync(join(outDir, file));
  }
}

for (const file of readdirSync(publicScreenshots)) {
  if (file.endsWith('.png')) {
    rmSync(join(publicScreenshots, file));
  }
}

for (const file of readdirSync(sourceDir)) {
  if (file.endsWith('.png')) {
    copyFileSync(join(sourceDir, file), join(publicScreenshots, file));
  }
}

for (const slideId of slides) {
  const output = join(outDir, `${slideId}.png`);
  const propsFile = join(propsDir, `${slideId}.json`);
  writeFileSync(propsFile, JSON.stringify({slideId}), 'utf8');
  execFileSync(
    'npx',
    [
      'remotion',
      'still',
      'src/index.ts',
      'RunnyMarketing',
      output,
      '--props',
      propsFile,
    ],
    {cwd: root, stdio: 'inherit', shell: process.platform === 'win32'},
  );
}
