# Ansible Configuration Management

Ansible repository for managing infrastructure across multiple environments, running in Docker for consistency and portability.

## Current Setup

### k3s Cluster Management

This repository manages the k3s cluster VMs from the `kubernetes-platform-infrastructure` project.

#### Cluster Inventory

**Nodes:**
- `k3s-cp-01` (192.168.122.10) - Control Plane
- `k3s-worker-01` (192.168.122.11) - Worker Node
- `k3s-worker-02` (192.168.122.12) - Worker Node
- `k3s-bastion-01` (192.168.122.13) - Bastion/Management Node

**Network:** 192.168.122.0/24 (libvirt default network)

## Prerequisites

- Docker and Docker Compose installed
- SSH key at `~/.ssh/id_rsa` for accessing k3s VMs
- Network access to 192.168.122.0/24 (libvirt network)

## Quick Start

```bash
# 1. Build the Ansible container
make build

# 2. Add k3s hosts to known_hosts (first time only)
make add-hosts

# 3. Test connectivity to k3s cluster
make ping

# 4. Update all cluster nodes
make update

# 5. Apply common configuration
make common
```

**Important:** Run `make add-hosts` before your first connection to securely add SSH host keys. See [SECURITY.md](SECURITY.md) for security hardening details.

## Makefile Commands

Run `make help` to see all available commands:

### Container Management
- `make build` - Build the Ansible container
- `make up` - Start the container in detached mode
- `make down` - Stop and remove the container
- `make shell` - Open a bash shell in the container
- `make rebuild` - Clean rebuild everything

### Testing & Inventory
- `make add-hosts` - Add k3s hosts to SSH known_hosts (first time setup)
- `make ping` - Test connectivity to k3s cluster nodes
- `make ping-all` - Test connectivity to all hosts (including bastion)
- `make inventory` - Show inventory graph
- `make inventory-list` - Show detailed inventory as JSON

### System Updates
- `make update` - Update all cluster nodes (serial, one at a time)
- `make update-check` - Dry-run of updates (check mode)
- `make update-workers` - Update only worker nodes
- `make update-cp` - Update only control plane
- `make update-bastion` - Update only bastion

### Configuration
- `make common` - Apply common role to all k3s nodes
- `make playbook PLAY=myplaybook.yml` - Run custom playbook
- `make install-collections` - Install Ansible Galaxy collections

### Monitoring & Troubleshooting
- `make uptime` - Check uptime on all k3s nodes
- `make disk` - Check disk usage on all k3s nodes
- `make facts` - Gather facts from all nodes
- `make check-reboot` - Check if any nodes need reboot
- `make k3s-status` - Check k3s service status

### Development
- `make lint` - Run ansible-lint on all playbooks

## Directory Structure

```
.
├── Dockerfile                  # Ansible container image
├── docker-compose.yml          # Docker Compose configuration
├── Makefile                    # Convenience commands
├── ansible.cfg                 # Ansible configuration
├── inventory/
│   └── k3s-cluster.yml        # k3s cluster inventory
├── group_vars/
│   ├── all.yml                # Global variables
│   └── k3s_cluster.yml        # k3s cluster group variables
├── host_vars/
│   ├── k3s-cp-01.yml          # Control plane host variables
│   ├── k3s-worker-01.yml      # Worker 1 host variables
│   ├── k3s-worker-02.yml      # Worker 2 host variables
│   └── k3s-bastion-01.yml     # Bastion host variables
├── roles/                      # Ansible roles
│   ├── common/                # Base system configuration
│   ├── apache/
│   ├── nfs-server/
│   └── ...
├── k3s-update.yml             # System updates for k3s cluster
├── k3s-common.yml             # Apply common role to k3s cluster
├── web-server.yml             # Apache web server playbook
├── nfs-server.yml             # NFS server playbook
└── ...
```

## Detailed Usage

### System Updates

```bash
# Standard update (one node at a time for safety)
make update

# Update with auto-reboot enabled
make update ARGS="-e auto_reboot=true"

# Update with check mode (dry-run)
make update-check

# Update specific nodes
make update ARGS="--limit k3s-worker-01,k3s-worker-02"

# Update workers in parallel (2 at a time)
make update ARGS="-e update_serial=2 --limit k3s_workers"

# Update with specific tags
make update ARGS="--tags upgrade"
make update ARGS="--skip-tags reboot"
```

### Running Ad-hoc Commands

```bash
# Open a shell in the container
make shell

# Inside the container:
ansible k3s_cluster -m command -a "systemctl status k3s-server"
ansible k3s_workers -m systemd -a "name=k3s-agent state=restarted"
ansible all -m shell -a "cat /etc/os-release"

# Or from outside:
make exec CMD="ansible k3s_cluster -m command -a 'uptime'"
```

### Custom Playbooks

```bash
# Run a custom playbook
make playbook PLAY=my-custom-playbook.yml

# With additional arguments
make playbook PLAY=my-custom-playbook.yml ARGS="--check --diff"

# Or enter the shell and run directly
make shell
ansible-playbook my-custom-playbook.yml --check
```

## Configuration Variables

Key variables in `group_vars/k3s_cluster.yml`:

- `k3s_version`: v1.34.3+k3s1
- `k3s_api_server`: https://192.168.122.10:6443
- `auto_reboot`: false (default)
- `update_cache_valid_time`: 3600 (seconds)
- `ntp_servers`: Ubuntu pool NTP servers
- `common_packages`: Standard packages to install

## SSH Access

All nodes use:
- **User:** ubuntu
- **Key:** ~/.ssh/id_rsa (mounted from host into container)
- **Port:** 22 (default)

The container mounts your `~/.ssh` directory as read-only to `/root/.ssh` in the container.

## Safety Features

### Update Playbook
- **Serial execution:** Updates run on one node at a time by default to maintain cluster availability
- **No auto-reboot:** Reboots require explicit `auto_reboot=true` flag
- **Check mode:** Test changes with `--check` before applying
- **Reboot detection:** Automatically detects when reboot is required

### Container Isolation
- Ansible runs in isolated container with specific versions
- Host network mode for direct access to k3s VMs
- Read-only SSH key mount for security
- Persistent volumes for facts cache and collections

## Troubleshooting

### Container won't start
```bash
# Rebuild from scratch
make rebuild

# Check container logs
docker compose logs ansible
```

### Can't reach k3s VMs
```bash
# Test from host first
ping 192.168.122.10

# Test from container
make shell
ping 192.168.122.10

# Verify network mode
docker compose ps
# Should show "network_mode: host"
```

### SSH key issues
```bash
# Verify SSH key exists on host
ls -la ~/.ssh/id_rsa

# Test SSH manually from container
make shell
ssh -i /root/.ssh/id_rsa ubuntu@192.168.122.10
```

### Collection not found
```bash
# Install collections
make install-collections

# Or manually
make shell
ansible-galaxy collection install -r collections/requirements.yml
```

## CI/CD Integration

The repository includes ansible-lint for CI/CD pipelines:

```bash
# Run linting locally
make lint

# In CI/CD (GitHub Actions example)
docker compose run --rm lint
```

## Other Playbooks

See individual playbook files for other configurations:
- `web-server.yml` - Apache web server
- `nfs-server.yml` - NFS server setup
- `ufw.yml` - Firewall configuration
- `lvm.yml` - LVM management

## Alternative: Local Installation

If you prefer to run Ansible locally instead of in Docker:

```bash
# Install Ansible
pip install ansible

# Install collections
ansible-galaxy collection install -r collections/requirements.yml

# Run playbooks directly
ansible-playbook k3s-update.yml
ansible k3s_cluster -m ping
```

Note: The Makefile commands won't work with local installation. Use `ansible` and `ansible-playbook` commands directly.
