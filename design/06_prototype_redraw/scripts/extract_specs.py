#!/usr/bin/env python3
"""Extract per-screen static + motion specs from the frozen Open Design HTML baseline.

Reads design/06_prototype_redraw/src/*.html and writes:
  design/06_prototype_redraw/MANIFEST.md   (route/frame/screen inventory)
  design/06_prototype_redraw/MOTION.md     (per-selector motion declarations)

Regenerate after the frozen baseline is updated:
  python design/06_prototype_redraw/scripts/extract_specs.py
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"

# Scope: 15 webapp routes -> screen files (+ shell entry, + aux files kept in src).
# Order mirrors fittracker-webapp.html ROUTE_ORDER/GROUPS.
ROUTES = [
    ("welcome", "fittracker-welcome-home.html", "screen-welcome", "启动-欢迎页"),
    ("home", "fittracker-welcome-home.html", "screen-home", "首页 Tab"),
    ("login", "fittracker-auth.html", "screen-login", "登录"),
    ("register", "fittracker-auth.html", "screen-register", "注册"),
    ("plan", "fittracker-plan.html", "screen-plan", "计划 Tab"),
    ("workout", "fittracker-training-preview.html", "screen-training-preview", "训练 Tab-预览"),
    ("plans", "fittracker-plan-detail.html", "screen-plan-detail", "计划组"),
    ("planGroup", "fittracker-plan-group-detail.html", "screen-plan-group-detail", "计划组详细"),
    ("active", "fittracker-training.html", "screen-training", "训练执行"),
    ("complete", "fittracker-training-complete.html", "screen-training-complete", "训练完成"),
    ("review", "fittracker-review.html", "screen-review", "训练回顾 Tab"),
    ("library", "fittracker-exercise-library.html", "screen-exercise-library", "动作库"),
    ("body", "fittracker-body-data.html", "screen-body-data", "身体数据"),
    ("profile", "fittracker-personal.html", "screen-personal", "我的 Tab"),
    ("settings", "fittracker-settings.html", "screen-settings", "设置"),
]
SHELL = "fittracker-webapp.html"
AUX = ["fittracker-brand-identity.html", "fittracker-training-preferences.html",
       "fittracker-review-openstats-1to1.html"]


def read_text(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def extract_styles(html: str) -> list[str]:
    return re.findall(r"<style[^>]*>(.*?)</style>", html, flags=re.S)


def extract_scripts(html: str) -> list[str]:
    return re.findall(r"<script[^>]*>(.*?)</script>", html, flags=re.S)


def css_rules(css: str):
    """Yield (selector_text, body_text) for top-level rules, skipping at-rules bodies."""
    pos = 0
    while True:
        brace = css.find("{", pos)
        if brace < 0:
            break
        sel = css[pos:brace].strip()
        depth = 1
        i = brace + 1
        while depth:
            c = css[i]
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
            i += 1
        body = css[brace + 1:i - 1]
        if not sel.startswith("@"):
            yield sel, body
        pos = i


def find_keyframes(css: str):
    out = []
    for m in re.finditer(r"@keyframes\s+([\w-]+)\s*{(.*?)}", css, flags=re.S):
        frames = re.findall(r"\b(from|to|\d+(?:\.\d+)?%)\s*\{", m.group(2))
        out.append((m.group(1), sorted(set(frames))))
    return out


def info_for(html: str) -> dict:
    styles = extract_styles(html)
    css = "\n".join(styles)
    kf = []
    for s in styles:
        kf += find_keyframes(s)
    motions = []
    active = []
    for sel, body in css_rules(css):
        decls = []
        for m in re.finditer(
            r"(transition|animation|transform)\s*:\s*([^;]+);", body):
            decls.append(f"{m.group(1)}:{m.group(2).strip()}")
        if decls:
            motions.append((sel, decls))
        if ":active" in sel:
            act = re.findall(r"transform\s*:\s*([^;]+);|opacity\s*:\s*([^;]+);", body)
            active.append((sel, [a or b for a, b in act]))
    root_vars = []
    for m in re.finditer(r":root\s*{(.*?)}", css, flags=re.S):
        root_vars += re.findall(r"(--[\w-]+)\s*:\s*([^;]+);", m.group(1))
    frames = re.findall(r'data-od-id="(screen-[\w-]+)"', html)
    titles = re.findall(r"<title>(.*?)</title>", html)
    return {
        "css_bytes": len(css),
        "keyframes": kf,
        "motions": motions,
        "active": active,
        "root_vars": root_vars,
        "frames": frames,
        "titles": titles,
        "scripts": len(extract_scripts(html)),
    }


def fmt_sel(sel: str, maxlen: int = 96) -> str:
    sel = " ".join(sel.split())
    return sel if len(sel) <= maxlen else sel[: maxlen - 1] + "…"


def build_manifest() -> str:
    lines = []
    lines.append("# FitTracker 界面重建 · 规格清单（MANIFEST）")
    lines.append("")
    lines.append("> 冻结基线目录：`design/06_prototype_redraw/src/`（唯一视觉规格源，勿手改；")
    lines.append("> HTML 更新走 Open Design 目录 → 增量 diff 流程）。")
    lines.append("")
    lines.append("## 1. 路由映射（来自 fittracker-webapp.html ROUTES）")
    lines.append("")
    lines.append("| # | route | 屏文件 | frame | 中文 | 当前仓库落点 |")
    lines.append("|---|-------|--------|-------|------|--------------|")
    mapping = {
        "welcome": "PencilWelcomePage.ets（参考已达标）",
        "home": "PencilHomePage.ets / PencilAppShell HomeContent",
        "login": "PencilLoginPage.ets",
        "register": "PencilRegisterPage.ets",
        "plan": "PencilPlanPage.ets / PlanContent",
        "workout": "PencilPreviewPage.ets",
        "plans": "PencilPlansPage.ets / PlansContent",
        "planGroup": "PencilPlanGroupDetailPage.ets / PlanGroupDetailContent",
        "active": "PencilActivePage.ets / ActiveContent",
        "complete": "WorkoutCompletePage.ets",
        "review": "PencilReviewPage.ets / ReviewContent",
        "library": "ExerciseLibraryPage.ets",
        "body": "BodyDataPage.ets / BodyDataContent",
        "profile": "PencilProfilePage.ets / ProfileContent",
        "settings": "PencilSettingsPage.ets / SettingsContent",
    }
    for i, (route, f, frame, zh) in enumerate(ROUTES, 1):
        lines.append(f"| {i} | `{route}` | `{f}` | `{frame}` | {zh} | {mapping[route]} |")
    lines.append("")
    lines.append(f"外壳入口：`{SHELL}`（15 路由预览壳，390×844 iframe）。")
    lines.append("")
    lines.append("## 2. 快照文件清单")
    lines.append("")
    lines.append("| 文件 | bytes | frames | 标题 |")
    lines.append("|---|---|---|---|")
    for f in sorted(p.name for p in SRC.glob("*.html")):
        t = read_text(SRC / f)
        info = info_for(t)
        frames = ", ".join(info["frames"]) or "-"
        title = (info["titles"][0] if info["titles"] else "-")
        lines.append(f"| `{f}` | {len(t.encode('utf-8'))} | {frames} | {title} |")
    lines.append("")
    lines.append("另含 `assets/`（ft-stage.js、exercise-gifs/、opengym-ref/）。")
    return "\n".join(lines) + "\n"


def build_motion() -> str:
    lines = []
    lines.append("# FitTracker 界面重建 · 动效规格表（MOTION）")
    lines.append("")
    lines.append("> 从冻结基线各屏 HTML `<style>` 自动提取。还原时按 ")
    lines.append("> `docs/opendesign-1to1-rules.md` 与 `docs/motion-restore-workflow.md` 映射到 ArkUI；")
    lines.append("> 时长/曲线/按压缩放系数统一落到 `common/styles/DesignTokens.ets` MotionTokens。")
    lines.append("")
    lines.append("口径：`transition/animation/transform` 声明 = 映射对象；`:active transform` = 按压反馈；")
    lines.append("`@keyframes` = 关键帧序列；循环动画（如 pulse）只核对映射表不逐帧截。")
    lines.append("")
    lines.append("生成：`python design/06_prototype_redraw/scripts/extract_specs.py`")
    lines.append("")
    for route, f, frame, zh in ROUTES:
        p = SRC / f
        if not p.exists():
            continue
        info = info_for(read_text(p))
        lines.append(f"## {route} · {f} · {zh} ({frame})")
        lines.append("")
        kf = info["keyframes"]
        if kf:
            lines.append("### @keyframes")
            lines.append("")
            lines.append("| 名称 | 关键帧% |")
            lines.append("|---|---|")
            for name, fr in kf:
                lines.append(f"| `{name}` | {', '.join(fr)} |")
            lines.append("")
        lines.append("### transition / animation / transform 规则")
        lines.append("")
        lines.append("| 选择器 | 声明 |")
        lines.append("|---|---|")
        for sel, decls in info["motions"]:
            lines.append(f"| `{fmt_sel(sel)}` | `{'; '.join(decls)}` |")
        lines.append("")
        lines.append("### :active 按压反馈")
        lines.append("")
        lines.append("| 选择器 | 效果 |")
        lines.append("|---|---|")
        for sel, eff in info["active"]:
            efftxt = "; ".join(eff) if eff else "-"
            lines.append(f"| `{fmt_sel(sel)}` | {efftxt} |")
        lines.append("")
    return "\n".join(lines) + "\n"


def main() -> None:
    if not SRC.exists():
        sys.exit(f"missing frozen baseline: {SRC}")
    manifest = build_manifest()
    (ROOT / "MANIFEST.md").write_text(manifest, encoding="utf-8")
    motion = build_motion()
    (ROOT / "MOTION.md").write_text(motion, encoding="utf-8")
    # quick summary for the caller
    print(f"MANIFEST.md  {len(manifest.encode('utf-8'))} bytes")
    print(f"MOTION.md    {len(motion.encode('utf-8'))} bytes")
    for route, f, frame, zh in ROUTES:
        info = info_for(read_text(SRC / f))
        print(f"  {route:<11} frames={len(info['frames'])} kf={len(info['keyframes'])} "
              f"motionRules={len(info['motions'])} active={len(info['active'])}")


if __name__ == "__main__":
    main()
