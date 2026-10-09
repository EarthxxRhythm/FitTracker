import json
import sys

sys.stdout.reconfigure(encoding="utf-8")

path = sys.argv[1] if len(sys.argv) > 1 else "work/ui.json"
d = json.load(open(path, encoding="utf-8"))

def walk(n, depth=0):
    t = n.get("attributes", {})
    txt = (t.get("text") or t.get("content") or "").strip()
    bounds = t.get("bounds", "")
    typ = t.get("type", "")
    clickable = t.get("clickable") is True
    if txt or clickable or typ in ("Button", "Text", "Image"):
        print("  " * depth + f"[{typ}] text={txt!r} bounds={bounds} clickable={clickable}")
    for c in n.get("children", []):
        walk(c, depth + 1)

walk(d)
