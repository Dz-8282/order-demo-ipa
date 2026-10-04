"""Verify image upload on the product photo slot.

Covers: click -> file chooser -> compressed dataURL stored -> survives reload ->
double click restores the default SVG. Leaves no test image behind.
"""
import json
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

TARGET = Path(sys.argv[1]).resolve()
OUT = Path(sys.argv[2]).resolve()
OUT.mkdir(parents=True, exist_ok=True)
ART = OUT / "upload_test_source.png"

from PIL import Image

Image.new("RGB", (600, 800), (214, 58, 48)).save(ART)

report = {}
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
    page.wait_for_timeout(200)

    report["initial_has_svg"] = page.locator("#deviceSlot svg").count()
    report["initial_has_img"] = page.locator("#deviceSlot img").count()

    with page.expect_file_chooser() as fc:
        page.locator("#deviceSlot").click()
    fc.value.set_files(str(ART))
    page.wait_for_timeout(700)

    report["after_upload_img"] = page.locator("#deviceSlot img").count()
    report["after_upload_class"] = page.locator("#deviceSlot").get_attribute("class")
    report["after_upload_src_prefix"] = page.evaluate(
        "() => { var i = document.querySelector('#deviceSlot img'); return i ? i.src.slice(0, 22) : null; }")
    report["after_upload_src_len"] = page.evaluate(
        "() => { var i = document.querySelector('#deviceSlot img'); return i ? i.src.length : 0; }")
    report["after_upload_stored_len"] = page.evaluate(
        "() => { try { return (localStorage.getItem('order-demo:photo') || '').length; } catch (e) { return 'ERR'; } }")
    report["after_upload_photo_key"] = page.evaluate(
        "() => Object.keys(localStorage).filter(function (k) { return k === 'order-demo:photo'; }).length")
    page.screenshot(path=str(OUT / "uploaded_product_430x932.png"))

    page.reload()
    page.wait_for_timeout(300)
    report["reload_img"] = page.locator("#deviceSlot img").count()
    report["reload_src_len"] = page.evaluate(
        "() => { var i = document.querySelector('#deviceSlot img'); return i ? i.src.length : 0; }")

    page.locator("#deviceSlot").dblclick()
    page.wait_for_timeout(400)
    report["after_dblclick_img"] = page.locator("#deviceSlot img").count()
    report["after_dblclick_svg"] = page.locator("#deviceSlot svg").count()
    report["after_dblclick_key"] = page.evaluate(
        "() => { try { return localStorage.getItem('order-demo:photo'); } catch (e) { return 'ERR'; } }")

    report["doc_scroll_w"] = page.evaluate("() => document.documentElement.scrollWidth")
    report["doc_client_w"] = page.evaluate("() => document.documentElement.clientWidth")

    # dataURL stored without leading prefix check + compression ratio
    page.evaluate("() => { try { localStorage.clear(); } catch (e) {} }")
    browser.close()

report["console_errors"] = errors
ART.unlink(missing_ok=True)
print(json.dumps(report, ensure_ascii=True, indent=1))
