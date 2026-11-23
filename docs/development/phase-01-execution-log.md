# Fresh Fries LUXE — execution log, phase P0 / FIX-01 and FIX-02

**Approved reference:** Final Approval v2, 2026-11-24, phase "Repairs first" (FIX-01 ... FIX-20).
**Environment status:** Development / simulated orders only; NOT a production rollout.
**Baseline:** main at `57ab198888f259acad0a09d813eceb132a795eec` (`v38.38.0`).
**Website:** GitHub Pages; **database:** Supabase; no database writes or resets are authorized by this source-only batch.

## FIX-01 — baseline inventory
- `baseline-v38.38.0-manifest.json` lists all 53 files, their byte lengths and immutable Git blob fingerprints.
- To reproduce the precise baseline: `git checkout 57ab198888f259acad0a09d813eceb132a795eec`.
- Do not assume local `index (20).html` or earlier exports are identical to the baseline.
- Maintain an incremental source diff and retain the baseline commit for rollback.

## FIX-02 — burger quantity regression
**Root cause of red CI:** outdated static assertions required literal `product.addEventListener('click',()=>shift(1))` inside the burger module. The code was refactored to a shared photo tile with `ui.createTile(...onAdd:()=>shift(1),onRemove:()=>shift(-1))`. The shared implementation installs the real browser handlers; the legacy fallback uses `.onclick`. This static assertion therefore failed even when the real handlers were present.

**Changes in this batch:**
- Static audit tests both the real shared tile callbacks and legacy fallback.
- Browser fixture actually clicks product, + and − and asserts 0..99 bounds and selection feedback at phone and desktop sizes.
- Keep real runtime wired the same way; if browser regression is red, fix application code. Do not disable the test.

**Acceptance criteria:** Node static tests green; Playwright browser tests green, including burger at widths 320, 390, 1280; GitHub Pages build successful. No live Supabase RPC, account modification or order writes in these tests.

## Not included yet
FIX-03 navigation mapping; FIX-04 CSS conflict audit; FIX-05..20; the 16 designs; full manager visual studio; new Supabase schema. These remain pending implementation and are NOT represented as completed.

## Approved decisions (do not override)
DEC-01 16 design styles; DEC-02 section named "المالية" without cashier accounting, inventory or sales; DEC-03 role/screen/branch/device customizations; DEC-04 draft/preview/limited test/publish/rollback; DEC-05 hybrid accordion/flat; DEC-06 dynamic dashboard starting 4 KPIs; DEC-07 five mobile nav styles with icon + name default; DEC-08 Ibrahim Al-Haddad special capacity starting at five; DEC-09 content and label studio; DEC-10 scoped delegated design edits, manager-only publish and rollback.
