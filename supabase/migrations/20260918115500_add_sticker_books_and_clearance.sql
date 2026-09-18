-- Add a dedicated sticker-book category and a reusable clearance flag.
ALTER TABLE public.productos
  ADD COLUMN IF NOT EXISTS en_remate boolean NOT NULL DEFAULT false;

INSERT INTO public.categorias (nombre, tipo, activo, nombre_normalizado)
VALUES ('Libros de stickers', 'categoria', true, 'libros de stickers')
ON CONFLICT (nombre) DO UPDATE
SET tipo = EXCLUDED.tipo,
    activo = true,
    nombre_normalizado = EXCLUDED.nombre_normalizado;
