"""Read-only publication verification for A02. No authentication or data mutation."""
from hashlib import sha256
from pathlib import Path
from urllib.request import Request,urlopen
from urllib.parse import urljoin,urlparse
from time import sleep
import re
root=Path(__file__).resolve().parents[1]
origin="https://delivery.freshfriesz.com/"
html=(root/"index.html").read_bytes()
source=html.decode("utf-8")
assets=["scripts/luxe-shared-photo-menu-20261123.js","scripts/luxe-unified-order-inputs-20261123.js","scripts/luxe-order-customer-edit-20261123.js"]
def get(path):
    req=Request(urljoin(origin,path),headers={"Cache-Control":"no-cache","User-Agent":"FreshFries-LUXE-A02-QA"})
    with urlopen(req,timeout=15) as response:
        assert response.status==200 and urlparse(response.geturl()).hostname==urlparse(origin).hostname
        return response.read()
for attempt in range(10):
    try:
        actual=get("?qa=20261125-a02-card-style")
        assert actual==html,"Deployed HTML does not match merged source"
        print("Exact deployed index SHA256:",sha256(actual).hexdigest(),flush=True)
        for asset in assets:
            m=re.search(re.escape(asset)+r"\?v=([^\"]+)",source)
            assert m,asset
            remote=get(asset+"?v="+m.group(1))
            assert remote==(root/asset).read_bytes(),asset
            print("Exact deployed asset:",asset,sha256(remote).hexdigest(),flush=True)
        print("PASS A02: full public HTML and three exact assets match",flush=True)
        break
    except (AssertionError,OSError,ValueError) as exc:
        if attempt==9:raise
        print("Publication attempt",attempt+1,str(exc),flush=True)
        sleep(8)
