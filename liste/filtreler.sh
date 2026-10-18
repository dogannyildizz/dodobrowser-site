#!/usr/bin/env bash
# Builds liste/filtreler.txt: EasyList, EasyPrivacy and AdGuard's Turkish filter in
# one file, for DodoBrowser's filter engine (src\FilterEngine.cs; 7 Oct 2026, the
# user's decision). Run every day by .github/workflows/liste.yml.
# Only data goes in, never code (the Microsoft Store's rule 10.2.2): every rule
# that runs or injects a script, or changes what a site sends, is dropped
# (#%#, #$#, #?#, $redirect, $replace, $removeparam, $csp, $header ...).
# Site fixes (10 Oct 2026): "a.com##+js(name, values)" stays only for a named
# site and only with a name of a fix built into the program (src\FilterEngine.cs
# FixNames, adblock\duzeltmeler.js); the line is data: which fix, where, with
# which values. Others (every site, trusted-*, names the program lacks) go.
# DodoBrowser 1.0.0 skips these lines (FilterEngine.SafeSelector: "+js").
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
# The program's fixes, by every name the lists use (keep in step with FilterEngine.FixNames).
fixnames='set-constant|set|abort-on-property-read|aopr|abort-on-property-write|aopw|abort-current-script|acs|abort-current-inline-script|acis|abort-on-stack-trace|aost|addEventListener-defuser|aeld|no-setTimeout-if|nostif|setTimeout-defuser|no-setInterval-if|nosiif|setInterval-defuser|adjust-setTimeout|nano-stb|nano-setTimeout-booster|adjust-setInterval|nano-sib|nano-setInterval-booster|no-window-open-if|nowoif|window\.open-defuser|prevent-fetch|no-fetch-if|no-xhr-if|prevent-xhr|remove-attr|ra|remove-class|rc|set-attr|remove-node-text|rmnt|json-prune|set-local-storage-item|set-session-storage-item|set-cookie|remove-cookie|cookie-remover|m3u-prune'
# Options that change what a site sends (data, never code: Store 10.2.2).
changers='[$,](redirect|redirect-rule|rewrite|replace|removeparam|queryprune|csp|header|removeheader|hls|permissions|urltransform|uritransform|empty|mp4|cookie|jsonprune|xmlprune)(=|,|$)'
for name in easylist easyprivacy adguard-turkce; do
  curl -fsSL --max-time 120 "${src[$name]}" -o "$name.tmp"
  v=$(grep -m1 -E '^! (Version|Last modified):' "$name.tmp" | sed -E 's/^! (Version|Last modified): *//' || true)
  versions="$versions $name=${v:-?}"
  # Site fixes: named sites only (no ~site, no /pattern/; "name.*" is a site), our names only.
  tr -d '\r' < "$name.tmp" \
    | grep -E "^[a-z0-9][a-z0-9.,*-]*#@?#\+js\((($fixnames)[,)]|\))" \
    >> filtre.tmp || true
  tr -d '\r' < "$name.tmp" \
    | grep -v -E '^[[:space:]]*(!|\[|$)' \
    | grep -v -E '##\+js|#@#\+js|#%#|#@%#|#\$#|#@\$#|#\?#|#@\?#|\$\$|\$\@\$' \
    | grep -v -E "$changers" \
    >> filtre.tmp
  rm "$name.tmp"
done
# Lines that break a site (filtre-istisnalari.txt, 10 Oct 2026): taken out as they are;
# "+ rule" lines are our own rules added (data only: no script rule, its exception is fine).
if [ -f filtre-istisnalari.txt ]; then
  tr -d '\r' < filtre-istisnalari.txt | grep -v -E '^[[:space:]]*(#|$)' > istisna.tmp || true
  grep -v -E '^\+ ' istisna.tmp > cikar.tmp || true
  if [ -s cikar.tmp ]; then
    grep -v -x -F -f cikar.tmp filtre.tmp > filtre2.tmp || true
    mv filtre2.tmp filtre.tmp
  fi
  # Our own lines go through the same filters as the lists' (10 Oct review, K24): no line
  # that runs a script or changes what a site sends, even by a slip of ours.
  grep -E '^\+ ' istisna.tmp | sed 's/^+ //' \
    | grep -v -E '##\+js|#%#|#@%#|#\$#|#@\$#|#\?#|#@\?#|\$\$|\$\@\$' \
    | grep -v -E "$changers" >> filtre.tmp || true
  rm -f istisna.tmp cikar.tmp
fi
count=$(wc -l < filtre.tmp)
if [ "$count" -lt 50000 ] || [ "$count" -gt 400000 ]; then
  echo "Filtre listesi beklenmedik boyutta ($count satir), yayinlanmadi." >&2
  exit 1
fi
# The header count is the file's real line count, after duplicates are removed:
# the 7 header lines written first, the "! Satir:" line itself, and the unique rules.
{
  echo "! DodoBrowser filtre listesi: EasyList, EasyPrivacy, AdGuard Turkish filter (betik calistiran kurallar cikarildi; site duzeltmeleri sadece programdakilerin adi ve degerleri)"
  echo "! EasyList ve EasyPrivacy: https://easylist.to (GPL-3.0 ya da CC BY-SA 3.0, The EasyList authors)"
  echo "! AdGuard Turkish filter: https://github.com/AdguardTeam/AdGuardFilters (GPL-3.0)"
  echo "! Lisans metni: liste/HAGEZI-LISANS.txt (GPL-3.0)"
  echo "! Surumler:$versions"
  echo "! DodoBrowser degisiklik tarihi (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "! Degisiklikler: kaynaklar birlestirildi, desteklenmeyen kurallar ve liste/filtre-istisnalari.txt satirlari suzuldu."
} > filtre.bas
sort -u filtre.tmp > filtre.sorted
unique=$(wc -l < filtre.sorted)
headcount=$(wc -l < filtre.bas)
total=$((unique + headcount + 1))
{
  cat filtre.bas
  echo "! Satir: $total"
  cat filtre.sorted
} > filtreler.txt
rm filtre.tmp filtre.sorted filtre.bas
echo "Filtre listesi: $total satir ($versions )"
