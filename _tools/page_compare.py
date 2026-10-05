"""Compare the two page implementations at a real iPhone size."""
import json
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(r"C:\Users\Administrator\Desktop\zhuabaio")
OUT = ROOT / "_verify"
OUT.mkdir(exist_ok=True)

PROBE = """
() => {
  const r = (sel) => {
    const el = document.querySelector(sel);
    if (!el) return null;
    const b = el.getBoundingClientRect();
    return { x: +b.x.toFixed(1), w: +b.width.toFixed(1), right: +b.right.toFixed(1),
             top: +b.top.toFixed(1), bottom: +b.bottom.toFixed(1), h: +b.height.toFixed(1) };
  };
  const cs = (sel, prop) => {
    const el = document.querySelector(sel);
    return el ? getComputedStyle(el)[prop] : null;
  };
  return {
    viewport: { w: window.innerWidth, h: window.innerHeight },
    doc: { scrollW: document.documentElement.scrollWidth, clientW: document.documentElement.clientWidth,
           scrollH: document.documentElement.scrollHeight, clientH: document.documentElement.clientHeight },
    body_bg: cs('body', 'backgroundColor'),
    sheet: r('.sheet') || r('#detail') || r('.panel') || r('main'),
    all_top_level: [].slice.call(document.body.children).map(function (el) {
      const b = el.getBoundingClientRect();
      return { tag: el.tagName.toLowerCase() + (el.className ? '.' + String(el.className).split(' ')[0] : ''),
               w: +b.width.toFixed(1), h: +b.height.toFixed(1), x: +b.x.toFixed(1) };
    }),
    horizontal_overflow: document.documentElement.scrollWidth - document.documentElement.clientWidth,
    vertical_overflow: document.documentElement.scrollHeight - document.documentElement.clientHeight
  };
}
"""

report = {}
with sync_playwright() as p:
    browser = p.chromium.launch(channel="msedge", headless=True,
                                args=["--hide-scrollbars", "--force-device-scale-factor=1"])
    for name in ("apple_order_layout_demo.html", "order-detail.html"):
        target = ROOT / name
        if not target.exists():
            report[name] = "missing"
            continue
        page = browser.new_page(viewport={"width": 393, "height": 852}, device_scale_factor=2)
        page.goto(target.as_uri())
        page.wait_for_timeout(400)
        report[name] = page.evaluate(PROBE)
        page.screenshot(path=str(OUT / f"cmp_{target.stem}_393x852.png"), full_page=True)
        page.close()
    browser.close()

print(json.dumps(report, ensure_ascii=True, indent=1))
