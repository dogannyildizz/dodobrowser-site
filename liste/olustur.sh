#!/usr/bin/env bash
# Builds liste/engelli-alanlar.txt: HaGeZi's Multi LIGHT (domains, each with its
# subdomains) minus liste/istisnalar.txt. Run every day by .github/workflows/liste.yml.
# Only plain domain names go in; a list too small or too big is not published.
set -euo pipefail
cd "$(dirname "$0")"
src="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/light-onlydomains.txt"
curl -fsSL --max-time 120 "$src" -o hagezi.tmp
version=$(grep -m1 '^# Version:' hagezi.tmp | sed 's/^# Version: *//' || true)
grep -v '^#' istisnalar.txt | tr -d '\r' | tr 'A-Z' 'a-z' | sed 's/[[:space:]]//g' | grep -v '^$' > istisna.tmp || true
grep -v '^#' hagezi.tmp | tr -d '\r' | tr 'A-Z' 'a-z' \
  | grep -E '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$' \
  | awk 'NR==FNR { ex[$0]=1; next } { keep=1; n=split($0, p, "."); for (i=1; i<n; i++) { s=p[i]; for (j=i+1; j<=n; j++) s=s "." p[j]; if (s in ex) keep=0 } if (keep) print }' istisna.tmp - \
  | sort -u > alanlar.tmp
count=$(wc -l < alanlar.tmp)
if [ "$count" -lt 10000 ] || [ "$count" -gt 300000 ]; then
  echo "Liste beklenmedik boyutta ($count satir), yayinlanmadi." >&2
  exit 1
fi
{
  echo "# DodoBrowser reklam ve izleyici listesi (alan adi basina bir satir, alt alan adlari da)"
  echo "# Kaynak: HaGeZi's Multi LIGHT, https://github.com/hagezi/dns-blocklists (GPL-3.0, liste/HAGEZI-LISANS.txt)"
  echo "# HaGeZi surumu: ${version:-bilinmiyor}"
  echo "# Cikarilanlar: liste/istisnalar.txt"
  echo "# Satir: $count"
  cat alanlar.tmp
} > engelli-alanlar.txt
rm hagezi.tmp istisna.tmp alanlar.tmp
echo "Liste: $count alan adi (HaGeZi $version)"
