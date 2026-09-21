-- Run with the migration inside BEGIN / ROLLBACK. No test records persist.
DO $$
DECLARE q jsonb; r jsonb; v jsonb; first_id bigint; aid bigint; key1 uuid:=gen_random_uuid(); key2 uuid:=gen_random_uuid(); failed boolean; n integer;
BEGIN
  INSERT INTO public.productos(id,nombre,precio,stock,imagen) VALUES
    (-920260920001,'TEST ATOMIC A',100,10,'https://example.com/a.png'),
    (-920260920002,'TEST ATOMIC B',10,10,'https://example.com/b.png'),
    (-920260920003,'TEST ATOMIC VARIANT',100,5,'https://example.com/c.png');
  INSERT INTO public.producto_variantes(id,producto_id,nombre,precio,stock,activo)
    VALUES(-920260920001,-920260920003,'Rosa','100',5,true);
  UPDATE public.configuracion_tienda SET descuento_reglas='[{"id":"test","activo":true,"porcentaje":20,"alcance":"todos","fecha_fin":"2099-09-30"}]' WHERE id=1;
  q:=public.brl_quote('[{"producto_id":-920260920001,"cantidad":1}]','binance',1);
  ASSERT (q->>'total')::numeric=72,'20% + 10% must be 72';
  ASSERT (q->>'descuento_promocion')::numeric=20,'Promotion audit';
  r:=public.brl_checkout(key1,'[{"producto_id":-920260920001,"cantidad":1}]','binance',1,72);
  first_id:=(r->>'id')::bigint;
  ASSERT (SELECT stock=10 FROM public.productos WHERE id=-920260920001),'Pending must not reserve stock';
  v:=public.brl_checkout(key1,'[{"producto_id":-920260920001,"cantidad":1}]','binance',1,72);
  ASSERT r=v,'Checkout retry must return the same receipt';
  SELECT count(*) INTO n FROM public.ventas WHERE checkout_key=key1; ASSERT n=1,'Duplicate checkout';
  PERFORM public.brl_sale_state(first_id,'Pagado');
  PERFORM public.brl_sale_state(first_id,'Pagado');
  PERFORM public.brl_sale_state(first_id,'Entregado');
  ASSERT (SELECT stock=9 FROM public.productos WHERE id=-920260920001),'Confirm/deliver once';
  PERFORM public.brl_sale_state(first_id,'Cancelado');
  PERFORM public.brl_sale_state(first_id,'Cancelado');
  ASSERT (SELECT stock=10 FROM public.productos WHERE id=-920260920001),'Cancel restores once';
  failed:=false;
  BEGIN PERFORM public.brl_checkout(gen_random_uuid(),'[{"producto_id":-920260920001,"cantidad":1}]','binance',1,0);
  EXCEPTION WHEN OTHERS THEN failed:=true; END;
  ASSERT failed,'Tampered expected total must be rejected';
  failed:=false;
  BEGIN PERFORM public.brl_quote('[{"producto_id":-920260920001,"cantidad":6},{"producto_id":-920260920001,"cantidad":6}]','binance',1);
  EXCEPTION WHEN OTHERS THEN failed:=true; END;
  ASSERT failed,'Duplicate lines must be grouped for stock validation';
  failed:=false;
  BEGIN PERFORM public.brl_quote('[{"producto_id":-920260920001,"cantidad":1.5}]','binance',1);
  EXCEPTION WHEN OTHERS THEN failed:=true; END;
  ASSERT failed,'Fractional quantities rejected';
  r:=public.brl_checkout(key2,'[{"producto_id":-920260920001,"cantidad":1},{"producto_id":-920260920002,"cantidad":1}]','binance',1,79.2);
  UPDATE public.productos SET stock=0 WHERE id=-920260920002;
  failed:=false;
  BEGIN PERFORM public.brl_sale_state((r->>'id')::bigint,'Pagado'); EXCEPTION WHEN OTHERS THEN failed:=true; END;
  ASSERT failed,'Insufficient second item must fail';
  ASSERT (SELECT stock=10 FROM public.productos WHERE id=-920260920001),'First item must roll back';
  ASSERT (SELECT NOT stock_aplicado AND estado='Pendiente' FROM public.ventas WHERE id=(r->>'id')::bigint),'Sale state must roll back';
  v:=public.brl_save_sale(first_id,'{"estado":"Pagado"}','[{"producto_id":-920260920001,"producto_nombre":"Test","precio_unitario":80,"cantidad":2}]');
  ASSERT (SELECT stock=8 FROM public.productos WHERE id=-920260920001),'Edit pending/cancelled to paid applies stock';
  failed:=false;
  BEGIN PERFORM public.brl_save_sale(first_id,'{"estado":"Pagado"}','[{"producto_id":-920260920001,"precio_unitario":80,"cantidad":20}]'); EXCEPTION WHEN OTHERS THEN failed:=true; END;
  ASSERT failed,'Invalid edit must fail';
  ASSERT (SELECT stock=8 FROM public.productos WHERE id=-920260920001),'Invalid edit restores entire previous state';
  ASSERT (SELECT cantidad=2 FROM public.venta_items WHERE venta_id=first_id),'Invalid edit preserves items';
  r:=public.brl_checkout(gen_random_uuid(),'[{"producto_id":-920260920003,"variante_id":-920260920001,"cantidad":1}]','consulta',1,80);
  aid:=(r->>'id')::bigint;
  v:=public.brl_convert_apartado(aid,'test');
  PERFORM public.brl_convert_apartado(aid,'test');
  ASSERT (SELECT stock=4 FROM public.producto_variantes WHERE id=-920260920001),'Conversion preserves variant and deducts once';
  ASSERT (SELECT count(*)=1 FROM public.ventas WHERE apartado_origen_id=aid),'One sale per apartado';
  PERFORM public.brl_sale_state((v->>'id')::bigint,'Cancelado');
  ASSERT (SELECT stock=5 FROM public.producto_variantes WHERE id=-920260920001),'Cancel restores variant';
  UPDATE public.configuracion_tienda SET descuento_reglas='[{"activo":true,"porcentaje":20,"alcance":"todos","fecha_fin":"2000-09-30"}]' WHERE id=1;
  q:=public.brl_quote('[{"producto_id":-920260920001,"cantidad":1}]','binance',1);
  ASSERT (q->>'total')::numeric=90,'Expired promotion leaves fixed Binance 10%';
  RAISE NOTICE 'All atomic checkout / inventory assertions passed';
END $$;
