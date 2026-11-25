-- A07: registered packs can be added with future CSS implementations without a fixed ceiling.
CREATE TABLE IF NOT EXISTS ff_private.a07_design_packs(code text PRIMARY KEY CHECK(code ~ '^D[0-9]{2,}$'),name text NOT NULL CHECK(length(name) BETWEEN 1 AND 100),sort_order integer NOT NULL);
REVOKE ALL ON ff_private.a07_design_packs FROM PUBLIC,anon,authenticated;
INSERT INTO ff_private.a07_design_packs(code,name,sort_order) VALUES
('D01','Fresh Classic',1),
('D02','Midnight Command',2),
('D03','Executive Carbon',3),
('D04','White Studio',4),
('D05','Graphite Pro',5),
('D06','Crimson Edge',6),
('D07','Soft Ivory',7),
('D08','Contrast Plus',8),
('D09','Touch Flow',9),
('D10','Compact Operations',10),
('D11','Control Grid',11),
('D12','Studio Cards',12),
('D13','Mission Control',13),
('D14','Kiosk Focus',14),
('D15','Minimal Black & White',15),
('D16','LUXE Editorial',16)
ON CONFLICT(code) DO NOTHING;
ALTER TABLE public.ff_ui_versions ADD CONSTRAINT ff_a07_pack_registered FOREIGN KEY(pack) REFERENCES ff_private.a07_design_packs(code);
ALTER TABLE public.ff_ui_versions DROP CONSTRAINT ff_ui_versions_pack_check;
CREATE OR REPLACE FUNCTION public.ff_a07_design_catalog() RETURNS TABLE(code text,name text) LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT p.code,p.name FROM ff_private.a07_design_packs p WHERE EXISTS(SELECT 1 FROM public.ff_profiles a WHERE a.user_id=auth.uid() AND a.active AND a.role='manager') ORDER BY p.sort_order,p.code
$$;
REVOKE ALL ON FUNCTION public.ff_a07_design_catalog() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_a07_design_catalog() TO authenticated;
