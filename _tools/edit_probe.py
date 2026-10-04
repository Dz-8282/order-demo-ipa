"""Verify in-place editing on the order-detail demo.

Flow: clean state -> not editable -> click -> editable -> type -> blur -> reload -> persisted.
Also captures a screenshot of the focused editing state.
"""
import json
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

TARGET = Path(sys.argv[1]).resolve()
OUT = Path(sys.argv[2]).resolve()
OUT.mkdir(parents=True, exist_ok=True)
TEST_TEXT = "智能手机 Pro Max 512GB 银色"

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

    name = page.locator("#productName")
    price = page.locator(".price")
    report["initial_editable"] = name.get_attribute("contenteditable")
    report["initial_text"] = name.inner_text()
    report["price_editable"] = price.get_attribute("contenteditable")
    report["price_text"] = price.inner_text()
    report["has_edit_button"] = page.locator("#editToggle, .edit-toggle").count()
    report["edit_mode_class"] = page.locator(".edit-mode").count()

    name.click()
    page.wait_for_timeout(120)
    report["after_click_editable"] = name.get_attribute("contenteditable")
    report["after_click_class"] = name.get_attribute("class")
    report["after_click_outline"] = page.evaluate(
        "() => getComputedStyle(document.querySelector('#productName')).outlineColor")
    page.screenshot(path=str(OUT / "editing_state_430x932.png"))

    name.fill(TEST_TEXT)
    page.wait_for_timeout(150)
    report["stored_while_typing"] = page.evaluate(
        "() => { try { return localStorage.getItem('order-demo:productName'); } catch (e) { return 'ERR'; } }")

    page.locator("h1").click()
    page.wait_for_timeout(150)
    report["after_blur_editable"] = name.get_attribute("contenteditable")
    report["after_blur_class"] = name.get_attribute("class")
    report["stored_after_blur"] = page.evaluate(
        "() => { try { return localStorage.getItem('order-demo:productName'); } catch (e) { return 'ERR'; } }")

    page.reload()
    page.wait_for_timeout(250)
    report["text_after_reload"] = page.locator("#productName").inner_text()
    report["persisted"] = report["text_after_reload"] == TEST_TEXT
    report["doc_scroll_w_after_reload"] = page.evaluate("() => document.documentElement.scrollWidth")
    report["doc_client_w_after_reload"] = page.evaluate("() => document.documentElement.clientWidth")

    page.evaluate("() => { try { localStorage.clear(); } catch (e) {} }")
    page.reload()
    page.wait_for_timeout(200)
    report["restored_text"] = page.locator("#productName").inner_text()
    report["addr_line_count"] = page.locator(".address-line").count()
    report["editable_count"] = page.locator(".editable").count()

    # --- delivery row ---
    delivery = page.locator("[data-field='delivery']")
    report["delivery_initial_editable"] = delivery.get_attribute("contenteditable")
    report["delivery_initial_text"] = delivery.inner_text()
    delivery.click()
    page.wait_for_timeout(100)
    report["delivery_after_click_editable"] = delivery.get_attribute("contenteditable")
    report["delivery_after_click_class"] = delivery.get_attribute("class")
    page.screenshot(path=str(OUT / "editing_state_delivery_430x932.png"))
    delivery.fill("周一 2026/09/21 通过 顺丰标快")
    delivery.press("Enter")
    page.wait_for_timeout(120)
    report["delivery_after_enter_editable"] = delivery.get_attribute("contenteditable")
    report["delivery_stored"] = page.evaluate(
        "() => { try { return localStorage.getItem('order-demo:delivery'); } catch (e) { return 'ERR'; } }")
    report["delivery_row_height"] = page.evaluate(
        "() => Math.round(document.querySelector(\"[data-field='delivery']\").closest('.row').getBoundingClientRect().height)")
    page.reload()
    page.wait_for_timeout(200)
    report["delivery_after_reload"] = delivery.inner_text()
    report["delivery_persisted"] = delivery.inner_text() == "周一 2026/09/21 通过 顺丰标快"
    page.evaluate("() => { try { localStorage.clear(); } catch (e) {} }")
    page.reload()
    page.wait_for_timeout(200)
    report["delivery_restored"] = delivery.inner_text()

    # --- order number + payment method rows ---
    for field, new_val in (("orderNo", "W2026092014"), ("payment", "支付宝付款")):
        el = page.locator(f"[data-field='{field}']")
        report[f"{field}_initial"] = el.inner_text()
        report[f"{field}_initial_editable"] = el.get_attribute("contenteditable")
        el.click()
        page.wait_for_timeout(100)
        report[f"{field}_after_click_editable"] = el.get_attribute("contenteditable")
        page.screenshot(path=str(OUT / f"editing_state_{field}_430x932.png"))
        el.fill(new_val)
        el.press("Enter")
        page.wait_for_timeout(100)
        report[f"{field}_stored"] = page.evaluate(
            "() => { try { return localStorage.getItem('order-demo:%s'); } catch (e) { return 'ERR'; } }" % field)
    report["final_editable_count"] = page.locator(".editable").count()
    report["final_store_keys"] = page.evaluate("() => Object.keys(localStorage).sort()")
    report["final_doc_scroll_w"] = page.evaluate("() => document.documentElement.scrollWidth")
    report["final_doc_client_w"] = page.evaluate("() => document.documentElement.clientWidth")
    page.reload()
    page.wait_for_timeout(220)
    report["orderNo_after_reload"] = page.locator("[data-field='orderNo']").inner_text()
    report["payment_after_reload"] = page.locator("[data-field='payment']").inner_text()
    page.evaluate("() => { try { localStorage.clear(); } catch (e) {} }")
    page.reload()
    page.wait_for_timeout(200)
    report["orderNo_restored"] = page.locator("[data-field='orderNo']").inner_text()
    report["payment_restored"] = page.locator("[data-field='payment']").inner_text()
    report["field_catalog"] = page.evaluate(
        "() => [].slice.call(document.querySelectorAll('.editable')).map(function (el) {"
        " return { f: el.getAttribute('data-field'), v: el.textContent.trim(), ce: el.getAttribute('contenteditable') }; })")

    price.click()
    page.wait_for_timeout(120)
    report["price_after_click_editable"] = price.get_attribute("contenteditable")
    report["price_after_click_class"] = price.get_attribute("class")
    price.fill("RMB 12,888")
    price.press("Enter")
    page.wait_for_timeout(150)
    report["price_after_enter_editable"] = price.get_attribute("contenteditable")
    report["store_keys"] = page.evaluate("() => Object.keys(localStorage).sort()")
    report["store_productName"] = page.evaluate(
        "() => { try { return localStorage.getItem('order-demo:productName'); } catch (e) { return 'ERR'; } }")
    report["store_price"] = page.evaluate(
        "() => { try { return localStorage.getItem('order-demo:price'); } catch (e) { return 'ERR'; } }")
    page.reload()
    page.wait_for_timeout(200)
    report["price_text_after_reload"] = price.inner_text()
    report["price_persisted"] = price.inner_text() == "RMB 12,888"

    # --- 5 address lines: each editable and stored under its own key ---
    vals = ["陕西 汉中市西乡县", "城关镇金牛路 88 号", "723500", "电话：138-0000-0000", "邮箱：demo@qq.com"]
    addr_new = []
    for i, val in enumerate(vals, start=1):
        line = page.locator(f".address-line[data-field='addr{i}']")
        line.click()
        page.wait_for_timeout(80)
        if i == 1:
            report["addr1_after_click_editable"] = line.get_attribute("contenteditable")
            report["addr1_after_click_class"] = line.get_attribute("class")
            page.screenshot(path=str(OUT / "editing_state_address_430x932.png"))
        line.fill(val)
        line.press("Enter")
        page.wait_for_timeout(80)
        addr_new.append(line.inner_text())
    report["addr_lines_edited"] = addr_new
    report["addr_stored"] = page.evaluate(
        "() => { var o = {}; for (var i = 1; i <= 5; i++) { o['addr' + i] = localStorage.getItem('order-demo:addr' + i); } return o; }")
    report["all_store_keys"] = page.evaluate("() => Object.keys(localStorage).sort()")
    report["doc_scroll_w_after_all"] = page.evaluate("() => document.documentElement.scrollWidth")
    report["doc_client_w_after_all"] = page.evaluate("() => document.documentElement.clientWidth")
    report["address_height"] = page.evaluate("() => Math.round(document.querySelector('.address').getBoundingClientRect().height)")

    page.reload()
    page.wait_for_timeout(250)
    addr_reload = [page.locator(f".address-line[data-field='addr{i}']").inner_text() for i in range(1, 6)]
    report["addr_after_reload"] = addr_reload
    report["addr_persisted"] = addr_reload == vals
    report["addr_editable_after_reload"] = page.evaluate(
        "() => document.querySelectorAll(\".address-line[contenteditable='true']\").length")

    page.evaluate("() => { try { localStorage.clear(); } catch (e) {} }")
    page.reload()
    page.wait_for_timeout(200)
    report["price_restored"] = price.inner_text()
    addr_restored = [page.locator(f".address-line[data-field='addr{i}']").inner_text() for i in range(1, 6)]
    report["addr_restored"] = addr_restored
    report["product_name_restored"] = page.evaluate(
        "() => { var el = document.querySelector('#productName'); return el ? el.textContent : null; }")
    browser.close()

report["console_errors"] = errors
print(json.dumps(report, ensure_ascii=True, indent=1))
