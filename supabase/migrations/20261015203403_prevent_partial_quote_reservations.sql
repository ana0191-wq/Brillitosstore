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
  IF EXISTS (
    SELECT 1 FROM public.venta_items
    WHERE venta_id=p_id AND producto_id IS NULL
  ) THEN
    RAISE EXCEPTION 'Hay productos sin vincular al inventario. Corrige el catálogo antes de reservar stock';
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