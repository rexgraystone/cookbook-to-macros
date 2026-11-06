"""Record one recipe's MyFitnessPal result.

usage: python3 record-result.py <book> <file.md> <status> "<NNN cal · NNP · NNC · NNF>" "<note or ''>" <entry.md> [--root DIR] [--force]

Sets the recipe's Status and "MFP per serving" cells in recipes/<book>/INDEX.md
(the note is appended after " — ") and appends "## MFP entry" plus the
contents of <entry.md> to recipes/<book>/<file.md>. Run once per recipe.

Status is checked strictly against the INDEX's "Book per serving" calories:
"done" is refused when MFP differs by more than 10%, and "flagged" needs a
note. --force skips the check. --root is the project folder (default: the
current directory). On Windows, Git Bash paths like /c/... are accepted.
"""
import io
import os
import re
import sys


def winpath(p):
    m = re.match(r'^/([a-zA-Z])/(.*)$', p)
    return f"{m.group(1)}:/{m.group(2)}" if os.name == 'nt' and m else p


def kcal(s):
    m = re.search(r'([\d,]+)\s*cal', s)
    return int(m.group(1).replace(',', '')) if m else None


def main(argv):
    for stream in (sys.stdout, sys.stderr):
        stream.reconfigure(encoding='utf-8', errors='replace')
    if '-h' in argv or '--help' in argv:
        print(__doc__); return
    force = '--force' in argv
    argv = [a for a in argv if a != '--force']
    root = '.'
    if '--root' in argv:
        i = argv.index('--root'); root = winpath(argv[i + 1]); del argv[i:i + 2]
    if len(argv) != 6:
        sys.exit(__doc__)
    book, fn, status, mfp, note, entry = argv
    if status not in ('done', 'flagged', 'skipped', 'todo'):
        sys.exit(f"unknown status: {status}")
    folder = os.path.join(winpath(root), 'recipes', book)
    idx = os.path.join(folder, 'INDEX.md')
    lines = io.open(idx, encoding='utf-8').read().split('\n')

    header = next((l for l in lines if l.startswith('|') and 'Status' in l), None)
    if header is None:
        sys.exit("no table header with a Status column in INDEX.md")
    cols = [c.strip() for c in header.strip().strip('|').split('|')]
    try:
        c_status, c_mfp = cols.index('Status'), cols.index('MFP per serving')
    except ValueError:
        sys.exit(f"INDEX.md columns not recognised: {cols}")
    c_book = cols.index('Book per serving') if 'Book per serving' in cols else None

    hits = [i for i, l in enumerate(lines) if l.startswith(f'| [{fn}]') or l.startswith(f'| {fn} ')]
    if len(hits) != 1:
        sys.exit(f"expected one INDEX row for {fn}, found {len(hits)}")
    i = hits[0]
    cells = [c.strip() for c in lines[i].strip().strip('|').split('|')]
    cells += [''] * (len(cols) - len(cells))

    if not force and c_book is not None:
        b, m = kcal(cells[c_book]), kcal(mfp)
        if b and m is not None:
            diff = (m - b) / b * 100
            print(f"book {b} kcal, MFP {m} kcal: {diff:+.1f}%")
            if status == 'done' and abs(diff) > 10:
                sys.exit("more than 10% off: use status 'flagged' with a note (or --force)")
    if status in ('flagged', 'skipped') and not note:
        sys.exit(f"status '{status}' needs a one-line note")

    rf = os.path.join(folder, fn)
    text = io.open(rf, encoding='utf-8').read().rstrip('\n')
    if '\n## MFP entry' in text:
        sys.exit(f"{fn} already has an MFP entry section; edit it and INDEX.md by hand")
    body = io.open(winpath(entry), encoding='utf-8').read().strip('\n')

    cells[c_status] = status
    cells[c_mfp] = mfp + (' — ' + note if note else '')
    lines[i] = '| ' + ' | '.join(cells) + ' |'
    io.open(idx, 'w', encoding='utf-8', newline='\n').write('\n'.join(lines))
    io.open(rf, 'w', encoding='utf-8', newline='\n').write(text + '\n\n## MFP entry\n' + body + '\n')
    print('ok')


if __name__ == '__main__':
    main(sys.argv[1:])
