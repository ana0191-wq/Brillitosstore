-- Add an explicit clearance price for products marked as Remate.
ALTER TABLE public.productos
  ADD COLUMN IF NOT EXISTS precio_remate numeric(10,2);

ALTER TABLE public.productos
  DROP CONSTRAINT IF EXISTS productos_precio_remate_check;

ALTER TABLE public.productos
  ADD CONSTRAINT productos_precio_remate_check
  CHECK (precio_remate IS NULL OR precio_remate > 0);
