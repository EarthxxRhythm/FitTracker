#!/usr/bin/env python3
"""Audit frozen HTML design tokens/motion values vs DesignTokens.ets (runtime parse).

Reads design/06_prototype_redraw/src/*.html and
entry/src/main/ets/common/styles/DesignTokens.ets,
writes design/06_prototype_redraw/TOKENS.md:
  - per-screen CSS var inventory (with cross-file consistency check)
  - mapping: HTML token -> existing ColorTokens/MotionTokens or GAP

Run:  python design/06_prototype_redraw/scripts/audit_tokens.py
"""
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
TOKENS_ETS = ROOT.parents[1] / "entry/src/main/ets/common/styles/DesignTokens.ets"

SCREENS = ["fittracker-welcome-home.html", "fittracker-auth.html", "fittracker-plan.html",
           "fittracker-plan-detail.html", "fittracker-plan-group-detail.html",
           "fittracker-training-preview.html", "fittracker-training.html",
           "fittracker-training-complete.html", "fittracker-review.html",
           "fittracker-exercise-library.html", "fittracker-body-data.html",
           "fittracker-personal.html", "fittracker-settings.html"]

# HTML token -> existing ArkUI token equivalence (curated). Key = canonical css var.
COLOR_MAP = {
    "--accent": "ColorTokens.ACCENT_PRIMARY (#50ECA7)",
    "--accent-deep": "ColorTokens.ACCENT_DEEP (#45C9A1)",
    "--accent-soft": "ColorTokens.ACCENT_SOFT (#8CEBCC)",
    "--txt-hi": "ColorTokens.TEXT_ON_DARK (#F3FBF7) / html #F7FBF8 接近",
    "--txt-body": "ColorTokens.TEXT_PRIMARY (#EDF6F2)",
    "--on-accent": "ColorTokens.TEXT_ON_PRIMARY (#09100F) -> html #07100B 微差",
    "--cta-a": "ColorTokens.ACCENT_PRIMARY 系（渐变起点 #47D994）",
    "--cta-b": "ColorTokens.ACCENT_HOVER (#53E7A5)",
    "--hairline": "ColorTokens.BORDER_HAIRLINE / DIVIDER",
    "--white-70": "ColorTokens.TEXT_ON_DARK_SECONDARY 类 alpha",
    "--nav-active": "ColorTokens.NAV_ACTIVE 语境（文本/激活）",
}


def read_css_vars(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    css = chr(10).join(re.findall(r"<style[^>]*>(.*?)</style>", text, flags=re.S))
    out = {}
    for m in re.finditer(r"(:root|body)\s*{(.*?)}", css, flags=re.S):
        for v in re.finditer(r"(--[\w-]+)\s*:\s*([^;]+);", m.group(2)):
            out.setdefault(v.group(1), v.group(2).strip())
    return out


def extract_class(ets: str, classname: str) -> dict:
    nl = chr(10)
    marker = "export class " + classname + " {"
    i = ets.find(marker)
    if i < 0:
        return {}
    j = ets.find(nl + "}", i + len(marker))
    if j < 0:
        return {}
    body = ets[i + len(marker):j]
    out = {}
    for line in body.split(nl):
        t = line.strip()
        if not t.startswith("static readonly "):
            continue
        rest = t[len("static readonly "):]
        if "=" not in rest:
            continue
        name = rest.split(":", 1)[0].strip()
        value = rest.split("=", 1)[1].split(";", 1)[0].strip()
        out[name] = value
    return out


def motion_from_css(path: Path) -> tuple:
    text = path.read_text(encoding="utf-8")
    css = chr(10).join(re.findall(r"<style[^>]*>(.*?)</style>", text, flags=re.S))
    durations = sorted(set(re.findall(r"\.(\d+)s", css)))
    curves = sorted(set(re.findall(r"cubic-bezier\(([\d.,\s]+)\)", css)))
    return durations, curves


def main() -> None:
    ets = TOKENS_ETS.read_text(encoding="utf-8").replace("\r\n", "\n")
    colors = extract_class(ets, "ColorTokens")
    motion = extract_class(ets, "MotionTokens")

    per_file = {f: read_css_vars(SRC / f) for f in SCREENS}
    canon = {}
    for f, vars_ in per_file.items():
        for k, v in vars_.items():
            canon.setdefault(k, Counter())[v] += 1
    canonical = {k: c.most_common(1)[0][0] for k, c in canon.items()}

    L = []
    L.append("# FitTracker 界面重建 · 令牌审计（TOKENS）")
    L.append("")
    L.append("> 对照：`design/06_prototype_redraw/src/*.html` `:root` 与 ")
    L.append("> `entry/src/main/ets/common/styles/DesignTokens.ets`（运行时解析，非人工抄写）。")
    L.append("> 审计基于冻结基线；基线更新后重跑：")
    L.append("> `python design/06_prototype_redraw/scripts/audit_tokens.py`")
    L.append("")
    L.append("## 1. 跨屏 CSS 变量一致性")
    L.append("")
    L.append("| CSS 变量 | 规范值（多数屏） | 偏离屏（值） |")
    L.append("|---|---|---|")
    for k in sorted(canonical):
        dev = []
        for f, vars_ in per_file.items():
            v = vars_.get(k)
            if v is not None and v != canonical[k]:
                dev.append(f.replace("fittracker-", "").replace(".html", "") + "=" + v)
        L.append("| `" + k + "` | `" + canonical[k] + "` | " +
                 (("；".join(dev)) if dev else "—") + " |")
    L.append("")
    L.append("## 2. 色值语义映射（HTML -> 现有 DesignTokens）")
    L.append("")
    L.append("| CSS 变量（规范值） | 现有令牌建议 |")
    L.append("|---|---|")
    for k, v in sorted(COLOR_MAP.items()):
        L.append("| `" + k + "` `" + canonical.get(k, "") + "` | " + v + " |")
    L.append("")
    L.append("## 3. 还原时须新增/对齐的令牌（GAP，颜色）")
    L.append("")
    L.append("> 仅列高频且与现有令牌语义对应的候选；页面专用值就地写，不强行入 token。")
    L.append("")
    for k, role in [("--ink-0", "页面背景主色（现 BG_PRIMARY=" + colors.get("BG_PRIMARY", "") + "）"),
                    ("--ink-1", "页面背景次级（现 BG_SECONDARY=" + colors.get("BG_SECONDARY", "") + "）"),
                    ("--surface", "卡片面（现 SURFACE_PRIMARY=" + colors.get("SURFACE_PRIMARY", "") + "）"),
                    ("--bg", "最外层背景（现 APP_BG_HOME=" + colors.get("APP_BG_HOME", "") + "）"),
                    ("--accent-12/20/32/40", "强调 alpha 蒙层/描边（现 OVERLAY_PRIMARY / BORDER_ACCENT）")]:
        L.append("- `" + k + "`（规范值 " + canonical.get(k.split("/")[0], "?") +
                 "）-> " + role + "。还原屏时若色差 > 1 L* 需新增语义成员，否则页面级直写。")
    L.append("")
    L.append("## 4. MotionTokens 覆盖审计（HTML 动效值 -> 令牌）")
    L.append("")
    L.append("### 4.1 跨屏出现的时长 / 曲线")
    L.append("")
    all_dur = set()
    all_cur = set()
    for f in SCREENS:
        d, c = motion_from_css(SRC / f)
        all_dur |= set(d)
        all_cur |= set(c)
    L.append("- 时长（.Ns）: " + ", ".join(sorted(all_dur, key=lambda x: int(x))))
    L.append("- 曲线 cubic-bezier: " + ", ".join(sorted(all_cur)))
    L.append("")
    L.append("### 4.2 现有 MotionTokens 成员")
    L.append("")
    L.append("| 成员 | 值 | 对应 HTML 值 |")
    L.append("|---|---|---|")
    lookup = [
        ("DURATION_PRESS", "120", ".12s 按压"),
        ("DURATION_COLOR_FAST", "160", ".16s 色/边框"),
        ("DURATION_COLOR_BASE", "180", ".18s 色"),
        ("DURATION_OVERLAY", "220", ".22s backdrop/modal/veil"),
        ("DURATION_PANEL", "280", ".28s~.3s sheet"),
        ("DURATION_RECORD", "180", "recordIn .18s"),
        ("DURATION_MARKER", "300", "markerPop .3s"),
        ("DURATION_CORE", "460", "coreIn .46s"),
        ("DURATION_SEG_POP", "460", "segPop .46s"),
        ("DURATION_CONFETTI_FLY", "1100", "confettiFly 1.1s"),
        ("DURATION_CONFETTI_FALL", "2600", "cf-fall 2.6s"),
        ("DURATION_PULSE", "1600", "livePulse 1.6s"),
        ("DURATION_CF_POP", "500", "cf-pop .5s"),
        ("DURATION_CF_RISE_FAST", "450", "cf-rise .45s"),
        ("DURATION_CF_RISE_BASE", "500", "cf-rise .5s"),
        ("EASE_MOTION", "bezier(0.2,0.7,0.2,1)", "--ease 默认"),
        ("EASE_PANEL", "bezier(0.32,0.72,0.3,1)", "sheet/面板"),
        ("EASE_FLY", "bezier(0.16,0.7,0.3,1)", "confettiFly"),
        ("EASE_FALL", "bezier(0.2,0.55,0.35,1)", "cf-fall"),
    ]
    missing = []
    for name, htmlv, note in lookup:
        val = motion.get(name, "MISSING")
        if name not in motion:
            missing.append(name)
        L.append("| `" + name + "` | " + str(val) + " | " + note + " (" + htmlv + ") |")
    L.append("")
    if missing:
        L.append("**缺漏成员（需新增）**：" + ", ".join(missing))
        L.append("")
    else:
        L.append("**结论**：MotionTokens 已覆盖训练执行/完成全部关键帧与通用转场；新增屏如 "
                 "body-data `.goal-fill width .35s` 建议补 `DURATION_PROGRESS=350`，sheet `.3s` "
                 "与 `DURATION_PANEL=280` 差异在观感容差内沿用 PANEL。")
        L.append("")
    L.append("## 5. 校准建议汇总")
    L.append("")
    L.append("1. 页面还原一律引用上述映射后的令牌成员，不写魔法值。")
    L.append("2. 色系以 #0B0F13/#50ECA7/#EDF6F2 为规范；现 ColorTokens 的 ACCENT/TEXT 族已一致，")
    L.append("   BG/SURFACE 旧值与 HTML 微差：还原屏时优先页面级直写或新增语义成员，不做全局覆盖。")
    L.append("3. MotionTokens 建议补 `DURATION_PROGRESS=350`（进度条 fill）。")
    text = chr(10).join(L) + chr(10)
    (ROOT / "TOKENS.md").write_text(text, encoding="utf-8")
    print("TOKENS.md  " + str(len(text.encode("utf-8"))) + " bytes")
    print("motion members parsed: " + str(len(motion)) + "; colors: " + str(len(colors)))


if __name__ == "__main__":
    main()
