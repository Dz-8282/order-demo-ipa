"""Render the order-detail demo in real Edge (Playwright) and measure overflow.

Checks performed per viewport:
  1. status bar node count (must be 0 after removal)
  2. documentElement.scrollWidth vs clientWidth (horizontal overflow)
  3. .stages label positions vs container bounds
  4. .bottom nav item positions vs container bounds
  5. every section box, for a full-page overlap/overflow scan
"""
import json
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

TARGET = Path(sys.argv[1]).resolve()
OUT = Path(sys.argv[2]).resolve()
VIEWPORTS = [(430, 932), (768, 1024), (1280, 900)]

PROBE = """
() => {
  const q = (s) => document.querySelector(s);
  const r = (el) => el ? { x: +el.getBoundingClientRect().x.toFixed(1),
                           w: +el.getBoundingClientRect().width.toFixed(1),
                           r: +el.getBoundingClientRect().right.toFixed(1) } : null;

  // --- bottom-nav icon geometry: real drawn extent (viewBox units == px, since svg is 22x22 with viewBox 0 0 24 24 ? scale=0.9167) ---
  const tabs = [...document.querySelectorAll('.bottom .tab')];
  const icons = tabs.map((t) => {
    const label = [...t.childNodes].filter(n => n.nodeType === 3).map(n => n.textContent.trim()).join('');
    const svg = t.querySelector('svg');
    if (!svg) {
      const s = t.querySelector('.search');
      const box = s.getBoundingClientRect();
      return { label, kind: 'search', w: +box.width.toFixed(1), h: +box.height.toFixed(1), scale: 1 };
    }
    const scale = svg.getBoundingClientRect().width / 24;
    const nums = (d) => (d.match(/-?\\d+(?:\\.\\d+)?/g) || []).map(Number);
    let minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9;
    const acc = (x, y) => { minX = Math.min(minX, x); maxX = Math.max(maxX, x); minY = Math.min(minY, y); maxY = Math.max(maxY, y); };
    return { label, kind: 'svg', scale: +scale.toFixed(4), drawn: (() => {
      svg.querySelectorAll('rect').forEach(el => {
        const x = +el.getAttribute('x'), y = +el.getAttribute('y');
        acc(x, y); acc(x + +el.getAttribute('width'), y + +el.getAttribute('height'));
      });
      svg.querySelectorAll('circle').forEach(el => {
        const cx = +el.getAttribute('cx'), cy = +el.getAttribute('cy'), rr = +el.getAttribute('r');
        acc(cx - rr, cy - rr); acc(cx + rr, cy + rr);
      });
      svg.querySelectorAll('path').forEach(el => {
        nums(el.getAttribute('d')).forEach((v, i, a) => {
          if (i > 0 && i % 2 === 0) acc(v, a[i + 1]);   // pair up coordinates
        });
      });
      return { x: [minX, maxX], y: [minY, maxY],
               w: +((maxX - minX) * scale).toFixed(2), h: +((maxY - minY) * scale).toFixed(2),
               stroke_w: +(el0Stroke(svg) * scale).toFixed(2) };
    })() };
  });

  function el0Stroke(svg) { return parseFloat(getComputedStyle(svg).strokeWidth) || 0; }

  const stages = [...document.querySelectorAll('.stages span')].map(r);
  const rows = [...document.querySelectorAll('.row')].map(el => ({ k: el.textContent.slice(0, 4), x: +el.getBoundingClientRect().x.toFixed(1),
    bottom: +el.getBoundingClientRect().bottom.toFixed(1), w: +el.getBoundingClientRect().width.toFixed(1) }));
  return {
    statusbar_nodes: document.querySelectorAll('.statusbar, .status-right, .signal, .wifi, .battery').length,
    doc_scroll_w: document.documentElement.scrollWidth,
    doc_client_w: document.documentElement.clientWidth,
    doc_h: document.documentElement.scrollHeight,
    scroll_y: window.scrollY,
    address_box: r(q('.address')),
    address_lines: [...document.querySelectorAll('.address-content, .address-content *')].length,
    rows: rows,
    sheet_bottom: +q('.sheet').getBoundingClientRect().bottom.toFixed(1),
    sheet: r(q('.sheet')),
    stages_items: stages,
    stages_overflow_right: stages.length ? Math.max(...stages.map(s => s.r)) - document.documentElement.clientWidth : 0,
    bottom: r(q('.bottom')),
    bottom_top: +q('.bottom').getBoundingClientRect().top.toFixed(1),
    tabs_box: tabs.map(r),
    tabs_overflow_right: tabs.length ? Math.max(...tabs.map(t => t.getBoundingClientRect().right)) - document.documentElement.clientWidth : 0,
    icons: icons
  };
}
"""

OUT.mkdir(parents=True, exist_ok=True)
report = []
with sync_playwright() as p:
    browser = p.chromium.launch(channel="msedge", headless=True,
                                args=["--hide-scrollbars", "--force-device-scale-factor=1"])
    for w, h in VIEWPORTS:
        page = browser.new_page(viewport={"width": w, "height": h}, device_scale_factor=2)
        page.goto(TARGET.as_uri())
        page.wait_for_timeout(250)
        page.evaluate("window.scrollTo(0, document.documentElement.scrollHeight)")
        page.wait_for_timeout(250)
        data = page.evaluate(PROBE)
        data["viewport"] = f"{w}x{h}"
        data["severe_overflow_x"] = data["doc_scroll_w"] - data["doc_client_w"]
        report.append(data)
        page.screenshot(path=str(OUT / f"render_{w}x{h}.png"), full_page=True)
        page.close()
    browser.close()

print(json.dumps(report, ensure_ascii=True, indent=1))
