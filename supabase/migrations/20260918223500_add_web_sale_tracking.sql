-- Track whether a sale has already affected inventory and preserve web-sale product context.
ALTER TABLE public.ventas
  ADD COLUMN IF NOT EXISTS stock_aplicado boolean NOT NULL DEFAULT true;

UPDATE public.ventas
SET stock_aplicado=false
WHERE estado IN ('Cancelado','Cotización');

ALTER TABLE public.venta_items
  ADD COLUMN IF NOT EXISTS variante_id bigint,
  ADD COLUMN IF NOT EXISTS variante_nombre text,
  ADD COLUMN IF NOT EXISTS imagen_url text;
