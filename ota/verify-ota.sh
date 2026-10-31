#!/bin/bash
set -euo pipefail

PACKAGE="${1:?Usage: verify-ota.sh <dossier-paquet>}"
PUBLIC_KEY="$HOME/domopi-ota/keys/ota-public.pem"

cd "$PACKAGE"

echo "[1/4] Vérification de la signature Ed25519..."

if ! openssl pkeyutl -verify -rawin \
  -pubin \
  -inkey "$PUBLIC_KEY" \
  -in manifest.txt \
  -sigfile manifest.sig >/dev/null 2>&1; then
    echo "ERREUR : signature Ed25519 invalide"
    exit 1
fi

echo "[2/4] Vérification du manifeste..."

EXPECTED_MANIFEST=$'version=2.0.0\nimage=domopi-dsvw:v2\narchive=dsvw-v2.tar\nsha256='

if [[ "$(wc -l < manifest.txt)" -ne 4 ]] ||
   [[ "$(head -n 3 manifest.txt)" != "$(printf '%s' "$EXPECTED_MANIFEST" | head -n 3)" ]]; then
    echo "ERREUR : manifeste inattendu"
    exit 1
fi

EXPECTED=$(sed -n 's/^sha256=//p' manifest.txt)

if [[ ! "$EXPECTED" =~ ^[a-f0-9]{64}$ ]]; then
    echo "ERREUR : SHA-256 invalide dans le manifeste"
    exit 1
fi

echo "[3/4] Vérification SHA-256..."

ACTUAL=$(sha256sum dsvw-v2.tar | awk '{print $1}')

if [[ "$EXPECTED" != "$ACTUAL" ]]; then
    echo "ERREUR : intégrité de l'archive compromise"
    exit 1
fi

echo "[4/4] Vérification de la version..."

CURRENT_VERSION=$(cat "$HOME/domopi-ota/state/current-version")
NEW_VERSION=$(sed -n 's/^version=//p' manifest.txt)


if ! dpkg --compare-versions "$NEW_VERSION" gt "$CURRENT_VERSION"; then
    echo "ERREUR : version non autorisée"
    exit 1
fi

echo "SUCCÈS : paquet OTA V2 authentifié et intègre"
echo "Aucune installation effectuée."
