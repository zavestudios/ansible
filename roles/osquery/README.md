# Osquery Role

Installs [osquery](https://osquery.io/) on Debian/Ubuntu systems.

## What is osquery?

osquery is Facebook's open-source tool that allows you to query your operating system using SQL. It exposes the OS as a high-performance relational database, making it easy to collect system information, monitor processes, network connections, hardware details, and more.

## Role Behavior

This role:
- Checks if osquery is already installed
- Downloads the osquery `.deb` package from pkg.osquery.io
- Verifies the package checksum (SHA256)
- Installs osquery via apt

## Variables

Defined in `defaults/main.yml`:

```yaml
osquery_version: 5.10.2-1:w
osquery_dpkg_url: "https://pkg.osquery.io/deb/osquery_{{ osquery_version }}.linux_amd64.deb"
osquery_dpkg_sha: sha256:65298f8320df25236bf212227e0f1f429c4019385c9c8576f7bad0a2c605cf5c
```

## Example Usage

### In a playbook:

```yaml
- hosts: all
  become: true
  roles:
    - role: osquery
```

### Running osquery queries:

After installation, you can query system information using SQL:

```bash
# Interactive mode
osqueryi

# Run a query
osqueryi "SELECT * FROM system_info"

# JSON output
osqueryi --json "SELECT * FROM processes LIMIT 5"
```

### Common Queries

```sql
-- Memory information
SELECT * FROM memory_info;

-- CPU load average
SELECT * FROM load_average;

-- Top processes by memory
SELECT pid, name, resident_size
FROM processes
ORDER BY resident_size DESC
LIMIT 10;

-- Listening network ports
SELECT port, protocol, processes.name
FROM listening_ports
JOIN processes USING (pid)
WHERE port != 0;

-- Disk usage
SELECT * FROM mounts;
```

## Performance Diagnostics

See `playbooks/k3s-performance-diagnostics.yml` for a comprehensive performance diagnostics playbook that uses osquery to gather system metrics across the cluster.

Run with:
```bash
make perf-diag
```

## Security

- Package downloads use HTTPS
- SHA256 checksum verification enabled
- SSL/TLS certificate validation enforced

## Requirements

- Debian/Ubuntu system
- Internet access to pkg.osquery.io

## References

- [osquery documentation](https://osquery.io/docs/)
- [osquery schema](https://osquery.io/schema/)
- [Package downloads](https://pkg.osquery.io/deb/)
