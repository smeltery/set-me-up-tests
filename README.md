# set-me-up-tests

[![CI](https://github.com/smeltery/set-me-up-tests/actions/workflows/ci.yml/badge.svg)](https://github.com/smeltery/set-me-up-tests/actions/workflows/ci.yml) [![License: PolyForm Shield 1.0.0](https://img.shields.io/badge/License-PolyForm%20Shield%201.0.0-blue.svg)](https://polyformproject.org/licenses/shield/1.0.0)

[![Docker](https://img.shields.io/badge/-Docker-2496ED?style=flat-square&logo=docker&logoColor=white)](https://www.docker.com/) [![Bash](https://img.shields.io/badge/-Bash-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/) [![Linux](https://img.shields.io/badge/-Linux-FCC624?style=flat-square&logo=linux&logoColor=black)](https://www.linux.org/) [![Ubuntu](https://img.shields.io/badge/-Ubuntu-E95420?style=flat-square&logo=ubuntu&logoColor=white)](https://ubuntu.com/) [![macOS](https://img.shields.io/badge/-macOS-000000?style=flat-square&logo=apple&logoColor=white)](https://www.apple.com/macos/)

Scenario-driven Docker tests for validating [`set-me-up`](https://github.com/smeltery/set-me-up) provisioning on portable Linux containers.

## Quick start

```bash
# Run the default scenario (Docker/Linux)
./scripts/run-scenario.sh default

# Run the dotfiles scenario (Docker/Linux)
./scripts/run-scenario.sh dotfiles

# Run the headless VPS scenario (Docker/Linux)
./scripts/run-scenario.sh vps
./scripts/run-scenario.sh vps-ubuntu
./scripts/run-scenario.sh vps-debian

# Run the real curl-path VPS matrix when Docker is available
SMU_RUN_REAL_VPS_SMOKE=true ./scripts/validate.sh

# Check documented productization smoke surfaces
./scripts/validate.sh

# Run the dotfiles scenario on macOS (native)
./scripts/run-scenario.sh --native dotfiles-macos
```

## Scenarios

| Scenario | Blueprint | Modules | Platform |
|----------|-----------|---------|----------|
| `default` | `smeltery/set-me-up-blueprint` (master) | `example` | Linux (Docker) |
| `dotfiles` | `smeltery/set-me-up-blueprint` (master) | `example` | Linux (Docker) |
| `vps` | `smeltery/set-me-up-blueprint` (master) | `server/headless` | Linux (Docker) |
| `dotfiles-macos` | `smeltery/set-me-up-blueprint` (master) | `example` | macOS (native) |
| `vps-ubuntu` | `smeltery/set-me-up-blueprint` (master) | `server/headless` | Ubuntu VPS fixture |
| `vps-debian` | `smeltery/set-me-up-blueprint` (master) | `server/headless` | Debian VPS fixture |

Machine-readable scenario metadata lives in `scenarios/index.tsv`.

## Requirements

- [Docker](https://www.docker.com/)

## Reproducible dev environment (Flox)

A [Flox](https://flox.dev) manifest at `.flox/env/manifest.toml` pins the harness toolchain (`bash`, `shellcheck`) used by CI. Activating it gives you the same versions GitHub Actions runs:

```bash
# From the tests/ directory:
flox activate

# Inside the activated shell:
shellcheck scripts/run-scenario.sh scripts/in-container-run.sh scripts/lib/assertions.sh
```

Docker is intentionally not pinned in the manifest — install it via your OS package manager or Docker Desktop.

To test installer changes before they are published to `main`, pass the
candidate ref into the scenario runner:

```bash
SMU_PASS_HOST_ENV=true SMU_INSTALLER_REF=my-branch ./scripts/run-scenario.sh default
```

The `CI` workflow also accepts `installer_ref` and `installer_url` inputs when
run manually from GitHub Actions. The opt-in real VPS smoke script covers
Ubuntu, Debian, and Arch containers across `rcm`, `nix`, and `hybrid`
provisioning adapter plan paths.
On the scheduled run, CI also exercises the stable `candidate` installer branch
against the default scenario.

The native validation also asserts that the installer exposes the productized
operations used by root executable docs: release packaging, fleet bootstrap
planning, blueprint registry lookup, module graph explanation, TUI planning,
drift doctor, post-install doctor, policy checks, rollback restore fixtures,
and product docs generation.

## Documentation

- [Scenario contract and environment variables](docs/scenarios.md)
- [Advanced usage](docs/usage.md)

## License

This project is licensed under the [PolyForm Shield License 1.0.0](https://polyformproject.org/licenses/shield/1.0.0) — see [LICENSE](LICENSE) for details.
