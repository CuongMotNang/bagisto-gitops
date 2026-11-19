#!/usr/bin/env bash
set -euo pipefail

: "${VAULT_TOKEN:?VAULT_TOKEN must be set}"

VAULT_NAMESPACE="${VAULT_NAMESPACE:-vault}"
VAULT_POD="${VAULT_POD:-vault-0}"

vault_exec() {
  kubectl -n "$VAULT_NAMESPACE" exec -i "$VAULT_POD" -- env VAULT_TOKEN="$VAULT_TOKEN" vault "$@"
}

if ! vault_exec auth list -format=json | jq -e '."kubernetes/"' >/dev/null; then
  vault_exec auth enable kubernetes
fi

vault_exec write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

vault_exec policy write bagisto-read - <<'POLICY'
path "secret/data/bagisto/*" {
  capabilities = ["read"]
}
POLICY

vault_exec write auth/kubernetes/role/bagisto \
  bound_service_account_names=eso-bagisto \
  bound_service_account_namespaces=bagisto \
  policies=bagisto-read \
  ttl=1h
