"""Verify the clickable order-progress control.

Covers: initial step -> click each stage -> fill width + active class + stored step ->
survives reload -> cleared storage falls back to step 1.
"""
import json
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

TARGET = Path(sys.argv[1]).resolve()
OUT = Path(sys.argv[2]).resolve()
OUT.mkdir(parents=True, exist_ok=True)

report = {"steps": []}
errors = []

with sync_playwright() as p:
    browser = p.chromium.launch(channel="msedge", headless=True,
                                args=["--hide-scrollbars", "--force-device-scale-factor=1"])
    page = browser.new_page(viewport={"width": 430, "height": 932}, device_scale_factor=2)
    page.on("console", lambda m: errors.append(f"console:{m.type}:{m.text}") if m.type == "error" else None)
    page.on("pageerror", lambda e: errors.append(f"pageerror:{e}"))

    page.goto(TARGET.as_uri())
    page.wait_for_timeout(200)
    page.evaluate("() => { try { localStorage.clear(); } catch (e) {} }")
    page.reload()
    page.wait_for_timeout(300)

    def snapshot():
        return page.evaluate("""() => {
          const fill = document.querySelector('.progress span');
          const stages = [].slice.call(document.querySelectorAll('.stages span'));
          return {
            active_index: stages.findIndex(function (s) { return s.classList.contains('active'); }),
            aria: stages.map(function (s) { return s.getAttribute('aria-selected'); }),
            fill_width: +fill.getBoundingClientRect().width.toFixed(1),
            fill_pct: getComputedStyle(fill).width,
            stored: (function () { try { return localStorage.getItem('order-demo:step'); } catch (e) { return 'ERR'; } })()
          };
        }""")

    report["initial"] = snapshot()
    for i in range(4):
        page.locator(f".stages span[data-step='{i}']").click()
        page.wait_for_timeout(420)
        snap = snapshot()
        snap["clicked"] = i
        # how far the green bar's right end sits from the stage label's right edge
        snap["edge_delta"] = page.evaluate(
            """(i) => {
              const fill = document.querySelector('.progress span').getBoundingClientRect();
              const label = document.querySelectorAll('.stages span')[i].getBoundingClientRect();
              return { fill_right: +fill.right.toFixed(1), label_right: +label.right.toFixed(1),
                       delta: +(fill.right - label.right).toFixed(1) };
            }""", i)
        report["steps"].append(snap)
        if i == 3:
            page.screenshot(path=str(OUT / "progress_step4_430x932.png"))
        if i == 0:
            page.screenshot(path=str(OUT / "progress_step1_430x932.png"))

    page.reload()
    page.wait_for_timeout(320)
    report["after_reload"] = snapshot()

    page.locator(".stages span[data-step='1']").press("Enter")
    page.wait_for_timeout(320)
    report["keyboard_enter_step1"] = snapshot()

    report["doc_scroll_w"] = page.evaluate("() => document.documentElement.scrollWidth")
    report["doc_client_w"] = page.evaluate("() => document.documentElement.clientWidth")
    report["stages_overflow_right"] = page.evaluate(
        "() => { var s = [].slice.call(document.querySelectorAll('.stages span'));"
        " return +(Math.max.apply(null, s.map(function (e) { return e.getBoundingClientRect().right; })) - document.documentElement.clientWidth).toFixed(1); }")

    page.evaluate("() => { try { localStorage.clear(); } catch (e) {} }")
    page.reload()
    page.wait_for_timeout(260)
    report["after_clear"] = snapshot()
    browser.close()

report["console_errors"] = errors
print(json.dumps(report, ensure_ascii=True, indent=1))
