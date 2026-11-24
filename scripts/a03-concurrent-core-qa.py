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
