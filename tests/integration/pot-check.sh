#!/usr/bin/env bash
#
# Is languages/crawl-cove-connector.pot in step with the source? Regenerates a
# template from the staged production copy (the exact file set that ships) with
# wp-cli's `i18n make-pot` and compares the SET of msgids with the committed
# file. Only the msgids are compared: the header carries a creation timestamp
# and the "#:" references carry line numbers, both of which move on every
# unrelated edit and mean nothing to a translator.
#
# Why: the committed POT shipped in 0.9.0 and 0.10.0 without any of the six
# `lang` error strings 0.9.0 added — nothing checked it. Translators working
# from the shipped template could not have seen them.
#
# Usage: tests/integration/pot-check.sh <staged-plugin-dir>
# Fix on failure: php tests/integration/.cache/wp-cli.phar i18n make-pot . \
#   languages/crawl-cove-connector.pot --exclude=vendor,tests,build,bin,wordpress-org

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../.." && pwd)"
STAGED="${1:?usage: pot-check.sh <staged-plugin-dir>}"
WPCLI=(php "$HERE/.cache/wp-cli.phar")
COMMITTED="$PLUGIN_ROOT/languages/crawl-cove-connector.pot"

log() { echo "[pot-check] $*"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if ! "${WPCLI[@]}" i18n make-pot "$STAGED" "$TMP/fresh.pot" --quiet 2>"$TMP/err"; then
  log "make-pot failed: $(cat "$TMP/err")"
  exit 1
fi

msgids() { grep '^msgid ' "$1" | grep -v '^msgid ""$' | sort -u; }
msgids "$COMMITTED" >"$TMP/committed.txt"
msgids "$TMP/fresh.pot" >"$TMP/fresh.txt"

if cmp -s "$TMP/committed.txt" "$TMP/fresh.txt"; then
  log "PASS — committed POT has the same $(wc -l <"$TMP/fresh.txt") msgids the source produces"
  exit 0
fi

log "FAIL — languages/crawl-cove-connector.pot is out of step with the source:"
diff "$TMP/committed.txt" "$TMP/fresh.txt" | grep '^[<>]' | sed 's/^</  only in committed POT:/; s/^>/  missing from committed POT:/'
log "regenerate: php tests/integration/.cache/wp-cli.phar i18n make-pot . languages/crawl-cove-connector.pot --exclude=vendor,tests,build,bin,wordpress-org"
exit 1
