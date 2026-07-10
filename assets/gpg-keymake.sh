#!/usr/bin/env bash
set -euo pipefail

yelp() {
  es=$1
  shift
  echo "$@" >&2
  exit "$es"
}

# 1. Read the passphrase from the stdin pipe
echo "[Config] Awaiting passphrase from stdin..."
read -r PASSPHRASE

test -z "${PASSPHRASE}"  && yelp 3 "[Error] No passphrase received. Exiting."

# 2. Define Configuration
: "${KEY_NAME:=trussio master key}"
: "${KEY_EMAIL:=trussio@f82.us}"
: "${OUTPUT_DIR:=/keys}"

test  -d "$OUTPUT_DIR"  || yelp 8 "[Error] No directory $OUTPUT_DIR"
test  -z "$(gpg --with-colons --list-secret-keys 2> /dev/null)"  || yelp 7 "[Error] gpg keys already exist"

echo "[GPG] Generating Primary Master Key [C] & GitHub Subkey [S] using Ed25519..."
gpg --batch --generate-key <<EOF
Key-Type: EDDSA
Key-Curve: ed25519
Key-Usage: cert
Subkey-Type: EDDSA
Subkey-Curve: ed25519
Subkey-Usage: sign
Name-Real: ${KEY_NAME}
Name-Email: ${KEY_EMAIL}
Expire-Date: 0
Passphrase: ${PASSPHRASE}
%commit
EOF

# Extract Master Fingerprint cleanly using awk
MASTER_FP=$(gpg --with-colons --fingerprint "${KEY_EMAIL}" | awk -F: '/^fpr/ {print $10; exit}')
echo "[GPG] Master Identity Fingerprint Verified: ${MASTER_FP}"

echo "[GPG] Generating Dedicated Home System Subkey [S]..."
gpg --batch --pinentry-mode loopback --passphrase "${PASSPHRASE}" \
    --quick-add-key "${MASTER_FP}" ed25519 sign 0

# Extract the Subkey IDs using fingerprints for absolute precision
SUBKEY_FPRS=($(gpg --with-colons --fingerprint "${KEY_EMAIL}" | awk -F: '/^fpr/ {print $10}'))
GITHUB_SUBKEY_FPR=${SUBKEY_FPRS[1]}
HOME_SUBKEY_FPR=${SUBKEY_FPRS[2]}

echo "[Export] Writing cryptographically isolated key files to ${OUTPUT_DIR}..."

# Export public key
gpg --armor --export "${MASTER_FP}" > "${OUTPUT_DIR}/public-key.asc"

# Export isolated secret subkeys (with stubbed master)
gpg --batch --pinentry-mode loopback --passphrase "${PASSPHRASE}" \
    --export-secret-subkeys --armor "${GITHUB_SUBKEY_FPR}!" > "${OUTPUT_DIR}/github-secrets.key"

gpg --batch --pinentry-mode loopback --passphrase "${PASSPHRASE}" \
    --export-secret-subkeys --armor "${HOME_SUBKEY_FPR}!" > "${OUTPUT_DIR}/home-secrets.key"

# Export the FULL master identity bundle
gpg --batch --pinentry-mode loopback --passphrase "${PASSPHRASE}" \
    --export-secret-keys --armor "${MASTER_FP}" > "${OUTPUT_DIR}/master-private.key"

echo "[Success] Key generation complete. Cryptographic supply chain initialized."
