#!/usr/bin/env bash
# Builds liste/filtreler.txt: EasyList, EasyPrivacy and AdGuard's Turkish filter in
# one file, for DodoBrowser's filter engine (src\FilterEngine.cs; 7 Oct 2026, the
# user's decision). Run every day by .github/workflows/liste.yml.
# Only data goes in, never code (the Microsoft Store's rule 10.2.2): every rule
# that runs or injects a script, or changes what a site sends, is dropped
# (##+js, #%#, #$#, #?#, $redirect, $replace, $removeparam, $csp, $header ...).
# Comments go too. A file too small or too big is not published.
set -euo pipefail
cd "$(dirname "$0")"
declare -A src=(
  [easylist]="https://easylist.to/easylist/easylist.txt"
  [easyprivacy]="https://easylist.to/easylist/easyprivacy.txt"
  [adguard-turkce]="https://filters.adtidy.org/extension/ublock/filters/13.txt"
)
: > filtre.tmp
versions=""
for name in easylist easyprivacy adguard-turkce; do
  curl -fsSL --max-time 120 "${src[$name]}" -o "$name.tmp"
  v=$(grep -m1 -E '^! (Version|Last modified):' "$name.tmp" | sed -E 's/^! (Version|Last modified): *//' || true)
  versions="$versions $name=${v:-?}"
  tr -d '\r' < "$name.tmp" \
    | grep -v -E '^[[:space:]]*(!|\[|$)' \
    | grep -v -E '##\+js|#@#\+js|#%#|#@%#|#\$#|#@\$#|#\?#|#@\?#|\$\$|\$\@\$' \
    | grep -v -E '[$,](redirect|redirect-rule|rewrite|replace|removeparam|queryprune|csp|header|permissions|urltransform|uritransform|empty|mp4|cookie|jsonprune|xmlprune)(=|,|$)' \
    >> filtre.tmp
  rm "$name.tmp"
done
count=$(wc -l < filtre.tmp)
if [ "$count" -lt 50000 ] || [ "$count" -gt 400000 ]; then
  echo "Filtre listesi beklenmedik boyutta ($count satir), yayinlanmadi." >&2
  exit 1
fi
{
  echo "! DodoBrowser filtre listesi: EasyList, EasyPrivacy, AdGuard Turkish filter (betik kurallari cikarildi)"
  echo "! EasyList ve EasyPrivacy: https://easylist.to (GPL-3.0 ya da CC BY-SA 3.0, The EasyList authors)"
  echo "! AdGuard Turkish filter: https://github.com/AdguardTeam/AdGuardFilters (GPL-3.0)"
  echo "! Lisans metni: liste/HAGEZI-LISANS.txt (GPL-3.0)"
  echo "! Surumler:$versions"
  echo "! Satir: $count"
  sort -u filtre.tmp
} > filtreler.txt
rm filtre.tmp
echo "Filtre listesi: $count satir ($versions )"
