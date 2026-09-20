-- Register web checkout sales safely and preserve product context.
ALTER TABLE public.ventas
  ADD COLUMN IF NOT EXISTS stock_aplicado boolean NOT NULL DEFAULT true;

ALTER TABLE public.venta_items
  ADD COLUMN IF NOT EXISTS variante_id bigint,
  ADD COLUMN IF NOT EXISTS variante_nombre text,
  ADD COLUMN IF NOT EXISTS imagen_url text;
