CREATE OR REPLACE FUNCTION ff_private.a07_valid_style(v jsonb) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path='' AS $$
SELECT CASE WHEN jsonb_typeof(v)<>'object' OR v IS NULL THEN false ELSE
  NOT EXISTS(SELECT 1 FROM jsonb_each(v) e WHERE NOT CASE e.key
  WHEN 'font' THEN e.value IN ('"system"'::jsonb,'"tahoma"'::jsonb,'"serif"'::jsonb,'"cairo"'::jsonb,'"noto"'::jsonb)
  WHEN 'scale' THEN e.value IN ('"normal"'::jsonb,'"large"'::jsonb,'"xlarge"'::jsonb)
  WHEN 'density' THEN e.value IN ('"normal"'::jsonb,'"compact"'::jsonb,'"spacious"'::jsonb)
  WHEN 'radius' THEN e.value IN ('"pack"'::jsonb,'"square"'::jsonb,'"round"'::jsonb)
  WHEN 'button' THEN e.value IN ('"pack"'::jsonb,'"square"'::jsonb,'"round"'::jsonb,'"pill"'::jsonb)
  WHEN 'shadow' THEN e.value IN ('"pack"'::jsonb,'"none"'::jsonb,'"soft"'::jsonb)
  WHEN 'logoSize' THEN e.value IN ('"normal"'::jsonb,'"small"'::jsonb,'"large"'::jsonb)
  WHEN 'logoAlign' THEN e.value IN ('"start"'::jsonb,'"center"'::jsonb,'"end"'::jsonb)
  WHEN 'weight' THEN e.value IN ('"normal"'::jsonb,'"strong"'::jsonb)
  WHEN 'accent' THEN e.value IN ('"pack"'::jsonb,'"red"'::jsonb,'"black"'::jsonb,'"navy"'::jsonb)
  WHEN 'surface' THEN e.value IN ('"pack"'::jsonb,'"light"'::jsonb,'"dark"'::jsonb)
  WHEN 'border' THEN e.value IN ('"pack"'::jsonb,'"thin"'::jsonb,'"strong"'::jsonb)
  WHEN 'iconSize' THEN e.value IN ('"normal"'::jsonb,'"large"'::jsonb)
  WHEN 'layout' THEN e.value IN ('"pack"'::jsonb,'"single"'::jsonb,'"double"'::jsonb,'"triple"'::jsonb)
  ELSE false END) END;
$$;
