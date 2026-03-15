# Ansible Configuration Management

Ansible repository for managing infrastructure across multiple environments, running in Docker for consistency and portability.

Repository Category: `infrastructure` (see [platform-docs/_platform/REPO_TAXONOMY.md](https://github.com/zavestudios/platform-docs/blob/main/_platform/REPO_TAXONOMY.md))

Documentation authority boundary:
- This repository documents implementation and operations for Ansible-managed infrastructure behavior.
- Platform governance, lifecycle, and contract doctrine remain authoritative in [platform-docs/_platform/](https://github.com/zavestudios/platform-docs/tree/main/_platform).

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
- k3s VMs already provisioned by [kubernetes-platform-infrastructure/terraform-libvirt](https://github.com/zavestudios/kubernetes-platform-infrastructure/tree/main/terraform-libvirt)
- A dedicated SSH key for automation, matching the key injected during VM provisioning
- Update [ansible.cfg](./ansible.cfg) and [group_vars/k3s_cluster.yml](./group_vars/k3s_cluster.yml) if you use a key name other than `~/.ssh/ansible_ed25519`
- Choose a connection mode that matches where you run Ansible:
  - `ssh_config` from a laptop or management workstation
  - `proxyjump` from a laptop without relying on SSH host aliases
  - `direct` from the hypervisor host

## Execution Environment

This repository supports both laptop-managed and hypervisor-local operation.

- The k3s VMs live on `192.168.122.0/24`, which is a private libvirt network.
- From a laptop, the canonical path is SSH-based access using the KPI bastion/jump configuration.
- From the hypervisor, direct access to the node IPs is acceptable.
- `docker-compose.yml` uses `network_mode: host`, so the container shares the network stack of the machine where you run this repo.
- The container mounts the host `~/.ssh` directory read-only and expects the configured automation key to already work against the VMs.

### Connection Modes

`ssh_config` is the default and recommended mode when running from a laptop. It uses inventory hostnames such as `k3s-cp-01` and expects your SSH client config to define how to reach them. This aligns with KPI's [config-templates/ssh-config.example](https://github.com/zavestudios/kubernetes-platform-infrastructure/blob/main/config-templates/ssh-config.example).

`proxyjump` is the explicit alternative when you do not want to depend on SSH host aliases:

```bash
make ping ARGS="-e k3s_connection_mode=proxyjump -e k3s_hypervisor_ssh_user=$USER -e k3s_hypervisor_ssh_host=<hypervisor-ip>"
```

`direct` is for running on the hypervisor itself, where `192.168.122.0/24` is directly reachable:

```bash
make ping ARGS="-e k3s_connection_mode=direct"
```

## Quick Start

```bash
# 1. Build the Ansible container
make build

# 2. Configure SSH reachability
# Laptop path: install KPI ssh config entries for k3s-* hosts
# Hypervisor path: use direct mode

# 3. Test connectivity to k3s cluster
make ping

# 4. Or, from hypervisor-local mode:
make ping ARGS="-e k3s_connection_mode=direct"

# 5. Update all cluster nodes
make update

# 6. Apply common configuration
make common
```

**Important:** `make add-hosts` only applies to `direct` mode. In `ssh_config` mode, follow the KPI SSH config pattern instead.

## Makefile Commands

Run `make help` to see all available commands:

### Container Management
- `make build` - Build the Ansible container
- `make up` - Start the container in detached mode
- `make down` - Stop and remove the container
- `make shell` - Open a bash shell in the container
- `make rebuild` - Clean rebuild everything

### Testing & Inventory
- `make add-hosts` - Add k3s hosts to SSH known_hosts for `direct` mode
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
- `make perf-diag` - Gather host-side performance diagnostics from k3s nodes and bastion
- `make playbook PLAY=myplaybook.yml` - Run custom playbook
- `make install-collections` - Install Ansible Galaxy collections

### Monitoring & Troubleshooting
- `make uptime` - Check uptime on all k3s nodes
- `make disk` - Check disk usage on all k3s nodes
- `make facts` - Gather facts from all nodes
- `make check-reboot` - Check if any nodes need reboot
- `make k3s-status` - Check k3s service status
- `make hypervisor-report` - Gather pre-maintenance facts from `zlab`
- `make hypervisor-autostart` - Enable autostart for critical hypervisor guests
- `make hypervisor-reboot` - Reboot `zlab` after manual-human outage confirmation

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
│   ├── hypervisors.yml        # Hypervisor inventory
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
│   ├── perf_diag/             # Host-side performance diagnostics
│   ├── apache/
│   ├── nfs-server/
│   └── ...
├── playbooks/
│   ├── k3s-update.yml         # System updates for k3s cluster
│   ├── k3s-common.yml         # Apply common role to k3s cluster
│   ├── perf-diag.yml          # Host-side performance diagnostics
│   ├── web-server.yml         # Apache web server playbook
│   └── nfs-server.yml         # NFS server playbook
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

### Performance Diagnostics

```bash
# Gather diagnostics from all k3s nodes and bastion
make perf-diag

# Limit diagnostics to one or more hosts
make perf-diag ARGS="--limit k3s-cp-01,k3s-bastion-01"

# Reduce journal output
make perf-diag ARGS="-e perf_diag_k3s_journal_lines=10"
```

The diagnostics playbook is host-side only. It reports uptime, CPU count, load average, memory, filesystem usage, and, where applicable, `k3s` or `k3s-agent` service state plus recent journal output. It does not use `kubectl`.

### Hypervisor Maintenance Report

```bash
# Gather host and libvirt pre-maintenance facts from zlab
make hypervisor-report

# Explicitly enable autostart for critical guests
make hypervisor-autostart

# Reboot zlab after manual-human outage confirmation
make hypervisor-reboot
```

The hypervisor maintenance report is inspection-only. It summarizes reboot-required state, load, memory, swap, temperature output, defined and running guests, critical guest autostart state, libvirt networks, and storage pools.

It also reports:
- critical guests that are still missing `autostart`
- non-critical guests that are still running
- recommended shutdown and startup order for a planned hypervisor maintenance window
- manual-human Kubernetes outage checkpoints for a full hypervisor reboot

`make hypervisor-autostart` is the explicit mutation path. It enables `autostart` for the critical guests listed in the role defaults and then refreshes the report so you can verify the new state.

`make hypervisor-reboot` performs the infrastructure reboot step after a manual-human confirmation gate. It does not run `kubectl`; it pauses for manual outage confirmation before reboot and reminds you to run the post-recovery Kubernetes checks afterward.

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

Most ad-hoc targets accept `ARGS`, so you can switch connection modes without editing tracked files:

```bash
make ping ARGS="-e k3s_connection_mode=proxyjump -e k3s_hypervisor_ssh_user=$USER -e k3s_hypervisor_ssh_host=<hypervisor-ip>"
make facts ARGS="-e k3s_connection_mode=direct"
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

Key variables in [group_vars/k3s_cluster.yml](./group_vars/k3s_cluster.yml):

- `k3s_version`: v1.34.3+k3s1
- `k3s_api_server`: https://192.168.122.10:6443
- `auto_reboot`: false (default)
- `update_cache_valid_time`: 3600 (seconds)
- `ntp_servers`: Ubuntu pool NTP servers
- `common_packages`: Standard packages to install

## SSH Access

All nodes use:
- **User:** ubuntu
- **Key:** `~/.ssh/ansible_ed25519` by default, unless you override it in [ansible.cfg](./ansible.cfg) and [group_vars/k3s_cluster.yml](./group_vars/k3s_cluster.yml)
- **Port:** 22 (default)

The container mounts your `~/.ssh` directory as read-only to `/root/.ssh` in the container.

The inventory keeps stable host identities and stores node IPs in host vars. Connection routing is controlled by:

- `k3s_connection_mode`
- `k3s_hypervisor_ssh_user`
- `k3s_hypervisor_ssh_host`

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
# Laptop-managed path
ssh k3s-cp-01 'hostname'
make ping

# Explicit ProxyJump path
make ping ARGS="-e k3s_connection_mode=proxyjump -e k3s_hypervisor_ssh_user=$USER -e k3s_hypervisor_ssh_host=<hypervisor-ip>"

# Hypervisor-local path
make ping ARGS="-e k3s_connection_mode=direct"
```

### SSH key issues
```bash
# Verify SSH key exists on host
ls -la ~/.ssh/ansible_ed25519

# Test SSH manually from container
make shell
ssh -i /root/.ssh/ansible_ed25519 ubuntu@192.168.122.10
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

## Performance Diagnostics

The `k3s-performance-diagnostics.yml` playbook uses osquery to gather comprehensive performance metrics from all cluster nodes.

### What it collects:
- **Memory**: Total, free, used, buffers, cached
- **CPU**: Load average, CPU time per core
- **Processes**: Top 10 by memory and CPU usage
- **Disk**: Disk info, mount points, usage statistics
- **Network**: Interface statistics, bytes/packets transferred
- **Ports**: All listening ports with associated processes
- **Uptime**: System uptime and boot time

### Usage:
```bash
make perf-diag
```

### Output:
Diagnostics are saved to `/tmp/k3s-diagnostics/` with detailed reports for each node:
```
/tmp/k3s-diagnostics/k3s-cp-01_1234567890.txt
/tmp/k3s-diagnostics/k3s-worker-01_1234567890.txt
/tmp/k3s-diagnostics/k3s-worker-02_1234567890.txt
```

Each report contains JSON-formatted osquery results for analysis.

### Use Cases:
- Investigating cluster performance issues
- Baseline performance documentation
- Capacity planning
- Troubleshooting slow pod startups or application performance

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
ansible-playbook playbooks/k3s-update.yml
ansible k3s_cluster -m ping
```

Note: The Makefile commands won't work with local installation. Use `ansible` and `ansible-playbook` commands directly.
