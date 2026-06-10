# Query: Diagnose + fix bare HTTP 500 from raster service anomaly overlay

**Date:** 2026-06-10 21:30 UTC
**Mode:** read-first diagnostic → propose → apply minimal fix → verify.

A chatbot session called `show_climate_overlay_on_map(product="rainfall_new_month", date="2026-03", island="Hawaiʻi", anomaly=True)` and the FastAPI raster service returned HTTP 500 with no detail body. In the same session, `/raster/stats` and `/raster/anomaly/stats` both succeeded with `island="Hawaiʻi"`, so island lookup was fine — the crash was specific to the overlay/PNG path.

---

## Bottom line

**Bug:** every `/raster/overlay.png` and `/raster/anomaly/overlay.png` request with an ʻokina-bearing island (`Hawaiʻi`, `Oʻahu`, `Kauaʻi`, `Lānaʻi`, `Molokaʻi`, `Niʻihau`, `Kahoʻolawe`) returned HTTP 500. Cause was a response-header serialization error, not the anomaly math, not the PNG rendering, not island cropping.

**Fix:** ASCII-fold the `X-Island` response header value at two call sites in `routes.py`. Single-file edit, 11 inserted lines, two value swaps. Service restarted (~2 s). All four diagnostic curls now 200; no errors in fresh journal.

---

## 1. Traceback (the critical frames)

```
File "/opt/hcdp/raster_service/routes.py", line 396, in anomaly_overlay
    return Response(content=png_bytes, media_type="image/png", headers=headers)
File ".../starlette/responses.py", line 61, in init_headers
    raw_headers = [(k.lower().encode("latin-1"), v.encode("latin-1")) for k, v in headers.items()]
UnicodeEncodeError: 'latin-1' codec can't encode character 'ʻ' in position 5: ordinal not in range(256)
```

Earlier non-anomaly 500s at 00:21–00:22 UTC the same day produced an identical stack into `routes.py:212` (the non-anomaly overlay endpoint). Same bug, both paths.

## 2. Four-curl reproduction

| # | Endpoint | Island | Before | After |
|---|---|---|---|---|
| 1 | `/raster/anomaly/overlay.png` | `Hawaiʻi` | **500** (21 B body) | **200** (73.9 KB PNG) |
| 2 | `/raster/anomaly/overlay.png` | `Maui` | 200 (20.6 KB) | 200 (20.6 KB) |
| 3 | `/raster/overlay.png` | `Hawaiʻi` | **500** (21 B body) | **200** (103.0 KB PNG) |
| 4 | `/raster/anomaly/overlay.png` | (statewide, no island) | 200 (98.5 KB) | 200 (98.5 KB) |

The pre-fix pattern isolated the bug precisely: 500 fires **only** when the URL-decoded `island` contains a non-latin-1 character. Anomaly math is fine (case 4 ✓), PNG rendering is fine (case 2 ✓), island cropping is fine (case 2 ✓). All four post-fix responses begin with the PNG magic `89 50 4E 47`, and the response carries `x-island: Hawaii` (ASCII-folded from the ʻokina form).

## 3. Root cause

`routes.py:210` (non-anomaly overlay) and `routes.py:394` (anomaly overlay) shoved the raw `island` query value into the `X-Island` response header:

```python
headers = {
    ...
    "X-Island": island or "",     # ← the ʻokina lands here
}
return Response(content=png_bytes, media_type="image/png", headers=headers)
```

Starlette wire-encodes header values as **latin-1** per RFC 9110:

```python
# starlette/responses.py:61
raw_headers = [(k.lower().encode("latin-1"), v.encode("latin-1")) for k, v in headers.items()]
```

ʻokina is U+02BB, outside the latin-1 range (0x00–0xFF). Every ʻokina-bearing island name (Hawaiʻi, Oʻahu, Kauaʻi, Lānaʻi, Molokaʻi, Niʻihau, Kahoʻolawe) would 500. Maui is the only major island whose ASCII spelling has no diacritic — that's why the bug was easy to miss in normal smoke testing.

`/raster/stats` and `/raster/anomaly/stats` succeeded in the same session because they return JSON and don't set an `X-Island` response header — same input character, different serialization path.

## 4. The fix (single file: `/opt/hcdp/raster_service/routes.py`)

```diff
+import unicodedata
 from typing import Optional


+def _ascii_header(s: Optional[str]) -> str:
+    # HTTP headers are latin-1 on the wire; fold diacritics so island names
+    # like "Hawaiʻi" (ʻokina U+02BB) survive as plain ASCII ("Hawaii").
+    if not s:
+        return ""
+    return unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode("ascii")
@@ line 219 (was 210, non-anomaly overlay)
-        "X-Island": island or "",
+        "X-Island": _ascii_header(island),
@@ line 403 (was 394, anomaly overlay)
-        "X-Island": island or "",
+        "X-Island": _ascii_header(island),
```

- Helper is 4 LOC, stdlib `unicodedata`, no new dependency
- Two call-site swaps — both spots that emit `X-Island`
- Nothing else changes: query handling, anomaly math, island geometry lookup, raster cropping, PNG bytes all untouched
- `X-Island` is informational metadata for client-side debugging; folding `Hawaiʻi → Hawaii` keeps it human-readable and matches the plain-ASCII vocabulary the station tables already use (see the earlier island-vocab report from today)

### Why I picked ASCII-fold over the alternatives

- **Alternative A — RFC 8187 `*=UTF-8''…` encoding.** Correct per spec, but `X-Island` is a custom non-standard header; clients reading it would need a parser for the encoded form. Heavier change, no real benefit.
- **Alternative B — drop the header when non-latin-1.** Loses information; client code that conditionally branches on `X-Island` presence would behave differently for Hawaiʻi vs Maui.
- **Alternative C (chosen) — ASCII-fold.** Keeps the header readable, consistent with station-table vocabulary, never raises.

## 5. Restart + post-fix verification

```
$ sudo systemctl restart hcdp-raster-service
$ systemctl is-active hcdp-raster-service
active
$ curl -s http://127.0.0.1:8000/health
{"status":"ok","service":"hcdp-raster-service","version":"0.1"}
```

All four curls re-run → all 200. Fresh journal since restart shows zero errors, only the `INFO: 200 OK` lines from the verification curls. Service was down ~2 s during restart.

The MCP tool `show_climate_overlay_on_map(..., anomaly=True, island="Hawaiʻi")` that triggered the original chatbot 500 will now succeed on the next call — no chatbot-side change needed.

## 6. One related item worth flagging (not part of this task)

The edited file lives at `/opt/hcdp/raster_service/routes.py`, which is **not** inside the `hcdp-ai-interface` git checkout at `/opt/hcdp/src/`. So this fix exists on the running host but isn't tracked in any repo visible from here:

```
/opt/hcdp/raster_service/   ← edited (in-place, untracked)
/opt/hcdp/src/              ← hcdp-ai-interface checkout (untouched)
```

If `raster_service/` is supposed to be sourced from somewhere — another repo, a tarball, manual provisioning — this edit will drift or be wiped on the next provision. Worth confirming where the canonical copy lives before the next deploy so the fix can be committed upstream and not regress.
