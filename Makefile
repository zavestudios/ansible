.PHONY: help build up down shell exec ping ping-all inventory inventory-list add-hosts \
	update update-check update-workers update-cp update-bastion reboot reboot-check \
	common playbook install-collections list-collections lint facts uptime \
	disk clean rebuild check-reboot k3s-status hypervisor-report hypervisor-autostart \
	hypervisor-reboot

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
	docker compose exec ansible ansible k3s_cluster -m ping $(ARGS)

ping-all: up ## Test connectivity to all hosts (including bastion)
	docker compose exec ansible ansible all -m ping $(ARGS)

inventory: up ## Show inventory
	docker compose exec ansible ansible-inventory --graph $(ARGS)

inventory-list: up ## Show detailed inventory as JSON
	docker compose exec ansible ansible-inventory --list $(ARGS)

add-hosts: ## Add k3s cluster hosts to SSH known_hosts
	@echo "$(CYAN)Adding k3s cluster hosts to known_hosts...$(RESET)"
	@for ip in 192.168.122.10 192.168.122.11 192.168.122.12 192.168.122.13; do \
		ssh-keyscan -H $$ip >> ~/.ssh/known_hosts 2>/dev/null && echo "$(GREEN)Added $$ip$(RESET)" || echo "Failed to add $$ip"; \
	done
	@echo "$(GREEN)Done! You can now run Ansible playbooks.$(RESET)"

# Playbook Commands
update: up ## Run k3s-update.yml playbook
	docker compose exec ansible ansible-playbook playbooks/k3s-update.yml $(ARGS)

update-check: up ## Run k3s-update.yml in check mode (dry-run)
	docker compose exec ansible ansible-playbook playbooks/k3s-update.yml --check

update-workers: up ## Update only worker nodes
	docker compose exec ansible ansible-playbook playbooks/k3s-update.yml --limit k3s_workers

update-cp: up ## Update only control plane
	docker compose exec ansible ansible-playbook playbooks/k3s-update.yml --limit k3s_control_plane

update-bastion: up ## Update only bastion
	docker compose exec ansible ansible-playbook playbooks/k3s-update.yml --limit k3s_bastion

reboot: up ## Reboot all nodes that require it (with k8s drain/uncordon)
	docker compose exec ansible ansible-playbook playbooks/k3s-reboot.yml

reboot-check: up ## Check which nodes need rebooting
	docker compose exec ansible ansible-playbook playbooks/k3s-reboot.yml --check --tags check

common: up ## Run k3s-common.yml playbook
	docker compose exec ansible ansible-playbook playbooks/k3s-common.yml $(ARGS)

playbook: up ## Run custom playbook (make playbook PLAY=myplaybook.yml ARGS="--check")
	docker compose exec ansible ansible-playbook $(PLAY) $(ARGS)

# Utility Commands
install-collections: up ## Install Ansible collections from requirements.yml
	docker compose exec ansible ansible-galaxy collection install -r collections/requirements.yml

list-collections: up ## List installed Ansible collections
	docker compose exec ansible ansible-galaxy collection list

lint: ## Run ansible-lint on all playbooks
	docker compose run --rm lint

facts: up ## Gather facts from all k3s nodes
	docker compose exec ansible ansible k3s_cluster -m setup $(ARGS)

uptime: up ## Check uptime on all k3s nodes
	docker compose exec ansible ansible k3s_cluster -m command -a "uptime" $(ARGS)

disk: up ## Check disk usage on all k3s nodes
	docker compose exec ansible ansible k3s_cluster -m command -a "df -h" $(ARGS)

# Cleanup
clean: down ## Stop containers and clean up volumes
	docker compose down -v

rebuild: clean build up ## Rebuild and restart everything

# Quick access to common tasks
check-reboot: up ## Check if any nodes need reboot
	docker compose exec ansible ansible k3s_cluster -m command -a "test -f /var/run/reboot-required && echo REBOOT_REQUIRED || echo NO_REBOOT_NEEDED" $(ARGS)

k3s-status: up ## Check k3s service status on all nodes
	docker compose exec ansible ansible k3s_control_plane -m command -a "systemctl status k3s --no-pager" $(ARGS)
	docker compose exec ansible ansible k3s_workers -m command -a "systemctl status k3s-agent --no-pager" $(ARGS)

hypervisor-report: up ## Gather hypervisor maintenance report for zlab
	docker compose exec ansible ansible-playbook -i inventory/hypervisors.yml playbooks/hypervisor-maint.yml $(ARGS)

hypervisor-autostart: up ## Enable autostart for critical hypervisor guests
	docker compose exec ansible ansible-playbook -i inventory/hypervisors.yml playbooks/hypervisor-maint.yml -e hypervisor_enforce_critical_autostart=true $(ARGS)

hypervisor-reboot: up ## Reboot hypervisors after manual-human outage checks
	docker compose exec ansible ansible-playbook -i inventory/hypervisors.yml playbooks/hypervisor-reboot.yml $(ARGS)
