"""Read-only public deployment verification; no auth, no order requests."""
from hashlib import sha256
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.parse import urljoin, urlparse
import re
root = Path(__file__).resolve().parents[1]
origin = "https://delivery.freshfriesz.com/"
asset = "scripts/luxe-unified-order-inputs-20261123.js"
marker = "20261124-a02-cart2"
def get(relative):
    target = urljoin(origin, relative)
    req = Request(target, headers={"Cache-Control": "no-cache", "User-Agent": "FreshFries-LUXE-deployment-QA"})
    with urlopen(req, timeout=25) as response:
        if urlparse(response.geturl()).hostname != urlparse(origin).hostname:
            raise RuntimeError("Unexpected public site redirect")
        if response.status != 200:
            raise RuntimeError(f"HTTP {response.status}")
        return response.read()
html = get("?qa=a02-cart2").decode("utf-8")
assert marker in html, "Latest merged cart cache-bust marker absent from public HTML"
assert 'ff71-customer-phone-otp' in html, "Customer portal missing"
remote = get(asset+"?v="+marker)
local = (root / asset).read_bytes()
print("Public asset SHA256:", sha256(remote).hexdigest())
print("Repository asset SHA256:", sha256(local).hexdigest())
assert remote == local, "Public script differs from tested repository asset"
print("PASS: HTTPS live HTML and exact merged cart asset are publicly served")
