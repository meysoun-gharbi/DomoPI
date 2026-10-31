# Countermeasure 1 — Docker Container Hardening

## Objective

Reduce the attack surface of the intentionally vulnerable DSVW Python application by migrating it from a privileged host service to a restricted Docker container.

## Implementation

Two Dockerfiles are included:

- `docker/Dockerfile.hardened`: initial hardened application image.
- `docker/Dockerfile.v2`: application image used for the signed OTA V2 deployment.

The running V2 container is named `dsvw-v2` and uses image `domopi-dsvw:v2`.

## Verified security restrictions

The following parameters were confirmed using `docker inspect`:

| Parameter | Verified value |
|---|---|
| User | `10001:10001` |
| Privileged | `false` |
| Linux capabilities | `ALL` dropped |
| Privilege escalation | `no-new-privileges:true` |
| Root filesystem | Read-only |
| Temporary filesystem | `/tmp` with `noexec,nosuid`, 16 MiB |
| Memory limit | 128 MiB |
| Process limit | 64 |
| Restart policy | `unless-stopped` |
| Networking | Host mode |

The application is reachable on `127.0.0.1:65413` and returned HTTP 200.

## Validation evidence

- [Hardening results](../evidence/docker/hardening-results.txt)
- [HTTP health check](../evidence/docker/http-healthcheck.txt)

## Limitations

The customized kernel does not provide the required networking capabilities for standard Docker bridge networking. Host networking was therefore used.

Host networking does not provide network namespace isolation from the host. Container hardening reduces privileges and filesystem exposure but does not eliminate vulnerabilities in the application or the underlying kernel.
