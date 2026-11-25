"""STEP12 isolated HTTP contract. Disposable Docker network; no live Supabase credentials."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import base64, hashlib, hmac, json, secrets, subprocess, time, urllib.request, urllib.error
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[1]
SUFFIX = uuid4().hex[:10]
PG, REST, NETWORK = ("ff12-pg-"+SUFFIX, "ff12-rest-"+SUFFIX, "ff12-net-"+SUFFIX)
SECRET = secrets.token_hex(32) # local-only ephemeral signing key
PASSWORD = secrets.token_hex(16)
URL = "http://127.0.0.1:18091"
STAFF, CUSTOMER, BRANCH, OLD, FRESH, CSID, FOREIGN, EXPIRED, UNKNOWN = [str(uuid4()) for _ in range(9)]

def run(*args, input=None):
    return subprocess.run(args, input=input, text=True, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout

def sql(query):
    return run("docker","exec","-i",PG,"psql","-U","postgres","-d","postgres","-At","-v","ON_ERROR_STOP=1",input=query).strip()

def token(uid, sid):
    def enc(v):
        return base64.urlsafe_b64encode(v).rstrip(b"=").decode()
    claims={"role":"authenticated","sub":uid,"exp":int(time.time())+600}
    if sid is not None:
        claims["session_id"]=sid
    unsigned=enc(b'{"alg":"HS256","typ":"JWT"}')+"."+enc(json.dumps(claims,separators=(",",":")).encode())
    return unsigned+"."+enc(hmac.new(SECRET.encode(),unsigned.encode(),hashlib.sha256).digest())

def request(path, bearer=None, method="GET", args=None, schema=None):
    headers={"Content-Type":"application/json"}
    if bearer is not None: headers["Authorization"]="Bearer "+bearer
    if schema: headers["Accept-Profile"]=schema
    req=urllib.request.Request(URL+path, None if args is None else json.dumps(args).encode(),headers,method=method)
    try:
        with urllib.request.urlopen(req,timeout=15) as response:
            return response.status,json.loads(response.read().decode())
    except urllib.error.HTTPError as exc:
        return exc.code,json.loads(exc.read().decode())

def wait_for(fn,label):
    for _ in range(60):
        try:
            if fn(): return
        except (OSError,subprocess.CalledProcessError):
            pass
        time.sleep(1)
    raise RuntimeError("Not ready: "+label)

fixture=f"""
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN BYPASSRLS;
CREATE ROLE authenticator LOGIN PASSWORD '{PASSWORD}' NOINHERIT;
GRANT anon, authenticated, service_role TO authenticator;
CREATE SCHEMA auth;
CREATE SCHEMA ff_private;
CREATE SCHEMA storage;
GRANT USAGE ON SCHEMA public,auth,storage TO anon,authenticated,service_role;
CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT nullif(current_setting('request.jwt.claims',true),'')::jsonb
$$;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
 SELECT (auth.jwt()->>'sub')::uuid
$$;
CREATE TABLE auth.users(id uuid PRIMARY KEY,deleted_at timestamptz,banned_until timestamptz);
CREATE TABLE auth.sessions(id uuid PRIMARY KEY,user_id uuid REFERENCES auth.users(id),created_at timestamptz,not_after timestamptz);
CREATE TABLE public.ff_profiles(user_id uuid PRIMARY KEY REFERENCES auth.users(id),role text,active boolean);
CREATE TABLE public.ff_branches(id uuid PRIMARY KEY);
CREATE TABLE storage.objects(id uuid PRIMARY KEY,user_id uuid);
ALTER TABLE public.ff_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ff_branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.ff_profiles, public.ff_branches, storage.objects TO authenticated;
CREATE POLICY own_profile ON public.ff_profiles FOR SELECT TO authenticated USING(user_id=auth.uid());
CREATE POLICY branch_staff ON public.ff_branches FOR SELECT TO authenticated USING(EXISTS(SELECT 1 FROM public.ff_profiles p WHERE p.user_id=auth.uid() AND p.active));
CREATE POLICY own_storage ON storage.objects FOR SELECT TO authenticated USING(user_id=auth.uid());
CREATE FUNCTION public.ff_step12_public_probe() RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT true $$;
REVOKE ALL ON FUNCTION public.ff_step12_public_probe() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ff_step12_public_probe() TO anon,authenticated;
INSERT INTO auth.users(id) VALUES('{STAFF}'),('{CUSTOMER}');
INSERT INTO public.ff_profiles VALUES('{STAFF}','cashier',true);
INSERT INTO public.ff_branches VALUES('{BRANCH}');
INSERT INTO storage.objects VALUES('{BRANCH}','{STAFF}');
INSERT INTO auth.sessions VALUES
 ('{OLD}','{STAFF}',clock_timestamp()-interval '1 hour',NULL),
 ('{CSID}','{CUSTOMER}',clock_timestamp()-interval '1 hour',NULL),
 ('{FOREIGN}','{CUSTOMER}',clock_timestamp()-interval '1 hour',NULL),
 ('{EXPIRED}','{STAFF}',clock_timestamp()-interval '1 hour',clock_timestamp()-interval '1 minute');
"""
migration1=(ROOT/"supabase/migrations/20261125221559_step12_current_auth_session_guard.sql").read_text()
migration2=(ROOT/"supabase/migrations/20261125224319_step12_staff_session_lifecycle.sql").read_text()
try:
    run("docker","network","create",NETWORK)
    run("docker","run","-d","--name",PG,"--network",NETWORK,"-e","POSTGRES_PASSWORD="+PASSWORD,"postgres:16.11")
    wait_for(lambda:run("docker","exec",PG,"pg_isready","-h","127.0.0.1","-U","postgres"),"Postgres")
    sql(fixture+migration1+migration2)
    run("docker","run","-d","--name",REST,"--network",NETWORK,"-p","127.0.0.1:18091:3000","-e","PGRST_DB_URI=postgres://authenticator:"+PASSWORD+"@"+PG+":5432/postgres","-e","PGRST_DB_SCHEMAS=public,storage","-e","PGRST_DB_ANON_ROLE=anon","-e","PGRST_JWT_SECRET="+SECRET,"postgrest/postgrest:v12.2.12")
    probe="/rpc/ff_step12_public_probe"
    wait_for(lambda:request(probe,method="POST",args={})==(200,True),"anonymous RPC")
    old=token(STAFF,OLD)
    assert request("/ff_branches?select=id",old)==(200,[{"id":BRANCH}])
    assert request("/objects?select=id",old,schema="storage")== (200,[{"id":BRANCH}])
    assert request("/rpc/ff_step12_session_valid",old,method="POST",args={})==(200,True)
    for sid in (None,UNKNOWN,FOREIGN,EXPIRED,"invalid"):
        assert request("/ff_branches?select=id",token(STAFF,sid))[0]==401,("invalid session",sid)
    sql(f"UPDATE public.ff_profiles SET active=false WHERE user_id='{STAFF}';")
    assert request(probe,old,method="POST",args={})[0]==401
    sql(f"UPDATE public.ff_profiles SET active=true WHERE user_id='{STAFF}';")
    assert request("/ff_branches?select=id",old)[0]==401
    assert request("/objects?select=id",old,schema="storage")[0]==401
    sql(f"INSERT INTO auth.sessions VALUES('{FRESH}','{STAFF}',clock_timestamp(),NULL);")
    fresh=token(STAFF,FRESH)
    with ThreadPoolExecutor(max_workers=8) as pool:
        assert list(pool.map(lambda _:request("/ff_branches?select=id",old)[0],range(8)))==[401]*8
        assert list(pool.map(lambda _:request("/ff_branches?select=id",fresh)[0],range(8)))==[200]*8
    assert request("/objects?select=id",fresh,schema="storage")== (200,[{"id":BRANCH}])
    assert request(probe,token(CUSTOMER,CSID),method="POST",args={})==(200,True)
    assert request("/ff_branches?select=id",token(CUSTOMER,CSID))==(200,[])
    assert request(probe,method="POST",args={})==(200,True)
    assert sql(f"SELECT count(*) FROM auth.sessions WHERE id IN ('{OLD}','{FRESH}');")=="2"
    sql(f"DELETE FROM auth.sessions WHERE id='{FRESH}';") # disposable fixture only
    assert request("/ff_branches?select=id",fresh)[0]==401
    print("PASS STEP12 signed local HTTP: valid/invalid session claims, disable/reactivate, storage metadata, 16 parallel calls, public/customer access, session preservation, explicit revocation",flush=True)
finally:
    for name in (REST,PG):
        subprocess.run(["docker","rm","-f",name],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=False)
    subprocess.run(["docker","network","rm",NETWORK],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=False)
