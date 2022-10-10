deploy: ## deploy GKE ACM PolicyController constraint templates
	helm upgrade --install constrainttemplates --namespace=gatekeeper-system .

undeploy: ## undeploys GKE ACM PolicyController constraint templates
	helm uninstall constrainttemplates --namespace=gatekeeper-system

help: ## show usage and tasks (default)
	@eval $$(sed -E -n 's/^([\*\.a-zA-Z0-9_-]+):.*?## (.*)$$/printf "\\033[36m%-30s\\033[0m %s\\n" "\1" "\2" ;/; ta; b; :a p' $(MAKEFILE_LIST))
.DEFAULT_GOAL := help
.PHONY: deploy undeploy
