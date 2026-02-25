.PHONY: help build up down shell ping update common playbook lint clean install-collections add-hosts

# Default target
.DEFAULT_GOAL := help

# Colors for output
CYAN := \033[0;36m
GREEN := \033[0;32m
RESET := \033[0m

help: ## Show this help message
	@echo "$(CYAN)Ansible Docker Compose Commands$(RESET)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}'

build: ## Build the Ansible container
	docker compose build ansible

up: ## Start the Ansible container in detached mode
	docker compose up -d ansible

down: ## Stop and remove the Ansible container
	docker compose down

shell: ## Open a bash shell in the Ansible container
	docker compose run --rm ansible /bin/bash

exec: ## Execute command in running container (make exec CMD="ansible --version")
	docker compose exec ansible $(CMD)

# Ansible Commands
ping: up ## Test connectivity to all k3s cluster nodes
	docker compose exec ansible ansible k3s_cluster -m ping

ping-all: up ## Test connectivity to all hosts (including bastion)
	docker compose exec ansible ansible all -m ping

inventory: up ## Show inventory
	docker compose exec ansible ansible-inventory --graph

inventory-list: up ## Show detailed inventory as JSON
	docker compose exec ansible ansible-inventory --list

add-hosts: ## Add k3s cluster hosts to SSH known_hosts
	@echo "$(CYAN)Adding k3s cluster hosts to known_hosts...$(RESET)"
	@for ip in 192.168.122.10 192.168.122.11 192.168.122.12 192.168.122.13; do \
		ssh-keyscan -H $$ip >> ~/.ssh/known_hosts 2>/dev/null && echo "$(GREEN)Added $$ip$(RESET)" || echo "Failed to add $$ip"; \
	done
	@echo "$(GREEN)Done! You can now run Ansible playbooks.$(RESET)"

# Playbook Commands
update: up ## Run k3s-update.yml playbook
	docker compose exec ansible ansible-playbook k3s-update.yml $(ARGS)

update-check: up ## Run k3s-update.yml in check mode (dry-run)
	docker compose exec ansible ansible-playbook k3s-update.yml --check

update-workers: up ## Update only worker nodes
	docker compose exec ansible ansible-playbook k3s-update.yml --limit k3s_workers

update-cp: up ## Update only control plane
	docker compose exec ansible ansible-playbook k3s-update.yml --limit k3s_control_plane

update-bastion: up ## Update only bastion
	docker compose exec ansible ansible-playbook k3s-update.yml --limit k3s_bastion

common: up ## Run k3s-common.yml playbook
	docker compose exec ansible ansible-playbook k3s-common.yml $(ARGS)

playbook: up ## Run custom playbook (make playbook PLAY=myplaybook.yml ARGS="--check")
	docker compose exec ansible ansible-playbook $(PLAY) $(ARGS)

# Utility Commands
install-collections: up ## Install Ansible collections from requirements.yml
	docker compose exec ansible ansible-galaxy collection install -r collections/requirements.yml

lint: ## Run ansible-lint on all playbooks
	docker compose run --rm lint

facts: up ## Gather facts from all k3s nodes
	docker compose exec ansible ansible k3s_cluster -m setup

uptime: up ## Check uptime on all k3s nodes
	docker compose exec ansible ansible k3s_cluster -m command -a "uptime"

disk: up ## Check disk usage on all k3s nodes
	docker compose exec ansible ansible k3s_cluster -m command -a "df -h"

# Cleanup
clean: down ## Stop containers and clean up volumes
	docker compose down -v

rebuild: clean build up ## Rebuild and restart everything

# Quick access to common tasks
check-reboot: up ## Check if any nodes need reboot
	docker compose exec ansible ansible k3s_cluster -m command -a "test -f /var/run/reboot-required && echo REBOOT_REQUIRED || echo NO_REBOOT_NEEDED"

k3s-status: up ## Check k3s service status on all nodes
	docker compose exec ansible ansible k3s_control_plane -m command -a "systemctl status k3s --no-pager"
	docker compose exec ansible ansible k3s_workers -m command -a "systemctl status k3s-agent --no-pager"
