#!/usr/bin/env python3
"""Dump cookbook PDF pages as column-aware text, list page titles, or render page images.

Uses PyMuPDF (pip install pymupdf), which keeps Unicode fractions (½ ⅓ ¾) and
handles two-column layouts far better than pdftotext.

Examples:
  python pdf_pages.py book.pdf --titles                     # one line per page: biggest text
  python pdf_pages.py book.pdf --pages 20-35 -o p20-35.txt  # column-aware text dump
  python pdf_pages.py book.pdf --pages 22 --render imgs/    # PNG of page 22 to check by eye
  python pdf_pages.py book.pdf --grep "Makes|Per serving"   # pages matching a regex

Page numbers are 1-based PDF page numbers (not the book's printed numbers).

Text dump format:
  ===== PAGE 22  (612x792 pt)
  --- column 1  x 36-290
  [ 36, 102] ## Sample Turkey Chili        <- "##" = bold line, sizes shown for big text
  [ 36, 140]    450g (16oz) ground turkey
Lines are grouped into columns by finding vertical gutters with no text, then
sorted top-to-bottom inside each column. Unmappable glyphs are shown as
<?FontName> so you know to check the page image.
"""
import argparse
import re
import sys

try:
    import pymupdf  # PyMuPDF >= 1.24
except ImportError:  # older installs
    try:
        import fitz as pymupdf
    except ImportError:
        sys.exit("PyMuPDF is not installed: pip install pymupdf")


def parse_pages(spec, n):
    if not spec:
        return list(range(1, n + 1))
    out = []
    for part in spec.split(","):
        part = part.strip()
        if "-" in part:
            a, b = part.split("-", 1)
            a = int(a) if a else 1
            b = int(b) if b else n
            out.extend(range(a, b + 1))
        elif part:
            out.append(int(part))
    return [p for p in out if 1 <= p <= n]


def page_lines(page):
    """Return [(x0, y0, x1, y1, text, bold, size)] for every non-empty line."""
    lines = []
    for b in page.get_text("dict")["blocks"]:
        for l in b.get("lines", []):
            parts, bold, size = [], False, 0.0
            for sp in l["spans"]:
                t = sp["text"].replace("�", f"<?{sp['font']}>")
                parts.append(t)
                if t.strip():
                    bold = bold or "bold" in sp["font"].lower() or bool(sp["flags"] & 16)
                    size = max(size, sp["size"])
            text = re.sub(r"\s+", " ", "".join(parts)).strip()
            if text:
                x0, y0, x1, y1 = l["bbox"]
                lines.append((x0, y0, x1, y1, text, bold, size))
    return lines


def split_columns(lines, width, min_gap=12.0):
    """Find x ranges with no text (ignoring full-width lines) and split there."""
    narrow = [ln for ln in lines if (ln[2] - ln[0]) < 0.6 * width]
    if not narrow:
        return [(0.0, width, sorted(lines, key=lambda t: (round(t[1]), t[0])))]
    spans = sorted((ln[0], ln[2]) for ln in narrow)
    merged = [list(spans[0])]
    for a, b in spans[1:]:
        if a <= merged[-1][1] + min_gap:
            merged[-1][1] = max(merged[-1][1], b)
        else:
            merged.append([a, b])
    cols = []
    for i, (a, b) in enumerate(merged):
        lo = a if i else 0.0
        hi = merged[i + 1][0] if i + 1 < len(merged) else width
        cols.append((lo, hi, []))
    for ln in lines:
        cx = ln[0] if (ln[2] - ln[0]) >= 0.6 * width else (ln[0] + ln[2]) / 2
        for lo, hi, bucket in cols:
            if lo <= cx < hi or (hi == width and cx >= lo):
                bucket.append(ln)
                break
        else:
            cols[0][2].append(ln)
    return [(lo, hi, sorted(b, key=lambda t: (round(t[1]), t[0]))) for lo, hi, b in cols if b]


def dump_page(page, pno, out, coords=True):
    w, h = page.rect.width, page.rect.height
    out.write(f"\n===== PAGE {pno}  ({w:.0f}x{h:.0f} pt)\n")
    lines = page_lines(page)
    if not lines:
        out.write("(no text layer: scanned page, read the page image instead; use --render)\n")
        return
    body = sorted(ln[6] for ln in lines)[len(lines) // 2]  # median font size
    for i, (lo, hi, col) in enumerate(split_columns(lines, w), 1):
        out.write(f"--- column {i}  x {lo:.0f}-{hi:.0f}\n")
        for x0, y0, x1, y1, text, bold, size in col:
            mark = "## " if bold else "   "
            big = f" (size {size:.0f})" if size >= body * 1.4 else ""
            pos = f"[{x0:4.0f},{y0:4.0f}] " if coords else ""
            out.write(f"{pos}{mark}{text}{big}\n")


def main():
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("pdf")
    ap.add_argument("--pages", help="e.g. 5-9,12,40- (1-based PDF pages; default all)")
    ap.add_argument("-o", "--out", help="write here instead of stdout (UTF-8)")
    ap.add_argument("--titles", action="store_true", help="list each page's largest text line")
    ap.add_argument("--grep", metavar="REGEX", help="list pages whose text matches REGEX (case-insensitive)")
    ap.add_argument("--render", metavar="DIR", help="save PNGs of the pages to DIR")
    ap.add_argument("--dpi", type=int, default=110, help="render resolution (default 110)")
    ap.add_argument("--no-coords", action="store_true", help="omit [x,y] prefixes")
    a = ap.parse_args()

    try:
        doc = pymupdf.open(a.pdf)
    except Exception as e:
        ap.error(f"can't open {a.pdf}: {e}")
    try:
        pages = parse_pages(a.pages, doc.page_count)
    except ValueError:
        ap.error(f"bad --pages {a.pages!r}; use e.g. 5-9,12,40-")
    if not pages:
        ap.error(f"no pages selected; the PDF has {doc.page_count} pages")
    if a.grep:
        try:
            rx = re.compile(a.grep, re.I)
        except re.error as e:
            ap.error(f"bad --grep regex: {e}")
    out = open(a.out, "w", encoding="utf-8") if a.out else sys.stdout
    try:
        if a.render:
            import os
            os.makedirs(a.render, exist_ok=True)
            for p in pages:
                path = os.path.join(a.render, f"page-{p:04d}.png")
                doc[p - 1].get_pixmap(dpi=a.dpi).save(path)
                out.write(path + "\n")
        elif a.titles:
            for p in pages:
                lines = page_lines(doc[p - 1])
                top = max(lines, key=lambda t: (round(t[6]), -t[1]))[4] if lines else "(no text)"
                out.write(f"{p:4d}  {top}\n")
        elif a.grep:
            for p in pages:
                hits = [ln[4] for ln in page_lines(doc[p - 1]) if rx.search(ln[4])]
                if hits:
                    out.write(f"{p:4d}  " + " | ".join(hits)[:200] + "\n")
        else:
            for p in pages:
                dump_page(doc[p - 1], p, out, coords=not a.no_coords)
    finally:
        if out is not sys.stdout:
            out.close()


if __name__ == "__main__":
    main()
