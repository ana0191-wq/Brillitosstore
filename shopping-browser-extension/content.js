(function(){
if(window.__brillitosCartReaderInstalled)return;window.__brillitosCartReaderInstalled=true;
const norm=s=>(s||'').replace(/\s+/g,' ').trim();
function priceFrom(text){const s=(text||'').replace(/\s/g,'');const matches=[...s.matchAll(/(?:US\$|USD|\$)\s?(\d{1,5}(?:[.,]\d{1,2})?)/gi)];if(!matches.length)return null;const raw=matches[matches.length-1][1];const val=Number(raw.replace(',','.'));return Number.isFinite(val)?val:null}
function storeName(){const h=location.hostname.toLowerCase();return h.includes('shein')?'SHEIN':h.includes('amazon')?'Amazon':h.includes('temu')?'Temu':h.includes('aliexpress')?'AliExpress':h}
function isVisible(el){const r=el.getBoundingClientRect(),s=getComputedStyle(el);return r.width>0&&r.height>0&&s.display!=='none'&&s.visibility!=='hidden'}
function extract(){const host=location.hostname.toLowerCase();let selectors=[];
if(host.includes('shein'))selectors=['[class*="cart-item"]','[class*="CartItem"]','[class*="goods-item"]','[class*="product-item"]','[data-testid*="cart"]'];
else if(host.includes('amazon'))selectors=['.sc-list-item','[data-name="Active Items"] .sc-list-item'];
else if(host.includes('temu'))selectors=['[class*="cart-item"]','[class*="CartItem"]','[class*="goodsItem"]','[data-testid*="cart-item"]'];
else if(host.includes('aliexpress'))selectors=['[class*="cart-item"]','[class*="product-item"]','[class*="cartItem"]'];
let nodes=[];for(const sel of selectors){try{nodes.push(...document.querySelectorAll(sel))}catch(e){}}
nodes=nodes.filter(isVisible);
const unique=[...new Set(nodes)];let items=[];
for(const el of unique){const text=norm(el.innerText||el.textContent);if(text.length<5||text.length>2500)continue;
const links=[...el.querySelectorAll('a[href]')].filter(a=>norm(a.innerText).length>2);let link=links.find(a=>a.querySelector('img'))||links.sort((a,b)=>norm(b.innerText).length-norm(a.innerText).length)[0];
const img=el.querySelector('img');let name=norm((link&&link.innerText)||img?.alt||'');
if(!name){const lines=(el.innerText||'').split(/\n+/).map(norm).filter(s=>s.length>5&&!/^(delete|remove|save for later|move to|eliminar|guardar|editar|qty|quantity|cantidad)$/i.test(s));name=lines.sort((a,b)=>a.length-b.length)[0]||''}
name=name.replace(/\b(delete|remove|save for later|eliminar|guardar para después)\b/ig,'').trim();if(name.length<3)continue;
const price=priceFrom(text);let quantity=null;const inputs=[...el.querySelectorAll('input')].filter(x=>x.type==='number'||/qty|quantity|cantidad/i.test(x.getAttribute('aria-label')||''));if(inputs.length){const q=Number(inputs[0].value);if(q>0&&q<10000)quantity=q}
if(quantity==null){const q=text.match(/(?:qty|quantity|cantidad)\s*[:x]?\s*(\d{1,3})/i);if(q)quantity=Number(q[1])}
const variant=norm([...el.querySelectorAll('select,[class*="size"],[class*="color"],[class*="variant"]')].map(x=>x.value||x.innerText||x.getAttribute('aria-label')||'').filter(Boolean).join(' · ')).slice(0,180);
const url=link?new URL(link.getAttribute('href'),location.href).href:'';const key=(name+'|'+url).toLowerCase();if(items.some(x=>x._key===key))continue;
items.push({name,price_usd:price,quantity:quantity||1,variant,url,_key:key,raw_text:text.slice(0,500)});
if(items.length>=100)break;
}
items=items.map(({_key,...x})=>x);return {store:storeName(),page_url:location.href,page_title:document.title,read_at:new Date().toISOString(),items};
}
chrome.runtime.onMessage.addListener((msg,sender,sendResponse)=>{if(msg?.type==='BRILLITOS_READ_CART'){try{sendResponse(extract())}catch(e){sendResponse({store:storeName(),page_url:location.href,items:[],error:'Extraction failed'})}return true}});
})();