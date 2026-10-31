# Countermeasure 2 — Secure Signed OTA Updates

## Objective

Protect application updates against unauthorized modification and accidental corruption.

This implementation performs an application-level Docker update from V1 to V2. It does not update the kernel, bootloader or firmware.

## Architecture

The development machine prepares a Docker image archive and a manifest containing:

- Application version: `2.0.0`
- Docker image: `domopi-dsvw:v2`
- Archive filename: `dsvw-v2.tar`
- SHA-256 digest of the archive

The manifest is signed using an Ed25519 private key retained on the development machine.

The Raspberry Pi holds the corresponding public key and verifies the package before deployment.

## Verification workflow

The `ota/verify-ota.sh` script:

1. Verifies the Ed25519 signature of `manifest.txt`.
2. Validates the expected manifest format and version.
3. Calculates the SHA-256 digest of the Docker archive.
4. Rejects the package if its integrity does not match the signed manifest.

The verifier currently expects the specific V2 package format and version.

## Deployment workflow

The `ota/deploy-ota.sh` script implements:

- Exclusive deployment locking using `flock`.
- Verification before deployment.
- Docker image loading and V2 container deployment.
- Application HTTP health checking.
- Persistent version tracking.
- A rollback procedure intended to restore V1 if deployment fails.

Rollback is implemented in the script but has not yet been validated through a dedicated failure-injection test.

## Experimental results

| Test | Observed result |
|---|---|
| Authentic V2 update | Accepted and deployed |
| Modified archive | Rejected: archive integrity compromised |
| Modified manifest | Rejected: invalid Ed25519 signature |
| Application health check | HTTP 200 |
| Installed version | `2.0.0` |

## Evidence

- [Archive tampering test](../evidence/ota/tampered-image-test.txt)
- [Manifest tampering test](../evidence/ota/tampered-manifest-test.txt)
- [Installed version](../evidence/ota/installed-version.txt)
- [Example manifest](../ota/manifest.example.txt)

## Security boundaries

The Ed25519 private key must never be copied to the Raspberry Pi or committed to GitHub.

A trusted public key is required on the device. The mechanism does not establish a complete secure boot chain, and the current version validation is specific to the V1-to-V2 demonstration.
