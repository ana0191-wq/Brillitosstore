-- Archive donated and out-of-stock products without deleting their history.
ALTER TABLE public.productos
  ADD COLUMN IF NOT EXISTS archivado_en timestamptz,
  ADD COLUMN IF NOT EXISTS motivo_archivo text;

UPDATE public.productos p
SET
  archivado_en = COALESCE(p.donado_en, p.vendido_en, now()),
  motivo_archivo = CASE
    WHEN p.donado_en IS NOT NULL THEN 'Donado'
    ELSE 'Agotado'
  END
WHERE p.archivado_en IS NULL
  AND (
    p.donado_en IS NOT NULL
    OR p.vendido_en IS NOT NULL
    OR (
      COALESCE(p.stock,0) <= 0
      AND NOT EXISTS (
        SELECT 1
        FROM public.producto_variantes pv
        WHERE pv.producto_id = p.id
          AND pv.activo IS DISTINCT FROM false
          AND COALESCE(pv.stock,0) > 0
      )
    )
  );
