// The root entry points are authoritative. Never hand-edit generated copies.
const fs=require('node:fs');
for(const f of ['CNAME','version.json','bunny-upload.js','admin-orders.js'])fs.copyFileSync(f,'dist/'+f);
fs.copyFileSync('index.html','docs/index.html');
fs.copyFileSync('version.json','docs/version.json');
console.log('Published entry points synchronized; public CSV files are not copied into dist.');
