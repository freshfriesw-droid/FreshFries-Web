from pathlib import Path
import hashlib, json
root = Path(__file__).parent
manifest = json.loads((root / 'MANIFEST.json').read_text(encoding='utf-8'))
target = root / manifest['archive']
with target.open('wb') as out:
    for part in manifest['parts']:
        data = (root / part['name']).read_bytes()
        if hashlib.sha256(data).hexdigest() != part['sha256']:
            raise ValueError('Corrupted part: ' + part['name'])
        out.write(data)
if hashlib.sha256(target.read_bytes()).hexdigest() != manifest['archive_sha256']:
    raise ValueError('Final archive integrity check failed')
print('SUCCESS:', target)
