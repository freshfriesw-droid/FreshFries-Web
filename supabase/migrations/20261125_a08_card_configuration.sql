-- A08 DEC-06: backwards-compatible restrictive card visibility and secondary dashboard panels.
CREATE OR REPLACE FUNCTION ff_private.a08_valid_panels(v jsonb) RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $$
BEGIN
 IF jsonb_typeof(v) IS DISTINCT FROM 'object' THEN RETURN false; END IF;
 RETURN NOT EXISTS(SELECT FROM jsonb_each(v) e WHERE e.key NOT IN ('activity','shortcuts','branches') OR jsonb_typeof(e.value)<>'boolean');
END $$;
CREATE OR REPLACE FUNCTION ff_private.a08_valid_actions(v jsonb) RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $$
BEGIN
 IF jsonb_typeof(v) IS DISTINCT FROM 'array' THEN RETURN false; END IF;
 RETURN NOT EXISTS(SELECT FROM jsonb_array_elements(v) e WHERE jsonb_typeof(e)<>'string' OR e#>>'{}' NOT IN ('new','orders','drivers','late','reports','assembly_admin','rewards','messages','driver','cashier','settings','reservations','attendance','offers','cases','customers','burger','cashier_finished')) AND (SELECT count(*) FROM jsonb_array_elements(v))=(SELECT count(DISTINCT e) FROM jsonb_array_elements(v) e);
END $$;
REVOKE ALL ON FUNCTION ff_private.a08_valid_panels(jsonb),ff_private.a08_valid_actions(jsonb) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.ff81_validate_cards(p_cards jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
declare card jsonb;
begin
 if p_cards is null then return true;end if;
 if jsonb_typeof(p_cards)<>'array' or octet_length(p_cards::text)>65536 then return false;end if;
 for card in select value from jsonb_array_elements(p_cards) loop
  if jsonb_typeof(card)<>'object' then return false;end if;
  if not (card ?& array['metric','label','size','tone']) or (card-array['metric','label','size','tone','roles','permission','icon'])<>'{}'::jsonb then return false;end if;
  if jsonb_typeof(card->'metric')<>'string' or jsonb_typeof(card->'label')<>'string' or jsonb_typeof(card->'size')<>'string' or jsonb_typeof(card->'tone')<>'string' then return false;end if;
  IF card ? 'roles' THEN
   IF jsonb_typeof(card->'roles') <> 'array' THEN RETURN false; END IF;
   IF EXISTS(SELECT 1 FROM jsonb_array_elements(card->'roles') e WHERE jsonb_typeof(e)<>'string' OR e#>>'{}' NOT IN ('manager','supervisor','customer_service','cashier','driver','assembly','burger_kitchen')) OR (SELECT count(*) FROM jsonb_array_elements(card->'roles'))<>(SELECT count(DISTINCT e) FROM jsonb_array_elements(card->'roles') e) THEN RETURN false; END IF;
  END IF;
  IF card ? 'permission' AND (jsonb_typeof(card->'permission')<>'string' OR card->>'permission' NOT IN ('view_reports','manage_drivers','create_order','assign_driver','edit_order','cancel_order')) THEN RETURN false; END IF;
  IF card ? 'icon' AND (jsonb_typeof(card->'icon')<>'string' OR card->>'icon' NOT IN ('orders','clock','users','alert','star','grid','bike','report')) THEN RETURN false; END IF;
  if card->>'metric' not in ('orders_today','late_today','completed_today','available_drivers')
   or card->>'size' not in ('normal','wide','full') or card->>'tone' not in ('default','red','black','neutral')
   or length(btrim(card->>'label')) not between 1 and 100 or card->>'label' ~ '[<>{}[:cntrl:]]'
   or card->>'label' ~* '(https?://|www\.|javascript:|data:|vbscript:|//)'
   or translate(card->>'label',U&'\061C\200E\200F\202A\202B\202C\202D\202E\2066\2067\2068\2069','')<>card->>'label' then return false;end if;
 end loop;
 return true;
end $function$;
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
ALTER TABLE public.ff_ui_versions ADD CONSTRAINT ff_a08_dashboard_scope CHECK (screen_scope IN ('all','dashboard') OR (card_layout IS NULL AND NOT style_config ? 'dashboardPanels' AND NOT style_config ? 'quickActions')) NOT VALID;
