"""FIX-01 A01: verify pinned Git trees, reconstruct baseline archive, and check trace coverage."""
import hashlib
import io
import json
import re
import subprocess
import tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs" / "implementation"
def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)

def tree(commit):
    out = {}
    for item in git("ls-tree", "-rlz", commit).split(b"\0"):
        if not item:
            continue
        meta, path = item.split(b"\t", 1)
        mode, kind, sha, size = meta.decode().split()
        assert kind == "blob", (kind, path)
        out[path.decode()] = {"sha": sha, "bytes": int(size), "mode": mode}
    return out

def verify_archive(commit, expected):
    with tarfile.open(fileobj=io.BytesIO(git("archive", "--format=tar", commit)), mode="r:") as tar:
        files = {}
        for member in tar.getmembers():
            if member.isdir():
                continue
            assert member.isfile(), member.name
            data = tar.extractfile(member).read()
            sha = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
            files[member.name] = {"sha": sha, "bytes": len(data)}
    assert set(files) == set(expected), "Archive file list mismatch"
    for path, record in expected.items():
        assert files[path] == {"sha": record["sha"], "bytes": record["bytes"]}, path
    print(f"PASS reconstructed archive {commit}: {len(files)} files")

baseline = json.loads((DOCS / "P0_BASELINE_v38.38.0_manifest.json").read_text())
diff = json.loads((DOCS / "A01-source-diff-20261124.json").read_text())
assert baseline["baseline_commit"] == diff["baseline_commit"]
old, reviewed = tree(diff["baseline_commit"]), tree(diff["reviewed_commit"])
assert len(old) == len(baseline["files"]) == baseline["source_file_count"] == 53
for item in baseline["files"]:
    assert old[item["path"]]["sha"] == item["git_blob_sha1"]
    assert old[item["path"]]["bytes"] == item["bytes"]
assert sum(x["bytes"] for x in old.values()) == baseline["total_file_bytes"]
assert len(reviewed) == diff["reviewed_files"]
assert len(diff["files"]) == len(set(old) | set(reviewed))
assert {x["path"] for x in diff["files"]} == set(old) | set(reviewed)
counts = dict.fromkeys(["added", "removed", "modified", "unchanged"], 0)
for row in diff["files"]:
    path = row["path"]
    assert row["baseline"] == old.get(path)
    assert row["reviewed"] == reviewed.get(path)
    status = "added" if path not in old else "removed" if path not in reviewed else "unchanged" if old[path] == reviewed[path] else "modified"
    assert row["status"] == status, path
    counts[status] += 1
assert counts == diff["counts"]
verify_archive(diff["baseline_commit"], old)
verify_archive(diff["reviewed_commit"], reviewed)
print("PASS complete pinned file delta", counts)
matrix = (DOCS / "A01-approval-traceability-20261124.md").read_text()
expected = {f"{prefix}-{n:02d}" for prefix, start, end in [("FIX",1,20),("DEC",1,10),("MSG",1,5),("UI",1,16),("QA",1,45),("T",1,20),("TR",21,45)] for n in range(start,end+1)}
expected.update(f"P{n}" for n in range(8))
actual = re.findall(r"^\| ((?:FIX|DEC|MSG|UI|QA|T|TR)-\d{2}|P[0-7]) \|", matrix, re.M)
assert len(actual) == len(set(actual)) == len(expected)
assert set(actual) == expected, (expected-set(actual), set(actual)-expected)
print(f"PASS trace ID coverage: {len(actual)} unique rows")
