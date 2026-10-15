CREATE EXTENSION IF NOT EXISTS pg_cron;

ALTER TABLE public.ventas
  ADD COLUMN IF NOT EXISTS cotizacion_expira_en timestamptz;

CREATE OR REPLACE FUNCTION public.brl_reserve_quote(p_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
  v public.ventas;
  items jsonb;
BEGIN
  SELECT * INTO STRICT v FROM public.ventas WHERE id=p_id FOR UPDATE;
  IF v.estado IS DISTINCT FROM 'Cotización' THEN
    RAISE EXCEPTION 'Solo se puede reservar inventario para una cotización';
  END IF;
  IF v.stock_aplicado IS TRUE AND v.cotizacion_expira_en > now() THEN
    RETURN to_jsonb(v);
  END IF;
  SELECT COALESCE(jsonb_agg(to_jsonb(i)),'[]'::jsonb)
    INTO items FROM public.venta_items i WHERE i.venta_id=p_id;
  IF jsonb_array_length(items)=0 THEN
    RAISE EXCEPTION 'La cotización no tiene productos';
  END IF;
  IF v.stock_aplicado IS TRUE THEN
    PERFORM public.brl_inventory(items,1);
    UPDATE public.ventas SET stock_aplicado=false WHERE id=p_id;
  END IF;
  PERFORM public.brl_inventory(items,-1);
  UPDATE public.ventas
    SET stock_aplicado=true,cotizacion_expira_en=now()+interval '1 hour'
    WHERE id=p_id
    RETURNING * INTO v;
  RETURN to_jsonb(v);
END
$function$;

CREATE OR REPLACE FUNCTION public.brl_expire_quotes()
RETURNS integer
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
  v public.ventas;
  items jsonb;
  expired_count integer:=0;
BEGIN
  FOR v IN
    SELECT * FROM public.ventas
    WHERE estado='Cotización'
      AND stock_aplicado IS TRUE
      AND cotizacion_expira_en IS NOT NULL
      AND cotizacion_expira_en <= now()
    ORDER BY id
    FOR UPDATE SKIP LOCKED
  LOOP
    SELECT COALESCE(jsonb_agg(to_jsonb(i)),'[]'::jsonb)
      INTO items FROM public.venta_items i WHERE i.venta_id=v.id;
    IF jsonb_array_length(items)>0 THEN
      PERFORM public.brl_inventory(items,1);
    END IF;
    UPDATE public.ventas SET stock_aplicado=false WHERE id=v.id;
    expired_count:=expired_count+1;
  END LOOP;
  RETURN expired_count;
END
$function$;

DO $schedule$
DECLARE j record;
BEGIN
  FOR j IN SELECT jobid FROM cron.job WHERE jobname='brillitos-expire-quote-reservations'
  LOOP
    PERFORM cron.unschedule(j.jobid);
  END LOOP;
  PERFORM cron.schedule(
    'brillitos-expire-quote-reservations',
    '* * * * *',
    'SELECT public.brl_expire_quotes();'
  );
END
$schedule$;

UPDATE public.ventas
SET monto_bs=round(total*tasa_bcv_usada,2),
    monto_pago=round(total*tasa_bcv_usada,2)
WHERE estado='Cotización'
  AND metodo_pago IN ('Pago Móvil','BCV','Efectivo Bs')
  AND COALESCE(tasa_bcv_usada,0)>0;
