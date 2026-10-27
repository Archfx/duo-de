#!/usr/bin/env python3
"""hinge_lint: list UI elements that overlap the Surface Duo hinge.

Dumps the visible window hierarchy with `uiautomator dump` (plus an optional screenshot) from a connected device and
reports every node whose bounds intersect the hinge rectangle. Containers that merely span both panels are ignored; a
node is reported when it is a leaf, or carries text / a content description, or is clickable (that is, something the
user sees or touches).

  hinge_lint.py                   # current screen, spanned or not, report on stdout
  hinge_lint.py --shot out.png    # also save a screenshot with the hinge band and the offenders outlined
  hinge_lint.py --label shade     # name the capture; with --out DIR writes DIR/shade.{xml,json,png}
  hinge_lint.py --pkg com.android.systemui --pkg com.android.launcher3   # only these packages
  hinge_lint.py --xml dump.xml --width 2754 --height 1892                # offline, no device

Exit status: 0 = clean, 1 = overlaps found, 2 = tool/device error. Geometry (Duo 2): panel 1344 px, hinge 66 px
(x 1344..1410 of 2754); gapless (persist.sys.phh.duo.disable_hinge=1): 2688 wide, no hinge band, so there is nothing to
report. A single-panel display (1344 wide) has no hinge either.
"""
import argparse, json, os, re, subprocess, sys
import xml.etree.ElementTree as ET

PANEL, HINGE, HEIGHT = 1344, 66, 1892  # Surface Duo 2 natural portrait-pair geometry, display rotation 0
BOUNDS = re.compile(r"\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]")


def adb(*args, binary=False):
    r = subprocess.run(["adb", *args], capture_output=True)
    if r.returncode:
        sys.exit(f"adb {' '.join(args)}: {r.stderr.decode(errors='replace').strip()}")
    return r.stdout if binary else r.stdout.decode(errors="replace")


def display_size():
    m = re.search(r"Physical size: (\d+)x(\d+)", adb("shell", "wm", "size"))
    o = re.search(r"Override size: (\d+)x(\d+)", adb("shell", "wm", "size"))
    w, h = map(int, (o or m).groups())
    return w, h


def hinge_rect(width, height):
    """Hinge band in current-display pixels, or None when there is none to overlap."""
    if width == 2 * PANEL + HINGE and height == HEIGHT:        # spanned, rotation 0
        return (PANEL, 0, PANEL + HINGE, height)
    if height == 2 * PANEL + HINGE and width == HEIGHT:        # spanned, rotated 90/270
        return (0, PANEL, width, PANEL + HINGE)
    return None                                                # single panel or gapless


def parse(xml_text):
    root = ET.fromstring(xml_text)
    for node in root.iter("node"):
        m = BOUNDS.fullmatch(node.get("bounds", ""))
        if not m:
            continue
        l, t, r, b = map(int, m.groups())
        yield node, (l, t, r, b)


def intersects(a, h):
    return a[0] < h[2] and a[2] > h[0] and a[1] < h[3] and a[3] > h[1]


def lint(xml_text, hinge, pkgs):
    hits = []
    for node, box in parse(xml_text):
        pkg = node.get("package", "")
        if pkgs and pkg not in pkgs:
            continue
        if box[2] <= box[0] or box[3] <= box[1] or not intersects(box, hinge):
            continue
        text = node.get("text") or node.get("content-desc")
        horizontal = hinge[3] - hinge[1] > hinge[2] - hinge[0]
        spans = (box[0] <= hinge[0] and box[2] >= hinge[2]) if horizontal else (box[1] <= hinge[1] and box[3] >= hinge[3])
        if spans and not text:      # a backdrop, scrim or container laid across both panels: fine
            continue
        leaf = len(node) == 0
        visible = node.get("text") or node.get("content-desc") or node.get("clickable") == "true"
        if not (leaf or visible):
            continue
        hits.append({
            "package": pkg, "class": node.get("class", ""), "id": node.get("resource-id", ""),
            "text": (node.get("text") or node.get("content-desc") or "")[:60],
            "bounds": list(box), "clickable": node.get("clickable") == "true",
            "inside_hinge": box[0] >= hinge[0] and box[2] <= hinge[2] and box[1] >= hinge[1] and box[3] <= hinge[3],
        })
    return hits


def annotate(png, hinge, hits, out):
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        open(out, "wb").write(png)
        print("(Pillow not installed: saved the plain screenshot)", file=sys.stderr)
        return
    import io
    im = Image.open(io.BytesIO(png)).convert("RGB")
    d = ImageDraw.Draw(im, "RGBA")
    d.rectangle(hinge, fill=(255, 0, 0, 60))
    for h in hits:
        d.rectangle(h["bounds"], outline=(255, 160, 0, 255), width=4)
    im.save(out)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pkg", action="append", help="only report nodes of this package (repeatable)")
    ap.add_argument("--xml", help="lint an existing uiautomator dump instead of the device")
    ap.add_argument("--width", type=int); ap.add_argument("--height", type=int)
    ap.add_argument("--shot", help="save an annotated screenshot here")
    ap.add_argument("--out", help="directory for dump, json and screenshot (with --label)")
    ap.add_argument("--label", default="capture")
    ap.add_argument("--json", action="store_true", help="machine readable output")
    a = ap.parse_args()

    if a.xml:
        xml_text = open(a.xml, encoding="utf-8").read()
        if not (a.width and a.height):
            sys.exit("--xml needs --width and --height")
        w, h = a.width, a.height
    else:
        w, h = display_size()
        adb("shell", "uiautomator", "dump", "/sdcard/hinge_lint.xml")
        xml_text = adb("exec-out", "cat", "/sdcard/hinge_lint.xml")
    hinge = hinge_rect(w, h)
    if hinge is None:
        print(f"display {w}x{h}: single panel or gapless, there is no hinge band to overlap")
        return 0
    hits = lint(xml_text, hinge, set(a.pkg or []))

    shot = a.shot
    if a.out:
        os.makedirs(a.out, exist_ok=True)
        open(os.path.join(a.out, a.label + ".xml"), "w", encoding="utf-8").write(xml_text)
        json.dump({"display": [w, h], "hinge": hinge, "hits": hits},
                  open(os.path.join(a.out, a.label + ".json"), "w"), indent=1)
        shot = shot or os.path.join(a.out, a.label + ".png")
    if shot and not a.xml:
        annotate(adb("exec-out", "screencap", "-p", binary=True), hinge, hits, shot)

    if a.json:
        print(json.dumps({"display": [w, h], "hinge": hinge, "hits": hits}, indent=1))
    else:
        print(f"display {w}x{h}, hinge band {hinge}: {len(hits)} overlap(s)")
        for h_ in hits:
            tag = "IN-HINGE" if h_["inside_hinge"] else "CROSSES "
            print(f"  {tag} {h_['package']} {h_['class'].split('.')[-1]:<22} {h_['bounds']} "
                  f"{'clickable ' if h_['clickable'] else ''}{h_['id'].split('/')[-1]} {h_['text']!r}")
    return 1 if hits else 0


if __name__ == "__main__":
    sys.exit(main())
