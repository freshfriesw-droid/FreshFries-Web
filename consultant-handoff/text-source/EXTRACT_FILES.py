from pathlib import Path
import base64, hashlib, json, sys
src=Path(__file__).resolve().parent
dest=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else src/'RESTORED_SYSTEM'
begin=b'\n<<<FF_LUXE_SOURCE_FILE_BEGIN>>>\n'
end=b'\n<<<FF_LUXE_SOURCE_FILE_END>>>\n'
manifest=json.loads((src/'MANIFEST.json').read_text(encoding='utf-8'))
count=0
for part in manifest['parts']:
    source=src/part['filename']
    raw=source.read_bytes()
    if hashlib.sha256(raw).hexdigest()!=part['sha256']:
        raise ValueError('Part corrupted: '+str(source))
    pos=0
    while True:
        index=raw.find(begin,pos)
        if index<0: break
        header_start=index+len(begin)
        header_end=raw.index(b'\n',header_start)
        meta=json.loads(raw[header_start:header_end].decode('utf-8'))
        payload_start=header_end+1
        payload_end=payload_start+meta['payload_bytes']
        payload=raw[payload_start:payload_end]
        if raw[payload_end:payload_end+len(end)]!=end:
            raise ValueError('Malformed file boundary: '+meta['path'])
        original=base64.b64decode(payload,validate=True) if meta['encoding']=='base64' else payload
        if len(original)!=meta['original_bytes'] or hashlib.sha256(original).hexdigest()!=meta['sha256']:
            raise ValueError('Checksum mismatch for '+meta['path'])
        target=dest/meta['path']
        if not target.resolve().is_relative_to(dest.resolve()):
            raise ValueError('Unsafe output path')
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(original)
        count+=1
        pos=payload_end+len(end)
assert count==manifest['count'],f'Expected {manifest["count"]} source files, got {count}'
print('SUCCESS: Restored',count,'original source files to',dest)
