"""Validate the P0 source snapshot and generate a repeatable inventory of controls.
Source candidates are not evidence of runtime authorization or successful clicks."""
import hashlib
import json
import re
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
p0 = json.loads((root / "docs/implementation/A01-p0-inventory-20261124.json").read_text())
def git(*args):
    return subprocess.check_output(["git", *args], cwd=root)
base = p0["reviewed_commit"]
index = git("show", f"{base}:index.html").decode()
assert len(re.findall(r"<style\b", index)) == p0["style_metrics"]["inline_style_blocks"]
assert index.count("!important") == p0["style_metrics"]["inline_important"]
assert len(re.findall(r"<button\b[^>]*>", index, re.I)) == p0["index_button_source_candidate_count"]
routes = {r["key"]: r for r in p0["routes"]}
group_source = index.split("const groups=[", 1)[1].split("const targets={catalog:", 1)[0]
actual = set(re.findall(r"\['[^']+','[^']+','([^']+)'\]", group_source))
assert actual == routes.keys() and len(routes) == 30
assert all(r["target"] and r["visibility"] and r["alternative"] and r["handler"] == f"navigate({key})" for key,r in routes.items())
css = git("show", f"{base}:styles/luxe-dashboard-studio.css").decode()
def luminance(color):
    channels = [int(color[i:i+2], 16)/255 for i in (1,3,5)]
    channels = [v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in channels]
    return sum(v*w for v,w in zip(channels, (.2126,.7152,.0722)))
packs = re.findall(r"\.ff-design-layout\[data-pack=(D\d\d)\]\{--pack-bg:(#[0-9a-f]{6});--pack-ink:(#[0-9a-f]{6});", css, re.I)
assert len(packs) == 16
for key,bg,ink in packs:
    row = next(r for r in p0["pack_contrast"] if r["pack"] == key)
    a,b = sorted((luminance(bg), luminance(ink)))
    assert row["bg"] == bg and row["ink"] == ink
    assert abs(row["ratio"]-(b+.05)/(a+.05)) < .011
assert len(p0["default_permissions"]) == p0["default_permission_count"]
print(f"PASS pinned route inventory: {len(routes)}, declared contrast pairs: {len(packs)}; role default snapshot: {p0['default_permission_count']}")
# Scan the current checked-out first-party source, including literal markup inside JS
# and explicit DOM factories. This records candidates, not unique rendered controls.
paths = [root/"index.html", *sorted((root/"scripts").glob("*.js")), *sorted((root/"assets").glob("*.js"))]
rows = []
for path in paths:
    source = path.read_text()
    for kind, pattern in (
        ("button markup", r"<button\b[^>]*>"),
        ("button factory", r"\b(?:createElement|S|make)\(\s*['\"]button['\"]"),
        ("submit binding", r"\.onsubmit\s*=|\.addEventListener\(\s*['\"]submit['\"]"),
        ("delegated click", r"\.addEventListener\(\s*['\"]click['\"]"),
        ("direct click binding", r"\.onclick\s*="),
    ):
        for m in re.finditer(pattern, source, re.I):
            attrs = {}
            if kind == "button markup":
                for a in re.finditer(r"\b(id|data-[\w-]+|aria-label|type)\s*=\s*(['\"])(.*?)\2", m.group(0)):
                    attrs[a.group(1)] = a.group(3)[:160]
            rows.append({"source": path.relative_to(root).as_posix(), "line": source.count("\n",0,m.start())+1,
                         "kind": kind, "attributes": attrs, "status": "requires runtime mapping in A06"})
out = root/"a01-evidence"
out.mkdir(exist_ok=True)
(out/"button-source-candidates.json").write_text(json.dumps({"commit":git("rev-parse","HEAD").decode().strip(),"files":[p.relative_to(root).as_posix() for p in paths],"candidates":rows},ensure_ascii=False,indent=2)+"\n")
print(f"PASS source inventory: {len(paths)} files, {len(rows)} source candidates; operational acceptance remains separate")
