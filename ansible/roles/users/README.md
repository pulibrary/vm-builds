# Ansible Role: Users

This role manages system users, groups, and SSH access for the Princeton University Library (PUL) virtual machine builds. It handles the creation of administrative users, configures passwordless sudo, and dynamically manages SSH authorized keys.

## Features

* **Pulsys User Management**: Creates a dedicated `pulsys` user with a configurable UID/GID (defaulting to `1050` to avoid cloud-image conflicts).
* **Dynamic SSH Keys**: Pulls authorized keys directly from GitHub profiles for Operations and Library staff.
* **Sudoers Configuration**: Grants passwordless sudo access via `/etc/sudoers.d/`.
* **SSH Hardening**: Manages `AllowUsers` in `sshd_config` during the provisioning phase to ensure connectivity while maintaining security.

## Role Variables

Variables are defined in `defaults/main.yml` and can be overridden in playbooks or inventory.

| Variable | Default | Description |
| :--- | :--- | :--- |
| `pulsys_enabled` | `true` | Whether to create the pulsys administrative user. |
| `pulsys_uid` | `1050` | The UID for the pulsys user. |
| `pulsys_gid` | `1050` | The GID for the pulsys group. |
| `ops_github_keys` | `[...]` | List of GitHub URLs to fetch public keys for Ops staff. |
| `library_github_keys` | `[...]` | List of GitHub URLs to fetch public keys for Library staff. |
| `pulsys_tower_key` | `ssh-ed25519 ...` | The public key for the Ansible Tower/AWX instance. |

## Tags

This role uses tags to allow for partial execution:

* `pulsys`: Runs all tasks related to the `pulsys` user, including group creation, home directory setup, and sudoers configuration.

## Dependencies

* `community.general` (for the `sudoers` module)
* `ansible.posix` (for the `authorized_key` module)

## Example Playbook

```yaml
- hosts: all
  roles:
    - role: users
      vars:
        pulsys_uid: 2000
        pulsys_gid: 2000
```
