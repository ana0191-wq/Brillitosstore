// All external requests are mocked. This test never writes to production.
const fs=require('node:fs'),http=require('node:http'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require(require.resolve('playwright',{paths:[process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES||process.cwd()]}));
const root=path.resolve(__dirname,'..');
const svg='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="120" height="120"><rect x="20" y="10" width="80" height="100" rx="9" fill="#f8c9de"/><path d="M35 35h50M35 55h50M35 75h50" stroke="white" stroke-width="4"/></svg>');
const prods=Array.from({length:30},(_,n)=>({id:n+1,nombre:'Libreta de prueba '+(n+1),categoria:'Papelería',precio:100,precio_costo:35,stock:10,activo:true,visible_web:true,imagen:svg,producto_variantes:[]}));
prods[29].producto_variantes=[{id:301,producto_id:30,nombre:'Rosa',precio:'100',stock:5,activo:true},{id:302,producto_id:30,nombre:'Azul',precio:'120',stock:2,activo:true}];
const rules=[{id:'test',nombre:'Inauguración página web',porcentaje:20,alcance:'todos',activo:true,fecha_fin:'2099-09-30',monto_minimo:4}];
const server=http.createServer((req,res)=>{
  const pathname=new URL(req.url,'http://localhost').pathname;
  const file=path.join(root,pathname==='/'?'index.html':pathname);
  if(!file.startsWith(root)||!fs.existsSync(file)){res.writeHead(404);return res.end();}
  res.setHeader('Content-Type',file.endsWith('.css')?'text/css':file.endsWith('.js')?'text/javascript':file.endsWith('.json')?'application/json':'text/html');res.end(fs.readFileSync(file));
});
(async()=>{
  await new Promise(r=>server.listen(0,'127.0.0.1',r));const base='http://127.0.0.1:'+server.address().port;
  const bundled=process.env.BRL_CHROMIUM_MODULE?require(process.env.BRL_CHROMIUM_MODULE):null;
  const executablePath=process.env.BRL_CHROMIUM_EXECUTABLE||(bundled?await bundled.executablePath():undefined);
  const browser=await chromium.launch({headless:true,args:bundled?bundled.args:['--no-sandbox'],...(executablePath?{executablePath}:{} )});
  try{
    const ctx=await browser.newContext({viewport:{width:1440,height:1050},timezoneId:'America/Caracas'});
    const errors=[],calls=[];let mode='success';
    await ctx.route('**/*',async route=>{
      const u=new URL(route.request().url());
      if(u.origin===base)return route.continue();
      let body=[];
      if(u.hostname.endsWith('supabase.co')){
        const name=u.pathname.split('/').pop();
        if(u.pathname.includes('/rpc/')){
          const args=route.request().postDataJSON();calls.push({name,args});
          if(name==='brl_quote'||name==='brl_checkout'){
            if(mode==='failure')return route.fulfill({status:400,json:{message:'Stock insuficiente'}});
            const unit=mode==='changed'?100:80,sub=unit*args.p_items.reduce((n,x)=>n+x.cantidad,0);
            body={id:101,numero:'WEB-test',items:args.p_items.map(x=>({...x,producto_nombre:'Libreta',precio_original:100,precio_unitario:unit,subtotal:unit*x.cantidad})),subtotal_original:100,subtotal:sub,descuento_promocion:100-sub,descuento:sub*.1,total:sub*.9,moneda_pago:'USDT',monto_pago:sub*.9};
          }else body={id:101,total:72};
        }else if(route.request().method()!=='GET')throw Error('Unexpected direct mutation: '+u.pathname);
        else if(name==='productos')body=prods;
        else if(name==='producto_variantes')body=prods.flatMap(p=>p.producto_variantes);
        else if(name==='configuracion_tienda')body=[{id:1,descuento_reglas:rules}];
      }else if(u.hostname.includes('dolarapi'))body={promedio:100};
      return route.fulfill({status:200,json:body});
    });
    const page=await ctx.newPage();page.on('pageerror',e=>errors.push(e.message));
    await page.goto(base+'/admin.html');await page.waitForFunction(()=>productos.length===30);
    await page.evaluate(()=>irA('productos'));
    assert.equal(await page.locator('.inventory-card').count(),24);
    await page.locator('#prod-next').click();assert.equal(await page.locator('.inventory-card').count(),6);
    await page.locator('#search-prods').fill('Rosa');assert.equal(await page.locator('.inventory-card').count(),1);
    assert.match(await page.locator('.inventory-card').innerText(),/7 uds/);
    await page.locator('.inventory-variants summary').click();assert.match(await page.locator('.inventory-variants').innerText(),/Azul/);
    await page.locator('#search-prods').fill('');
    await page.screenshot({path:'/workspace/scratch/344196d2d43c/admin-desktop.png'});
    await page.setViewportSize({width:390,height:844});
    assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true,'No mobile overflow');
    await page.screenshot({path:'/workspace/scratch/344196d2d43c/admin-mobile.png'});
    await page.evaluate(async()=>{await cambiarEstadoVenta(1,'Pagado');});
    assert(calls.some(c=>c.name==='brl_sale_state'));
    const shop=await ctx.newPage();shop.on('pageerror',e=>errors.push(e.message));
    await shop.goto(base);await shop.waitForFunction(()=>CATALOG.length===30);
    await shop.evaluate(()=>{addToCart(1);window.open=()=>({location:{href:''},close(){}});});
    assert.equal(await shop.locator('#bnc-total').textContent(),'72.00 USDT');
    await shop.evaluate(()=>sendWA('binance'));
    assert(calls.some(c=>c.name==='brl_checkout'&&c.args.p_expected===72));
    assert.equal(await shop.evaluate(()=>cart.length),0);
    mode='failure';await shop.evaluate(()=>{addToCart(1);return sendWA('binance');});
    assert.equal(await shop.evaluate(()=>cart.length),1,'Failure keeps cart');
    mode='changed';const previous=calls.filter(c=>c.name==='brl_checkout').length;
    await shop.evaluate(()=>sendWA('binance'));
    assert.equal(calls.filter(c=>c.name==='brl_checkout').length,previous,'Changed price requires confirmation');
    assert.equal(await shop.evaluate(()=>cart[0].precio),100);
    const uploads=[];let uploadStatus=201;
    await page.route('https://storage.bunnycdn.com/brillitos/**',async route=>{
      uploads.push(route.request().headers()['accesskey']);
      await route.fulfill({status:uploadStatus,body:''});
    });
    const startUpload=()=>page.evaluate(()=>{
      window.uploadResult=null;
      brlUploadPhoto('productos/test.jpg',new Blob(['test'],{type:'image/jpeg'}))
        .then(r=>window.uploadResult=r.status).catch(e=>window.uploadResult=e.message);
    });
    await startUpload();await page.locator('#bunny-upload-key').fill('test-only-not-a-real-key');
    await page.locator('dialog button[type=submit]').click();
    await page.waitForFunction(()=>uploadResult===201);
    assert.equal(uploads[0],'test-only-not-a-real-key');
    assert.equal(await page.evaluate(()=>JSON.stringify({...localStorage,...sessionStorage}).includes('test-only-not-a-real-key')),false);
    assert.equal(await page.locator('#bunny-upload-key').count(),0);
    uploadStatus=401;await startUpload();await page.waitForFunction(()=>uploadResult===401);
    await startUpload();await page.locator('dialog [data-cancel]').click();
    await page.waitForFunction(()=>uploadResult==='Subida cancelada');
    assert.equal(uploads.length,2,'Cancelled upload sends no request');
    assert.deepEqual(errors,[]);
    console.log('PASS: desktop/mobile inventory, pagination, variant search, atomic state RPC, checkout totals, failure/repricing, JS errors');
  }finally{await browser.close();server.close();}
})().catch(e=>{console.error(e);server.close();process.exitCode=1;});
