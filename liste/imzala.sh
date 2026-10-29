#!/bin/bash
# Signs a list for the program (review B-04, 29 Oct 2026). Copied to the public site repository
# as liste/imzala.sh and run by .github/workflows/liste.yml after the lists are built.
#   bash liste/imzala.sh <file> <list name: engelli-alanlar | filtreler> <key id>
# The private key (RSA-3072, PEM) comes only from the environment variable LISTE_IMZA_ANAHTARI
# (a GitHub secret); it is never written to the repository or printed.
# Three comment lines end the list: "! dodo-liste: <name>", "! dodo-zaman: <UTC seconds>",
# "! dodo-imza: <key id> <base64>". The signed bytes run from the first byte to the end of the
# dodo-zaman line (src/ListSignature.cs, Android kalkan/ListeImzasi.kt: same rules).
# If the list body did not change since the committed version, the committed (signed) file is
# kept as it is, so a day without news makes no commit.
set -euo pipefail
f="$1"; name="$2"; id="$3"
[ -n "${LISTE_IMZA_ANAHTARI:-}" ] || { echo "LISTE_IMZA_ANAHTARI yok" >&2; exit 1; }
[ -s "$f" ] || { echo "$f yok ya da bos" >&2; exit 1; }
trailer='^! dodo-\(liste\|zaman\|imza\):'
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
grep -v "$trailer" "$f" > "$tmp/body"
if [ -n "$(tail -c1 "$tmp/body")" ]; then echo >> "$tmp/body"; fi
if git cat-file -e "HEAD:$f" 2>/dev/null; then
  git show "HEAD:$f" | grep -v "$trailer" > "$tmp/old" || true
  if [ -n "$(tail -c1 "$tmp/old")" ]; then echo >> "$tmp/old"; fi
  if cmp -s "$tmp/old" "$tmp/body" && git show "HEAD:$f" | tail -n1 | grep -q '^! dodo-imza: '; then
    git checkout -- "$f"; echo "$f: degismedi, eski imzali dosya kaldi"; exit 0
  fi
fi
umask 077
printf '%s\n' "$LISTE_IMZA_ANAHTARI" > "$tmp/key.pem"
now="$(date -u +%s)"
{ cat "$tmp/body"; printf '! dodo-liste: %s\n! dodo-zaman: %s\n' "$name" "$now"; } > "$tmp/signed"
openssl dgst -sha256 -sign "$tmp/key.pem" -out "$tmp/sig" "$tmp/signed"
# Self-check with the public half before the file is replaced.
openssl pkey -in "$tmp/key.pem" -pubout -out "$tmp/pub.pem"
openssl dgst -sha256 -verify "$tmp/pub.pem" -signature "$tmp/sig" "$tmp/signed" > /dev/null
{ cat "$tmp/signed"; printf '! dodo-imza: %s %s\n' "$id" "$(base64 -w0 "$tmp/sig")"; } > "$f"
echo "$f: imzalandi ($name, anahtar $id, zaman $now)"
