-- Customer details, order lines and inventory semantics commit together.
CREATE OR REPLACE FUNCTION public.brl_checkout_customer(
  p_key uuid,p_items jsonb,p_method text,p_rate numeric,p_expected numeric,p_customer jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE q jsonb; cid bigint; customer_name text; phone text; num text;
BEGIN
  customer_name:=regexp_replace(trim(p_customer->>'nombre'),'\s+',' ','g');
  phone:=regexp_replace(COALESCE(p_customer->>'telefono',''),'[^0-9]','','g');
  IF phone ~ '^0[24][0-9]{9}$' THEN phone:='58'||substring(phone from 2); END IF;
  IF customer_name IS NULL OR length(customer_name)<2 OR length(customer_name)>100
    OR customer_name ~ '[<>[:cntrl:]]' THEN RAISE EXCEPTION 'Escribe un nombre válido (2 a 100 caracteres)'; END IF;
  IF length(phone)<10 OR length(phone)>15 THEN RAISE EXCEPTION 'Escribe tu WhatsApp con código de país'; END IF;
  q:=public.brl_checkout(p_key,p_items,p_method,p_rate,p_expected);
  IF q ? 'cliente_nombre' THEN
    IF q->>'cliente_nombre' IS DISTINCT FROM customer_name OR q->>'telefono' IS DISTINCT FROM phone THEN
      RAISE EXCEPTION 'Este pedido ya fue registrado para otro cliente';
    END IF;
    RETURN q;
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('brl-customer:'||phone||':'||lower(customer_name),0));
  SELECT id INTO cid FROM public.clientes WHERE lower(trim(nombre))=lower(customer_name)
    AND (CASE WHEN regexp_replace(telefono,'[^0-9]','','g') ~ '^0[24][0-9]{9}$'
      THEN '58'||substring(regexp_replace(telefono,'[^0-9]','','g') from 2)
      ELSE regexp_replace(telefono,'[^0-9]','','g') END)=phone ORDER BY id LIMIT 1;
  IF cid IS NULL THEN INSERT INTO public.clientes(nombre,telefono) VALUES(customer_name,phone) RETURNING id INTO cid; END IF;
  num:='WEB-'||CASE WHEN q->>'tipo'='consulta' THEN 'C' ELSE 'V' END||lpad(q->>'id',greatest(6,length(q->>'id')),'0');
  q:=q||jsonb_build_object('numero',num,'cliente_nombre',customer_name,'telefono',phone);
  IF q->>'tipo'='consulta' THEN
    UPDATE public.apartados SET cliente_id=cid,cliente_nombre=customer_name,numero=num,
      checkout_payload=jsonb_set(checkout_payload,'{response}',q) WHERE checkout_key=p_key;
  ELSE
    UPDATE public.ventas SET cliente_id=cid,cliente_nombre=customer_name,numero=num,
      checkout_payload=jsonb_set(checkout_payload,'{response}',q) WHERE checkout_key=p_key;
  END IF;
  RETURN q;
END $$;
REVOKE ALL ON FUNCTION public.brl_checkout_customer(uuid,jsonb,text,numeric,numeric,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.brl_checkout_customer(uuid,jsonb,text,numeric,numeric,jsonb) TO anon,authenticated,service_role;
