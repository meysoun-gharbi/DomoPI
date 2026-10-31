
#!/usr/bin/env bash
set -Eeuo pipefail

OTA_HOME="$HOME/domopi-ota"
PACKAGE="$OTA_HOME/incoming/v2"
VERIFY="$OTA_HOME/scripts/verify-ota.sh"
VERSION_FILE="$OTA_HOME/state/current-version"
PUBLIC_KEY="$OTA_HOME/keys/ota-public.pem"

OLD_CONTAINER="dsvw-hardened"
NEW_CONTAINER="dsvw-v2"
OLD_IMAGE="domopi-dsvw:v1"
NEW_IMAGE="domopi-dsvw:v2"
EXPECTED_VERSION="2.0.0"
HEALTH_URL="http://127.0.0.1:65413/"

STAGING=""
DEPLOYMENT_STARTED=false
DEPLOYMENT_SUCCESS=false

# Empêcher deux déploiements simultanés.
exec 9>"$OTA_HOME/deploy.lock"
flock -n 9 || {
    echo "ERREUR : un déploiement OTA est déjà en cours"
    exit 1
}

rollback() {
    echo "[ROLLBACK] Restauration de V1..."

    # Empêcher un second rollback lors de la sortie.
    trap - EXIT

    sudo docker rm -f "$NEW_CONTAINER" 2>/dev/null || true

    if ! sudo docker container inspect "$OLD_CONTAINER" >/dev/null 2>&1; then
        echo "ERREUR CRITIQUE : conteneur V1 introuvable"
        return 1
    fi

    sudo docker start "$OLD_CONTAINER" >/dev/null

    for i in 1 2 3 4 5; do
        if curl --fail --silent --output /dev/null \
            --max-time 3 "$HEALTH_URL"; then
            echo "[ROLLBACK] V1 restaurée avec succès"
            return 0
        fi
        sleep 2
    done

    echo "ERREUR CRITIQUE : V1 ne répond pas après rollback"
    return 1
}

cleanup() {
    local status=$?
    trap - EXIT

    if [ "$DEPLOYMENT_STARTED" = true ] &&
       [ "$DEPLOYMENT_SUCCESS" != true ]; then
        echo "[SECURITE] Déploiement non validé : rollback..."
        rollback || status=1
    fi

    if [ -n "$STAGING" ] && [ -d "$STAGING" ]; then
        rm -rf -- "$STAGING"
    fi

    exit "$status"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "[1/7] Vérification du paquet OTA..."

# Le script de vérification existant valide Ed25519,
# le manifeste, le SHA-256 et la version.
"$VERIFY" "$PACKAGE"

echo "[2/7] Création d'une copie de travail protégée..."

STAGING=$(mktemp -d "$OTA_HOME/staging.XXXXXX")
chmod 700 "$STAGING"

cp -- "$PACKAGE/manifest.txt" \
       "$PACKAGE/manifest.sig" \
       "$PACKAGE/dsvw-v2.tar" \
       "$STAGING/"

chmod 600 "$STAGING"/*

# Vérifier la copie qui sera utilisée pour docker load.
"$VERIFY" "$STAGING"

# Vérification indépendante de la signature sur la copie.
openssl pkeyutl -verify -rawin \
    -pubin \
    -inkey "$PUBLIC_KEY" \
    -in "$STAGING/manifest.txt" \
    -sigfile "$STAGING/manifest.sig" >/dev/null

echo "[3/7] Contrôles préalables..."

if sudo docker container inspect "$NEW_CONTAINER" >/dev/null 2>&1; then
    echo "ERREUR : le conteneur V2 existe déjà"
    exit 1
fi

if ! sudo docker container inspect "$OLD_CONTAINER" \
    --format '{{.State.Running}}' | grep -qx true; then
    echo "ERREUR : V1 n'est pas en cours d'exécution"
    exit 1
fi

if ! sudo docker image inspect "$OLD_IMAGE" >/dev/null 2>&1; then
    echo "ERREUR : image V1 indisponible"
    exit 1
fi

if ! curl --fail --silent --output /dev/null \
    --max-time 3 "$HEALTH_URL"; then
    echo "ERREUR : V1 ne répond pas avant le déploiement"
    exit 1
fi

if [ "$(cat "$VERSION_FILE")" != "1.0.0" ]; then
    echo "ERREUR : état de version inattendu"
    exit 1
fi

# Empêcher qu'une image déjà présente sous le tag V2
# soit remplacée par docker load sans contrôle.
sudo docker image rm "$NEW_IMAGE" >/dev/null 2>&1 || true

echo "[4/7] Chargement de l'image V2..."

# Revérifier l'intégrité immédiatement avant le chargement.
"$VERIFY" "$STAGING"

sudo docker load -i "$STAGING/dsvw-v2.tar"

IMAGE_VERSION=$(sudo docker image inspect "$NEW_IMAGE" \
    --format '{{index .Config.Labels "org.opencontainers.image.version"}}')

if [ "$IMAGE_VERSION" != "$EXPECTED_VERSION" ]; then
    echo "ERREUR : version de l'image Docker inattendue"
    exit 1
fi

IMAGE_USER=$(sudo docker image inspect "$NEW_IMAGE" \
    --format '{{.Config.User}}')

if [ "$IMAGE_USER" != "10001:10001" ]; then
    echo "ERREUR : utilisateur Docker inattendu"
    exit 1
fi

echo "[5/7] Basculement de V1 vers V2..."

DEPLOYMENT_STARTED=true

sudo docker stop "$OLD_CONTAINER"

if ! sudo docker run -d \
    --name "$NEW_CONTAINER" \
    --network host \
    --user 10001:10001 \
    --cap-drop ALL \
    --security-opt no-new-privileges:true \
    --read-only \
    --tmpfs /tmp:rw,noexec,nosuid,size=16m \
    --memory 128m \
    --pids-limit 64 \
    --restart unless-stopped \
    "$NEW_IMAGE"; then

    echo "ERREUR : impossible de démarrer V2"
    exit 1
fi

echo "[6/7] Vérification du fonctionnement de V2..."

HEALTHY=false

for i in 1 2 3 4 5; do
    if sudo docker container inspect "$NEW_CONTAINER" \
        --format '{{.State.Running}}' 2>/dev/null | grep -qx true &&
       curl --fail --silent --output /dev/null \
           --max-time 3 "$HEALTH_URL"; then
        HEALTHY=true
        break
    fi

    sleep 2
done

if [ "$HEALTHY" != true ]; then
    echo "ERREUR : V2 ne répond pas correctement"
    exit 1
fi

echo "[7/7] Validation de la nouvelle version..."

# Enregistrer la version de manière atomique.
VERSION_TMP=$(mktemp "$OTA_HOME/state/version.XXXXXX")
printf '%s\n' "$EXPECTED_VERSION" > "$VERSION_TMP"
chmod 600 "$VERSION_TMP"
mv -f "$VERSION_TMP" "$VERSION_FILE"

DEPLOYMENT_SUCCESS=true

echo "=========================================="
echo "SUCCÈS : mise à jour OTA V2 déployée"
echo "Version installée : $(cat "$VERSION_FILE")"
echo "V1 conservée pour un éventuel rollback"
echo "=========================================="

