# Initial Security Assessment

## Environment

DomoPi is a Raspberry Pi-based embedded Linux environment containing intentionally vulnerable services.

The laboratory exercise focuses on security assessment and the implementation of defensive countermeasures while preserving the customized kernel and boot chain.

## Identified weaknesses

| Finding | Security concern |
|---|---|
| Root bind shell on TCP 64444 | Unauthenticated privileged access |
| DSVW application running as root on TCP 65412 | Excessive privileges for a vulnerable application |
| Unnecessary service exposure | Increased attack surface |
| Customized legacy kernel | Compatibility constraints and residual security risks |

## Defensive actions

The project implemented:

1. Docker-based application isolation and privilege reduction.
2. Ed25519-signed, SHA-256-verified application OTA updates.
3. SSH configuration hardening.
4. AIDE file integrity monitoring.
5. Host security auditing with Lynis.

## Validation summary

The Docker V2 container runs as UID/GID `10001:10001`, with all capabilities dropped, a read-only root filesystem and resource limits.

The OTA verifier rejected both a modified archive and a modified signed manifest. The authenticated V2 application returned HTTP 200.

The Lynis hardening index was reported to improve from 60 to 64.

## Scope

All experiments were conducted in an authorized educational laboratory. This report describes observed findings and implemented defenses, not a claim that the entire device is secure.
