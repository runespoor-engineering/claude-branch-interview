#!/usr/bin/env bash
# Structural check for dossier files written by dossier-builder.
# Usage: bash tests/check-dossier.sh <dossier.md>...
set -uo pipefail

[ "$#" -ge 1 ] || { echo "usage: check-dossier.sh <dossier.md>..." >&2; exit 2; }
status=0
for f in "$@"; do
  missing=""
  for pat in '^# Dossier c-[0-9a-f]\{7\} · ' '^hunks: ' '^scores: importance [1-5] · complexity [1-5] · doubt [1-5]$' '^reason: ' \
             '^## What$' '^## Why$' '^Confidence: \(high\|medium\|low\)$' '^## Alternatives$' '^## Weaknesses$' '^## Findings$' '^## Questions$' \
             '^### what$' '^### why$' '^### alternatives$' '^### weaknesses$'; do
    grep -q "$pat" "$f" || missing="$missing
  missing: $pat"
  done
  for axis in what why alternatives weaknesses; do
    block=$(awk -v a="### $axis" '$0 == a { on = 1; next } /^### / { on = 0 } on' "$f")
    if printf '%s\n' "$block" | grep -q '^N/A'; then continue; fi
    for key in 'Question: ' 'Key points: ' 'Rung 1: ' 'Rung 2: ' 'Rung 3: '; do
      printf '%s\n' "$block" | grep -q "^$key" || missing="$missing
  missing in $axis: $key"
    done
  done
  if [ -n "$missing" ]; then echo "FAIL $f$missing"; status=1; else echo "ok   $f"; fi
done
exit $status
