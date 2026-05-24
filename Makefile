################################################################################
# FILE         : Makefile
# LOCATION     : Repository root
# DESCRIPTION  : Operational developer workflow for the local-first
#                cloud-native platform. Manages K3d cluster lifecycle,
#                platform bootstrap via Terraform, and clean teardown.
#
# USAGE:
#   make help             — Show all available targets
#   make deps             — Install required local tools
#   make cluster-up       — Create K3d cluster
#   make cluster-status   — Check cluster health
#   make platform-init    — Terraform init for platform/
#   make platform-plan    — Terraform plan for platform/
#   make platform-bootstrap — Deploy namespaces + ArgoCD to cluster
#   make argocd-password  — Retrieve ArgoCD admin initial password
#   make argocd-open      — Open ArgoCD UI in browser
#   make destroy          — Destroy platform Terraform resources
#   make cluster-down     — Delete K3d cluster completely
#   make clean            — Full teardown (platform + cluster)
#
# PREREQUISITES:
#   docker, k3d, kubectl, terraform, helm
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
################################################################################

# ── CONFIGURATION ─────────────────────────────────────────────────────────────
CLUSTER_NAME        := fintech-local
K3D_IMAGE           := rancher/k3s:v1.28.8-k3s1
KUBECONFIG_PATH     := $(HOME)/.kube/config
PLATFORM_DIR        := platform
ARGOCD_NAMESPACE    := argocd
ARGOCD_PORT         := 8080
KUBECTL             := kubectl
TERRAFORM           := terraform
HELM                := helm

# Colour codes for readable output
RED    := \033[0;31m
GREEN  := \033[0;32m
YELLOW := \033[1;33m
BLUE   := \033[0;34m
RESET  := \033[0m

# ── DEFAULT TARGET ─────────────────────────────────────────────────────────────
.DEFAULT_GOAL := help

# ── PHONY DECLARATIONS ─────────────────────────────────────────────────────────
.PHONY: help deps cluster-up cluster-status cluster-down \
        platform-init platform-plan platform-bootstrap \
        argocd-password argocd-open \
        destroy clean

# ── HELP ───────────────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "$(BLUE)╔══════════════════════════════════════════════════════════╗$(RESET)"
	@echo "$(BLUE)║   Enterprise Cloud-Native Platform — Developer Workflow  ║$(RESET)"
	@echo "$(BLUE)╚══════════════════════════════════════════════════════════╝$(RESET)"
	@echo ""
	@echo "$(GREEN)CLUSTER MANAGEMENT:$(RESET)"
	@echo "  make cluster-up        Create K3d cluster ($(CLUSTER_NAME))"
	@echo "  make cluster-status    Check cluster node and pod health"
	@echo "  make cluster-down      Delete K3d cluster"
	@echo ""
	@echo "$(GREEN)PLATFORM BOOTSTRAP:$(RESET)"
	@echo "  make platform-init     Terraform init for platform/"
	@echo "  make platform-plan     Terraform plan — preview changes"
	@echo "  make platform-bootstrap Deploy namespaces + ArgoCD to cluster"
	@echo ""
	@echo "$(GREEN)ARGOCD:$(RESET)"
	@echo "  make argocd-password   Get ArgoCD admin initial password"
	@echo "  make argocd-open       Port-forward ArgoCD UI to localhost:$(ARGOCD_PORT)"
	@echo ""
	@echo "$(GREEN)TEARDOWN:$(RESET)"
	@echo "  make destroy           Destroy platform Terraform resources only"
	@echo "  make cluster-down      Delete K3d cluster only"
	@echo "  make clean             Full teardown — platform + cluster"
	@echo ""
	@echo "$(YELLOW)FIRST TIME SETUP ORDER:$(RESET)"
	@echo "  1. make deps"
	@echo "  2. make cluster-up"
	@echo "  3. make cluster-status"
	@echo "  4. make platform-init"
	@echo "  5. make platform-bootstrap"
	@echo "  6. make argocd-password"
	@echo "  7. make argocd-open"
	@echo ""

# ── DEPENDENCY CHECK ───────────────────────────────────────────────────────────
deps:
	@echo "$(BLUE)Checking required tools...$(RESET)"
	@echo ""
	@which docker    > /dev/null 2>&1 && echo "$(GREEN)✅ docker$(RESET)    : $$(docker --version)" || echo "$(RED)❌ docker    : NOT FOUND — Install from https://docs.docker.com/engine/install/$(RESET)"
	@which k3d       > /dev/null 2>&1 && echo "$(GREEN)✅ k3d$(RESET)       : $$(k3d version | head -1)" || echo "$(RED)❌ k3d       : NOT FOUND — Run: curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash$(RESET)"
	@which kubectl   > /dev/null 2>&1 && echo "$(GREEN)✅ kubectl$(RESET)   : $$(kubectl version --client --short 2>/dev/null || kubectl version --client)" || echo "$(RED)❌ kubectl   : NOT FOUND — Run: sudo apt-get install -y kubectl$(RESET)"
	@which terraform > /dev/null 2>&1 && echo "$(GREEN)✅ terraform$(RESET) : $$(terraform version | head -1)" || echo "$(RED)❌ terraform : NOT FOUND — Run: sudo apt-get install -y terraform$(RESET)"
	@which helm      > /dev/null 2>&1 && echo "$(GREEN)✅ helm$(RESET)       : $$(helm version --short)" || echo "$(RED)❌ helm       : NOT FOUND — Run: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash$(RESET)"
	@echo ""

# ── CLUSTER MANAGEMENT ────────────────────────────────────────────────────────

cluster-up:
	@echo "$(BLUE)Creating K3d cluster: $(CLUSTER_NAME)$(RESET)"
	@echo "K3s image: $(K3D_IMAGE)"
	@echo ""
	@if k3d cluster list | grep -q "$(CLUSTER_NAME)"; then \
		echo "$(YELLOW)⚠️  Cluster '$(CLUSTER_NAME)' already exists. Skipping creation.$(RESET)"; \
		echo "Run 'make cluster-down' first to recreate it."; \
	else \
                k3d cluster create $(CLUSTER_NAME) \
			--image $(K3D_IMAGE) \
			--servers 1 \
			--agents 2 \
			--port "80:80@loadbalancer" \
			--port "443:443@loadbalancer" \
			--wait \
			--timeout 120s && \
		echo "" && \
		echo "$(GREEN)✅ Cluster '$(CLUSTER_NAME)' created successfully$(RESET)" && \
		echo "" && \
		echo "Merging kubeconfig..." && \
		k3d kubeconfig merge $(CLUSTER_NAME) --kubeconfig-switch-context && \
		echo "$(GREEN)✅ Kubeconfig updated — context switched to k3d-$(CLUSTER_NAME)$(RESET)"; \
	fi
	@echo ""
	@echo "$(BLUE)Waiting for all system pods to be ready...$(RESET)"
	@$(KUBECTL) wait --for=condition=Ready pods --all -n kube-system --timeout=120s || true
	@echo ""
	@echo "$(GREEN)Cluster is ready. Run 'make cluster-status' to verify.$(RESET)"

cluster-status:
	@echo "$(BLUE)══════════════════════════════════════════$(RESET)"
	@echo "$(BLUE)  CLUSTER STATUS — $(CLUSTER_NAME)$(RESET)"
	@echo "$(BLUE)══════════════════════════════════════════$(RESET)"
	@echo ""
	@echo "$(GREEN)Nodes:$(RESET)"
	@$(KUBECTL) get nodes -o wide
	@echo ""
	@echo "$(GREEN)System Pods:$(RESET)"
	@$(KUBECTL) get pods -n kube-system
	@echo ""
	@echo "$(GREEN)All Namespaces:$(RESET)"
	@$(KUBECTL) get namespaces
	@echo ""

cluster-down:
	@echo "$(YELLOW)Deleting K3d cluster: $(CLUSTER_NAME)$(RESET)"
	@if k3d cluster list | grep -q "$(CLUSTER_NAME)"; then \
		k3d cluster delete $(CLUSTER_NAME) && \
		echo "$(GREEN)✅ Cluster '$(CLUSTER_NAME)' deleted$(RESET)"; \
	else \
		echo "$(YELLOW)Cluster '$(CLUSTER_NAME)' does not exist — nothing to delete$(RESET)"; \
	fi

# ── PLATFORM BOOTSTRAP ────────────────────────────────────────────────────────

platform-init:
	@echo "$(BLUE)Initialising Terraform — platform/$(RESET)"
	@echo ""
	@cd $(PLATFORM_DIR) && \
		$(TERRAFORM) init \
			-input=false \
			-no-color && \
		echo "" && \
		echo "$(GREEN)✅ Platform Terraform init complete$(RESET)"

platform-plan:
	@echo "$(BLUE)Terraform Plan — platform/$(RESET)"
	@echo ""
	@cd $(PLATFORM_DIR) && \
		$(TERRAFORM) plan \
			-input=false \
			-no-color && \
		echo "" && \
		echo "$(GREEN)✅ Plan complete — review above before applying$(RESET)"

platform-bootstrap:
	@echo "$(BLUE)Bootstrapping platform onto cluster: $(CLUSTER_NAME)$(RESET)"
	@echo ""
	@echo "$(YELLOW)Pre-flight: verifying cluster is accessible...$(RESET)"
	@$(KUBECTL) cluster-info > /dev/null 2>&1 || \
		(echo "$(RED)❌ Cluster not accessible. Run 'make cluster-up' first$(RESET)" && exit 1)
	@echo "$(GREEN)✅ Cluster accessible$(RESET)"
	@echo ""
	@echo "$(BLUE)Running Terraform apply — namespaces + ArgoCD...$(RESET)"
	@cd $(PLATFORM_DIR) && \
		$(TERRAFORM) apply \
			-input=false \
			-auto-approve \
			-no-color && \
		echo "" && \
		echo "$(GREEN)✅ Platform bootstrap complete$(RESET)"
	@echo ""
	@echo "$(BLUE)Waiting for ArgoCD pods to be ready...$(RESET)"
	@$(KUBECTL) wait --for=condition=Ready pods \
		--all \
		-n $(ARGOCD_NAMESPACE) \
		--timeout=180s || \
		(echo "$(YELLOW)⚠️  Some pods not ready yet. Check: kubectl get pods -n argocd$(RESET)")
	@echo ""
	@echo "$(GREEN)══════════════════════════════════════════════════════$(RESET)"
	@echo "$(GREEN)  PLATFORM READY                                      $(RESET)"
	@echo "$(GREEN)  Run 'make argocd-password' then 'make argocd-open'  $(RESET)"
	@echo "$(GREEN)══════════════════════════════════════════════════════$(RESET)"

# ── ARGOCD OPERATIONS ────────────────────────────────────────────────────────

argocd-password:
	@echo "$(BLUE)ArgoCD Admin Initial Password:$(RESET)"
	@echo ""
	@$(KUBECTL) -n $(ARGOCD_NAMESPACE) get secret argocd-initial-admin-secret \
		-o jsonpath="{.data.password}" 2>/dev/null | base64 -d && echo "" || \
		echo "$(YELLOW)Secret not found yet. Wait for ArgoCD pods to be Running first.$(RESET)"
	@echo ""
	@echo "$(GREEN)Username: admin$(RESET)"
	@echo "$(GREEN)URL     : https://argocd.fintech.local  OR  http://localhost:$(ARGOCD_PORT)$(RESET)"

argocd-open:
	@echo "$(BLUE)Port-forwarding ArgoCD UI to http://localhost:$(ARGOCD_PORT)$(RESET)"
	@echo "$(YELLOW)Press CTRL+C to stop port-forward$(RESET)"
	@echo ""
	@$(KUBECTL) port-forward \
		svc/argocd-server \
		-n $(ARGOCD_NAMESPACE) \
		$(ARGOCD_PORT):443

# ── TEARDOWN ─────────────────────────────────────────────────────────────────

destroy:
	@echo "$(YELLOW)Destroying platform Terraform resources in platform/$(RESET)"
	@echo "$(YELLOW)This removes namespaces and ArgoCD from the cluster.$(RESET)"
	@echo "$(YELLOW)The K3d cluster itself will remain running.$(RESET)"
	@echo ""
	@cd $(PLATFORM_DIR) && \
		$(TERRAFORM) destroy \
			-input=false \
			-auto-approve \
			-no-color && \
		echo "" && \
		echo "$(GREEN)✅ Platform resources destroyed$(RESET)"

clean: destroy cluster-down
	@echo ""
	@echo "$(GREEN)✅ Full teardown complete — cluster deleted, platform destroyed$(RESET)"
	@echo ""

# ── LOCAL DNS HELPER ──────────────────────────────────────────────────────────
hosts-setup:
	@echo "$(BLUE)Adding local DNS entries to /etc/hosts$(RESET)"
	@echo "$(YELLOW)This requires sudo password$(RESET)"
	@grep -q "argocd.fintech.local" /etc/hosts || \
		echo "127.0.0.1 argocd.fintech.local api.fintech.local" | \
		sudo tee -a /etc/hosts > /dev/null && \
		echo "$(GREEN)✅ Local DNS entries added$(RESET)" || \
		echo "$(YELLOW)Entries already exist in /etc/hosts$(RESET)"
	@cat /etc/hosts | grep "fintech.local"

# ── PHASE 2: APPLICATION BUILD AND DEPLOY ────────────────────────────────────

APP_NAME       := payment-service
APP_VERSION    := 1.0.0
APP_DIR        := applications/payment-service
HELM_CHART_DIR := $(APP_DIR)/helm-chart

docker-build:
	@echo "$(BLUE)Building Docker image: $(APP_NAME):$(APP_VERSION)$(RESET)"
	@docker build \
		--build-arg APP_VERSION=$(APP_VERSION) \
		--build-arg BUILD_DATE=$(shell date -u +%Y-%m-%dT%H:%M:%SZ) \
		--build-arg GIT_COMMIT=$(shell git rev-parse --short HEAD) \
		-t $(APP_NAME):$(APP_VERSION) \
		$(APP_DIR)
	@echo "$(GREEN)✅ Docker image built: $(APP_NAME):$(APP_VERSION)$(RESET)"
	@echo ""
	@docker images | grep $(APP_NAME)

docker-run:
	@echo "$(BLUE)Running $(APP_NAME) locally on port 8000$(RESET)"
	@echo "$(YELLOW)Press CTRL+C to stop$(RESET)"
	@docker run --rm \
		-p 8000:8000 \
		-e APP_ENV=local \
		-e APP_VERSION=$(APP_VERSION) \
		-e SERVICE_NAME=$(APP_NAME) \
		$(APP_NAME):$(APP_VERSION)

k3d-image-load:
	@echo "$(BLUE)Loading Docker image into K3d cluster: $(CLUSTER_NAME)$(RESET)"
	@k3d image import $(APP_NAME):$(APP_VERSION) \
		--cluster $(CLUSTER_NAME)
	@echo "$(GREEN)✅ Image loaded into K3d cluster$(RESET)"

nginx-install:
	@echo "$(BLUE)Installing NGINX Ingress Controller$(RESET)"
	@$(HELM) repo add ingress-nginx \
		https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
	@$(HELM) repo update
	@$(HELM) upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
		--namespace platform \
		--create-namespace \
		--set controller.replicaCount=1 \
		--set controller.resources.requests.cpu=50m \
		--set controller.resources.requests.memory=64Mi \
		--set controller.admissionWebhooks.enabled=false \
		--timeout 120s || true
	@echo "$(YELLOW)Waiting 15s for NGINX pod to start...$(RESET)"
	@sleep 15
	@$(KUBECTL) get pods -n platform
	@echo "$(GREEN)✅ NGINX Ingress Controller installed$(RESET)"
	@echo "$(YELLOW)Note: EXTERNAL-IP pending is normal on WSL K3d$(RESET)"

app-deploy:
	@echo "$(BLUE)Deploying $(APP_NAME) via Helm into apps namespace$(RESET)"
	@$(KUBECTL) cluster-info > /dev/null 2>&1 || \
		(echo "$(RED)❌ Cluster not accessible. Run make cluster-up first$(RESET)" && exit 1)
	@$(HELM) upgrade --install $(APP_NAME) $(HELM_CHART_DIR) \
		--namespace apps \
		--create-namespace \
		--set image.tag=$(APP_VERSION) \
		--set environment=local \
		--timeout 120s
	@sleep 10
	@echo ""
	@echo "$(GREEN)✅ $(APP_NAME) deployed$(RESET)"
	@echo ""
	@$(KUBECTL) get pods,svc,ingress -n apps
	@echo ""
	@echo "$(GREEN)Test: kubectl port-forward svc/payment-service 8001:80 -n apps$(RESET)"
	@echo "$(GREEN)Then: curl http://localhost:8001/health$(RESET)"

app-status:
	@echo "$(BLUE)Application Status — apps namespace$(RESET)"
	@echo ""
	@$(KUBECTL) get pods,svc,ingress -n apps -o wide

app-logs:
	@echo "$(BLUE)Streaming logs — $(APP_NAME)$(RESET)"
	@echo "$(YELLOW)Press CTRL+C to stop$(RESET)"
	@$(KUBECTL) logs \
		-l app.kubernetes.io/name=$(APP_NAME) \
		-n apps \
		--follow \
		--tail=50

app-test:
	@echo "$(BLUE)Testing $(APP_NAME) via port-forward$(RESET)"
	@echo "$(YELLOW)Starting port-forward on localhost:8001$(RESET)"
	@$(KUBECTL) port-forward svc/$(APP_NAME) 8001:80 -n apps &
	@sleep 3
	@echo ""
	@echo "Health check:"
	@curl -s http://localhost:8001/health | python3 -m json.tool
	@echo ""
	@echo "Readiness check:"
	@curl -s http://localhost:8001/ready | python3 -m json.tool
	@echo ""
	@echo "Root endpoint:"
	@curl -s http://localhost:8001/ | python3 -m json.tool
	@echo ""
	@echo "$(GREEN)✅ All endpoints responding$(RESET)"
	@echo "$(YELLOW)Docs available at: http://localhost:8001/docs$(RESET)"

app-delete:
	@echo "$(YELLOW)Removing $(APP_NAME) from cluster$(RESET)"
	@$(HELM) uninstall $(APP_NAME) --namespace apps 2>/dev/null || true
	@echo "$(GREEN)✅ $(APP_NAME) removed$(RESET)"
