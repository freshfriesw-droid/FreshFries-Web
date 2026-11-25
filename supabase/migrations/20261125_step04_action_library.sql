-- STEP04: compatible structured shortcut instances. Original strings remain unique; copies use objects.
CREATE OR REPLACE FUNCTION ff_private.a08_valid_actions(v jsonb)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $$
DECLARE item jsonb; k text; lbl text; seen text[]:=ARRAY[]::text[];
BEGIN
 IF jsonb_typeof(v) IS DISTINCT FROM 'array' OR octet_length(v::text)>65536 THEN RETURN false; END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(v) LOOP
  IF jsonb_typeof(item)='string' THEN
   k:=item#>>'{}';
   IF k=ANY(seen) THEN RETURN false; END IF;
   seen:=array_append(seen,k);
  ELSIF jsonb_typeof(item)='object' THEN
   IF NOT (item ?& ARRAY['key','label','icon','size','tone']) OR (item-ARRAY['key','label','icon','size','tone'])<>'{}'::jsonb THEN RETURN false; END IF;
   IF EXISTS(SELECT FROM jsonb_each(item) WHERE jsonb_typeof(value)<>'string') THEN RETURN false; END IF;
   k:=item->>'key'; lbl:=item->>'label';
   IF length(btrim(lbl)) NOT BETWEEN 1 AND 100 OR length(lbl)>100 OR lbl ~ '[<>{}[:cntrl:]]' OR lbl ~* '(https?://|www\.|javascript:|data:|vbscript:|//)' OR translate(lbl,U&'\061C\200E\200F\202A\202B\202C\202D\202E\2066\2067\2068\2069','')<>lbl THEN RETURN false; END IF;
   IF item->>'icon' NOT IN ('home','grid','plus','orders','bike','clock','alert','bell','settings','refresh','user','report','wallet','calendar','folder','message','star','users','check','search','shield','filter','phone') OR item->>'size' NOT IN ('normal','wide','full') OR item->>'tone' NOT IN ('default','red','black','neutral') THEN RETURN false; END IF;
  ELSE RETURN false;
  END IF;
  IF k NOT IN ('home','new','orders','late','drivers','driver','cashier','reservations','transfer','routes','messages','cases','offers','attendance','burger','cashier_finished','reports','archive','ratings','settlements','rewards','catalog','customers','changes','team','assembly_admin','applications','application_alerts','branch_policy','staff_link','studio','data_center','security','integrity','access','readiness','qa','diagnostics','settings','refresh') THEN RETURN false; END IF;
 END LOOP;
 RETURN true;
END $$;
REVOKE ALL ON FUNCTION ff_private.a08_valid_actions(jsonb) FROM PUBLIC,anon,authenticated;
