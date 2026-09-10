#!/usr/bin/env bash
# One-time setup after the cluster first comes up. Re-running is safe (helm
# upgrade --install is idempotent); the ESO secret step is skipped if it
# already exists.
#
# Prereqs: KUBECONFIG pointed at the cluster (see get-kubeconfig.sh), helm,
# and you've run `terraform apply` in terraform-k3s/ already.
set -euo pipefail

echo "== ingress-nginx =="
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx --force-update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx --create-namespace \
  -f "$(dirname "$0")/../cluster-addons/ingress-nginx-values.yaml"

echo "== cert-manager =="
helm repo add jetstack https://charts.jetstack.io --force-update
helm upgrade --install cert-manager jetstack/cert-manager \
  -n cert-manager --create-namespace --set installCRDs=true
kubectl wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=120s
kubectl apply -f "$(dirname "$0")/../cluster-addons/cert-manager-cluster-issuer.yaml"

echo "== external-secrets =="
helm repo add external-secrets https://charts.external-secrets.io --force-update
helm upgrade --install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace

# Same class of race as cert-manager above, just missed here originally:
# the CRDs (ClusterSecretStore, ExternalSecret, etc.) take a moment to
# register with the API server after Helm installs the chart. Applying a
# ClusterSecretStore before that finishes fails with "no matches for kind
# ClusterSecretStore" - a CRD-registration gap, not a controller-readiness
# one, so wait on the CRD's own Established condition specifically rather
# than on a Deployment being Available.
kubectl wait --for condition=Established --timeout=120s crd/clustersecretstores.external-secrets.io

echo "== Seeding the ESO credential (from Terraform outputs, never git) =="
if ! kubectl get secret aws-secrets-manager-credentials -n external-secrets >/dev/null 2>&1; then
  ACCESS_KEY_ID=$(terraform -chdir="$(dirname "$0")/../terraform-k3s" output -raw eso_access_key_id)
  SECRET_ACCESS_KEY=$(terraform -chdir="$(dirname "$0")/../terraform-k3s" output -raw eso_secret_access_key)
  kubectl create secret generic aws-secrets-manager-credentials \
    -n external-secrets \
    --from-literal=access-key-id="$ACCESS_KEY_ID" \
    --from-literal=secret-access-key="$SECRET_ACCESS_KEY"
else
  echo "  already exists, skipping"
fi
kubectl apply -f "$(dirname "$0")/../cluster-addons/external-secrets-secretstore.yaml"

echo "== Kyverno =="
helm repo add kyverno https://kyverno.github.io/kyverno --force-update
helm upgrade --install kyverno kyverno/kyverno -n kyverno --create-namespace
kubectl wait --for=condition=Available deployment/kyverno-admission-controller -n kyverno --timeout=180s
kubectl apply -f "$(dirname "$0")/../cluster-addons/kyverno-policies/"

echo "== ArgoCD =="
helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm upgrade --install argocd argo/argo-cd \
  -n argocd --create-namespace \
  --version 10.8.1 \
  -f "$(dirname "$0")/../cluster-addons/argocd-values.yaml"
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=180s

echo "  Applying dev/prod Application definitions (edit repoURL/path in"
echo "  cluster-addons/argocd-apps/ first if you haven't already)"
kubectl apply -f "$(dirname "$0")/../cluster-addons/argocd-apps/dev-application.yaml"
kubectl apply -f "$(dirname "$0")/../cluster-addons/argocd-apps/prod-application.yaml"

echo ""
echo "Done. ArgoCD will auto-sync dev-space2study from git within a few"
echo "minutes of any push to values-dev.yaml (see the Jenkinsfile's"
echo "'Update GitOps Manifest' stage - that's what writes the image tag)."
echo ""
echo "prod-space2study requires a manual sync - that's the approval gate now:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443 &"
echo "  argocd login localhost:8080 --username admin \\"
echo "    --password \$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
echo "  argocd app sync prod-space2study"
echo ""
echo "NOTE: running BOTH dev and prod simultaneously on this same 3-node"
echo "cluster likely exceeds available memory (each environment runs its own"
echo "3-node Mongo replica set) - see README cost/capacity notes before"
echo "syncing prod for real use, not just to see it work once."
