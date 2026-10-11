from pathlib import Path

import numpy as np
from PIL import Image, ImageChops


ROOT = Path(r"D:\.CodeSpace\.DevEcoStudioProjects\FitTracker")
PROTO_SETTLED = ROOT / "test_run" / "prototype-phone"
PROTO_MOTION = ROOT / "test_run" / "prototype-motion"
DEVICE_DIR = ROOT / "test_run" / "device-motion"
DIFF_DIR = ROOT / "test_run" / "motion-diff"

# prototype page name -> device capture base name
PAGES = {
    "welcome-home": "home",
    "auth": "login",
    "plan": "plan",
    "training-preview": "preview",
    "training": "active",
    "training-complete": "complete",
    "review": "review",
    "personal": "profile",
}

STATES = ["settled", "pressed", "mid"]


def load_resized(path: Path):
    image = Image.open(path).convert("RGB")
    return np.asarray(image.resize((390, 844), Image.Resampling.LANCZOS), dtype=np.float32)


def best_alignment(ref: np.ndarray, device: np.ndarray):
    ref_gray = ref.mean(axis=2)
    device_gray = device.mean(axis=2)
    device_gray = device_gray[39:]
    ref_gray = ref_gray[: device_gray.shape[0]]
    best = None
    for dy in range(-24, 25, 2):
        for dx in range(-24, 25, 2):
            ref_slice = ref_gray
            device_slice = device_gray
            if dy > 0:
                ref_slice = ref_slice[dy:]
            elif dy < 0:
                device_slice = device_slice[-dy:]
            if dx > 0:
                ref_slice = ref_slice[:, dx:]
            elif dx < 0:
                device_slice = device_slice[:, -dx:]
            min_h = min(ref_slice.shape[0], device_slice.shape[0])
            min_w = min(ref_slice.shape[1], device_slice.shape[1])
            ref_slice = ref_slice[:min_h, :min_w]
            device_slice = device_slice[:min_h, :min_w]
            mae = float(np.mean(np.abs(ref_slice - device_slice)))
            if best is None or mae < best[0]:
                best = (mae, dx, dy)
    return best


def build_sheet(ref: Image.Image, device: Image.Image, name: str):
    diff = ImageChops.difference(ref, device).convert("L")
    sheet = Image.new("RGB", (390 * 3 + 24, 844), (20, 24, 28))
    sheet.paste(ref, (0, 0))
    sheet.paste(device, (390 + 12, 0))
    sheet.paste(diff, (390 * 2 + 24, 0))
    path = DIFF_DIR / f"{name}.png"
    sheet.save(path)
    return path


def main():
    DIFF_DIR.mkdir(parents=True, exist_ok=True)
    lines = ["# Motion Frame Diff (prototype vs device)", ""]
    for page, device_name in PAGES.items():
        for state in STATES:
            if state == "settled":
                ref_path = PROTO_SETTLED / f"{page}.png"
            else:
                ref_path = PROTO_MOTION / f"{page}-{state}.png"
            device_path = DEVICE_DIR / f"{device_name}-{state}.jpeg"
            if not ref_path.exists() or not device_path.exists():
                lines.append(f"- {page}/{state}: missing ({'ref' if not ref_path.exists() else 'device'})")
                continue
            ref = load_resized(ref_path)
            device = load_resized(device_path)
            mae, dx, dy = best_alignment(ref, device)
            ref_img = Image.open(ref_path).convert("RGB").resize((390, 844), Image.Resampling.LANCZOS)
            dev_img = Image.open(device_path).convert("RGB").resize((390, 844), Image.Resampling.LANCZOS)
            sheet = build_sheet(ref_img, dev_img, f"{page}-{state}")
            lines.append(f"- {page}/{state}: MAE={mae:.2f}/255, offset=({dx},{dy}), diff={sheet.name}")
        lines.append("")
    report = DIFF_DIR / "report.md"
    report.write_text("\n".join(lines), encoding="utf-8")
    print(report)
    print("\n".join(lines))


if __name__ == "__main__":
    main()
