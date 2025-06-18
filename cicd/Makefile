###############################################################################
# Makefile – Kind CI/CD stack (Jenkins, Gitea, Harbor, SonarQube, Nginx Ingress) via Argo CD
###############################################################################

# Colors and formatting
YELLOW := \033[1;33m
GREEN  := \033[1;32m
RED    := \033[1;31m
BLUE   := \033[1;34m
CYAN   := \033[1;36m
BOLD   := \033[1m
RESET  := \033[0m
CHECK  := ✔️
CROSS  := ❌
ARROW  := ➜
CUBE   := 📦
STAR   := ✨
INFO   := ℹ️

.ONESHELL:
SHELL := /bin/bash
SHELLFLAGS := -eu -o pipefail -c

CLUSTER_NAME        ?= cicd
CLUSTER_CONFIG      ?= cluster/kind-cluster-config.yaml
KIND_IMAGE          ?= kindest/node:v1.33.0

METALLB_MANIFEST    ?= https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml
METALLB_NAMESPACE   ?= metallb-system

ARGOCD_NS           ?= argocd
HELM_RELEASE        ?= argocd
HELM_CHART          ?= argo/argo-cd
HELM_CHART_VERSION  ?= 8.0.17
HELM_VALUES         ?= values/argocd/argocd-values.yaml
ARGO_PROJECTS_APP   ?= argocd/argocd-apps/argocd-projects-application.yaml
ARGO_APP            ?= argocd/argocd-apps/argocd-application.yaml
ARGO_APPS_APP       ?= argocd/argocd-apps/argocd-apps-application.yaml

SUBDOMAINS          ?= jenkins.local gitea.local harbor.local sonarqube.local

.DEFAULT_GOAL := help

# ---------------------------------------------------------------------------
# HELP
# ---------------------------------------------------------------------------

.PHONY: help
help:
	@echo ""
	@echo "$(BOLD)$(BLUE)──────────────────────────── AJUDA ────────────────────────────$(RESET)"
	@echo "$(YELLOW)make check-deps       $(RESET)- Verifica dependências (docker, kind, kubectl, helm)"
	@echo "$(YELLOW)make create-cluster   $(RESET)- Cria o cluster Kind"
	@echo "$(YELLOW)make delete-cluster   $(RESET)- Remove o cluster Kind"
	@echo "$(YELLOW)make setup-metallb    $(RESET)- Instala MetalLB + pool"
	@echo "$(YELLOW)make setup-argocd     $(RESET)- Instala Argo CD"
	@echo "$(YELLOW)make apply-projects   $(RESET)- Aplica AppProjects Argo CD"
	@echo "$(YELLOW)make apply-apps       $(RESET)- Aplica Applications Argo CD"
	@echo "$(YELLOW)make hosts            $(RESET)- Atualiza /etc/hosts local"
	@echo "$(YELLOW)make deploy-all       $(RESET)- Executa sequência completa"
	@echo "$(YELLOW)make delete-all       $(RESET)- Remove ambiente completo"
	@echo "$(YELLOW)make passwords        $(RESET)- Exibe credenciais geradas"
	@echo "$(BOLD)$(BLUE)──────────────────────────────────────────────────────────────$(RESET)"
	@echo ""

# ---------------------------------------------------------------------------
# DEPENDÊNCIAS
# ---------------------------------------------------------------------------

.PHONY: check-deps
check-deps:
	@echo ""
	@echo "$(BOLD)$(CYAN)───────────────────── DEPENDÊNCIAS ─────────────────────$(RESET)"
	@missing=0; for bin in docker kind kubectl helm; do \
        if ! command -v $$bin &>/dev/null; then \
            echo "$(RED)$(CROSS)  $$bin não encontrado$(RESET)"; missing=1; \
        else \
            printf "$(GREEN)$(CHECK)  %-6s %s$(RESET)\n" $$bin "$$($$bin version --short 2>/dev/null | head -1)"; \
        fi; \
    done; \
    if [ $$missing -eq 1 ]; then echo "$(RED)$(BOLD)Instale as dependências e execute novamente.$(RESET)"; exit 1; fi
	@echo "$(BOLD)$(CYAN)─────────────────────────────────────────────────────────$(RESET)"

# ---------------------------------------------------------------------------
# CLUSTER
# ---------------------------------------------------------------------------

.PHONY: create-cluster delete-cluster
create-cluster:
	@echo ""
	@echo "$(BOLD)$(CYAN)───────────────────── CLUSTER KIND ─────────────────────$(RESET)"
	@echo "$(CUBE)  Criando cluster $(CLUSTER_NAME)..."
	kind create cluster --name $(CLUSTER_NAME) --config $(CLUSTER_CONFIG) --image $(KIND_IMAGE)
	kubectl wait --for=condition=Ready nodes --all --timeout=180s
	@echo "$(GREEN)$(CHECK)  Cluster pronto$(RESET)"
	@echo "$(BOLD)$(CYAN)─────────────────────────────────────────────────────────$(RESET)"

delete-cluster:
	@echo ""
	@echo "$(BOLD)$(CYAN)─────────────────── REMOVENDO CLUSTER ──────────────────$(RESET)"
	@echo "$(YELLOW)$(ARROW)  Excluindo cluster $(CLUSTER_NAME)...$(RESET)"
	-kind delete cluster --name $(CLUSTER_NAME) || true
	@echo "$(BOLD)$(CYAN)─────────────────────────────────────────────────────────$(RESET)"

.PHONY: create-cluster-argocd
create-cluster-argocd: check-deps create-cluster setup-metallb setup-argocd apply-apps hosts
	@echo ""
	@echo "$(BOLD)$(GREEN)──────────────── BOOTSTRAP ARGOCD+APPS FINALIZADO ───────────────$(RESET)"
	@echo "$(STAR)  Cluster + ArgoCD + Apps provisionados!"
	@echo "$(CYAN)Acesse o painel do ArgoCD para verificar os apps.$(RESET)"
	@echo "$(BOLD)$(GREEN)─────────────────────────────────────────────────────────────$(RESET)"


# ---------------------------------------------------------------------------
# INSTALAÇÃO DO METALLB
# ---------------------------------------------------------------------------

.PHONY: setup-metallb wait-metallb setup-metallb-pool
setup-metallb:
	@echo ""
	@echo "$(BOLD)$(YELLOW)──────────────────── INSTALANDO METALLB ──────────────────$(RESET)"
	kubectl apply -f $(METALLB_MANIFEST)
	$(MAKE) wait-metallb
	$(MAKE) setup-metallb-pool
	@echo "$(BOLD)$(YELLOW)─────────────────────────────────────────────────────────$(RESET)"

wait-metallb:
	@echo "$(CYAN)Aguardando pods do MetalLB ficarem prontos...$(RESET)"
	kubectl wait --namespace $(METALLB_NAMESPACE) \
        --for=condition=ready pod \
        --selector=app=metallb \
        --timeout=120s
	@echo "$(GREEN)$(CHECK)  MetalLB pronto$(RESET)"

setup-metallb-pool:
	@echo "$(CYAN)Aplicando configuração do pool do MetalLB...$(RESET)"
	kubectl apply -f manifests/metallb-pool.yaml
	@echo "$(GREEN)$(CHECK)  Pool MetalLB configurado$(RESET)"

# ---------------------------------------------------------------------------
# ARGO CD
# ---------------------------------------------------------------------------

.PHONY: setup-argocd
setup-argocd:
	@echo "$(BOLD)$(BLUE)─ Instalando Argo CD via Helm$(RESET)"
	helm repo add argo https://argoproj.github.io/argo-helm || true
	helm repo update
	helm upgrade --install $(HELM_RELEASE) $(HELM_CHART) \
	  --version $(HELM_CHART_VERSION) \
	  --namespace $(ARGOCD_NS) \
	  --create-namespace \
	  -f $(HELM_VALUES)
	kubectl -n $(ARGOCD_NS) rollout status deployment/argocd-server --timeout=300s
	@echo "$(GREEN)$(CHECK)  Argo CD instalado$(RESET)"

	@echo "$(BOLD)$(BLUE)─ Aplicando self-managed Application$(RESET)"
	kubectl apply -f $(ARGO_APP)
	@echo "$(GREEN)$(CHECK)  Application criado$(RESET)"
	@echo "$(BOLD)$(BLUE)────────────────────────────────$(RESET)"

# ---------------------------------------------------------------------------
# ARGOCD - APPPROJECTS & APPLICATIONS
# ---------------------------------------------------------------------------

.PHONY: apply-projects apply-apps
apply-projects:
	@echo ""
	@echo "$(BOLD)$(BLUE)─────────────────── APPPROJECTS ARGOCD ──────────────────$(RESET)"
	@echo "$(STAR) Aplicando AppProjects...$(RESET)"
	kubectl apply -f $(ARGO_PROJECTS_APP)
	@echo "$(BOLD)$(BLUE)─────────────────────────────────────────────────────────$(RESET)"

apply-apps: apply-projects
	@echo ""
	@echo "$(BOLD)$(BLUE)────────────────── APPLICATIONS ARGOCD ─────────────────$(RESET)"
	@echo "$(STAR) Aplicando Applications...$(RESET)"
	kubectl apply -f $(ARGO_APPS_APP)
	@echo "$(BOLD)$(BLUE)─────────────────────────────────────────────────────────$(RESET)"

# ---------------------------------------------------------------------------
# ATUALIZAÇÃO DO /etc/hosts
# ---------------------------------------------------------------------------

.PHONY: hosts
hosts:
	@echo ""
	@echo "$(BOLD)$(YELLOW)───────────────────── ATUALIZANDO HOSTS ─────────────────$(RESET)"
	for h in $(SUBDOMAINS); do \
	  if ! grep -q "^172\.18\.0\.50[[:space:]]$$h$$" /etc/hosts; then \
	    sudo sh -c "echo '172.18.0.50 $$h' >> /etc/hosts"; \
	  fi; \
	done
	@echo "$(GREEN)$(CHECK) /etc/hosts atualizado$(RESET)"
	@echo "$(BOLD)$(YELLOW)─────────────────────────────────────────────────────────$(RESET)"

# ---------------------------------------------------------------------------
# EXIBIÇÃO DE CREDENCIAIS
# ---------------------------------------------------------------------------

.PHONY: passwords
passwords:
	@echo ""
	@echo "$(BOLD)$(CYAN)───────────────────── CREDENCIAIS ──────────────────────$(RESET)"
	@echo "Jenkins →"; kubectl get secret -n jenkins jenkins -o jsonpath='{.data.jenkins-admin-user}' | base64 -d; echo -n ":"; kubectl get secret -n jenkins jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d; echo
	@echo "Gitea → gitea_admin : adminadmin"
	@echo "Harbor → admin : admin"
	@echo "SonarQube → admin : adminn"
	@echo "$(BOLD)$(CYAN)─────────────────────────────────────────────────────────$(RESET)"

# ---------------------------------------------------------------------------
# TARGETS COMPOSTOS (deploy-all, delete-all)
# ---------------------------------------------------------------------------

.PHONY: deploy-all delete-all
deploy-all: check-deps create-cluster setup-metallb setup-argocd apply-projects apply-apps hosts
	@echo ""
	@echo "$(BOLD)$(GREEN)────────────────────── DEPLOY FINALIZADO ──────────────────$(RESET)"
	@echo "$(STAR)  Ambiente completo criado!"
	@echo "$(CYAN)Acompanhe a sincronização no painel do Argo CD.$(RESET)"
	@echo "$(BOLD)$(GREEN)─────────────────────────────────────────────────────────$(RESET)"

delete-all:
	@echo ""
	@echo "$(BOLD)$(RED)──────────────────── REMOVENDO AMBIENTE ───────────────────$(RESET)"
	kind delete cluster --name $(CLUSTER_NAME) || true
	@echo "$(BOLD)$(RED)─────────────────────────────────────────────────────────$(RESET)"
