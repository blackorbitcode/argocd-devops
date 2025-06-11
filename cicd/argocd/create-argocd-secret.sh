#!/bin/bash
# Crie um Secret no ArgoCD para armazenar as credenciais do repositório Git
set -a
source .env
set +a

# Crie o Secret no namespace argocd
kubectl create secret generic argocd-repo-creds \
  --from-literal=url=$GIT_REPO_URL \
  --from-literal=username=$GITHUB_USERNAME \
  --from-literal=password=$GITHUB_TOKEN \
  -n argocd \
  --dry-run=client -o yaml | kubectl apply -f -
# Verifique se o Secret foi criado corretamente
kubectl get secret argocd-repo-creds -n argocd -o yaml