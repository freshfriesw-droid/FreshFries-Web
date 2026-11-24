"""Read-only HTTPS deployment check against the exact checked-out revision.
Use only after the corresponding product change has merged.
"""
from hashlib import sha256
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.parse import urljoin, urlparse
from time import sleep
import re
root=Path(__file__).resolve().parents[1]
origin="https://delivery.freshfriesz.com/"
source=(root/"index.html").read_text(encoding="utf-8")
assets=["scripts/luxe-unified-order-inputs-20261123.js","scripts/luxe-order-customer-edit-20261123.js"]
def get(relative):
    request=Request(urljoin(origin,relative),headers={"Cache-Control":"no-cache","User-Agent":"FreshFries-LUXE-deployment-QA"})
    with urlopen(request,timeout=25) as response:
        if urlparse(response.geturl()).hostname!=urlparse(origin).hostname or response.status!=200:
            raise RuntimeError("Unexpected public site response")
        return response.read()
def revision(html,asset):
    match=re.search(re.escape(asset)+r"\?v=([^\"]+)",html)
    assert match, f"Versioned asset missing: {asset}"
    return match.group(1)
def fragment(html,start,end):
    pos=html.index(start)
    return html[pos:html.index(end,pos)]
expected={a:revision(source,a) for a in assets}
for attempt in range(7):
    try:
        published=get("?qa="+expected[assets[0]]).decode("utf-8")
        assert "ff71-customer-phone-otp" in published
        assert "c.orders_count??0" in published
        for a,v in expected.items():
            assert revision(published,a)==v, f"Stale HTML reference: {a}"
            remote=get(a+"?v="+v)
            local=(root/a).read_bytes()
            assert remote==local, f"Public asset mismatch: {a}"
            print(f"{a}?v={v}: exact SHA256 {sha256(remote).hexdigest()}",flush=True)
        # Compare the exact source for the preview, cards, staff/driver guards and archive projection.
        for start,end in [
            ('<script id="ff75-unified-parser-ux">','</script>'),
            ('function additionsFor(order)','function drawMetrics()'),
            ('function drawOrders()','function drawCashier()'),
            ('function drawDriver()','function drawRoster()'),
            ("$('ff52LateSave').onclick=async()=>{","function ff52RouteSelections()"),
            ('box.innerHTML=ff51ArchiveRows.length?',"$('ff51ArchiveNext').disabled")
        ]:
            remote=fragment(published,start,end)
            local=fragment(source,start,end)
            assert remote==local, f"Inline addition source mismatch: {start}"
            print(f"Exact inline source: {start} SHA256 {sha256(remote.encode()).hexdigest()}",flush=True)
        assert "window.ff75ReviewAddition" in published
        assert "addition_events" in published
        print("PASS FIX-08 #81: deployed shared menu, canonical preview, active cards, delivery guards and archive match tested source",flush=True)
        break
    except (AssertionError,ValueError,OSError,RuntimeError) as exc:
        if attempt==6:
            raise
        print(f"Publication attempt {attempt+1}: {exc}",flush=True)
        sleep(8)
