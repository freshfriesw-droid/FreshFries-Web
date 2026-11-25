#!/usr/bin/env python3
"""QA-13/28: two independent PostgreSQL sessions using production core function snapshots.
Uses a disposable CI database with minimal dependencies, never production.
"""
import json
import os
import subprocess
import time
import uuid
from pathlib import Path

def query(sql, app="a03-inspect", check=True):
    return subprocess.run(["psql","-X","-qAt","-v","ON_ERROR_STOP=1","-c",sql],
        env={**os.environ,"PGAPPNAME":app},text=True,capture_output=True,check=check,timeout=20)

def scalar(sql):
    return query(sql).stdout.strip()

def uid():
    return str(uuid.uuid4())

def wait_for(app,event,kind=False,timeout=3):
    deadline=time.monotonic()+timeout
    field="wait_event_type" if kind else "wait_event"
    while time.monotonic()<deadline:
        if scalar(f"select exists(select 1 from pg_stat_activity where application_name='{app}' and {field}='{event}')")=="t":
            return
        time.sleep(.05)
    raise AssertionError(f"{app} never observed in {field}={event}")

def race(first,second,expect_error=None):
    """Prove the second session actually waited on a lock, not sequential replay."""
    a="a03-first-"+uid()[:8]; b="a03-second-"+uid()[:8]
    cmd=["psql","-X","-qAt","-v","ON_ERROR_STOP=1"]
    pa=subprocess.Popen(cmd+["-c","begin; set local lock_timeout='12s'; "+first+"; select pg_sleep(4); commit;"],env={**os.environ,"PGAPPNAME":a},stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    pb=None
    try:
        wait_for(a,"PgSleep")
        pb=subprocess.Popen(cmd+["-c","set lock_timeout='12s'; "+second+";"],env={**os.environ,"PGAPPNAME":b},stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        wait_for(b,"Lock",kind=True)
        out1,err1=pa.communicate(timeout=15)
        out2,err2=pb.communicate(timeout=15)
        assert pa.returncode==0,err1
        if expect_error:
            assert pb.returncode!=0 and expect_error in err2,err2
        else:
            assert pb.returncode==0,err2
        print("PASS actual distinct sessions: second blocked until first committed",flush=True)
        return out1.strip(),out2.strip()
    finally:
        for proc in (pa,pb):
            if proc and proc.poll() is None:
                proc.kill();proc.communicate()

# Guard against accidental execution anywhere except the dedicated CI service database.
assert os.environ.get("PGDATABASE")=="a03_qa"
assert os.environ.get("PGHOST") in ("127.0.0.1","localhost")
assert scalar("select current_database()")=="a03_qa"
root=Path(__file__).resolve().parents[1]
subprocess.run(["psql","-X","-v","ON_ERROR_STOP=1","-f",str(root/"supabase/tests/a03_concurrent_core_fixture.sql")],check=True,timeout=30)
# STEP10: load the exact dispatcher replacement from the new migration.
# Its report-core replacement and RLS are exercised separately on Supabase.
migration=(root/"supabase/migrations/20261125_step10_dispatch_report_evidence.sql").read_text()
start=migration.index("DO $migration$")
end=migration.index(" d:=pg_get_functiondef('ff_private.a10_report_core",start)
query(migration[start:end]+"\nEND $migration$;")
branch=uid(); normal=uid(); special=uid(); user=uid(); order=uid()
query(f"""
insert into ff_drivers(id,branch_id) values ('{normal}','{branch}'),('{special}','{branch}');
insert into ff_private.special_courier_capacity(driver_id) values ('{special}');
insert into ff38_driver_presence(driver_id,state,checked_in_at,last_seen_at) values ('{normal}','ready',now(),now()),('{special}','ready',now(),now());
insert into ff_profiles(user_id,role) values ('{user}','driver');
insert into ff38_driver_links(user_id,driver_id) values ('{user}','{normal}');
insert into ff_orders(id,branch_id,area_snapshot) values ('{order}','{branch}','QA');
""")
a,b=race(f"select public.ff38__offer_next('{order}')",f"select public.ff38__offer_next('{order}')")
assert json.loads(a.splitlines()[0])["state"]=="offered"
assert json.loads(b.splitlines()[-1])["state"]=="pending"
assert scalar(f"select count(*) from ff38_dispatch_offers where order_id='{order}' and status='offered'")=="1"
assert scalar(f"select count(*) from ff_audit_log where entity_id='{order}' and action='step10_dispatch_evidence' and details->>'mode'='automatic' and details->>'kind'='offer'")=="1"
print("PASS STEP10 concurrent dispatch evidence: one successful offer and one source event",flush=True)
offer=scalar(f"select id from ff38_dispatch_offers where order_id='{order}'")
reply=f"select set_config('request.jwt.claim.sub','{user}',true); select public.ff38_driver_reply('{offer}',true,null)"
a,b=race(reply,reply,"العرض غير متاح")
assert scalar(f"select count(*) from ff38_delivery_tasks where order_id='{order}' and driver_id='{normal}'")=="1"
assert scalar(f"select status from ff38_dispatch_offers where id='{offer}'")=="accepted"
orders=[uid() for _ in range(6)]
query("insert into ff_orders(id,branch_id,area_snapshot) values "+",".join(f"('{o}','{branch}','QA')" for o in orders))
query("insert into ff38_delivery_tasks(order_id,driver_id) values "+",".join(f"('{o}','{special}')" for o in orders[:4]))
race(f"insert into ff38_delivery_tasks(order_id,driver_id) values ('{orders[4]}','{special}')",f"insert into ff38_delivery_tasks(order_id,driver_id) values ('{orders[5]}','{special}')","اكتمل سقف")
assert scalar(f"select ff_private.special_courier_load('{special}')")=="5"
assert scalar(f"select count(*) from ff38_delivery_tasks where order_id='{orders[5]}'")=="0"
print("PASS A03 concurrent core: one offer, one acceptance, fifth succeeds and sixth fails",flush=True)


# QA-14: load actual cashier/courier RPC definitions and guards into the same isolated DB.
subprocess.run(["psql","-X","-v","ON_ERROR_STOP=1","-f",str(root/"supabase/tests/a03_concurrent_lifecycle_fixture.sql")],check=True,timeout=30)
cashier=uid()
query(f"insert into ff_profiles(user_id,role) values ('{cashier}','cashier'); insert into ff_user_branches values ('{cashier}','{branch}')")
def as_actor(actor,sql):
    return f"select set_config('request.jwt.claim.sub','{actor}',true); {sql}"
def cash(sql):
    return as_actor(cashier,sql)
def courier(sql):
    return as_actor(user,sql)
# Repeated receive is idempotent; repeated invoice can never replace the recorded reference.
receive=cash(f"select public.ff49_cashier_receive('{order}')")
race(receive,receive)
assert scalar(f"select count(*) from ff49_cashier_receipts where order_id='{order}'")=="1"
race(cash(f"select public.ff49_cashier_invoice('{order}','QA-FIRST')"),
     cash(f"select public.ff49_cashier_invoice('{order}','QA-SECOND')"),"لا يمكن اعتماد القطع")
assert scalar(f"select invoice_ref from ff49_cashier_receipts where order_id='{order}'")=="QA-FIRST"
assert scalar(f"select cashier_stage from ff38_delivery_tasks where order_id='{order}'")=="printed"
prepare=cash(f"select public.ff38_cashier_set_stage('{order}','preparing')")
race(prepare,prepare,"يجب تحديث مراحل الكاشير بالترتيب")
query(cash(f"select public.ff38_cashier_set_stage('{order}','ready')"))
# Pending addition must stop handover; no state change.
aid=uid()
query(f"insert into ff38_order_additions values ('{aid}','{order}','pending')")
handoff=cash(f"select public.ff38_cashier_set_stage('{order}','handed_over')")
blocked=query(handoff,check=False)
assert blocked.returncode!=0 and "إضافات بدون اعتماد فاتورة" in blocked.stderr,blocked.stderr
assert scalar(f"select cashier_stage from ff38_delivery_tasks where order_id='{order}'")=="ready"
query(f"update ff38_order_additions set status='invoiced' where id='{aid}'")
depart=courier(f"select public.ff38_driver_progress('{order}','on_way')")
# The courier's concurrent request waits for the cashier's handover commit.
race(handoff,depart)
assert scalar(f"select cashier_stage||':'||phase from ff38_delivery_tasks where order_id='{order}'")=="handed_over:on_way"
arrive=courier(f"select public.ff38_driver_progress('{order}','arrived')")
race(arrive,arrive,"خطوة غير متاحة")
# Exclude spare capacity fixtures from the delivery-triggered redispatch sweep.
query(f"update ff_orders set status='cancelled' where id='{orders[5]}'")
deliver=courier(f"select public.ff38_driver_progress('{order}','delivered')")
race(deliver,deliver,"الطلب ملغي أو منته")
assert scalar(f"select status from ff_orders where id='{order}'")=="delivered"
assert scalar(f"select count(*) from ff60_workflow_events where order_id='{order}' and event_type='cashier' and actor_id='{cashier}'")=="4"
assert scalar(f"select count(*) from ff60_workflow_events where order_id='{order}' and event_type='courier' and actor_id='{user}'")=="3"
print("PASS A03 lifecycle concurrency: idempotent receipt, immutable invoice, single transitions, pending addition guard, handoff before departure, audited completion",flush=True)


# STEP10: load exact A10 fee evidence function into a disposable minimal schema.
query("""
create table public.ff42_driver_settlements(id uuid primary key,status text,cash_received numeric,delivered_delivery_fees numeric);
create or replace function public.ff_is_manager() returns boolean language sql stable as $$ select exists(select 1 from public.ff_profiles where user_id=auth.uid() and role='manager' and active) $$;
""")
fee_source=(root/"supabase/migrations/20261125_a10_reporting_scope.sql").read_text()
fee_start=fee_source.index("CREATE TABLE ff_private.a10_fee_evidence")
fee_func=fee_source.index("CREATE OR REPLACE FUNCTION public.ff_a10_confirm_fee",fee_start)
fee_end=fee_source.index("CREATE OR REPLACE FUNCTION public.ff_a10_fee_history",fee_func)
fee_table=fee_source[fee_start:fee_func]
fee_table="\n".join(line for line in fee_table.splitlines() if not line.startswith("REVOKE ALL"))
query(fee_table+fee_source[fee_func:fee_end])
manager=uid(); settlement=uid()
query(f"insert into ff_profiles(user_id,role) values ('{manager}','manager');insert into ff42_driver_settlements values ('{settlement}','closed',800,300)")
race(as_actor(manager,f"select public.ff_a10_confirm_fee('{settlement}',200,'QA first evidence')"),as_actor(manager,f"select public.ff_a10_confirm_fee('{settlement}',250,'QA corrected evidence')"))
assert scalar(f"select count(*) from ff_private.a10_fee_evidence where settlement_id='{settlement}'")=="2"
assert scalar(f"select amount from ff_private.a10_fee_evidence where settlement_id='{settlement}' order by id desc limit 1")=="250"
assert scalar(f"select cash_received from ff42_driver_settlements where id='{settlement}'")=="800"
print("PASS STEP10 concurrent confirmed fee: both evidence revisions retained, latest ordered, settlement unchanged",flush=True)


# STEP11: use exact new attendance functions and dispatch lock recheck.
query("""
alter table public.ff38_driver_presence add column checked_out_at timestamptz;
create table public.ff51_driver_breaks(id bigint generated always as identity primary key,driver_id uuid not null,started_at timestamptz not null default now(),ended_at timestamptz);
""")
att=(root/"supabase/migrations/20261126_step11_attendance_guards.sql").read_text()
a=att.index("CREATE OR REPLACE FUNCTION public.ff38_clock_out")
b=att.index("-- Both automatic offer paths",a)
query(att[a:b])
a=att.index("DO $migration$",b)
b=att.index(" d:=pg_get_functiondef('public.ff52_reassign_before_pos",a)
query(att[a:b]+"\nEND $migration$;")
br=uid(); du=uid(); courier_uid=uid(); ord_a=uid(); ord_b=uid(); ord_c=uid()
query(f"""
insert into ff_drivers(id,branch_id) values ('{du}','{br}');
insert into ff_profiles(user_id,role) values ('{courier_uid}','driver');
insert into ff38_driver_links(user_id,driver_id) values ('{courier_uid}','{du}');
insert into ff38_driver_presence(driver_id,state,checked_in_at,last_seen_at) values ('{du}','ready',now(),now());
insert into ff_orders(id,branch_id,area_snapshot) values ('{ord_a}','{br}','QA'),('{ord_b}','{br}','QA'),('{ord_c}','{br}','QA');
""")
checkout=as_actor(courier_uid,"select public.ff38_clock_out()")
pause=as_actor(courier_uid,"select public.ff51_driver_set_break(true)")
# A dispatcher can see the candidate before checkout commits, but must recheck the locked row.
a,b=race(checkout,f"select public.ff38__offer_next('{ord_a}','{du}')")
assert json.loads(b.splitlines()[-1])["state"]=="queued"
assert scalar(f"select count(*) from ff38_dispatch_offers where order_id='{ord_a}'")=="0"
assert scalar(f"select state from ff38_driver_presence where driver_id='{du}'")=="offline"
query(f"update ff38_driver_presence set state='ready',checked_in_at=now(),checked_out_at=null,last_seen_at=now() where driver_id='{du}'")
race(f"select public.ff38__offer_next('{ord_b}','{du}')",checkout,"ينتظر قبولك")
assert scalar(f"select count(*) from ff38_dispatch_offers where order_id='{ord_b}' and status='offered'")=="1"
assert scalar(f"select state from ff38_driver_presence where driver_id='{du}'")=="ready"
query(f"update ff38_dispatch_offers set status='expired' where order_id='{ord_b}'")
a,b=race(pause,f"select public.ff38__offer_next('{ord_c}','{du}')")
assert json.loads(b.splitlines()[-1])["state"]=="queued"
assert scalar(f"select count(*) from ff38_dispatch_offers where order_id='{ord_c}'")=="0"
query(checkout)
assert scalar(f"select count(*) from ff51_driver_breaks where driver_id='{du}' and ended_at is null")=="0"
print("PASS STEP11 actual concurrent checkout/dispatch in both orders, pause/dispatch, no orphan break",flush=True)
