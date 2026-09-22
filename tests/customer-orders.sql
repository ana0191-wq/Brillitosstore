-- Run after atomic-checkout.sql, within the same rolled-back transaction.
DO $$
DECLARE k uuid:=gen_random_uuid(); r jsonb; again jsonb; amount numeric; cid bigint; other jsonb; failed boolean:=false;
BEGIN
  amount:=(public.brl_quote('[{"producto_id":-920260920001,"cantidad":1}]','binance',1)->>'monto_pago')::numeric;
  r:=public.brl_checkout_customer(k,'[{"producto_id":-920260920001,"cantidad":1}]','binance',1,amount,'{"nombre":"TEST CUSTOMER 920260921","telefono":"04241234567"}');
  ASSERT r->>'numero' ~ '^WEB-V[0-9]{6,}$';
  ASSERT r->>'telefono'='584241234567';
  SELECT cliente_id INTO cid FROM public.ventas WHERE id=(r->>'id')::bigint;
  ASSERT cid IS NOT NULL;
  again:=public.brl_checkout_customer(k,'[{"producto_id":-920260920001,"cantidad":1}]','binance',1,amount,'{"nombre":"TEST CUSTOMER 920260921","telefono":"+58 424 1234567"}');
  ASSERT r=again,'Retries must return the same numbered order';
  BEGIN
    PERFORM public.brl_checkout_customer(k,'[{"producto_id":-920260920001,"cantidad":1}]','binance',1,amount,'{"nombre":"Different customer","telefono":"584241234567"}');
  EXCEPTION WHEN OTHERS THEN failed:=true; END;
  ASSERT failed,'Cannot reassign an idempotent checkout';
  amount:=(public.brl_quote('[{"producto_id":-920260920001,"cantidad":1}]','consulta',1)->>'monto_pago')::numeric;
  other:=public.brl_checkout_customer(gen_random_uuid(),'[{"producto_id":-920260920001,"cantidad":1}]','consulta',1,amount,'{"nombre":"TEST CUSTOMER 920260921","telefono":"584241234567"}');
  ASSERT other->>'numero' ~ '^WEB-C[0-9]{6,}$';
  ASSERT (SELECT cliente_id=cid FROM public.apartados WHERE id=(other->>'id')::bigint),'Same customer for sale and consultation';
  failed:=false;
  BEGIN
    PERFORM public.brl_checkout_customer(gen_random_uuid(),'[{"producto_id":-920260920001,"cantidad":1}]','consulta',1,amount,'{"nombre":"<script>bad</script>","telefono":"584241234567"}');
  EXCEPTION WHEN OTHERS THEN failed:=true; END;
  ASSERT failed,'Reject HTML in names';
END $$;
