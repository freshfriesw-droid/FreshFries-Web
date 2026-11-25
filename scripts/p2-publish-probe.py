"""Read-only P2 deployment parity; no authenticated traffic or data writes."""
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.parse import urljoin, urlparse
from hashlib import sha256
from time import sleep
import re, json
root=Path(__file__).resolve().parents[1]
origin='https://delivery.freshfriesz.com/'
report=json.loads((root/'docs/implementation/P2-css-consolidation-20261125.json').read_text())
html=(root/'index.html').read_bytes()
assert b'luxe-p2-components.css?v=20261125-p2' in html
assets=sorted(set(re.findall(rb'href="([^"]+\.css)(?:\?[^"]*)?"',html)))
assets=[x.decode().removeprefix('./') for x in assets if not x.startswith((b'http:',b'https:',b'//'))]
assert 'styles/luxe-p2-components.css' in assets

def get(path):
 req=Request(urljoin(origin,path),headers={'Cache-Control':'no-cache','User-Agent':'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/130.0 Safari/537.36'})
 with urlopen(req,timeout=20) as r:
  assert urlparse(r.geturl()).hostname==urlparse(origin).hostname
  assert r.status==200
  return r.read()
for attempt in range(12):
 try:
  remote=get('?qa=20261125-p2-'+str(attempt))
  assert remote==html,'published HTML not yet byte-identical'
  for path in assets:
   expected=(root/path).read_bytes(); actual=get(path+'?qa=20261125-p2-'+str(attempt))
   assert actual==expected,'public CSS differs: '+path
   print('PASS',path,sha256(actual).hexdigest(),flush=True)
  print('PASS exact public HTML and',len(assets),'local CSS assets',sha256(remote).hexdigest(),flush=True)
  break
 except (OSError,AssertionError) as exc:
  print('Publish attempt',attempt+1, str(exc),flush=True)
  if attempt==11:raise
  sleep(10)
