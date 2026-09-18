-- Brillitos: configurable discount rules
-- Rules live in one JSONB list so the admin can create multiple promotions
-- targeting all products, selected categories, or selected product IDs.

CREATE TABLE IF NOT EXISTS public.configuracion_tienda (
  id integer PRIMARY KEY,
  descuento_reglas jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT configuracion_tienda_singleton CHECK (id = 1),
  CONSTRAINT configuracion_tienda_descuento_reglas_array
    CHECK (jsonb_typeof(descuento_reglas) = 'array')
);

ALTER TABLE public.configuracion_tienda
  ADD COLUMN IF NOT EXISTS descuento_reglas jsonb NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE public.configuracion_tienda
  DROP CONSTRAINT IF EXISTS configuracion_tienda_descuento_reglas_array;

ALTER TABLE public.configuracion_tienda
  ADD CONSTRAINT configuracion_tienda_descuento_reglas_array
  CHECK (jsonb_typeof(descuento_reglas) = 'array');

INSERT INTO public.configuracion_tienda (id, descuento_reglas)
VALUES (1, '[]'::jsonb)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.configuracion_tienda ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Lectura pública configuración tienda" ON public.configuracion_tienda;
CREATE POLICY "Lectura pública configuración tienda"
  ON public.configuracion_tienda
  FOR SELECT
  TO anon, authenticated
  USING (id = 1);

DROP POLICY IF EXISTS "Actualizar configuración tienda" ON public.configuracion_tienda;
CREATE POLICY "Actualizar configuración tienda"
  ON public.configuracion_tienda
  FOR UPDATE
  TO anon, authenticated
  USING (id = 1)
  WITH CHECK (id = 1);

DROP POLICY IF EXISTS "Crear configuración tienda" ON public.configuracion_tienda;
CREATE POLICY "Crear configuración tienda"
  ON public.configuracion_tienda
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (id = 1);

GRANT SELECT, INSERT, UPDATE ON TABLE public.configuracion_tienda TO anon, authenticated;
