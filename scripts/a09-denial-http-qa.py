"""A09 HTTP contract test. Disposable PostgreSQL/PostgREST only; no live credentials."""
import base64
import hashlib
import hmac
import json
import os
import subprocess
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SECRET = "local-a09-test-only-not-production-jwt-secret-123456789"
MANAGER = "10000000-0000-4000-8000-000000000001"
WORKER = "10000000-0000-4000-8000-000000000002"
BRANCH = "10000000-0000-4000-8000-000000000003"
URL = "http://127.0.0.1:18090"
PG = "a09-pg"
REST = "a09-rest"
NETWORK = "a09-http-qa"


def run(*args, input=None):
    return subprocess.run(args, input=input, text=True, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout


def sql(query):
    return run("docker", "exec", "-i", PG, "psql", "-U", "postgres", "-d", "postgres", "-At", "-v", "ON_ERROR_STOP=1", input=query).strip()


def token(uid):
    def enc(value):
        return base64.urlsafe_b64encode(value).rstrip(b"=").decode()
    unsigned = enc(b'{"alg":"HS256","typ":"JWT"}') + "." + enc(json.dumps({"role":"authenticated","sub":uid,"exp":int(time.time())+600}, separators=(",",":")).encode())
    return unsigned + "." + enc(hmac.new(SECRET.encode(),unsigned.encode(),hashlib.sha256).digest())


def call(name, args, uid=WORKER):
    req = urllib.request.Request(URL + "/rpc/" + name, json.dumps(args).encode(), {"Content-Type":"application/json","Authorization":"Bearer "+token(uid)}, method="POST")
    try:
        with urllib.request.urlopen(req,timeout=15) as res:
            return res.status, res.read().decode()
    except urllib.error.HTTPError as err:
        return err.code, err.read().decode()


def wait_for(fn, description):
    for _ in range(60):
        try:
            if fn():
                return
        except (OSError, subprocess.CalledProcessError):
            pass
        time.sleep(1)
    raise RuntimeError("Not ready: " + description)


fixture = f"""
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE authenticator LOGIN PASSWORD 'test-only-a09' NOINHERIT;
GRANT anon, authenticated TO authenticator;
CREATE SCHEMA auth;
CREATE SCHEMA ff_private;
GRANT USAGE ON SCHEMA public, auth TO anon,authenticated;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
 SELECT (nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'sub')::uuid
$$;
CREATE TABLE public.ff_profiles(user_id uuid PRIMARY KEY,role text,active boolean);
INSERT INTO public.ff_profiles VALUES('{MANAGER}','manager',true),('{WORKER}','cashier',true);
CREATE TABLE public.ff82_content_grants(id bigint PRIMARY KEY,recipient uuid,starts_at timestamptz,ends_at timestamptz,revoked_at timestamptz);
INSERT INTO public.ff82_content_grants VALUES(10,'{WORKER}',now()-interval '1 hour',now()+interval '1 hour',now());
CREATE TABLE public.ff_ui_versions(id bigint PRIMARY KEY,screen_scope text,role_scope text,branch_id uuid,device text,previous_id bigint,published_at timestamptz,published_by uuid);
INSERT INTO public.ff_ui_versions VALUES(20,'cashier','cashier','{BRANCH}','mobile',NULL,NULL,NULL);
CREATE TABLE public.ff_content_versions(id bigint PRIMARY KEY,content_key text,role_scope text,branch_id uuid,previous_id bigint,published_at timestamptz,published_by uuid);
INSERT INTO public.ff_content_versions VALUES(30,'cashier.title','cashier','{BRANCH}',NULL,NULL,NULL);
CREATE TABLE public.ff_ui_trials(id bigint PRIMARY KEY);
CREATE TABLE public.ff82_content_audit(id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,actor_id uuid,grant_id bigint REFERENCES public.ff82_content_grants(id),action text,outcome text,reason text,design_revision bigint,revision_id bigint);
ALTER TABLE public.ff82_content_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ff82_content_audit FROM PUBLIC,anon,authenticated;
"""
migration = (ROOT/"supabase/migrations/20261125_a09_manager_denial_audit.sql").read_text()
endpoints = [
    ("ff_ui_publish", {"p_id":20}, "design_publish",20),
    ("ff_ui_rollback", {"p_current":20}, "design_restore",20),
    ("ff_ui_control_trial", {"p_id":20,"p_accounts":[WORKER],"p_hours":1}, "design_trial",20),
    ("ff_content_publish", {"p_id":30}, "content_publish",30),
    ("ff_content_create_draft", {"p_key":"cashier.title","p_role":"cashier","p_branch":BRANCH,"p_body":None}, "content_restore",None),
    ("ff_ui_save_draft", {"p_role":"cashier","p_branch":BRANCH,"p_device":"mobile","p_pack":"D01","p_text":"","p_bar":"labels","p_restore":20}, "design_restore_draft",20),
    ("ff_ui_named_draft", {"p_role":"cashier","p_branch":BRANCH,"p_device":"mobile","p_pack":"D01","p_text":"","p_bar":"labels","p_name":"test","p_description":""}, "design_manager_draft",None),
    ("ff_a07_named_design", {"p_screen":"cashier","p_role":"cashier","p_branch":BRANCH,"p_device":"mobile","p_pack":"D01","p_text":"","p_bar":"labels","p_name":"test","p_description":"","p_cards":None,"p_style":{}}, "design_manager_draft",None),
    ("ff81_named_card_draft", {"p_role":"cashier","p_branch":BRANCH,"p_device":"mobile","p_pack":"D01","p_text":"","p_bar":"labels","p_name":"test","p_description":"","p_cards":None}, "design_card_draft",None),
    ("ff82_set_grant", {"p_recipient":WORKER,"p_branch":BRANCH,"p_screen":"cashier","p_capabilities":["edit"],"p_start":"2026-11-25T00:00:00Z","p_end":"2026-11-26T00:00:00Z"}, "grant_manage",None),
    ("ff_a09_set_grant", {"p_recipient":WORKER,"p_branch":BRANCH,"p_screen":"cashier","p_capabilities":["edit"],"p_start":"2026-11-25T00:00:00Z","p_end":"2026-11-26T00:00:00Z","p_kinds":["text"]}, "grant_manage",None),
    ("ff82_revoke_grant", {"p_id":10}, "grant_revoke",10),
]
try:
    run("docker","network","create",NETWORK)
    run("docker","run","-d","--name",PG,"--network",NETWORK,"-e","POSTGRES_PASSWORD=test-only-a09","postgres:16.11")
    wait_for(lambda: run("docker","exec",PG,"pg_isready","-h","127.0.0.1","-U","postgres"),"PostgreSQL")
    sql(fixture + migration + """
DO $$DECLARE f record; BEGIN
 FOR f IN SELECT p.oid::regprocedure AS fn FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN ('ff_ui_publish','ff_ui_rollback','ff_ui_control_trial','ff_content_publish','ff_content_create_draft','ff_ui_save_draft','ff_ui_named_draft','ff_a07_named_design','ff81_named_card_draft','ff82_set_grant','ff_a09_set_grant','ff82_revoke_grant')
 LOOP EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon',f.fn); EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',f.fn); END LOOP;
END $$;
""")
    run("docker","run","-d","--name",REST,"--network",NETWORK,"-p","127.0.0.1:18090:3000","-e","PGRST_DB_URI=postgres://authenticator:test-only-a09@a09-pg:5432/postgres","-e","PGRST_DB_SCHEMAS=public","-e","PGRST_DB_ANON_ROLE=anon","-e","PGRST_JWT_SECRET="+SECRET,"postgrest/postgrest:v12.2.12")
    wait_for(lambda: urllib.request.urlopen(URL+"/",timeout=2).status==200,"PostgREST")
    for name,args,action,target in endpoints:
        before=int(sql("SELECT count(*) FROM ff82_content_audit;"))
        status,body=call(name,args)
        assert status==403,(name,status,body)
        row=json.loads(sql("SELECT row_to_json(a)::text FROM ff82_content_audit a ORDER BY id DESC LIMIT 1;"))
        assert int(sql("SELECT count(*) FROM ff82_content_audit;"))==before+1,(name,"missing committed audit")
        assert row["actor_id"]==WORKER and row["grant_id"]==10 and row["action"]==action and row["attempted_revision"]==target and row["reason"]=="manager_only:revoked" and row["effect"]=="no_change" and row["outcome"]=="denied",row
        print("PASS HTTP 403 + committed audit:",name,flush=True)
    assert sql("SELECT count(*) FROM ff_ui_versions WHERE published_at IS NOT NULL;")=="0"
    assert sql("SELECT count(*) FROM ff_content_versions WHERE published_at IS NOT NULL;")=="0"
    assert sql("SELECT count(*) FROM ff_ui_trials;")=="0"
    assert sql("SELECT count(*) FROM ff82_content_grants WHERE revoked_at IS NOT NULL;")=="1"
    for name,args in [("ff_ui_publish",{"p_id":20}),("ff_content_publish",{"p_id":30})]:
        status,body=call(name,args,MANAGER)
        assert status in (200,204),(name,status,body)
    assert sql("SELECT count(*) FROM ff_ui_versions WHERE published_at IS NOT NULL;")=="1"
    assert sql("SELECT count(*) FROM ff_content_versions WHERE published_at IS NOT NULL;")=="1"
    print("PASS manager publish unchanged; all 12 real HTTP denials committed without side effects",flush=True)
except Exception:
    for name in (PG,REST):
        subprocess.run(["docker","logs",name],check=False)
    raise
finally:
    for name in (REST,PG):
        subprocess.run(["docker","rm","-f",name],check=False,stdout=subprocess.DEVNULL)
    subprocess.run(["docker","network","rm",NETWORK],check=False,stdout=subprocess.DEVNULL)
