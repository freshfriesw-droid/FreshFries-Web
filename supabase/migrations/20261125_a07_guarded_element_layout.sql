
CREATE OR REPLACE FUNCTION ff_private.a07_valid_elements(v jsonb,p_screen text)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $$
DECLARE g record; e jsonb; seen text[]; allowed text[]; spec jsonb:='{"dashboard_actions":{"screen":"dashboard","keys":["ffx-hero-new","ffx-hero-reserve","ffx-hero-overdue"]},"orders_actions":{"screen":"orders","keys":["createBtn","ffA06DiscardDraft","ffReserveBottom"]},"driver_actions":{"screen":"driver","keys":["ff51BreakBtn","clockInBtn","clockOutBtn"]},"assembly_actions":{"screen":"assembly","keys":["ffV12Toggle","ffV12Refresh","ffV12BurgerOpen","ffV12Logout"]},"burger_actions":{"screen":"burger_kitchen","keys":["ffBurgerKitchenNotifications","ffBurgerViewFinished","ffBurgerKitchenRefresh","ffBurgerKitchenLogout"]},"catalog_actions":{"screen":"catalog","keys":["ff51ItemSave","ff51ItemReset"]},"catalog_offers":{"screen":"catalog","keys":["ff51OfferSave","ff51OfferReset"]},"archive_actions":{"screen":"archive","keys":["ff51ArchiveRefresh","ff51ArchiveExport","ff51ArchiveClose"]},"ratings_actions":{"screen":"ratings","keys":["ff51RatingsRefresh","ff51RatingsClose"]},"reservations_actions":{"screen":"reservations","keys":["ff49ReservationsRefresh","ff49ReservationsClose"]},"cases_actions":{"screen":"cases","keys":["ff41Refresh","ff41Close"]},"messages_actions":{"screen":"messages","keys":["ff39Refresh","ff39Close"]},"system_actions":{"screen":"system","keys":["ff48Refresh","ff48Export","ff48Close"]},"driver_regions":{"screen":"driver","keys":["clockInBtn","driverOffers","driverTasks"]},"assembly_stats":{"screen":"assembly","keys":["ffV12CountAll","ffV12CountPrinted","ffV12CountPreparing","ffV12CountReady"]},"cashier_stage":{"screen":"cashier","keys":["cashier_stage"]},"staff_actions":{"screen":"staff","keys":["staffAuditRefresh"]},"customers_actions":{"screen":"customers","keys":["ff51CustomerFind","ff51CustomerNoteSave"]}}'::jsonb;
BEGIN
 IF v IS NULL OR jsonb_typeof(v)<>'object' THEN RETURN false; END IF;
 FOR g IN SELECT * FROM jsonb_each(v) LOOP
  IF NOT spec ? g.key OR (p_screen<>'all' AND spec->g.key->>'screen'<>p_screen) OR jsonb_typeof(g.value)<>'array' THEN RETURN false; END IF;
  SELECT array_agg(k) INTO allowed FROM jsonb_array_elements_text(spec->g.key->'keys') k;
  IF jsonb_array_length(g.value)<>cardinality(allowed) THEN RETURN false; END IF;
  seen:='{}';
  FOR e IN SELECT * FROM jsonb_array_elements(g.value) LOOP
   IF jsonb_typeof(e)<>'object' THEN RETURN false; END IF;
   IF NOT (e ?& ARRAY['key','shape','size']) OR (SELECT count(*) FROM jsonb_object_keys(e))<>3
      OR NOT coalesce(e->>'key'=ANY(allowed),false) OR coalesce(e->>'key'=ANY(seen),true)
      OR NOT coalesce(e->>'shape' IN ('pack','square','round','pill','outline','icon_label'),false)
      OR NOT coalesce(e->>'size' IN ('normal','large'),false) THEN RETURN false;END IF;
   seen:=array_append(seen,e->>'key');
  END LOOP;
 END LOOP;
 RETURN true;
END $$;
REVOKE ALL ON FUNCTION ff_private.a07_valid_elements(jsonb,text) FROM PUBLIC,anon,authenticated;
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
  WHEN 'elements' THEN ff_private.a07_valid_elements(e.value,'all')
  ELSE false END) END;
$$;

ALTER TABLE public.ff_ui_versions ADD CONSTRAINT ff_a07_element_scope_valid CHECK (NOT style_config ? 'elements' OR ff_private.a07_valid_elements(style_config->'elements',screen_scope));
