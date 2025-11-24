# Security First-Boot Role

Prepares VM golden images with first-boot installation scripts for security tools required by Princeton University. The tools are **not installed during image build** but are configured to install automatically on first boot via systemd oneshot services.

## Overview

The role installs three security monitoring/management agents:

1. **BigFix** - Endpoint management and patch compliance
2. **Rapid7 Insight Agent** - Vulnerability management and monitoring
3. **Palo Alto Cortex XDR** - Endpoint detection and response (EDR)

Each agent has its own systemd oneshot service that runs once during the first boot of a VM instance (triggered by `cloud-final.service`). After successful installation, a marker file is created to prevent re-installation.

## How It Works

### Build Time (Packer/Ansible)
- Creates `/var/lib/security-firstboot/` for state markers
- Creates `/etc/pul/security-tools.env` (empty template - populated by cloud-init)
- Installs bash scripts to `/usr/local/sbin/`:
  - `bigfix-firstboot.sh`
  - `rapid7-firstboot.sh`
  - `cortex-xdr-firstboot.sh`
- Installs systemd oneshot units to `/etc/systemd/system/`:
  - `bigfix-firstboot.service`
  - `rapid7-firstboot.service`
  - `cortex-xdr-firstboot.service`
- Configures firewall rules (UFW on Debian/Ubuntu, firewalld on RHEL/Rocky)
- Installs and configures fail2ban

### First Boot (Cloud-Init)
1. Cloud-init populates `/etc/pul/security-tools.env` with secrets/URLs from user-data
2. Systemd triggers `cloud-final.service`
3. Each firstboot service runs its installation script:
   - Downloads agent packages from internal mirrors or external sources
   - Installs configuration files
   - Installs the agent package
   - Enables and starts the agent service
   - Creates marker file (e.g., `/var/lib/security-firstboot/bigfix.done`)
4. Marker file prevents re-installation on subsequent boots

## Required Environment Variables

These variables should be provided via cloud-init user-data and will be written to `/etc/pul/security-tools.env`:

### BigFix
- `BIGFIX_MASTHEAD_URL` - URL to download the masthead file (actionsite.afxm)
- OR `BIGFIX_MASTHEAD_B64` - Base64-encoded masthead content

### Rapid7
- `RAPID7_TOKEN` - Activation token for the Insight Agent
- `RAPID7_ATTRIBUTES` - Optional attributes (default: "Library Systems")

### Cortex XDR
- `CORTEX_XDR_TARBALL_URL` - URL to download the Cortex XDR installation tarball

## Cortex XDR Installation Details

The Cortex XDR agent installation follows the manual process documented in the vendor README:

1. **Configuration**: The installation tarball must contain a `cortex.conf` file which is copied to `/etc/panw/`
2. **Package Installation**: The tarball contains RPM packages that are installed via dnf/yum
3. **Service Activation**: After installation, the agent service (typically `cytool.service`) is enabled and started

### Cortex XDR Package Format

The expected tarball structure (as from Princeton's mirror):
```
Linux-11062025_rpm.tar.gz
├── cortex.conf          # Agent configuration
├── README.md           # Vendor installation instructions
└── *.rpm               # Agent RPM package(s)
```

### Manual Installation Reference

For reference, the manual installation steps that this role automates:

```bash
# Download and extract
wget http://pulmirror.princeton.edu/mirror/palo/greenfield/Linux-11062025_rpm.tar.gz
tar xzvf Linux-11062025_rpm.tar.gz

# Configure
sudo mkdir -p /etc/panw
sudo cp ./cortex.conf /etc/panw/

# Install (RPM-based systems)
sudo dnf install ./*.rpm
# OR
sudo yum install ./*.rpm
```

## Role Variables

### defaults/main.yml

```yaml
# Enable/disable the role
prepare_security_firstboot: true

# Security tools environment file location
security_env_file: /etc/pul/security-tools.env

# BigFix package URLs
bigfix_deb_url: "https://software.bigfix.com/download/bes/100/BESAgent-10.0.7.52-debian6.amd64.deb"
bigfix_rpm_url: "https://software.bigfix.com/download/bes/100/BESAgent-10.0.7.52-rhe6.x86_64.rpm"
bigfix_gpg_key_url: "https://software.bigfix.com/download/bes/95/RPM-GPG-KEY-BigFix-9-V2"

# Rapid7 package URLs
rapid7_deb_url: "https://us.storage.endpoint.ingress.rapid7.com/..."
rapid7_rpm_url: "https://us.storage.endpoint.ingress.rapid7.com/..."
rapid7_rpm_pubkey: "https://us.storage.endpoint.ingress.rapid7.com/..."

# Cortex XDR tarball URL
cortex_xdr_tarball_url: "http://pulmirror.princeton.edu/mirror/palo/greenfield/Linux-11062025_rpm.tar.gz"
cortex_xdr_gpg_key_url: ""  # Optional GPG key URL

# Network access control
allowed_admin_cidrs:
  - 10.249.64.0/18
  - 10.249.0.0/18
  - 128.112.0.0/16
  - 172.20.80.0/22
  - 172.20.95.0/24
  - 172.20.192.0/19
  - 10.0.2.0/24  # For local QEMU testing

# Fail2ban settings
fail2ban_backend: systemd
fail2ban_bantime: 1h
fail2ban_findtime: 10m
fail2ban_maxretry: 5
```

## Firewall Configuration

### Debian/Ubuntu (UFW)
- Default incoming: DENY
- Default outgoing: ALLOW
- SSH (port 22) allowed from `allowed_admin_cidrs`
- BigFix (port 52311/tcp) allowed from anywhere
- ICMP redirects blocked via sysctl and iptables

### RHEL/Rocky (firewalld)
- Generic SSH service disabled
- SSH (port 22) allowed via rich rules for `allowed_admin_cidrs`
- BigFix (port 52311/tcp) allowed
- Zone: public

## Fail2ban Configuration

- Backend: systemd (journalctl)
- Ban time: 1 hour
- Find time: 10 minutes (window to count failures)
- Max retry: 5 attempts before ban
- Protected ranges: SSH-allowed CIDRs (never banned)
- Ban action: UFW (Debian) or firewalld rich rules (RHEL)

## Tags

- `firstboot` - First-boot preparation tasks
- `firewall` - Firewall configuration
- `ssh` - SSH-related firewall rules
- `security` - General security hardening
- `fail2ban` - Fail2ban installation and configuration
- `icmp_redirects` - ICMP redirect protection
- `sysctl` - Sysctl kernel parameter tuning

## Example Playbook

```yaml
- hosts: all
  roles:
    - role: security_firstboot
      vars:
        prepare_security_firstboot: true
        cortex_xdr_tarball_url: "http://pulmirror.princeton.edu/mirror/palo/greenfield/Linux-11062025_rpm.tar.gz"
```

## Cloud-Init User-Data Example

```yaml
#cloud-config
write_files:
  - path: /etc/pul/security-tools.env
    owner: root:root
    permissions: '0600'
    content: |
      BIGFIX_MASTHEAD_URL=https://example.com/masthead/actionsite.afxm
      RAPID7_TOKEN=us:abc123def456...
      RAPID7_ATTRIBUTES=Library Systems
      CORTEX_XDR_TARBALL_URL=http://pulmirror.princeton.edu/mirror/palo/greenfield/Linux-11062025_rpm.tar.gz
```

## Testing

### Disable for Local Testing

If you need to test images locally without installing security agents:

```yaml
security_local_test: true
prepare_security_firstboot: false
```

### Verify First-Boot Services

After image build:
```bash
systemctl list-unit-files | grep firstboot
# Should show:
# bigfix-firstboot.service        enabled
# rapid7-firstboot.service        enabled
# cortex-xdr-firstboot.service    enabled
```

Check service status after first boot:
```bash
systemctl status bigfix-firstboot.service
systemctl status rapid7-firstboot.service
systemctl status cortex-xdr-firstboot.service

# Check marker files
ls -l /var/lib/security-firstboot/
```

## Troubleshooting

### First-Boot Script Logs

View logs from the first-boot services:
```bash
journalctl -u bigfix-firstboot.service
journalctl -u rapid7-firstboot.service
journalctl -u cortex-xdr-firstboot.service
```

### Manual Installation Testing

To test a first-boot script manually:
```bash
# Source the env file
source /etc/pul/security-tools.env

# Remove marker to allow re-run
rm /var/lib/security-firstboot/cortex-xdr.done

# Run the script
sudo /usr/local/sbin/cortex-xdr-firstboot.sh
```

### Reset First-Boot State

To force reinstallation on next boot:
```bash
sudo rm /var/lib/security-firstboot/*.done
```

## File Locations

| File/Directory | Purpose |
|----------------|---------|
| `/var/lib/security-firstboot/` | State markers (*.done files) |
| `/etc/pul/security-tools.env` | Environment variables with secrets |
| `/usr/local/sbin/*-firstboot.sh` | Installation scripts |
| `/etc/systemd/system/*-firstboot.service` | Systemd oneshot units |
| `/opt/BESClient/` | BigFix agent installation |
| `/etc/panw/cortex.conf` | Cortex XDR configuration |
| `/opt/CrowdStrike/` | (deprecated - removed in favor of Cortex XDR) |

## Security Considerations

1. **Secrets Management**: All secrets (tokens, URLs) are provided via cloud-init and stored in `/etc/pul/security-tools.env` with 0600 permissions
2. **Network Security**: Firewall rules restrict SSH access to Princeton networks only
3. **Fail2ban**: Automated SSH brute-force protection with IP banning
4. **ICMP Hardening**: ICMP redirects disabled via sysctl and firewall rules
5. **Service Isolation**: Each security tool installs independently; failure of one doesn't affect others

## Dependencies

- `community.general.ufw` (Debian/Ubuntu)
- `ansible.posix.firewalld` (RHEL/Rocky)
- Cloud-init support in the base image
- Network connectivity on first boot for package downloads

## Maintenance

### Updating Package URLs

Edit `defaults/main.yml` to update package URLs when new versions are released:
- BigFix: Update `bigfix_deb_url`, `bigfix_rpm_url`
- Rapid7: Update `rapid7_deb_url`, `rapid7_rpm_url`
- Cortex XDR: Update `cortex_xdr_tarball_url` when new versions are published to pulmirror

### Updating Cortex XDR

When a new Cortex XDR package is available:
1. Download new tarball from Palo Alto
2. Verify it contains `cortex.conf` and RPM packages
3. Upload to Princeton mirror: `http://pulmirror.princeton.edu/mirror/palo/greenfield/`
4. Update `cortex_xdr_tarball_url` in role defaults or override in playbook

## License

Princeton University Library

## Author

DevOps/Infrastructure Team - Princeton University Library
