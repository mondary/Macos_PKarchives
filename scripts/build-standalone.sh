#!/bin/bash
# Génère une version HTML 100 % autonome de la landing (vidéo et images inline en base64).
# Usage : scripts/build-standalone.sh [source.html] [sortie.html]
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEFAULT_SRC="${DIR}/store/website/index.html"
[[ -f "$DEFAULT_SRC" ]] || DEFAULT_SRC="${DIR}/website/index.html"
[[ -f "$DEFAULT_SRC" ]] || DEFAULT_SRC="${DIR}/website/PKarchives/index.html"
SRC="${1:-$DEFAULT_SRC}"
OUT="${2:-${SRC%.html}-standalone.html}"

python3 - "$SRC" "$OUT" <<'PY'
import base64, re, sys
from pathlib import Path

src, out = map(Path, sys.argv[1:])
html = src.read_text()
media = src.parent / "media"

MIME = {"jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png",
        "gif": "image/gif", "webp": "image/webp", "mp4": "video/mp4", "webm": "video/webm"}

def data_uri(name):
    f = media / Path(name).name
    if not f.exists():
        raise SystemExit(f"❌ Média manquant : {f}")
    mime = MIME.get(f.suffix.lstrip(".").lower())
    if not mime:
        raise SystemExit(f"❌ Type non géré : {f}")
    return f"data:{mime};base64," + base64.b64encode(f.read_bytes()).decode()

# attributs src= / poster="media/…"
html = re.sub(r'(src|poster)="(media/[^"]+)"',
              lambda m: f'{m.group(1)}="{data_uri(m.group(2))}"', html)
# url('media/…') en CSS
html = re.sub(r"url\('(media/[^']+)'\)",
              lambda m: f"url('{data_uri(m.group(1))}')", html)

out.write_text(html)
print(f"✅ {out} — {out.stat().st_size / 1e6:.1f} Mo, aucun fichier externe requis.")
PY
