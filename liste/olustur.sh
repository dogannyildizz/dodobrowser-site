#!/usr/bin/env bash
# Builds liste/engelli-alanlar.txt: HaGeZi's Multi LIGHT (domains, each with its
# subdomains) minus liste/istisnalar.txt. Run every day by .github/workflows/liste.yml.
# Only plain domain names go in; a list too small or too big is not published.
# Also liste/engelli-alanlar-pro.txt (Kalkan plan P12, 15 Nov 2026): the "Sıkı" protection
# level's extra names, HaGeZi's Multi PRO minus what LIGHT (with its subdomains) already
# blocks and minus our exceptions. The program adds it to LIGHT only at "Sıkı".
set -euo pipefail
cd "$(dirname "$0")"
light_src="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/light-onlydomains.txt"
pro_src="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/pro-onlydomains.txt"
grep -v '^#' istisnalar.txt | tr -d '\r' | tr 'A-Z' 'a-z' | sed 's/[[:space:]]//g' | grep -v '^$' > istisna.tmp || true

# The names of one HaGeZi list: plain domain names only, lower case, minus every name the
# first file covers (the name itself or one of its parent domains).
names() {
  grep -v '^#' "$1" | tr -d '\r' | tr 'A-Z' 'a-z' \
    | grep -E '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$' \
    | awk 'NR==FNR { ex[$0]=1; next } { keep=1; n=split($0, p, "."); for (i=1; i<n; i++) { s=p[i]; for (j=i+1; j<=n; j++) s=s "." p[j]; if (s in ex) keep=0 } if (keep) print }' "$2" - \
    | sort -u
}

# One published list: its header, then the names. $1 file, $2 source name, $3 version,
# $4 what was taken out, $5 the names.
publish() {
  local count
  count=$(wc -l < "$5")
  {
    echo "# DodoBrowser reklam ve izleyici listesi (alan adi basina bir satir, alt alan adlari da)"
    echo "# Kaynak: $2, https://github.com/hagezi/dns-blocklists (GPL-3.0, liste/HAGEZI-LISANS.txt)"
    echo "# HaGeZi surumu: ${3:-bilinmiyor}"
    echo "# DodoBrowser degisiklik tarihi (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "# Degisiklikler: $4"
    echo "# Cikarilanlar: liste/istisnalar.txt"
    echo "# Satir: $count"
    cat "$5"
  } > "$1"
}

curl -fsSL --max-time 120 "$light_src" -o hagezi.tmp
version=$(grep -m1 '^# Version:' hagezi.tmp | sed 's/^# Version: *//' || true)
names hagezi.tmp istisna.tmp > alanlar.tmp
count=$(wc -l < alanlar.tmp)
if [ "$count" -lt 10000 ] || [ "$count" -gt 300000 ]; then
  echo "Liste beklenmedik boyutta ($count satir), yayinlanmadi." >&2
  exit 1
fi
publish engelli-alanlar.txt "HaGeZi's Multi LIGHT" "$version" \
  "alan adlari ayiklandi, tekrarlar ve istisnalarin alt alan adlari cikarildi." alanlar.tmp
echo "Liste: $count alan adi (HaGeZi $version)"

# The strict list: a failure here leaves yesterday's file and doesn't stop the main list.
if curl -fsSL --max-time 120 "$pro_src" -o hagezi-pro.tmp; then
  pro_version=$(grep -m1 '^# Version:' hagezi-pro.tmp | sed 's/^# Version: *//' || true)
  cat istisna.tmp alanlar.tmp > pro-disi.tmp
  # In the condition, not on its own line: a download that is empty, only comments or a
  # page (grep finds nothing and fails) must not end the script under "set -e" (review, 15 Nov).
  if ! names hagezi-pro.tmp pro-disi.tmp > pro.tmp; then : > pro.tmp; fi
  pro_count=$(wc -l < pro.tmp)
  if [ "$pro_count" -lt 1000 ] || [ "$pro_count" -gt 300000 ]; then
    echo "Siki liste beklenmedik boyutta ($pro_count satir), yayinlanmadi." >&2
  else
    publish engelli-alanlar-pro.txt "HaGeZi's Multi PRO" "$pro_version" \
      "alan adlari ayiklandi; engelli-alanlar.txt'nin (LIGHT) kapsadiklari, tekrarlar ve istisnalarin alt alan adlari cikarildi." pro.tmp
    echo "Siki liste: $pro_count alan adi (HaGeZi PRO $pro_version)"
  fi
  rm -f hagezi-pro.tmp pro-disi.tmp pro.tmp
else
  echo "Siki liste indirilemedi, dunku kaldi." >&2
fi
rm hagezi.tmp istisna.tmp alanlar.tmp
