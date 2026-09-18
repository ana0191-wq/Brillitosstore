-- Track products that have sold out through the quick-sale action.
ALTER TABLE public.productos
  ADD COLUMN IF NOT EXISTS vendido_en timestamptz,
  ADD COLUMN IF NOT EXISTS stock_vendido integer NOT NULL DEFAULT 0;
