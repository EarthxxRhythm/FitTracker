import os
import subprocess
import sys
from pathlib import Path

from lxml import html

CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

SOURCE_ROOT = Path(r"C:\Users\19308\AppData\Roaming\Open Design\namespaces\release-stable-win\data\projects\56d6b0af-ac55-498d-9942-c02a4d35cc71")
OUTPUT_DIR = Path(r"D:\.CodeSpace\.DevEcoStudioProjects\FitTracker\test_run\prototype-phone")
WRAPPER_DIR = Path(r"D:\.CodeSpace\.DevEcoStudioProjects\FitTracker\test_run\prototype-wrappers")

MAPPING = {
    "welcome-home": ("fittracker-welcome-home.html", 0),
    "auth": ("fittracker-auth.html", 1),
    "plan": ("fittracker-plan.html", 0),
    "training-preview": ("fittracker-training-preview.html", 0),
    "training": ("fittracker-training.html", 0),
    "training-complete": ("fittracker-training-complete.html", 0),
    "review": ("fittracker-review.html", 0),
    "personal": ("fittracker-personal.html", 0),
    "brand-identity": ("fittracker-brand-identity.html", None),
}


def build_wrapper(source_path: Path, phone_index):
    document = html.parse(str(source_path))
    root = document.getroot()

    style_text = "\n".join(
        element.text or ""
        for element in root.xpath("//style")
    )
    script_text = "\n".join(
        element.text or ""
        for element in root.xpath("//script")
    )
    defs_text = "\n".join(
        html.tostring(element, encoding="unicode")
        for element in root.xpath("//svg[contains(@class,'defs') or contains(@id,'defs')]")
    )

    phones = root.xpath("//div[contains(concat(' ', normalize-space(@class), ' '), ' phone ')]")
    if phone_index is None or not phones:
        return None
    selected = phones[min(phone_index, len(phones) - 1)]
    phone_text = html.tostring(selected, encoding="unicode")

    wrapper = (
        "<!doctype html><html lang=\"zh-CN\"><head><meta charset=\"utf-8\"/>"
        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"/>"
        "<style>html,body{margin:0;padding:0;background:#000;}body{overflow:hidden;}</style>"
        "<style>" + style_text + "</style>"
        "</head><body>"
        + defs_text
        + phone_text
        + "<script>" + script_text + "</script>"
        + "</body></html>"
    )
    return wrapper


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    WRAPPER_DIR.mkdir(parents=True, exist_ok=True)
    produced = []

    for name, (file_name, phone_index) in MAPPING.items():
        source_path = SOURCE_ROOT / file_name
        if not source_path.exists():
            produced.append((name, "missing-source"))
            continue
        if phone_index is None:
            produced.append((name, "no-phone"))
            continue

        wrapper = build_wrapper(source_path, phone_index)
        wrapper_path = WRAPPER_DIR / f"{name}.html"
        wrapper_path.write_text(wrapper, encoding="utf-8")

        output_path = OUTPUT_DIR / f"{name}.png"
        url = wrapper_path.as_uri()
        subprocess.run(
            [
                CHROME,
                "--headless=new",
                "--disable-gpu",
                "--hide-scrollbars",
                "--force-device-scale-factor=1",
                "--window-size=390,844",
                f"--screenshot={output_path}",
                url,
            ],
            check=True,
            capture_output=True,
            timeout=60,
        )
        produced.append((name, str(output_path)))

    for name, value in produced:
        print(f"{name}\t{value}")


if __name__ == "__main__":
    main()
