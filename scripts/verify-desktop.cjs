const fs = require('node:fs');
for (const path of ['apps/desktop/main.cjs','apps/desktop/preload.cjs']) {
 if(!fs.existsSync(path)) throw new Error(`Missing ${path}`);
}
console.log('Desktop source files verified. Windows/Linux installer packaging is not implemented yet.');
