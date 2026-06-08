
-- PRODUCTOS
CREATE TABLE productos (
  id            bigserial PRIMARY KEY,
  nombre        text NOT NULL,
  categoria     text,
  subcategoria  text,
  precio        numeric(10,2) NOT NULL DEFAULT 0,
  precio_costo  numeric(10,2),
  stock         integer NOT NULL DEFAULT 0,
  imagen        text,
  foto          text,
  imagenes      text[],
  descripcion   text,
  activo        boolean NOT NULL DEFAULT true,
  visible_web   boolean NOT NULL DEFAULT true,
  es_nuevo      boolean NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE productos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anon_select_productos" ON productos FOR SELECT TO anon USING (true);
CREATE POLICY "anon_insert_productos" ON productos FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "anon_update_productos" ON productos FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_delete_productos" ON productos FOR DELETE TO anon USING (true);

-- PRODUCTO VARIANTES
CREATE TABLE producto_variantes (
  id          bigserial PRIMARY KEY,
  producto_id bigint NOT NULL REFERENCES productos(id) ON DELETE CASCADE,
  nombre      text NOT NULL,
  precio      numeric(10,2),
  stock       integer NOT NULL DEFAULT 0,
  activo      boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE producto_variantes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anon_select_pvariantes" ON producto_variantes FOR SELECT TO anon USING (true);
CREATE POLICY "anon_insert_pvariantes" ON producto_variantes FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "anon_update_pvariantes" ON producto_variantes FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_delete_pvariantes" ON producto_variantes FOR DELETE TO anon USING (true);

-- APARTADOS
CREATE TABLE apartados (
  id             bigserial PRIMARY KEY,
  numero         text,
  cliente_nombre text,
  canal          text,
  metodo_pago    text,
  total          numeric(10,2) NOT NULL DEFAULT 0,
  abono          numeric(10,2) NOT NULL DEFAULT 0,
  saldo          numeric(10,2) GENERATED ALWAYS AS (total - abono) STORED,
  estado         text NOT NULL DEFAULT 'Por confirmar',
  notas          text,
  created_at     timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE apartados ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anon_select_apartados" ON apartados FOR SELECT TO anon USING (true);
CREATE POLICY "anon_insert_apartados" ON apartados FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "anon_update_apartados" ON apartados FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_delete_apartados" ON apartados FOR DELETE TO anon USING (true);

-- APARTADO ITEMS
CREATE TABLE apartado_items (
  id          bigserial PRIMARY KEY,
  apartado_id bigint NOT NULL REFERENCES apartados(id) ON DELETE CASCADE,
  nombre      text,
  variante    text,
  cantidad    integer NOT NULL DEFAULT 1,
  precio      numeric(10,2) NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE apartado_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anon_select_apt_items" ON apartado_items FOR SELECT TO anon USING (true);
CREATE POLICY "anon_insert_apt_items" ON apartado_items FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "anon_update_apt_items" ON apartado_items FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_delete_apt_items" ON apartado_items FOR DELETE TO anon USING (true);

-- VENTAS
CREATE TABLE ventas (
  id               bigserial PRIMARY KEY,
  numero           text,
  cliente_nombre   text,
  canal            text,
  metodo_pago      text,
  total            numeric(10,2) NOT NULL DEFAULT 0,
  descuento        numeric(10,2) NOT NULL DEFAULT 0,
  estado           text NOT NULL DEFAULT 'Pagado',
  tasa_bcv_usada   numeric(10,4),
  cuenta_cobro     text,
  fecha_venta      date NOT NULL DEFAULT CURRENT_DATE,
  created_at       timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE ventas ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anon_select_ventas" ON ventas FOR SELECT TO anon USING (true);
CREATE POLICY "anon_insert_ventas" ON ventas FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "anon_update_ventas" ON ventas FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_delete_ventas" ON ventas FOR DELETE TO anon USING (true);

-- VENTA ITEMS
CREATE TABLE venta_items (
  id         bigserial PRIMARY KEY,
  venta_id   bigint NOT NULL REFERENCES ventas(id) ON DELETE CASCADE,
  nombre     text,
  variante   text,
  cantidad   integer NOT NULL DEFAULT 1,
  precio     numeric(10,2) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE venta_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anon_select_venta_items" ON venta_items FOR SELECT TO anon USING (true);
CREATE POLICY "anon_insert_venta_items" ON venta_items FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "anon_update_venta_items" ON venta_items FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_delete_venta_items" ON venta_items FOR DELETE TO anon USING (true);
