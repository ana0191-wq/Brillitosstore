-- venta_items: add columns the admin code expects
ALTER TABLE venta_items
  ADD COLUMN IF NOT EXISTS producto_id      bigint,
  ADD COLUMN IF NOT EXISTS producto_nombre  text,
  ADD COLUMN IF NOT EXISTS precio_unitario  numeric(10,2),
  ADD COLUMN IF NOT EXISTS subtotal         numeric(10,2);

-- backfill from existing data
UPDATE venta_items SET
  producto_nombre  = COALESCE(producto_nombre, nombre),
  precio_unitario  = COALESCE(precio_unitario, precio),
  subtotal         = COALESCE(subtotal, precio * cantidad)
WHERE producto_nombre IS NULL OR precio_unitario IS NULL OR subtotal IS NULL;

-- apartado_items: same
ALTER TABLE apartado_items
  ADD COLUMN IF NOT EXISTS producto_id      bigint,
  ADD COLUMN IF NOT EXISTS producto_nombre  text,
  ADD COLUMN IF NOT EXISTS precio_unitario  numeric(10,2),
  ADD COLUMN IF NOT EXISTS subtotal         numeric(10,2);

UPDATE apartado_items SET
  producto_nombre  = COALESCE(producto_nombre, nombre),
  precio_unitario  = COALESCE(precio_unitario, precio),
  subtotal         = COALESCE(subtotal, precio * cantidad)
WHERE producto_nombre IS NULL OR precio_unitario IS NULL OR subtotal IS NULL;

-- ventas: add tipo_entrega which the admin code references
ALTER TABLE ventas
  ADD COLUMN IF NOT EXISTS tipo_entrega text;
