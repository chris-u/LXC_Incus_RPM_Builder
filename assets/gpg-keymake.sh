#!/bin/sh
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

test -z "${PASSPHRASE}" && yelp 3 "[Error] No passphrase received. Exiting."


# 2. Define Configuration
: "${KEY_NAME:=trussio master key}"
: "${KEY_EMAIL:=trussio@f82.us}"
: "${OUTPUT_DIR:=/keys}"

test -d "$OUTPUT_DIR" || yelp 8 "[Error] No directory $OUTPUT_DIR"

test -z "$(gpg --with-colons --list-secret-keys 2> /dev/null)" || yelp 7 "[Error] gpg keys already exist"

echo "[GPG] Generating Primary Master Key & GitHub Subkey..."
gpg --batch --generate-key <<EOF
Key-Type: RSA
Key-Length: 4096
Key-Usage: cert
Subkey-Type: RSA
Subkey-Length: 4096
Subkey-Usage: sign
Name-Real: ${KEY_NAME}
Name-Email: ${KEY_EMAIL}
Expire-Date: 0
Passphrase: ${PASSPHRASE}
%commit
EOF


# Find the Master Key Fingerprint programmatically
MASTER_FP=$(
 gpg --with-colons --list-secret-keys "${KEY_EMAIL}"  |
   while 
     IFS=: read a b  &&
     case "$a" 
     in 
       "sec") read -r next_line && echo "$next_line"  | cut -f10 -d: ; false ;; 
     esac  
   do
     :
   done ;
           )

echo "[GPG] Generating Dedicated Home System Subkey..."
gpg --batch --pinentry-mode loopback --passphrase "${PASSPHRASE}" \
    --quick-add-key "${MASTER_FP}" rsa4096 sign 0


# Extract the Subkey IDs
o=$(gpg --with-colons --list-secret-keys "${KEY_EMAIL}" | awk -F: '/^ssb/ {print $5}')
GITHUB_SUBKEY_ID=$(echo "$o" | head -1 )
HOME_SUBKEY_ID=$(echo "$o" | head -2 | tail -1)

echo "[Export] Writing key files to ${OUTPUT_DIR}..."

# Export public key
gpg --armor --export "${MASTER_FP}" > "${OUTPUT_DIR}/public-key.asc"

# Export isolated subkeys (trailing ! isolates them)
gpg --batch --pinentry-mode loopback --passphrase "${PASSPHRASE}" \
    --export-secret-subkeys --armor "${GITHUB_SUBKEY_ID}!" > "${OUTPUT_DIR}/github-secrets.key"

gpg --batch --pinentry-mode loopback --passphrase "${PASSPHRASE}" \
    --export-secret-subkeys --armor "${HOME_SUBKEY_ID}!" > "${OUTPUT_DIR}/home-secrets.key"

# Export the FULL master identity (including the primary key and all subkeys)
gpg --batch --pinentry-mode loopback --passphrase "${PASSPHRASE}" \
    --export-secret-keys --armor "${MASTER_FP}" > "${OUTPUT_DIR}/master-private.key"

echo "[Success] Key generation complete. Files written to host volume mount."
