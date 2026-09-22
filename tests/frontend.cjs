const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const shop=fs.readFileSync('index.html','utf8'),admin=fs.readFileSync('admin.html','utf8');
for(const [name,html] of [['shop',shop],['admin',admin]]){
  for(const m of html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi))new vm.Script(m[1],{filename:name});
}
const context=vm.createContext({STORE_CONFIG:{descuento_reglas:[{porcentaje:20,activo:true,alcance:'todos',monto_minimo:4,fecha_fin:'2026-09-30'}]},CATALOG:[],cart:[],saveCart(){}});
vm.runInContext(shop.slice(shop.indexOf('function clampDiscountPct'),shop.indexOf('var FEATURED_SECTIONS')),context);
context.storeDateToday=()=> '2026-09-30';
assert.equal(context.getPriceInfo({id:1,precio:100},100).final,80);
assert.equal(context.getPriceInfo({id:1,precio:3},3).final,3);
assert.equal(context.getPriceInfo({id:1,enRemate:true,precioRemate:50},100).final,50);
context.storeDateToday=()=> '2026-10-01';assert.equal(context.getPriceInfo({id:1},100).final,100);
for(const tz of ['UTC','America/Caracas','Asia/Tokyo']){
  process.env.TZ=tz;
  const realDate=Date;
  const fixed=class extends realDate{static now(){return new realDate('2026-10-01T03:59:59Z').getTime();}};
  const c=vm.createContext({Date:fixed});
  vm.runInContext(admin.match(/function hoyVEN\(\)\{[^\n]+/)[0],c);
  assert.equal(c.hoyVEN(),'2026-09-30',tz);
  fixed.now=()=>new realDate('2026-10-01T04:00:00Z').getTime();assert.equal(c.hoyVEN(),'2026-10-01',tz);
}
assert(shop.includes("webRPC('brl_checkout_customer'"));
assert(!shop.includes("'/rest/v1/ventas',"),'Web checkout must use atomic RPC');
for(const fn of ['brl_save_sale','brl_sale_state','brl_convert_apartado','brl_update_sales'])assert(admin.includes("brlRPC('"+fn+"'"));
assert(admin.includes('class="inventory-grid"'));assert(admin.includes('variante_id:it.variante_id||null'));
console.log('PASS: inline JS syntax, promotion minimum/remate/expiry, Caracas midnight in 3 timezones, atomic RPC wiring');
