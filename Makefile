# ############################################################################################################
# Variables
# ############################################################################################################

HELM_REPO_NAME ?= platformfix
HELM_REPO_URL  ?= https://platformfix.github.io/podium
RELEASE_NAME   ?= podium
NAMESPACE      ?= podium

.PHONY: initialise lint template repo-add presenter attendee

# ############################################################################################################
# Local tasks
# ############################################################################################################

initialise:
	@echo "Initialising pre-commit hooks"
	pre-commit --version || brew install pre-commit
	pre-commit install --install-hooks
	pre-commit run -a

lint:
	helm lint helm/podium

template:
	helm template $(RELEASE_NAME) helm/podium

# ############################################################################################################
# Training tasks
#
# Both targets install into the same NAMESPACE (default: podium), never
# the cluster's default namespace, so podium's footprint is always in one
# predictable, easy-to-clean-up place.
# ############################################################################################################

repo-add:
	@helm repo add $(HELM_REPO_NAME) $(HELM_REPO_URL) >/dev/null
	@helm repo update $(HELM_REPO_NAME) >/dev/null

# For the trainer, on your own teacher cluster: cluster-admin, and the
# live-terminal broadcast turned on so attendees can follow along.
presenter: repo-add
	helm upgrade --install $(RELEASE_NAME) $(HELM_REPO_NAME)/podium \
		--namespace $(NAMESPACE) --create-namespace \
		--set rbac.cluster.clusterRoles="{cluster-admin}" \
		--set broadcast.enabled=true \
		--set broadcast.service.type=NodePort
	kubectl wait deployment/$(RELEASE_NAME) --namespace $(NAMESPACE) --for=condition=Available --timeout=120s
	kubectl attach -it deployment/$(RELEASE_NAME) --namespace $(NAMESPACE) -c podium

# For attendees, each on their own dedicated cluster: cluster-admin and a
# persistent $HOME (see examples/attendee-cluster-values.yaml). Run from the
# workshop bastion node once the cluster is up - clone the repo, run
# "make attendee", and you're attached and ready to go.
attendee: repo-add
	helm upgrade --install $(RELEASE_NAME) $(HELM_REPO_NAME)/podium \
		--namespace $(NAMESPACE) --create-namespace \
		-f examples/attendee-cluster-values.yaml
	kubectl wait deployment/$(RELEASE_NAME) --namespace $(NAMESPACE) --for=condition=Available --timeout=120s
	kubectl attach -it deployment/$(RELEASE_NAME) --namespace $(NAMESPACE) -c podium
