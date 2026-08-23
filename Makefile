initialise:
	@echo "Installing pre-commit hooks"
	pre-commit --version || brew install pre-commit
	pre-commit install --install-hooks

lint:
	helm lint helm/podium

template:
	helm template podium helm/podium
