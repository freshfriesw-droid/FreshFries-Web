/* Fresh Fries LUXE - finishing touches 2026-11-21.
   Additive UI layer: no direct writes; all mutations use scoped Supabase RPCs. */
(function () {
'use strict';
const $ = id => document.getElementById(id);

// All drawer-style navigation starts closed on desktop AND mobile.
// Closed menus must not retain keyboard focus or expose hidden actions.
const sidebar = $('ffx-sidebar');
if (sidebar) {
  const sync = () => {
    const open = document.body.classList.contains('ffx-menu-open');
    sidebar.inert = !open;
    if (open) sidebar.removeAttribute('aria-hidden');
    else sidebar.setAttribute('aria-hidden', 'true');
    $('ffx-menu')?.setAttribute('aria-expanded', String(open));
  };
  new MutationObserver(sync).observe(document.body, {attributes:true, attributeFilter:['class']});
  sync();
}

// Predict the next eligible driver while the customer-service operator edits
// the branch or area. The result remains an estimate; dispatch is server-side.
const branchInput = $('newBranch'), areaInput = $('newArea');
let pendingPreview = 0, lastPreviewKey = '', previewRevision = 0;
async function updateCandidate() {
  const box = $('ffLuxeDriverCandidate');
  if (!box || !branchInput?.value || !data || !['manager','customer_service'].includes(data.role)) return;
  const key = branchInput.value+'|'+String(areaInput?.value||'').trim();
  if (key === lastPreviewKey) return;
  lastPreviewKey = key;
  const revision = ++previewRevision;
  box.textContent = '🛵 الموصل التالي المتوقع: جارٍ التحقق...';
  try {
    const p = await rpc('ff_luxe_dispatch_preview', {
      p_branch: branchInput.value,
      p_area: String(areaInput?.value||'').trim()
    });
    if (revision !== previewRevision || !data) return;
    box.textContent = p?.state === 'candidate'
      ? '🛵 الموصل التالي المتوقع: '+String(p.driver_name||'غير معروف')+' (توقع وليس إسنادًا نهائيًا)'
      : p?.state === 'waiting'
        ? '🛵 الموصل التالي المتوقع: لا يوجد موصل مؤهل الآن؛ سيُوضع الطلب في الانتظار'
        : '🛵 الموصل التالي المتوقع: لا يمكن تحديده الآن';
  } catch (_) {
    if (revision === previewRevision) box.textContent =
      '🛵 الموصل التالي المتوقع: تعذرت المعاينة؛ سيحسم الخادم الإسناد عند الاعتماد';
  }
}
function scheduleCandidate() {
  window.clearTimeout(pendingPreview);
  lastPreviewKey = '';
  pendingPreview = window.setTimeout(() => { void updateCandidate(); }, 500);
}
for (const node of [branchInput,areaInput]) {
  node?.addEventListener('change', scheduleCandidate);
  node?.addEventListener('input', scheduleCandidate);
}
window.addEventListener('ff:open-order', scheduleCandidate);
$('ffx-hero-new')?.addEventListener('click', scheduleCandidate);

// Cashiers can evaluate the assigned driver on a 1-5 star popup with an
// optional note. Managerial cashier preview uses an independent manager role.
const originalCashierDraw = typeof drawCashier === 'function' ? drawCashier : null;
function attachCashierRatings() {
  if (!data || !['cashier','manager'].includes(data.role)) return;
  const root = $('cashierOrders');
  if (!root) return;
  const visibleOrders = (data.orders||[]).filter(o =>
    o.phase && o.phase !== 'delivered' &&
    (o.cashier_stage !== 'handed_over' ||
       (typeof additionsFor === 'function' &&
        additionsFor(o).some(a => a.status==='pending'||a.late_state==='invoiced')))
  );
  for (const card of root.querySelectorAll(':scope > .item')) {
    const orderNumber = card.querySelector('.item-top strong')?.textContent?.match(/#\s*(\d+)/)?.[1];
    const order = visibleOrders.find(o => String(o.number)===orderNumber);
    const actions = card.querySelector('.actions');
    if (!order?.driver_id || !actions || actions.querySelector('[data-luxe-cashier-rating]')) continue;
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'outline';
    button.dataset.luxeCashierRating = order.id;
    button.textContent = '⭐ تقييم الموصل (1–5 نجوم)';
    button.addEventListener('click', async () => {
      if (!['cashier','manager'].includes(data?.role)) return;
      const rating = await window.ffLuxeStarPrompt('تقييم الموصل من الكاشير');
      if (!rating) return;
      button.disabled = true;
      try {
        await rpc('ff_luxe_rate_driver_cashier', {
          p_order:order.id,p_stars:rating.stars,p_note:rating.note||''
        });
        toast('✅ تم حفظ تقييم الموصل وملاحظتك');
      } catch (err) {
        toast('تعذر حفظ تقييم الموصل: '+(err?.message||err));
      } finally { button.disabled = false; }
    });
    actions.append(button);
  }
}
if (originalCashierDraw) {
  drawCashier = function () {
    originalCashierDraw.apply(this,arguments);
    attachCashierRatings();
  };
}

// Extra-strong visual cancellation warning, kept separate from active orders
// until cashier acknowledges having checked the matching MicroPOS invoice.
const style = document.createElement('style');
style.id = 'ff-luxe-operational-polish-20261121';
style.textContent = `
  #ffx-sidebar{visibility:hidden!important;pointer-events:none!important}
  body.ffx-menu-open #ffx-sidebar{visibility:visible!important;pointer-events:auto!important}
  #ffx-menu{display:inline-flex!important;min-width:46px;min-height:46px}
  #ffLuxeDriverCandidate{flex:1 1 220px!important;flex-basis:220px!important;margin:3px 4px!important;min-height:49px;display:flex;align-items:center;line-height:1.45}
  @media(max-width:570px){#ffLuxeDriverCandidate{flex-basis:100%!important;order:-1}}
  #cashierOrders>.item{border:4px solid #b70e1c!important;margin-block:0 19px!important;padding:16px!important;border-radius:15px!important;box-shadow:0 5px 18px #3b000025!important}
  #cashierOrders>.item .ff-cashier-status{font-size:clamp(20px,4vw,27px)!important;font-weight:950!important;color:#a40000!important;background:#fff0f0!important;border:3px solid #bd1220!important;line-height:1.65!important}
  #ffLuxeCancelledAlerts:not(.hidden){display:grid!important;gap:14px!important;margin:12px 0 22px!important}
  #ffLuxeCancelledAlerts .ff-luxe-cancelled{background:#ffdfdf!important;color:#7a0000!important;border:5px solid #b10000!important;border-radius:16px!important;padding:20px!important;box-shadow:0 8px 23px #b000003b!important}
  #ffLuxeCancelledAlerts .ff-luxe-cancel-tag{font-size:clamp(23px,4.5vw,31px)!important;font-weight:950!important;line-height:1.55!important}
  #ffLuxeCancelledAlerts .ff-luxe-cancelled button{min-height:52px!important;font-weight:900!important;font-size:16px!important}
  #ffLuxeLeaveView, #ffLuxeAssemblyPreview [data-exit]{min-height:56px!important;font-size:19px!important;font-weight:950!important}
`;
document.head.append(style);
})();
