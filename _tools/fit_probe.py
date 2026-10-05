"""Measure every section at real iPhone sizes so the page fits one screen."""
import json
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

TARGET = Path(r"C:\Users\Administrator\Desktop\zhuabaio\apple_order_layout_demo.html")
OUT = Path(r"C:\Users\Administrator\Desktop\zhuabaio\_verify")

PROBE = """
() => {
  const h = (sel) => {
    const el = document.querySelector(sel);
    if (!el) return null;
    const b = el.getBoundingClientRect();
    return { top: +b.top.toFixed(1), h: +b.height.toFixed(1), bottom: +b.bottom.toFixed(1), w: +b.width.toFixed(1), x: +b.x.toFixed(1) };
  };
  return {
    viewport: window.innerHeight,
    doc_scrollH: document.documentElement.scrollHeight,
    doc_clientH: document.documentElement.clientHeight,
    doc_scrollW: document.documentElement.scrollWidth,
    doc_clientW: document.documentElement.clientWidth,
    sheet: h('.sheet'),
    header: h('.header'),
    product: h('.product'),
    ship: h('.ship'),
    address: h('.address'),
    payment_title: h('.payment-title'),
    rows: [].slice.call(document.querySelectorAll('.row')).map(function (el) {
      const b = el.getBoundingClientRect();
      return { label: el.textContent.slice(0, 3), h: +b.height.toFixed(1), bottom: +b.bottom.toFixed(1) };
    }),
    bottom_nav: h('.bottom'),
    overflow: document.documentElement.scrollHeight - document.documentElement.clientHeight
  };
}
"""

report = {}
with sync_playwright() as p:
    browser = p.chromium.launch(channel="msedge", headless=True,
                                args=["--hide-scrollbars", "--force-device-scale-factor=1"])
    for w, h in ((375, 812), (393, 852), (430, 932)):
        page = browser.new_page(viewport={"width": w, "height": h}, device_scale_factor=2)
        page.goto(TARGET.as_uri())
        page.wait_for_timeout(350)
        report[f"{w}x{h}"] = page.evaluate(PROBE)
        page.screenshot(path=str(OUT / f"fit_{w}x{h}.png"), full_page=True)
        page.close()
    browser.close()

print(json.dumps(report, ensure_ascii=True, indent=1))
