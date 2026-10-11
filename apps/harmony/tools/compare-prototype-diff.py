import os
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops

ROOT = Path(r"D:\.CodeSpace\.DevEcoStudioProjects\FitTracker")
DIFF_DIR = ROOT / "test_run" / "diff"

PAIRS = {
    "plan": ("test_run/prototype-phone/plan.png", "midscene_run/workout-chain/pixel-final/plan.jpeg"),
    "review": ("test_run/prototype-phone/review.png", "midscene_run/workout-chain/pixel-final/review.jpeg"),
    "personal": ("test_run/prototype-phone/personal.png", "midscene_run/workout-chain/pixel-final/profile.jpeg"),
    "training": ("test_run/prototype-phone/training.png", "midscene_run/workout-chain/pixel-final/active.jpeg"),
    "training-preview": ("test_run/prototype-phone/training-preview.png", "midscene_run/workout-chain/pixel-final/preview.jpeg"),
    "training-complete": ("test_run/prototype-phone/training-complete.png", "midscene_run/workout-chain/pixel-final/complete.jpeg"),
    "welcome-home": ("test_run/prototype-phone/welcome-home.png", "midscene_run/workout-chain/pixel-final/home.jpeg"),
}


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


def build_sheet(ref: Image.Image, device: Image.Image, diff: Image.Image, name: str, mae: float):
    sheet = Image.new("RGB", (390 * 3 + 24, 844), (20, 24, 28))
    sheet.paste(ref, (0, 0))
    sheet.paste(device, (390 + 12, 0))
    sheet.paste(diff, (390 * 2 + 24, 0))
    sheet_path = DIFF_DIR / f"{name}.png"
    sheet.save(sheet_path)
    return sheet_path


def main():
    DIFF_DIR.mkdir(parents=True, exist_ok=True)
    report_lines = ["# Prototype vs Device Diff", ""]
    for name, (ref_name, device_name) in PAIRS.items():
        ref_path = ROOT / ref_name
        device_path = ROOT / device_name
        if not ref_path.exists() or not device_path.exists():
            report_lines.append(f"- {name}: missing ({'ref' if not ref_path.exists() else 'device'})")
            continue
        ref = load_resized(ref_path)
        device = load_resized(device_path)
        mae, dx, dy = best_alignment(ref, device)
        ref_image = Image.open(ref_path).convert("RGB").resize((390, 844), Image.Resampling.LANCZOS)
        device_image = Image.open(device_path).convert("RGB").resize((390, 844), Image.Resampling.LANCZOS)
        diff_image = ImageChops.difference(ref_image, device_image).convert("L")
        build_sheet(ref_image, device_image, diff_image, name, mae)
        report_lines.append(f"- {name}: MAE={mae:.2f}/255, best offset=({dx},{dy}), diff=test_run/diff/{name}.png")

    report_lines.append("")
    report_lines.append("Note: device screenshots include the system status bar; reference phone canvas is cropped after a small alignment search.")
    report_path = DIFF_DIR / "diff-report.md"
    report_path.write_text("\n".join(report_lines), encoding="utf-8")
    print(report_path)
    print("\n".join(report_lines))


if __name__ == "__main__":
    main()
