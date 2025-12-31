# Forgejo Service Configuration

This module provides a NixOS configuration for running [Forgejo](https://forgejo.org/), a self-hosted Git forge.

## Features

- Git repository hosting with SSH and HTTP(S) access
- Forgejo Actions for CI/CD (optional)
- Package registry support (optional)
- Git LFS support (optional)
- ActivityPub federation (optional)
- PostgreSQL database backend
- Tailscale integration for secure remote access
- Automated backups via PostgreSQL backup system

## Configuration Options

### Basic Configuration

```nix
services.clubcotton.forgejo = {
  enable = true;
  port = 3000;              # HTTP port
  sshPort = 2222;           # SSH port for git operations
  domain = "forgejo.lan";   # Domain name
  customPath = "/ssdpool/local/forgejo";  # Data storage path
  tailnetHostname = "forgejo";  # Tailscale hostname (null to disable)

  database = {
    enable = true;
    passwordFile = config.age.secrets."forgejo-database".path;
  };

  features = {
    actions = true;      # Enable CI/CD
    packages = true;     # Enable package registry
    lfs = true;          # Enable Git LFS
    federation = false;  # Enable ActivityPub
  };
};
```

### PostgreSQL Integration

The Forgejo service can use either:

1. **Embedded PostgreSQL** (default for single-node deployments)
   - Managed by the Forgejo service module
   - Database created automatically
   - Suitable for testing and standalone installations

2. **Centralized PostgreSQL** (recommended for production)
   - Managed by `services.clubcotton.postgresql` module
   - Shared database server with other services
   - Automated backups and monitoring
   - Better resource utilization

To use the centralized PostgreSQL module:

```nix
services.clubcotton.postgresql = {
  enable = true;
  forgejo = {
    enable = true;
    passwordFile = config.age.secrets."forgejo-database".path;
  };
};

services.clubcotton.forgejo = {
  enable = true;
  database = {
    enable = true;
    passwordFile = config.age.secrets."forgejo-database".path;
  };
  # ... other options
};
```

## Secret Management

### Required Secrets

You need to create an age-encrypted secret for the Forgejo database password.

### Creating the Database Password Secret

1. **Generate a strong password:**
   ```bash
   openssl rand -base64 32
   ```

2. **Create the secret file:**
   ```bash
   # Create a temporary file with just the password (no newline)
   echo -n "YOUR_GENERATED_PASSWORD" > /tmp/forgejo-db-password
   ```

3. **Encrypt with agenix:**
   ```bash
   # From your nix-config repository root
   cd secrets

   # Edit secrets.nix to add the new secret definition
   # Add this to the secrets list:
   "forgejo-database.age" = {
     publicKeys = [ yourUserKey yourHostKey ];
   };

   # Create the encrypted secret
   agenix -e forgejo-database.age
   # Paste the password when the editor opens, save and exit
   ```

4. **Reference in your host configuration:**
   ```nix
   age.secrets."forgejo-database" = {
     file = ../../../secrets/forgejo-database.age;
     mode = "0440";
     owner = "forgejo";
     group = "postgres";
   };
   ```

5. **Clean up the temporary file:**
   ```bash
   rm /tmp/forgejo-db-password
   ```

### Secret Requirements

- The secret file should contain only the password (no trailing newline)
- File permissions will be managed by agenix
- The secret must be readable by both the `forgejo` user and `postgres` group
- Use a strong, randomly generated password (at least 32 characters)

## Storage Configuration

### Default Storage Layout

When using `customPath`, Forgejo creates the following directory structure:

```
/ssdpool/local/forgejo/
├── repositories/    # Git repositories
├── lfs/            # Large File Storage objects
├── data/           # Application data
└── packages/       # Package registry artifacts
```

### ZFS Configuration Example

For optimal performance with ZFS:

```nix
clubcotton.zfs_raidz1.ssdpool = {
  filesystems = {
    "local/forgejo" = {
      mountpoint = "/ssdpool/local/forgejo";
      options = {
        compression = "lz4";
        atime = "off";
        quota = "200G";
      };
    };
  };
};
```

## Firewall Configuration

The module automatically opens the required ports:
- HTTP port (default: 3000)
- SSH port (default: 2222)

## Service Dependencies

The Forgejo service will automatically:
- Wait for PostgreSQL to be ready (when `database.enable = true`)
- Start after network is available
- Wait for Tailscale (when `tailnetHostname` is configured)

## Testing

Three test suites are available:

1. **Service Test** - Tests basic Forgejo functionality with embedded PostgreSQL
   ```bash
   nix build '.#checks.x86_64-linux.forgejo'
   ```

2. **Runner Test** - Tests Forgejo Actions runner integration
   ```bash
   nix build '.#checks.x86_64-linux.forgejo-runner'
   ```

3. **PostgreSQL Integration Test** - Tests Forgejo with centralized PostgreSQL
   ```bash
   nix build '.#checks.x86_64-linux.postgresql-integration'
   ```

## Initial Setup

After deployment:

1. Access Forgejo web interface at `http://YOUR_DOMAIN:PORT`
2. Complete the initial setup wizard (most settings are pre-configured)
3. Create the first admin user
4. Configure runner registration tokens (if using Actions)

## Backup and Recovery

### Automatic Backups

When using the centralized PostgreSQL module, database backups are handled automatically:
- Daily backups to `/backups/postgresql/`
- Retention managed by `services.postgresqlBackup`

### Manual Backup

```bash
# Backup database
sudo -u postgres pg_dump forgejo > forgejo-backup.sql

# Backup repositories and data
sudo tar -czf forgejo-data-backup.tar.gz /ssdpool/local/forgejo/
```

### Recovery

```bash
# Restore database
sudo -u postgres psql forgejo < forgejo-backup.sql

# Restore data
sudo tar -xzf forgejo-data-backup.tar.gz -C /
```

## Monitoring

When using the centralized PostgreSQL module, monitoring is included:
- Prometheus PostgreSQL exporter for database metrics
- Backup monitoring and alerting
- Service health checks

## Troubleshooting

### Service Won't Start

Check logs:
```bash
journalctl -u forgejo.service -f
```

Common issues:
- Database connection failed: Check password file and PostgreSQL status
- Port already in use: Verify no other service is using the configured ports
- Permission errors: Check directory ownership and secret file permissions

### Database Connection Issues

```bash
# Check PostgreSQL is running
systemctl status postgresql

# Test database connection
sudo -u forgejo psql -h localhost -U forgejo -d forgejo

# Check password file exists and is readable
sudo -u forgejo cat /path/to/password/file
```

### Actions Not Working

1. Ensure Actions are enabled in features
2. Check runner registration token is valid
3. Verify runner service is running
4. Check runner can reach Forgejo server

## Security Considerations

1. **Use strong passwords** for database access
2. **Enable HTTPS** for production deployments
3. **Restrict registration** (`DISABLE_REGISTRATION = true` by default)
4. **Use Tailscale** for secure remote access
5. **Regular backups** of both database and repositories
6. **Keep Forgejo updated** to latest stable version

## References

- [Forgejo Documentation](https://forgejo.org/docs/)
- [NixOS Forgejo Module](https://search.nixos.org/options?query=services.forgejo)
- [PostgreSQL Module Documentation](../../../modules/postgresql/README.md)
