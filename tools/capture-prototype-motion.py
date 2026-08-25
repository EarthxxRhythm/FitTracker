import subprocess
import importlib.util
from pathlib import Path


def _load_render_module():
    spec = importlib.util.spec_from_file_location(
        "render_prototype_phone",
        Path(__file__).parent / "render-prototype-phone.py",
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


rp = _load_render_module()


OUTPUT_DIR = Path(r"D:\.CodeSpace\.DevEcoStudioProjects\FitTracker\test_run\prototype-motion")
WRAPPER_DIR = Path(r"D:\.CodeSpace\.DevEcoStudioProjects\FitTracker\test_run\prototype-wrappers-motion")

# Force the primary CTA into its pressed scale so the "pressed" reference frame is deterministic.
PRESSED_CSS = (
    "<style>"
    "[class*='btn-primary'], .cf-btn-primary, .auth-cta, .wo-btn-primary, .pv-btn-primary "
    "{ transform: scale(.985) !important; }"
    "</style>"
)

# Pause every running CSS animation at ~50% of its duration to freeze a representative mid-frame.
MID_SCRIPT = (
    "<script>(function(){"
    "function half(){"
    "var as=document.getAnimations?document.getAnimations():[];"
    "for(var i=0;i<as.length;i++){try{"
    "var a=as[i];var t=(a.effect&&a.effect.getTiming)?a.effect.getTiming():null;"
    "var d=(t&&typeof t.duration==='number'&&t.duration>0)?t.duration:1000;"
    "a.pause();a.currentTime=d*0.5;"
    "}catch(e){}}"
    "}"
    "if(document.readyState==='complete'){half();}else{window.addEventListener('load',function(){setTimeout(half,60);});}"
    "})();</script>"
)


def inject_before_body(wrapper: str, extra: str) -> str:
    marker = "</body>"
    return wrapper.replace(marker, extra + marker)


def capture(url: str, output: Path) -> None:
    subprocess.run(
        [
            rp.CHROME,
            "--headless=new",
            "--disable-gpu",
            "--hide-scrollbars",
            "--force-device-scale-factor=1",
            "--window-size=390,844",
            "--virtual-time-budget=1200",
            f"--screenshot={output}",
            url,
        ],
        check=True,
        capture_output=True,
        timeout=60,
    )


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    WRAPPER_DIR.mkdir(parents=True, exist_ok=True)
    results = []
    for name, (file_name, phone_index) in rp.MAPPING.items():
        if phone_index is None:
            results.append((name, "no-phone"))
            continue
        source = rp.SOURCE_ROOT / file_name
        if not source.exists():
            results.append((name, "missing-source"))
            continue
        wrapper = rp.build_wrapper(source, phone_index)

        pressed_html = inject_before_body(wrapper, PRESSED_CSS)
        pressed_path = WRAPPER_DIR / f"{name}-pressed.html"
        pressed_path.write_text(pressed_html, encoding="utf-8")
        pressed_out = OUTPUT_DIR / f"{name}-pressed.png"
        capture(pressed_path.as_uri(), pressed_out)

        mid_html = inject_before_body(wrapper, MID_SCRIPT)
        mid_path = WRAPPER_DIR / f"{name}-mid.html"
        mid_path.write_text(mid_html, encoding="utf-8")
        mid_out = OUTPUT_DIR / f"{name}-mid.png"
        capture(mid_path.as_uri(), mid_out)

        results.append((name, f"pressed={pressed_out.name} mid={mid_out.name}"))

    for name, value in results:
        print(f"{name}\t{value}")


if __name__ == "__main__":
    main()
