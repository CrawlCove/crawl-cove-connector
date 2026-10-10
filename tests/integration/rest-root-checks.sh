#!/usr/bin/env bash
#
# REST root discovery: the shape of the REST URL depends on the site's
# permalink setting (/wp-json/, /index.php/wp-json/, /index.php?rest_route=/),
# and a client that hard-codes /wp-json/ cannot reach a plain-permalink site
# (review ticket #200, 10 Oct 2026). README "Finding the REST root" tells
# clients to read the Link header on the site URL. This pins that contract
# against a real WordPress: the header is present, it names the root the
# site actually uses, and crawlcove/v1 answers under that root. Unit stubs
# have no rest_output_link_header() and no permalink setting to vary.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

: "${CCC_SITE:?}" "${CCC_CACHE:?}"
WPCLI=(php "$CCC_CACHE/wp-cli.phar")
wp() { "${WPCLI[@]}" "$@" --path="$CCC_SITE"; }

STRUCTURE="$(wp option get permalink_structure 2>/dev/null || true)"
if [[ -z "$STRUCTURE" ]]; then
  PASS=$((PASS+1)); echo "  ok   harness site uses plain permalinks (the shape a /wp-json/-only client cannot reach)"
else
  FAIL=$((FAIL+1)); echo "  FAIL harness site permalink_structure is '$STRUCTURE', expected plain (empty)"
fi

echo "-- the site URL advertises its REST root --"
HEADERS="$(curl -s -D - -o /dev/null --max-time 10 "$CCC_URL/")"
LINK="$(printf '%s' "$HEADERS" | tr -d '\r' | grep -i '^link:' | grep -i 'rel="https://api.w.org/"' | head -1)"
if [[ -n "$LINK" ]]; then
  PASS=$((PASS+1)); echo "  ok   GET / carries a Link rel=\"https://api.w.org/\" header"
else
  FAIL=$((FAIL+1)); echo "  FAIL GET / has no api.w.org Link header; headers: $(printf '%s' "$HEADERS" | tr -d '\r' | tr '\n' ' ' | head -c 400)"
fi
ROOT="$(printf '%s' "$LINK" | sed -n 's/.*<\([^>]*\)>.*/\1/p')"
if [[ "$ROOT" == "$CCC_URL/index.php?rest_route=/" ]]; then
  PASS=$((PASS+1)); echo "  ok   advertised root is the plain-permalink form: $ROOT"
else
  FAIL=$((FAIL+1)); echo "  FAIL advertised root '$ROOT' is not $CCC_URL/index.php?rest_route=/"
fi
WP_ROOT="$(wp eval 'echo get_rest_url();' 2>/dev/null)"
if [[ -n "$ROOT" && "$ROOT" == "$WP_ROOT" ]]; then
  PASS=$((PASS+1)); echo "  ok   advertised root matches get_rest_url()"
else
  FAIL=$((FAIL+1)); echo "  FAIL Link root '$ROOT' differs from get_rest_url() '$WP_ROOT'"
fi

echo "-- crawlcove/v1 answers under the advertised root --"
# Append the route to the root the way README says: a ?rest_route=/ root
# takes the route in its query value, never as a second path.
OUT="$(curl -s -u "$EDITOR" --max-time 10 -w '\n%{http_code}' "${ROOT}crawlcove/v1/status")"
HTTP="$(echo "$OUT" | tail -1)"
BODY="$(echo "$OUT" | sed '$d')"
check "editor GET <root>crawlcove/v1/status is 200 JSON with plugin_version" 200 "$HTTP" '.plugin_version | type' string "$BODY"
PLUGIN_VERSION="$(sed -n "s/^ \* Version: *\([0-9.]*\).*/\1/p" "$CCC_SITE/wp-content/plugins/crawl-cove-connector/crawl-cove-connector.php" | head -1)"
if [[ -n "$PLUGIN_VERSION" && "$(echo "$BODY" | jq -r .plugin_version)" == "$PLUGIN_VERSION" ]]; then
  PASS=$((PASS+1)); echo "  ok   plugin_version is the installed header version ($PLUGIN_VERSION)"
else
  FAIL=$((FAIL+1)); echo "  FAIL plugin_version '$(echo "$BODY" | jq -r .plugin_version)' vs header '$PLUGIN_VERSION'"
fi
OUT="$(curl -s --max-time 10 -w '\n%{http_code}' "${ROOT}crawlcove/v1/status")"
check "anonymous GET <root>crawlcove/v1/status is 401 JSON (route exists, auth required)" 401 "$(echo "$OUT" | tail -1)" '.code' rest_forbidden "$(echo "$OUT" | sed '$d')"

echo "-- the hard-coded /wp-json/ shape is not the REST API here --"
OUT="$(curl -s -L -u "$EDITOR" --max-time 10 -w '\n%{http_code}' "$CCC_URL/wp-json/crawlcove/v1/status")"
HTTP="$(echo "$OUT" | tail -1)"
BODY="$(echo "$OUT" | sed '$d')"
if ! echo "$BODY" | jq -e '.plugin_version' >/dev/null 2>&1; then
  PASS=$((PASS+1)); echo "  ok   /wp-json/crawlcove/v1/status does not return the status JSON on this site (http=$HTTP), so discovery is required"
else
  FAIL=$((FAIL+1)); echo "  FAIL /wp-json/ unexpectedly served the status JSON on a plain-permalink site"
fi

summary
