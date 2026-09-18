-- Brillitos: store-wide and product-specific discounts
-- Product-specific discount overrides the general store discount.
-- Both can define a minimum unit price before the discount becomes active.

ALTER TABLE productos
  ADD COLUMN IF NOT EXISTS descuento_pct numeric(5,2) NOT NULL DEFAULT 0;

ALTER TABLE productos
  ADD COLUMN IF NOT EXISTS descuento_min_precio numeric(10,2) NOT NULL DEFAULT 0;

ALTER TABLE productos
  DROP CONSTRAINT IF EXISTS productos_descuento_pct_check;

ALTER TABLE productos
  ADD CONSTRAINT productos_descuento_pct_check
  CHECK (descuento_pct >= 0 AND descuento_pct <= 100);

ALTER TABLE productos
  DROP CONSTRAINT IF EXISTS productos_descuento_min_precio_check;

ALTER TABLE productos
  ADD CONSTRAINT productos_descuento_min_precio_check
  CHECK (descuento_min_precio >= 0);

CREATE TABLE IF NOT EXISTS configuracion_tienda (
  id integer PRIMARY KEY,
  descuento_general_activo boolean NOT NULL DEFAULT false,
  descuento_general_pct numeric(5,2) NOT NULL DEFAULT 0,
  descuento_general_min_precio numeric(10,2) NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT configuracion_tienda_singleton CHECK (id = 1),
  CONSTRAINT configuracion_tienda_descuento_check CHECK (
    descuento_general_pct >= 0 AND descuento_general_pct <= 100
  ),
  CONSTRAINT configuracion_tienda_min_precio_check CHECK (
    descuento_general_min_precio >= 0
  )
);

-- Safe upgrade if configuracion_tienda was created by an earlier version.
ALTER TABLE configuracion_tienda
  ADD COLUMN IF NOT EXISTS descuento_general_min_precio numeric(10,2) NOT NULL DEFAULT 0;

ALTER TABLE configuracion_tienda
  DROP CONSTRAINT IF EXISTS configuracion_tienda_min_precio_check;

ALTER TABLE configuracion_tienda
  ADD CONSTRAINT configuracion_tienda_min_precio_check
  CHECK (descuento_general_min_precio >= 0);

INSERT INTO configuracion_tienda (id, descuento_general_activo, descuento_general_pct, descuento_general_min_precio)
VALUES (1, false, 0, 0)
ON CONFLICT (id) DO NOTHING;

GRANT SELECT, INSERT, UPDATE ON TABLE configuracion_tienda TO anon, authenticated;
