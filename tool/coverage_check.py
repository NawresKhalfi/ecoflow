#!/usr/bin/env python3
"""Couverture minimale des tests (US-130), hors code généré.

  flutter test --coverage && python3 tool/coverage_check.py 75
"""
import re
import sys

EXCLUDED = ('/l10n/gen/', 'firebase_options.dart')


def coverage(path='coverage/lcov.info'):
    found = hit = 0
    for block in open(path, encoding='utf-8').read().split('end_of_record'):
        source = re.search(r'SF:(.*)', block)
        if not source or any(x in source.group(1) for x in EXCLUDED):
            continue
        lf, lh = re.search(r'LF:(\d+)', block), re.search(r'LH:(\d+)', block)
        if lf and lh:
            found, hit = found + int(lf.group(1)), hit + int(lh.group(1))
    return 100 * hit / found if found else 0


if __name__ == '__main__':
    minimum = float(sys.argv[1]) if len(sys.argv) > 1 else 75
    value = coverage()
    print(f'Couverture : {value:.1f} % (minimum {minimum:g} %)')
    sys.exit(0 if value >= minimum else 1)
