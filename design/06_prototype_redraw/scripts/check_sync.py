#!/usr/bin/env python3
"""上游 Open Design 项目 <-> 冻结基线 src/ 的对账脚本。

上游（Open Design 应用数据目录）是**活的设计源**；`src/` 是从它冻结出来的副本，
所有 ArkUI 还原工作只读 `src/`。本脚本报告两者漂移，让「冻结」保持诚实：
冻结之后上游若再改过 HTML，这里必须看得见。

用法：
  python design/06_prototype_redraw/scripts/check_sync.py [--source <dir>] [--json]

源目录解析顺序：
  1. `--source <dir>`
  2. 环境变量 `FITTRACKER_OPENDESIGN_DIR`
  3. 本机默认路径 `DEFAULT_SOURCE`

退出码：0 = 同步；1 = 存在漂移；2 = 源目录缺失。

比对范围：源目录**顶层**的 `*.html` / `*.artifact.json`，以及 `assets/` 递归。
不比对 `.file-versions/`（Open Design 的版本历史）等点开头目录。

已知排除项见 `EXCLUDED`——上游存在但不纳入规格基线，有意为之，不算漂移。
"""
import argparse
import hashlib
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"

DEFAULT_SOURCE = Path(
    r"C:\Users\19308\AppData\Roaming\Open Design\namespaces"
    r"\release-stable-win\data\projects\56d6b0af-ac55-498d-9942-c02a4d35cc71"
)

# 上游存在但有意不纳入 src/ 的文件（附理由）。这些不计入漂移。
EXCLUDED = {
    "index.html": "2026-08-19 的早期单文件原型，无 data-od-id 规格帧，已被 fittracker-webapp.html + 各屏 html 取代",
}


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    h.update(p.read_bytes())
    return h.hexdigest()


def collect(dirpath: Path) -> dict:
    """返回 {相对路径: sha256}，覆盖顶层 html/artifact.json 与 assets/ 递归。"""
    out: dict = {}
    if not dirpath.exists():
        return out
    for p in dirpath.iterdir():
        if p.is_file() and (p.name.endswith(".html") or p.name.endswith(".artifact.json")):
            out[p.name] = sha256(p)
    assets = dirpath / "assets"
    if assets.is_dir():
        for p in assets.rglob("*"):
            if p.is_file():
                out["assets/" + p.relative_to(assets).as_posix()] = sha256(p)
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description="上游 Open Design 目录与冻结基线 src/ 对账")
    ap.add_argument("--source", default=None, help="上游 Open Design 项目目录")
    ap.add_argument("--json", action="store_true", help="以 JSON 输出")
    args = ap.parse_args()

    source = Path(args.source or os.environ.get("FITTRACKER_OPENDESIGN_DIR") or DEFAULT_SOURCE)
    if not source.exists():
        if args.json:
            print(json.dumps({"status": "source-missing", "source": str(source)},
                             ensure_ascii=False, indent=2))
        else:
            print(f"上游目录不存在：{source}")
            print("用 --source 或环境变量 FITTRACKER_OPENDESIGN_DIR 指定。")
        sys.exit(2)

    up = collect(source)
    loc = collect(SRC)

    only_up = sorted(set(up) - set(loc))
    only_loc = sorted(set(loc) - set(up))
    both = sorted(set(up) & set(loc))
    drift = [f for f in both if up[f] != loc[f]]

    excluded_present = [f for f in only_up if f in EXCLUDED]
    real_only_up = [f for f in only_up if f not in EXCLUDED]

    in_sync = not drift and not real_only_up and not only_loc

    payload = {
        "status": "in-sync" if in_sync else "drift",
        "source": str(source),
        "baseline": str(SRC),
        "counts": {
            "compared": len(both),
            "drift": len(drift),
            "onlyUpstream": len(real_only_up),
            "onlyBaseline": len(only_loc),
            "excludedUpstream": len(excluded_present),
        },
        "drift": drift,
        "onlyUpstream": real_only_up,
        "onlyBaseline": only_loc,
        "excludedUpstream": [{"file": f, "reason": EXCLUDED[f]} for f in excluded_present],
    }

    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        print(f"上游：{source}")
        print(f"基线：{SRC}")
        print(f"比对 {len(both)} 个文件（源内 {len(up)}，基线内 {len(loc)}）")
        print()
        for f in drift:
            print(f"  DIFF           {f}")
        for f in real_only_up:
            print(f"  ONLY-UPSTREAM  {f}")
        for f in only_loc:
            print(f"  ONLY-BASELINE  {f}")
        for f in excluded_present:
            print(f"  EXCLUDED       {f}  —— {EXCLUDED[f]}")
        print()
        print("结论：" + ("同步" if in_sync else "存在漂移，按 README §2 同步流程处理"))

    sys.exit(0 if in_sync else 1)


if __name__ == "__main__":
    main()
