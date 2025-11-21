# Homelab Documentation

This directory contains detailed documentation for applications and services running in the homelab cluster.

## Available Documentation

### Applications

- **[WriteFreely](writefreely.md)** - Blogging platform at write.pane.run
  - **[Quick Start Guide](writefreely-quickstart.md)** - Get started in 5 minutes
  - **[Deployment Summary](deployment-summary-writefreely.md)** - WriteFreely deployment details
  - User management, backup/restore, configuration, troubleshooting

- **[Zitadel](deployment-summary-zitadel.md)** - OIDC/OAuth2 identity provider at zitadel.pane.run
  - Deployment configuration and setup
  - Database and Redis integration

### Infrastructure

- **[OAuth2-Proxy Guide](oauth2-proxy-guide.md)** - Comprehensive authentication setup guide
  - **[Reverse Proxy Mode](oauth2-proxy-reverse-proxy-mode.md)** - Detailed reverse proxy mode setup
  - **[Authentication Setup Complete](authentication-setup-complete.md)** - Authentication architecture overview

- **[Traefik externalIPs Migration](traefik-externalips-migration.md)** - Traefik networking architecture
  - How externalIPs work with Kubernetes networking
  - Migration from hostNetwork to externalIPs

- **[Prometheus Talos Fix](prometheus-talos-fix.md)** - Talos-specific Prometheus configuration
  - Running Prometheus as root on Talos Linux
  - Security context configuration

- **[Backup Procedures](backup-procedures.md)** - Comprehensive backup and recovery procedures
  - PostgreSQL, WriteFreely, and cluster-wide backups

## Quick Links

### Active Applications

| Application | URL | Purpose | Documentation |
|------------|-----|---------|---------------|
| **Zitadel** | https://zitadel.pane.run | OIDC/OAuth2 Identity Provider | [deployment-summary-zitadel.md](deployment-summary-zitadel.md) |
| **WriteFreely** | https://write.pane.run | Multi-user blogging platform | [writefreely.md](writefreely.md) |
| **Portainer** | https://portainer.pane.run | Container management UI | - |
| **Headlamp** | https://headlamp.pane.run | Modern Kubernetes dashboard | - |
| **Kubernetes Dashboard** | https://k8s.pane.run | Official K8s dashboard | - |
| **Grafana** | https://grafana.pane.run | Metrics visualization (admin / prom-operator) | [prometheus-talos-fix.md](prometheus-talos-fix.md) |
| **Whoami** | https://whoami.pane.run | Test app (OAuth2-Proxy demo) | [oauth2-proxy-reverse-proxy-mode.md](oauth2-proxy-reverse-proxy-mode.md) |
| **Traefik Dashboard** | https://traefik.pane.run | Ingress controller dashboard (if enabled) | [traefik-externalips-migration.md](traefik-externalips-migration.md) |

### Infrastructure Details

- **Kubernetes**: v1.34.1 (single-node cluster)
- **Talos Linux**: v1.11.5
- **PostgreSQL 16**: 50Gi (used by Zitadel)
- **PostgreSQL 18**: 8Gi (general purpose)
- **Redis**: 8Gi (used by Zitadel)
- **Storage**: ~199Gi total persistent storage

## Backup Scripts

Automated backup scripts are located in `~/homelab/scripts/`:

- `backup-writefreely.sh` - Backup WriteFreely database and keys

### Running Backups

```bash
# WriteFreely backup
~/homelab/scripts/backup-writefreely.sh

# Backups are stored in:
~/homelab/backups/writefreely/
```

## Documentation Standards

When adding new applications, please create documentation that includes:

1. **Overview** - What the application is and does
2. **Access Information** - URLs, credentials, configuration
3. **Architecture** - Components, resources, storage
4. **Operations** - Common tasks, monitoring, logs
5. **Backup/Restore** - How to backup and restore data
6. **Troubleshooting** - Common issues and solutions
7. **Security** - Security considerations and best practices

## Contributing

When deploying new applications, please:

1. Create comprehensive documentation in `docs/<app-name>.md`
2. Update this README with a link
3. Add backup scripts if needed
4. Update main `CLAUDE.md` repository structure

---

**Last Updated**: 2025-11-20
