#!/usr/bin/env python3
"""QA-15/16: two independent PostgreSQL sessions using production assembly/burger snapshots.
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


# Explicit isolated CI-only guard.
assert os.environ.get("PGDATABASE")=="a04_qa"
assert os.environ.get("PGHOST") in ("127.0.0.1","localhost")
assert scalar("select current_database()")=="a04_qa"
root=Path(__file__).resolve().parents[1]
for name in ("a03_concurrent_core_fixture.sql","a03_concurrent_lifecycle_fixture.sql","a04_concurrent_fixture.sql"):
    subprocess.run(["psql","-X","-v","ON_ERROR_STOP=1","-f",str(root/"supabase/tests"/name)],check=True,timeout=30)
branch=uid(); assembly=uid(); cashier=uid(); k1=uid(); k2=uid(); driver=uid(); order=uid(); category=uid(); item=uid(); token=uid()
query(f"""
insert into ff_branches(id,name,code) values ('{branch}','QA branch','qa');
insert into ff_profiles(user_id,role) values ('{assembly}','assembly'),('{cashier}','cashier'),('{k1}','burger_kitchen'),('{k2}','burger_kitchen');
insert into ff_user_branches values ('{assembly}','{branch}'),('{cashier}','{branch}'),('{k1}','{branch}'),('{k2}','{branch}');
insert into ff_v9_assembly_access values ('{assembly}','{branch}',true);
insert into ff_drivers(id,branch_id) values ('{driver}','{branch}');
insert into ff38_driver_presence(driver_id,state,checked_in_at,last_seen_at) values ('{driver}','busy',now(),now());
insert into ff_orders(id,branch_id,area_snapshot,driver_id,status) values ('{order}','{branch}','QA','{driver}','sent');
insert into ff38_delivery_tasks(order_id,driver_id) values ('{order}','{driver}');
insert into ff49_cashier_receipts(order_id,received_by,invoiced_by,invoiced_at) values ('{order}','{cashier}','{cashier}',now());
update ff38_delivery_tasks set cashier_stage='printed' where order_id='{order}';
insert into ff_menu_categories(id,name) values ('{category}','QA برجر');
insert into ff_menu_items(id,category_id,name) values ('{item}','{category}','QA burger');
""")
def actor(u,sql):
    return f"select set_config('request.jwt.claim.sub','{u}',true); {sql}"
def stage(u,s,expected):
    if u==assembly:
        return actor(u,f"select public.ff_v12_assembly_set_stage('{order}','{s}','{expected}')")
    return actor(u,f"select public.ff38_cashier_set_stage('{order}','{s}')")
race(stage(assembly,"preparing","printed"),stage(cashier,"preparing","printed"),"يجب تحديث مراحل الكاشير بالترتيب")
assert scalar(f"select cashier_stage from ff38_delivery_tasks where order_id='{order}'")=="preparing"
race(stage(cashier,"ready","preparing"),stage(assembly,"ready","preparing"),"تغيرت حالة الطلب")
assert scalar(f"select cashier_stage from ff38_delivery_tasks where order_id='{order}'")=="ready"
race(stage(assembly,"handed_over","ready"),stage(cashier,"handed_over","ready"),"يجب تحديث مراحل الكاشير بالترتيب")
assert scalar(f"select cashier_stage from ff38_delivery_tasks where order_id='{order}'")=="handed_over"
assert scalar(f"select count(*) from ff60_workflow_events where order_id='{order}' and event_type='cashier'")=="4"
send=actor(cashier,f"select ff_burger_send('{branch}','local',null,'',jsonb_build_array(jsonb_build_object('id','{item}','qty',2)),'QA note','{token}')")
race(send,send)
assert scalar(f"select count(*) from ff_burger_tickets where client_token='{token}'")=="1"
ticket=scalar(f"select id from ff_burger_tickets where client_token='{token}'")
def transition(u,a):return actor(u,f"select ff_burger_transition('{ticket}','{a}')")
race(transition(k1,"receive"),transition(k2,"receive"),"المرحلة تغيرت")
assert scalar(f"select kitchen_id from ff_burger_tickets where id='{ticket}'")==k1
query(actor(k1,f"select ff_burger_confirm_notes('{ticket}')"))
race(transition(k1,"ready"),transition(k1,"ready"),"المرحلة تغيرت")
race(transition(assembly,"skip"),transition(cashier,"skip"),"المرحلة تغيرت")
assert scalar(f"select status from ff_burger_tickets where id='{ticket}'")=="acknowledged"
assert scalar(f"select acknowledged_by from ff_burger_tickets where id='{ticket}'")==assembly
assert scalar(f"select (sent_at<=accepted_at and accepted_at<=ready_at and ready_at<=acknowledged_at) from ff_burger_tickets where id='{ticket}'")=="t"
print("PASS A04: seven actual two-session races, one stage/one ticket/one receiver, notes and timestamps",flush=True)
