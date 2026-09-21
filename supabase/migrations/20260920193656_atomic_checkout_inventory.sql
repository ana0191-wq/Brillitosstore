-- Atomic checkout and inventory. Intentionally SECURITY INVOKER: existing RLS is
-- unchanged. Authentication / public write permissions are a separate follow-up.
ALTER TABLE public.ventas
  ADD COLUMN IF NOT EXISTS checkout_key uuid UNIQUE,
  ADD COLUMN IF NOT EXISTS checkout_payload jsonb,
  ADD COLUMN IF NOT EXISTS subtotal_original numeric(12,2),
  ADD COLUMN IF NOT EXISTS descuento_promocion numeric(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS monto_pago numeric(12,2),
  ADD COLUMN IF NOT EXISTS tasa_usdt_usada numeric,
  ADD COLUMN IF NOT EXISTS apartado_origen_id bigint UNIQUE;
ALTER TABLE public.venta_items
  ADD COLUMN IF NOT EXISTS precio_original numeric(12,2),
  ADD COLUMN IF NOT EXISTS promocion jsonb;
ALTER TABLE public.apartados
  ADD COLUMN IF NOT EXISTS checkout_key uuid UNIQUE,
  ADD COLUMN IF NOT EXISTS checkout_payload jsonb;
ALTER TABLE public.apartado_items
  ADD COLUMN IF NOT EXISTS variante_id bigint,
  ADD COLUMN IF NOT EXISTS variante_nombre text,
  ADD COLUMN IF NOT EXISTS imagen_url text;

CREATE OR REPLACE FUNCTION public.brl_quote(p_items jsonb, p_method text, p_rate numeric DEFAULT 1)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE
  i record; p public.productos; v public.producto_variantes;
  rule jsonb; rules jsonb; chosen jsonb; pct numeric; base numeric; price numeric;
  original numeric := 0; sub numeric := 0; discount numeric; total numeric;
  result_items jsonb := '[]'; today text := (now() AT TIME ZONE 'America/Caracas')::date::text;
BEGIN
  IF p_method IS NULL OR p_method NOT IN ('binance','bolivares','paypal','consulta') THEN
    RAISE EXCEPTION 'Método de pago inválido'; END IF;
  IF jsonb_typeof(p_items) IS DISTINCT FROM 'array' OR jsonb_array_length(p_items) NOT BETWEEN 1 AND 100 THEN
    RAISE EXCEPTION 'Carrito vacío o demasiado grande'; END IF;
  IF p_rate IS NULL OR p_rate <= 0 OR p_rate > 1000000 THEN RAISE EXCEPTION 'Tasa inválida'; END IF;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(p_items) x WHERE
    COALESCE((x->>'cantidad')::numeric,0) NOT BETWEEN 1 AND 10000 OR
    (x->>'cantidad')::numeric <> trunc((x->>'cantidad')::numeric) OR x->>'producto_id' IS NULL)
    THEN RAISE EXCEPTION 'Cantidad o producto inválido'; END IF;
  SELECT descuento_reglas INTO rules FROM public.configuracion_tienda WHERE id=1;
  FOR i IN SELECT (x->>'producto_id')::bigint pid, NULLIF(x->>'variante_id','')::bigint vid,
    sum((x->>'cantidad')::integer)::integer qty FROM jsonb_array_elements(p_items) x
    GROUP BY 1,2 ORDER BY 1,2 NULLS FIRST LOOP
    SELECT * INTO p FROM public.productos WHERE id=i.pid FOR SHARE;
    IF NOT FOUND OR p.activo IS FALSE OR p.visible_web IS FALSE OR p.archivado_en IS NOT NULL THEN
      RAISE EXCEPTION 'Producto no disponible: %',i.pid; END IF;
    v := NULL; base:=p.precio;
    IF i.vid IS NOT NULL THEN
      SELECT * INTO v FROM public.producto_variantes WHERE id=i.vid AND producto_id=i.pid AND activo IS NOT FALSE FOR SHARE;
      IF NOT FOUND THEN RAISE EXCEPTION 'Variante no disponible'; END IF;
      IF COALESCE(NULLIF(v.precio,'')::numeric,0)>0 THEN base:=v.precio::numeric; END IF;
      IF COALESCE(v.stock,0)<i.qty THEN RAISE EXCEPTION 'Stock insuficiente: %',p.nombre; END IF;
    ELSE
      IF EXISTS (SELECT 1 FROM public.producto_variantes WHERE producto_id=i.pid AND activo IS NOT FALSE) THEN
        RAISE EXCEPTION 'Selecciona una variante para %',p.nombre; END IF;
      IF p.stock<i.qty THEN RAISE EXCEPTION 'Stock insuficiente: %',p.nombre; END IF;
    END IF;
    IF base<=0 THEN RAISE EXCEPTION 'Precio no disponible'; END IF;
    pct:=0; chosen:=NULL;
    FOR rule IN SELECT value FROM jsonb_array_elements(COALESCE(rules,'[]')) LOOP
      IF COALESCE((rule->>'activo')::boolean,true)
        AND COALESCE(NULLIF(rule->>'fecha_inicio',''),today)<=today
        AND COALESCE(NULLIF(rule->>'fecha_fin',''),today)>=today
        AND base>=COALESCE((rule->>'monto_minimo')::numeric,0)
        AND (COALESCE(rule->>'alcance','todos')='todos'
          OR (rule->>'alcance'='productos' AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(rule->'producto_ids') id WHERE id=p.id::text))
          OR (rule->>'alcance'='categorias' AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(rule->'categorias') cat
            WHERE lower(trim(translate(cat,'áéíóúÁÉÍÓÚ','aeiouAEIOU')))=lower(trim(translate(p.categoria,'áéíóúÁÉÍÓÚ','aeiouAEIOU'))))))
        AND LEAST(100,GREATEST(0,(rule->>'porcentaje')::numeric))>pct THEN
        pct:=LEAST(100,GREATEST(0,(rule->>'porcentaje')::numeric)); chosen:=rule;
      END IF;
    END LOOP;
    price:=round(base*(1-pct/100),2);
    IF p.en_remate AND p.precio_remate>0 AND p.precio_remate<base THEN
      price:=round(p.precio_remate,2); chosen:=jsonb_build_object('nombre','Remate'); END IF;
    sub:=sub+price*i.qty; original:=original+base*i.qty;
    result_items:=result_items||jsonb_build_array(jsonb_build_object(
      'producto_id',p.id,'variante_id',i.vid,'variante_nombre',v.nombre,'producto_nombre',p.nombre,
      'imagen_url',COALESCE(NULLIF(v.imagen,''),NULLIF(p.imagen,''),p.imagenes[1]),
      'precio_original',base,'precio_unitario',price,'cantidad',i.qty,'subtotal',price*i.qty,'promocion',chosen));
  END LOOP;
  discount:=CASE WHEN p_method='binance' THEN round(sub*0.1,2) ELSE 0 END;
  total:=sub-discount;
  RETURN jsonb_build_object('items',result_items,'subtotal_original',original,'subtotal',sub,
    'descuento_promocion',original-sub,'descuento',discount,'total',total,
    'moneda_pago',CASE p_method WHEN 'binance' THEN 'USDT' WHEN 'bolivares' THEN 'Bs' ELSE 'USD' END,
    'monto_pago',CASE p_method WHEN 'binance' THEN round(total/p_rate,2)
      WHEN 'bolivares' THEN round(total*p_rate,2) WHEN 'paypal' THEN round((total+0.30)/0.946,2) ELSE total END);
END $$;

CREATE OR REPLACE FUNCTION public.brl_checkout(p_key uuid,p_items jsonb,p_method text,p_rate numeric,p_expected numeric)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE q jsonb; old_payload jsonb; payload jsonb; vid bigint; aid bigint; it jsonb; num text; label text;
BEGIN
  IF p_key IS NULL THEN RAISE EXCEPTION 'Falta identificador del pedido'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(p_key::text,0));
  payload:=jsonb_build_object('items',p_items,'method',p_method,'rate',p_rate);
  SELECT id,checkout_payload INTO vid,old_payload FROM public.ventas WHERE checkout_key=p_key;
  IF FOUND THEN
    IF old_payload->'request' IS DISTINCT FROM payload THEN RAISE EXCEPTION 'Este pedido ya fue registrado con otros datos'; END IF;
    RETURN old_payload->'response';
  END IF;
  SELECT id,checkout_payload INTO aid,old_payload FROM public.apartados WHERE checkout_key=p_key;
  IF FOUND THEN
    IF old_payload->'request' IS DISTINCT FROM payload THEN RAISE EXCEPTION 'Esta consulta ya fue registrada con otros datos'; END IF;
    RETURN old_payload->'response';
  END IF;
  q:=public.brl_quote(p_items,p_method,p_rate);
  IF p_expected IS NULL OR (q->>'monto_pago')::numeric<>p_expected THEN
    RAISE EXCEPTION 'El precio cambió. Revisa el total actualizado antes de continuar'; END IF;
  num:='WEB-'||p_key::text;
  label:=CASE p_method WHEN 'binance' THEN 'Binance/USDT' WHEN 'paypal' THEN 'PayPal' WHEN 'bolivares' THEN 'Pago Móvil' ELSE 'Consulta' END;
  IF p_method='consulta' THEN
    INSERT INTO public.apartados(numero,cliente_nombre,canal,metodo_pago,estado,total,abono,saldo,notas,checkout_key)
    VALUES(num,'Web — Consulta','Web',label,'Por confirmar',(q->>'total')::numeric,0,(q->>'total')::numeric,
      'Consulta web. No reserva inventario.',p_key) RETURNING id INTO aid;
    FOR it IN SELECT value FROM jsonb_array_elements(q->'items') LOOP
      INSERT INTO public.apartado_items(apartado_id,producto_id,producto_nombre,variante_id,variante_nombre,imagen_url,precio_unitario,cantidad,subtotal)
      SELECT aid, x.producto_id,x.producto_nombre,x.variante_id,x.variante_nombre,x.imagen_url,x.precio_unitario,x.cantidad,x.subtotal
      FROM jsonb_populate_record(NULL::public.apartado_items,it) x;
    END LOOP;
    q:=q||jsonb_build_object('id',aid,'numero',num,'tipo','consulta');
    UPDATE public.apartados SET checkout_payload=jsonb_build_object('request',payload,'response',q) WHERE id=aid;
  ELSE
    INSERT INTO public.ventas(numero,cliente_nombre,canal,metodo_pago,estado,subtotal,costo_envio,descuento,total,
      fecha_venta,tipo_entrega,notas,moneda_pago,cuenta_cobro,stock_aplicado,checkout_key,subtotal_original,descuento_promocion,
      monto_pago,tasa_usdt_usada,tasa_bcv_usada,monto_bs)
    VALUES(num,'Cliente web — '||label,'Web',label,'Pendiente',(q->>'subtotal')::numeric,0,(q->>'descuento')::numeric,
      (q->>'total')::numeric,(now() AT TIME ZONE 'America/Caracas')::date,'Por coordinar','Comprobante pendiente de verificar',
      q->>'moneda_pago',CASE p_method WHEN 'bolivares' THEN 'bancaamiga_luisma' ELSE p_method END,false,p_key,
      (q->>'subtotal_original')::numeric,(q->>'descuento_promocion')::numeric,(q->>'monto_pago')::numeric,
      CASE WHEN p_method='binance' THEN p_rate END,CASE WHEN p_method='bolivares' THEN p_rate END,
      CASE WHEN p_method='bolivares' THEN (q->>'monto_pago')::numeric END) RETURNING id INTO vid;
    FOR it IN SELECT value FROM jsonb_array_elements(q->'items') LOOP
      INSERT INTO public.venta_items(venta_id,producto_id,producto_nombre,variante_id,variante_nombre,imagen_url,precio_unitario,cantidad,subtotal,precio_original,promocion)
      SELECT vid,x.producto_id,x.producto_nombre,x.variante_id,x.variante_nombre,x.imagen_url,x.precio_unitario,x.cantidad,x.subtotal,x.precio_original,x.promocion
      FROM jsonb_populate_record(NULL::public.venta_items,it) x;
    END LOOP;
    q:=q||jsonb_build_object('id',vid,'numero',num,'tipo','venta');
    UPDATE public.ventas SET checkout_payload=jsonb_build_object('request',payload,'response',q) WHERE id=vid;
  END IF;
  RETURN q;
END $$;

-- Every stock adjustment locks parent products in ascending order, then variants.
-- A failed item or state write aborts the entire transaction, including archiving.
CREATE OR REPLACE FUNCTION public.brl_inventory(p_items jsonb,p_direction integer)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE it record; p public.productos; v public.producto_variantes; remaining bigint;
BEGIN
  IF p_direction NOT IN (-1,1) THEN RAISE EXCEPTION 'Movimiento inválido'; END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_items) x WHERE COALESCE((x->>'cantidad')::integer,0)<=0) THEN
    RAISE EXCEPTION 'Cantidad inválida'; END IF;
  PERFORM id FROM public.productos WHERE id IN (SELECT (x->>'producto_id')::bigint FROM jsonb_array_elements(p_items) x) ORDER BY id FOR UPDATE;
  FOR it IN SELECT (x->>'producto_id')::bigint pid,NULLIF(x->>'variante_id','')::bigint vid,sum((x->>'cantidad')::integer) qty
    FROM jsonb_array_elements(p_items) x WHERE x->>'producto_id' IS NOT NULL GROUP BY 1,2 ORDER BY 1,2 NULLS FIRST LOOP
    SELECT * INTO p FROM public.productos WHERE id=it.pid;
    IF NOT FOUND THEN RAISE EXCEPTION 'Producto inexistente: %',it.pid; END IF;
    IF it.vid IS NOT NULL THEN
      SELECT * INTO v FROM public.producto_variantes WHERE id=it.vid AND producto_id=it.pid FOR UPDATE;
      IF NOT FOUND THEN RAISE EXCEPTION 'Variante inexistente'; END IF;
      remaining:=COALESCE(v.stock,0)+p_direction*it.qty;
      IF remaining<0 THEN RAISE EXCEPTION 'Stock insuficiente: % — %',p.nombre,v.nombre; END IF;
      UPDATE public.producto_variantes SET stock=remaining WHERE id=it.vid;
    ELSE
      IF EXISTS(SELECT 1 FROM public.producto_variantes WHERE producto_id=it.pid AND activo IS NOT FALSE) THEN
        RAISE EXCEPTION 'Falta la variante de %. Edita el detalle antes de confirmar',p.nombre; END IF;
      remaining:=p.stock+p_direction*it.qty;
      IF remaining<0 THEN RAISE EXCEPTION 'Stock insuficiente: %',p.nombre; END IF;
      UPDATE public.productos SET stock=remaining WHERE id=p.id;
    END IF;
  END LOOP;
  FOR p IN SELECT * FROM public.productos WHERE id IN (SELECT (x->>'producto_id')::bigint FROM jsonb_array_elements(p_items) x) LOOP
    IF EXISTS(SELECT 1 FROM public.producto_variantes WHERE producto_id=p.id AND activo IS NOT FALSE) THEN
      SELECT COALESCE(sum(stock),0) INTO remaining FROM public.producto_variantes WHERE producto_id=p.id AND activo IS NOT FALSE;
      UPDATE public.productos SET stock=remaining WHERE id=p.id;
    ELSE remaining:=p.stock; END IF;
    IF remaining=0 AND p.donado_en IS NULL THEN
      UPDATE public.productos SET archivado_en=COALESCE(archivado_en,now()),motivo_archivo='Agotado',
        vendido_en=COALESCE(vendido_en,now()),activo=false,visible_web=false WHERE id=p.id;
    ELSIF remaining>0 AND p.motivo_archivo='Agotado' AND p.donado_en IS NULL THEN
      UPDATE public.productos SET archivado_en=NULL,motivo_archivo=NULL,vendido_en=NULL,activo=true,visible_web=true WHERE id=p.id;
    END IF;
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.brl_sale_state(p_id bigint,p_state text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE v public.ventas; items jsonb; desired boolean;
BEGIN
  IF p_state IS NULL OR p_state NOT IN ('Pendiente','Pagado','Entregado','Cancelado','Cotización') THEN RAISE EXCEPTION 'Estado inválido'; END IF;
  SELECT * INTO STRICT v FROM public.ventas WHERE id=p_id FOR UPDATE;
  desired:=p_state IN ('Pagado','Entregado') OR (p_state='Pendiente' AND v.canal IS DISTINCT FROM 'Web');
  IF desired IS DISTINCT FROM v.stock_aplicado THEN
    SELECT COALESCE(jsonb_agg(to_jsonb(i)),'[]') INTO items FROM public.venta_items i WHERE venta_id=p_id;
    IF desired AND jsonb_array_length(items)=0 THEN RAISE EXCEPTION 'No se puede confirmar una venta sin productos'; END IF;
    PERFORM public.brl_inventory(items,CASE WHEN desired THEN -1 ELSE 1 END);
  END IF;
  UPDATE public.ventas SET estado=p_state,stock_aplicado=desired WHERE id=p_id RETURNING * INTO v;
  RETURN to_jsonb(v);
END $$;

CREATE OR REPLACE FUNCTION public.brl_save_sale(p_id bigint,p_data jsonb,p_items jsonb,p_key uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE old public.ventas; v public.ventas; it jsonb; old_items jsonb; sub numeric:=0; orig numeric:=0; state text;
BEGIN
  IF jsonb_typeof(p_items) IS DISTINCT FROM 'array' OR jsonb_array_length(p_items) NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'Agrega productos'; END IF;
  IF p_id IS NULL AND p_key IS NULL THEN RAISE EXCEPTION 'Falta identificador de venta'; END IF;
  IF p_key IS NOT NULL THEN
    PERFORM pg_advisory_xact_lock(hashtextextended(p_key::text,0));
    IF p_id IS NULL THEN
      SELECT * INTO old FROM public.ventas WHERE checkout_key=p_key;
      IF FOUND THEN RETURN to_jsonb(old); END IF;
    END IF;
  END IF;
  IF p_id IS NOT NULL THEN
    SELECT * INTO STRICT old FROM public.ventas WHERE id=p_id FOR UPDATE;
    SELECT COALESCE(jsonb_agg(to_jsonb(i)),'[]') INTO old_items FROM public.venta_items i WHERE venta_id=p_id;
    -- Lock the union before restoring and re-applying to prevent reversed lock order.
    PERFORM id FROM public.productos WHERE id IN (SELECT (x->>'producto_id')::bigint FROM jsonb_array_elements(old_items||p_items) x) ORDER BY id FOR UPDATE;
    IF old.stock_aplicado THEN PERFORM public.brl_inventory(old_items,1); END IF;
    v:=old;
  END IF;
  -- Only form-owned fields are accepted; internal tracking cannot be overwritten.
  SELECT * INTO v FROM jsonb_populate_record(v,p_data - ARRAY['id','checkout_key','checkout_payload','stock_aplicado','apartado_origen_id','creado_en']);
  FOR it IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    IF COALESCE((it->>'cantidad')::numeric,0) NOT BETWEEN 1 AND 10000
      OR (it->>'cantidad')::numeric<>trunc((it->>'cantidad')::numeric)
      OR COALESCE((it->>'precio_unitario')::numeric,-1)<0 THEN RAISE EXCEPTION 'Precio o cantidad inválidos'; END IF;
    sub:=sub+round((it->>'precio_unitario')::numeric,2)*(it->>'cantidad')::integer;
    orig:=orig+GREATEST(COALESCE((it->>'precio_original')::numeric,0),(it->>'precio_unitario')::numeric)*(it->>'cantidad')::integer;
  END LOOP;
  v.subtotal:=sub; v.subtotal_original:=orig; v.descuento_promocion:=orig-sub;
  v.costo_envio:=COALESCE(v.costo_envio,0);v.descuento:=COALESCE(v.descuento,0);
  IF v.canal='Web' THEN
    v.descuento:=CASE WHEN v.metodo_pago='Binance/USDT' THEN round(sub*0.1,2) ELSE 0 END;
  END IF;
  IF v.costo_envio<0 OR v.descuento<0 OR v.descuento>sub+v.costo_envio THEN RAISE EXCEPTION 'Descuento o envío inválidos'; END IF;
  v.total:=sub+v.costo_envio-v.descuento; state:=COALESCE(v.estado,'Pendiente');
  IF v.metodo_pago='Binance/USDT' THEN
    v.moneda_pago:='USDT'; v.tasa_usdt_usada:=COALESCE(NULLIF(v.tasa_usdt_usada,0),1); v.monto_pago:=round(v.total/v.tasa_usdt_usada,2);
  ELSIF v.metodo_pago IN ('Pago Móvil','BCV','Efectivo Bs') THEN v.moneda_pago:='Bs';v.monto_pago:=v.monto_bs;
  ELSE v.moneda_pago:='USD';v.monto_pago:=CASE WHEN v.metodo_pago='PayPal' THEN round((v.total+0.30)/0.946,2) ELSE v.total END; END IF;
  IF p_id IS NULL THEN
    INSERT INTO public.ventas(numero,cliente_id,cliente_nombre,canal,evento_id,metodo_pago,tipo_entrega,fecha_venta,fecha_entrega,
      estado,subtotal,costo_envio,descuento,total,tasa_bcv_usada,monto_bs,moneda_pago,cuenta_cobro,referencia_pago,notas,
      stock_aplicado,checkout_key,subtotal_original,descuento_promocion,monto_pago,tasa_usdt_usada)
    VALUES(COALESCE(v.numero,'V-'||p_key::text),v.cliente_id,v.cliente_nombre,v.canal,v.evento_id,v.metodo_pago,v.tipo_entrega,
      COALESCE(v.fecha_venta,(now() AT TIME ZONE 'America/Caracas')::date),v.fecha_entrega,'Cotización',sub,v.costo_envio,v.descuento,v.total,
      v.tasa_bcv_usada,v.monto_bs,v.moneda_pago,v.cuenta_cobro,v.referencia_pago,v.notas,false,p_key,orig,orig-sub,v.monto_pago,v.tasa_usdt_usada) RETURNING id INTO p_id;
  ELSE
    UPDATE public.ventas SET cliente_id=v.cliente_id,cliente_nombre=v.cliente_nombre,canal=v.canal,evento_id=v.evento_id,
      metodo_pago=v.metodo_pago,tipo_entrega=v.tipo_entrega,fecha_venta=v.fecha_venta,fecha_entrega=v.fecha_entrega,
      subtotal=sub,costo_envio=v.costo_envio,descuento=v.descuento,total=v.total,tasa_bcv_usada=v.tasa_bcv_usada,
      monto_bs=v.monto_bs,moneda_pago=v.moneda_pago,cuenta_cobro=v.cuenta_cobro,referencia_pago=v.referencia_pago,
      stock_aplicado=false,subtotal_original=orig,descuento_promocion=orig-sub,monto_pago=v.monto_pago,tasa_usdt_usada=v.tasa_usdt_usada WHERE id=p_id;
    DELETE FROM public.venta_items WHERE venta_id=p_id;
  END IF;
  FOR it IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    INSERT INTO public.venta_items(venta_id,producto_id,producto_nombre,variante_id,variante_nombre,imagen_url,precio_unitario,cantidad,subtotal,precio_original,promocion)
    SELECT p_id,x.producto_id,x.producto_nombre,x.variante_id,x.variante_nombre,x.imagen_url,round(x.precio_unitario,2),x.cantidad,
      round(x.precio_unitario,2)*x.cantidad,x.precio_original,x.promocion FROM jsonb_populate_record(NULL::public.venta_items,it) x;
  END LOOP;
  RETURN public.brl_sale_state(p_id,state);
END $$;

CREATE OR REPLACE FUNCTION public.brl_convert_apartado(p_id bigint,p_reference text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE a public.apartados; v public.ventas; sub numeric; vid bigint;
BEGIN
  SELECT * INTO STRICT a FROM public.apartados WHERE id=p_id FOR UPDATE;
  SELECT * INTO v FROM public.ventas WHERE apartado_origen_id=p_id;
  IF FOUND THEN RETURN to_jsonb(v); END IF;
  IF a.estado IN ('Completado','Cancelado') THEN RAISE EXCEPTION 'El apartado ya está cerrado'; END IF;
  SELECT sum(subtotal) INTO sub FROM public.apartado_items WHERE apartado_id=p_id;
  IF sub IS NULL THEN RAISE EXCEPTION 'El apartado no tiene productos'; END IF;
  INSERT INTO public.ventas(numero,cliente_id,cliente_nombre,canal,metodo_pago,estado,subtotal,total,descuento,costo_envio,
    fecha_venta,referencia_pago,tasa_bcv_usada,monto_bs,moneda_pago,cuenta_cobro,stock_aplicado,apartado_origen_id)
  VALUES('APT-VENTA-'||p_id,a.cliente_id,a.cliente_nombre,a.canal,a.metodo_pago,'Pendiente',sub,a.total,GREATEST(0,sub-a.total),0,
    (now() AT TIME ZONE 'America/Caracas')::date,p_reference,a.tasa_bcv_usada,a.monto_bs,a.moneda_pago,a.cuenta_cobro,
    a.canal IS DISTINCT FROM 'Web',p_id) RETURNING id INTO vid;
  INSERT INTO public.venta_items(venta_id,producto_id,producto_nombre,variante_id,variante_nombre,imagen_url,precio_unitario,cantidad,subtotal)
    SELECT vid,producto_id,producto_nombre,variante_id,variante_nombre,imagen_url,precio_unitario,cantidad,subtotal FROM public.apartado_items WHERE apartado_id=p_id;
  PERFORM public.brl_sale_state(vid,'Pagado');
  UPDATE public.apartados SET estado='Completado',abono=total,saldo=0 WHERE id=p_id;
  SELECT * INTO v FROM public.ventas WHERE id=vid; RETURN to_jsonb(v);
END $$;

-- Do not change table policies in this release. These invoker functions cannot
-- exceed existing caller privileges. Remove anon admin access with the auth rollout.
REVOKE ALL ON FUNCTION public.brl_quote(jsonb,text,numeric), public.brl_checkout(uuid,jsonb,text,numeric,numeric),
 public.brl_inventory(jsonb,integer),public.brl_sale_state(bigint,text),public.brl_save_sale(bigint,jsonb,jsonb,uuid),
 public.brl_convert_apartado(bigint,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.brl_quote(jsonb,text,numeric),public.brl_checkout(uuid,jsonb,text,numeric,numeric),
 public.brl_inventory(jsonb,integer),public.brl_sale_state(bigint,text),public.brl_save_sale(bigint,jsonb,jsonb,uuid),
 public.brl_convert_apartado(bigint,text) TO anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.brl_update_sales(p_ids bigint[],p_changes jsonb)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE v public.ventas; state text;
BEGIN
  IF cardinality(p_ids)>500 THEN RAISE EXCEPTION 'Demasiadas ventas'; END IF;
  PERFORM id FROM public.ventas WHERE id=ANY(p_ids) ORDER BY id FOR UPDATE;
  PERFORM id FROM public.productos WHERE id IN(SELECT producto_id FROM public.venta_items WHERE venta_id=ANY(p_ids)) ORDER BY id FOR UPDATE;
  FOR v IN SELECT * FROM public.ventas WHERE id=ANY(p_ids) ORDER BY id LOOP
    SELECT * INTO v FROM jsonb_populate_record(v,(SELECT COALESCE(jsonb_object_agg(key,value),'{}') FROM jsonb_each(p_changes)
      WHERE key IN ('canal','evento_id','metodo_pago','cuenta_cobro','fecha_venta','estado')));
    state:=v.estado;
    UPDATE public.ventas SET canal=v.canal,evento_id=v.evento_id,metodo_pago=v.metodo_pago,cuenta_cobro=v.cuenta_cobro,fecha_venta=v.fecha_venta WHERE id=v.id;
    PERFORM public.brl_sale_state(v.id,state);
  END LOOP;
END $$;
REVOKE ALL ON FUNCTION public.brl_update_sales(bigint[],jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.brl_update_sales(bigint[],jsonb) TO anon,authenticated,service_role;
NOTIFY pgrst, 'reload schema';
