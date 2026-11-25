CREATE OR REPLACE FUNCTION ff_private.a07_valid_style(v jsonb)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
SELECT CASE WHEN jsonb_typeof(v)<>'object' OR v IS NULL THEN false ELSE
  NOT EXISTS(SELECT 1 FROM jsonb_each(v) e WHERE NOT CASE e.key
  WHEN 'font' THEN e.value IN ('"system"'::jsonb,'"tahoma"'::jsonb,'"serif"'::jsonb,'"cairo"'::jsonb,'"noto"'::jsonb)
  WHEN 'scale' THEN e.value IN ('"normal"'::jsonb,'"large"'::jsonb,'"xlarge"'::jsonb)
  WHEN 'density' THEN e.value IN ('"normal"'::jsonb,'"compact"'::jsonb,'"spacious"'::jsonb)
  WHEN 'radius' THEN e.value IN ('"pack"'::jsonb,'"square"'::jsonb,'"round"'::jsonb)
  WHEN 'button' THEN e.value IN ('"pack"'::jsonb,'"square"'::jsonb,'"round"'::jsonb,'"pill"'::jsonb)
  WHEN 'shadow' THEN e.value IN ('"pack"'::jsonb,'"none"'::jsonb,'"soft"'::jsonb)
  WHEN 'logoSize' THEN e.value IN ('"normal"'::jsonb,'"small"'::jsonb,'"large"'::jsonb)
  WHEN 'logoAsset' THEN e.value IN ('"brand"'::jsonb,'"mark"'::jsonb)
  WHEN 'logoDarkAsset' THEN e.value IN ('"brand"'::jsonb,'"mark"'::jsonb)
  WHEN 'logoWidth' THEN e.value IN ('"24"'::jsonb,'"32"'::jsonb,'"40"'::jsonb,'"48"'::jsonb,'"56"'::jsonb,'"64"'::jsonb,'"80"'::jsonb,'"10%"'::jsonb,'"20%"'::jsonb,'"30%"'::jsonb,'"40%"'::jsonb)
  WHEN 'logoPosition' THEN e.value IN ('"header"'::jsonb,'"cover"'::jsonb,'"menu"'::jsonb)
  WHEN 'dialogRadius' THEN e.value IN ('"square"'::jsonb,'"round"'::jsonb)
  WHEN 'dialogPadding' THEN e.value IN ('"normal"'::jsonb,'"wide"'::jsonb)
  WHEN 'ratingScale' THEN e.value IN ('"normal"'::jsonb,'"large"'::jsonb)
  WHEN 'logoAlign' THEN e.value IN ('"start"'::jsonb,'"center"'::jsonb,'"end"'::jsonb)
  WHEN 'weight' THEN e.value IN ('"normal"'::jsonb,'"strong"'::jsonb)
  WHEN 'accent' THEN e.value IN ('"pack"'::jsonb,'"red"'::jsonb,'"black"'::jsonb,'"navy"'::jsonb)
  WHEN 'surface' THEN e.value IN ('"pack"'::jsonb,'"light"'::jsonb,'"dark"'::jsonb)
  WHEN 'border' THEN e.value IN ('"pack"'::jsonb,'"thin"'::jsonb,'"strong"'::jsonb)
  WHEN 'iconSize' THEN e.value IN ('"normal"'::jsonb,'"large"'::jsonb)
  WHEN 'layout' THEN e.value IN ('"pack"'::jsonb,'"single"'::jsonb,'"double"'::jsonb,'"triple"'::jsonb)
  WHEN 'elements' THEN ff_private.a07_valid_elements(e.value,'all')
  WHEN 'dashboardPanels' THEN ff_private.a08_valid_panels(e.value)
  WHEN 'quickActions' THEN ff_private.a08_valid_actions(e.value)
  ELSE false END) END;
$function$;