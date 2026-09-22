// Customer order workspace. Existing sale/apartado editors remain authoritative.
let customerOrders=[],ordersLoading=false,ordersPage=1,ordersInitialized=false;
let ordersSeen=new Set();
try{ordersSeen=new Set(JSON.parse(localStorage.getItem('brl-orders-seen')||'[]'));}catch(e){}
const orderKey=o=>o.kind+':'+o.id;
const orderIsNew=o=>o.canal==='Web'&&!ordersSeen.has(orderKey(o));
async function fetchOrderRows(table,select){
  const result=[];
  for(let offset=0;offset<10000;offset+=500){
    const response=await apiFetch(SB+'/rest/v1/'+table+'?select='+select+'&order=id.desc&limit=500&offset='+offset,{headers:H});
    if(!response||!response.ok)throw Error('No se pudo leer '+table+'. Vuelve a intentar.');
    const rows=await response.json();
    if(!Array.isArray(rows))throw Error('Respuesta inválida al consultar '+table);
    result.push(...rows);if(rows.length<500)return result;
  }
  throw Error('Demasiados pedidos para esta vista. Usa Ventas para consultar el historial.');
}
async function cargarPedidosClientes(silent=false){
  if(ordersLoading)return;
  ordersLoading=true;
  const status=document.getElementById('orders-status');
  if(!silent)status.textContent='Cargando pedidos…';
  try{
    const [vs,aps,cs]=await Promise.all([
      fetchOrderRows('ventas','*,venta_items(*)'),fetchOrderRows('apartados','*,apartado_items(*)'),fetchOrderRows('clientes','*')
    ]);
    const previous=new Set(customerOrders.map(orderKey));
    clientes=cs;
    const converted=new Set(vs.map(v=>String(v.apartado_origen_id||'')));
    customerOrders=[...vs.map(v=>({...v,kind:'venta',items:v.venta_items||[]})),
      ...aps.filter(a=>!converted.has(String(a.id))).map(a=>({...a,kind:'apartado',items:a.apartado_items||[]}))];
    const fresh=customerOrders.filter(o=>orderIsNew(o)&&!previous.has(orderKey(o)));
    if(ordersInitialized&&fresh.length){
      toast('📦 '+fresh.length+' pedidos web nuevos');
      if('Notification' in window&&Notification.permission==='granted')new Notification('Brillitos',{body:fresh.length+' pedidos web nuevos. Revísalos en el Admin.'});
    }
    ordersInitialized=true;
    const select=document.getElementById('orders-manual-customer'),value=select.value;
    select.innerHTML='<option value="">Selecciona un cliente para un pedido manual</option>'+clientes.map(c=>'<option value="'+c.id+'">'+escVentaHtml(c.nombre)+(c.telefono?' · '+escVentaHtml(c.telefono):'')+'</option>').join('');select.value=value;
    status.textContent='Actualizado '+new Date().toLocaleTimeString('es-VE')+' · Los avisos se actualizan mientras el Admin esté abierto.';
    renderPedidosClientes();
  }catch(e){status.textContent='No se pudieron actualizar los pedidos: '+e.message;}
  finally{ordersLoading=false;}
}
function renderPedidosClientes(reset=false){
  if(reset)ordersPage=1;
  const h=escVentaHtml,q=document.getElementById('orders-search').value.trim().toLowerCase(),state=document.getElementById('orders-state').value;
  const totalNew=customerOrders.filter(orderIsNew).length;
  document.querySelectorAll('.orders-new-count').forEach(el=>el.textContent=totalNew?' ('+totalNew+')':'');
  document.getElementById('orders-new-summary').textContent=totalNew+' pedidos web sin revisar';
  const groups=new Map();
  for(const o of customerOrders){
    const c=clientes.find(c=>String(c.id)===String(o.cliente_id));
    const name=c?.nombre||o.cliente_nombre||'Sin cliente';
    const phone=o.checkout_payload?.response?.telefono||c?.telefono||'';
    if(q&&![name,phone,o.numero,...o.items.map(i=>i.producto_nombre)].join(' ').toLowerCase().includes(q))continue;
    if(state==='activos'&&['Entregado','Cancelado','Completado','Vencido'].includes(o.estado))continue;
    if(state==='nuevos'&&!orderIsNew(o))continue;
    if(!['','activos','nuevos'].includes(state)&&o.estado!==state)continue;
    // Unlinked orders stay separate; matching names alone do not prove identity.
    const key=c?'c:'+c.id:orderKey(o);
    if(!groups.has(key))groups.set(key,{name,phone,cid:c?.id,orders:[]});
    groups.get(key).orders.push(o);
  }
  const list=[...groups.values()].sort((a,b)=>Math.max(...b.orders.map(o=>Date.parse(o.creado_en)||0))-Math.max(...a.orders.map(o=>Date.parse(o.creado_en)||0)));
  const pages=Math.max(1,Math.ceil(list.length/20));ordersPage=Math.min(ordersPage,pages);
  document.getElementById('orders-page').textContent=list.length+' grupos · Página '+ordersPage+' de '+pages;
  document.getElementById('orders-prev').disabled=ordersPage===1;document.getElementById('orders-next').disabled=ordersPage===pages;
  document.getElementById('orders-groups').innerHTML=list.slice((ordersPage-1)*20,ordersPage*20).map(g=>
    '<details class="card order-customer" open><summary><strong>'+h(g.name)+'</strong> <span>'+h(g.phone)+' · '+g.orders.length+' pedidos</span></summary>'+g.orders.map(o=>{
      const args="'"+o.kind+"',"+o.id;
      const contact=o.checkout_payload?.response?.telefono||g.phone;
      const amount=o.kind==='apartado'?'Saldo: $'+Number(o.saldo||0).toFixed(2):'Total: $'+Number(o.total||0).toFixed(2);
      return '<article class="customer-order"><div class="customer-order-head"><strong>'+h(o.numero||'#'+o.id)+'</strong><span>'+h(o.estado||'')+' · '+h(o.canal||'Manual')+'</span>'+(orderIsNew(o)?'<b class="order-new">Nuevo</b>':'')+'</div>'+
        '<div class="customer-order-items">'+o.items.map(i=>'<span>'+h(i.producto_nombre||'Producto')+(i.variante_nombre?' · '+h(i.variante_nombre):'')+' × '+Number(i.cantidad||0)+'</span>').join('')+'</div>'+
        '<p>'+amount+' · '+h(formatFecha(o.fecha_venta||o.fecha_apartado||o.creado_en))+(o.fecha_entrega?' · Entrega: '+h(formatFecha(o.fecha_entrega)):'')+'</p>'+
        (o.notas?'<p>'+h(o.notas)+'</p>':'')+
        '<div class="inventory-actions"><button class="btn btn-primary btn-sm" onclick="editarPedidoCliente('+args+')">Abrir pedido</button>'+
        '<button class="btn btn-secondary btn-sm" onclick="asignarPedidoCliente('+args+')">Asignar cliente</button>'+
        (contact?'<a class="btn btn-secondary btn-sm" target="_blank" rel="noopener" href="https://wa.me/'+h(normalizarTelefonoPedido(contact))+'">WhatsApp</a>':'')+
        (orderIsNew(o)?'<button class="btn btn-secondary btn-sm" onclick="marcarPedidoRevisado('+args+')">Marcar revisado</button>':'')+'</div></article>';
    }).join('')+'</details>').join('')||'<div class="inventory-empty">No hay pedidos con estos filtros.</div>';
}
function normalizarTelefonoPedido(phone){let p=String(phone).replace(/\D/g,'');return /^0[24]\d{9}$/.test(p)?'58'+p.slice(1):p;}
function paginaPedidosClientes(delta){ordersPage+=delta;renderPedidosClientes();}
function marcarPedidoRevisado(kind,id){ordersSeen.add(kind+':'+id);try{localStorage.setItem('brl-orders-seen',JSON.stringify([...ordersSeen]));}catch(e){}renderPedidosClientes();}
function editarPedidoCliente(kind,id){
  const o=customerOrders.find(o=>o.kind===kind&&o.id===id);if(!o)return;
  if(kind==='venta')abrirModalVenta(o);
  else{const i=apartados.findIndex(a=>a.id===id);if(i<0)apartados.push(o);else apartados[i]=o;abrirModalApartado(id);}
}
function nuevoPedidoCliente(){
  const id=document.getElementById('orders-manual-customer').value,c=clientes.find(c=>String(c.id)===id);
  if(!c){toast('Selecciona un cliente o créalo con + Cliente');return;}
  abrirModalVenta();document.getElementById('v-cliente-id').value=c.id;document.getElementById('v-cliente-search').value=c.nombre;
  document.getElementById('v-estado').value='Cotización';
  document.getElementById('modal-venta-title').textContent='Nuevo pedido · '+c.nombre;
}
function asignarPedidoCliente(kind,id){
  const dialog=document.createElement('dialog');dialog.className='order-assign-dialog';
  dialog.innerHTML='<form method="dialog"><h3>Asignar pedido a cliente</h3><select required><option value="">Selecciona un cliente</option>'+clientes.map(c=>'<option value="'+c.id+'">'+escVentaHtml(c.nombre)+' · '+escVentaHtml(c.telefono||'')+'</option>').join('')+'</select><p role="status"></p><button type="button">Cancelar</button> <button type="submit">Guardar</button></form>';
  dialog.querySelector('button[type=button]').onclick=()=>dialog.close();
  dialog.onclose=()=>dialog.remove();
  dialog.querySelector('form').onsubmit=async e=>{
    e.preventDefault();const c=clientes.find(c=>String(c.id)===dialog.querySelector('select').value);if(!c)return;
    const button=dialog.querySelector('button[type=submit]');button.disabled=true;
    try{
      const response=await apiFetch(SB+'/rest/v1/'+(kind==='venta'?'ventas':'apartados')+'?id=eq.'+id,{method:'PATCH',headers:{...H,Prefer:'return=representation'},body:JSON.stringify({cliente_id:c.id,cliente_nombre:c.nombre})});
      if(!response||!response.ok)throw Error('No se pudo asignar el cliente. Vuelve a intentar.');
      const saved=await response.json();if(!saved.length)throw Error('El pedido ya no está disponible. Actualiza la lista.');
      dialog.close();await cargarPedidosClientes();
    }
    catch(error){dialog.querySelector('[role=status]').textContent=error.message;button.disabled=false;}
  };
  document.body.append(dialog);dialog.showModal();
}
async function activarAvisosPedidos(){
  if(!('Notification' in window)){toast('Este navegador no permite avisos. Revisa el contador del Admin.');return;}
  const permission=await Notification.requestPermission();
  toast(permission==='granted'?'Avisos activados mientras el Admin esté abierto':'Puedes revisar los avisos dentro del Admin');
}
setTimeout(()=>cargarPedidosClientes(true),1500);
setInterval(()=>cargarPedidosClientes(true),60000);
