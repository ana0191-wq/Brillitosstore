
-- EVENTOS
CREATE TABLE eventos (
  id         bigserial PRIMARY KEY,
  nombre     text NOT NULL,
  fecha      date,
  lugar      text,
  notas      text,
  activo     boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE eventos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anon_select_eventos" ON eventos FOR SELECT TO anon USING (true);
CREATE POLICY "anon_insert_eventos" ON eventos FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "anon_update_eventos" ON eventos FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_delete_eventos" ON eventos FOR DELETE TO anon USING (true);

-- Columnas faltantes en ventas (que usa el POS)
ALTER TABLE ventas ADD COLUMN IF NOT EXISTS subtotal       numeric(10,2);
ALTER TABLE ventas ADD COLUMN IF NOT EXISTS costo_envio    numeric(10,2) DEFAULT 0;
ALTER TABLE ventas ADD COLUMN IF NOT EXISTS monto_bs       numeric(12,2);
ALTER TABLE ventas ADD COLUMN IF NOT EXISTS moneda_pago    text DEFAULT 'USD';
ALTER TABLE ventas ADD COLUMN IF NOT EXISTS evento_id      bigint REFERENCES eventos(id);

-- Columnas faltantes en apartados
ALTER TABLE apartados ADD COLUMN IF NOT EXISTS fecha_entrega date;
