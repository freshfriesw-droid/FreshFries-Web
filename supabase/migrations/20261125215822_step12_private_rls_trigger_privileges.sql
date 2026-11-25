-- STEP12: defense in depth; private schema remains inaccessible to client roles.
alter table ff_private.a07_design_packs enable row level security;
alter table ff_private.special_courier_capacity enable row level security;
revoke execute on function ff_private.ff_burger_event_and_notify(),ff_private.ff_case_order_push(),ff_private.ff_f01_anomaly_notice(),ff_private.ff_f01_stamp_order() from public,anon,authenticated;
