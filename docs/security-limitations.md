# Security Limitations

## Customized kernel

The original Linux kernel `4.19.118-v8+` and U-Boot boot chain were preserved.

This imposes compatibility and security constraints, including missing networking features required for standard Docker bridge operation and netfilter-based firewalling.

## Docker networking

The application uses Docker host networking because the required kernel networking capabilities are unavailable.

This reduces network isolation compared with a dedicated container network.

## Application security

DSVW is intentionally vulnerable. Container restrictions reduce the impact of some potential compromises but do not remediate all application vulnerabilities.

## OTA scope

The signed OTA mechanism updates the Docker application image only.

It does not authenticate or update the kernel, firmware, bootloader or complete operating system.

The current verifier expects version `2.0.0`, rather than implementing a general-purpose version management and anti-rollback policy.

## Recovery

The deployment script includes automatic rollback logic, but recovery after an induced deployment failure has not yet been experimentally demonstrated.

## Host security

SSH hardening and AIDE provide additional defensive measures. They do not replace kernel maintenance, vulnerability remediation or network segmentation.

## AIDE configuration dependencies

The provided AIDE configuration references additional files under
`/etc/aide/aide.conf.d/` and `/etc/aide/aide.settings.d/`.

The repository therefore documents the main AIDE configuration but
does not necessarily reproduce every host-specific monitoring rule.
