'use strict';
// Builds the standalone Marketplace page from the shared platform core + UI.
const fs = require('node:fs');
const path = require('node:path');
const root = __dirname;
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const output = read('marketplace/template.html')
  .replace('/*__CORE__*/', () => read('src/core.js'))
  .replace('/*__APP__*/', () => read('marketplace/app.js'));
const dest = path.join(root, 'public', 'index.html');
fs.mkdirSync(path.dirname(dest), { recursive: true });
fs.writeFileSync(dest, output);
console.log(`Wrote ${dest} (${(Buffer.byteLength(output) / 1024).toFixed(1)} KiB)`);
