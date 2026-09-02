# Scenarios

Scenario files live in `scenarios/` and define the environment variables for each test run.
Each scenario bootstraps the blueprint, verifies the installer refuses dirty
blueprint updates by default, checks the `smu update` dry-run commands, verifies
`smu update blueprint` fast-forwards from a local test remote, then runs the
configured provisioning modules. It also verifies `smu update blueprint
--force-reset` discards a local-only commit in a controlled checkout.

## Scenario contract

### Required

| Variable | Description | Example |
|----------|-------------|---------|
| `SMU_BLUEPRINT` | GitHub repo to clone | `smeltery/set-me-up-blueprint` |
| `SMU_BLUEPRINT_BRANCH` | Branch to check out | `master`, `main` |

### Optional

| Variable | Description | Default |
|----------|-------------|---------|
| `SMU_BLUEPRINT_SHA` | Exact commit to pin to after install | _(none)_ |
| `SMU_MODULES` | Space or comma-separated module names | _(none)_ |
| `SMU_SETUP_PROFILE` | Named `smu --setup-profile` path to run instead of explicit modules | _(none)_ |
| `SMU_RUN_IDEMPOTENCY` | Re-run provision to check idempotency | `true` |
| `SMU_RUN_UPDATE_SMOKE` | Run blueprint update and force-reset smoke checks | `true` |
| `SMU_EXPECTED_SYMLINKS` | Space or comma-separated paths that must be symlinks | _(none)_ |
| `SMU_EXPECTED_COMMANDS` | Space or comma-separated commands that must exist after provisioning | _(none)_ |
| `SMU_EXPECTED_PREFLIGHT_ADAPTER` | Adapter to verify with `smu provisioning-adapter preflight --json` | _(none)_ |
| `SMU_EXPECTED_PREFLIGHT_PROFILE` | Profile used for the preflight assertion | `default` |
| `SMU_EXPECTED_PREFLIGHT_MODULES` | Space or comma-separated modules used for the preflight assertion | _(profile modules)_ |
| `SMU_EXPECTED_PREFLIGHT_ALLOW_FAILURE` | Treat preflight output as a readiness fixture without failing the scenario | `false` |
| `SMU_EXPECTED_NO_SECRETS` | Assert no secret-like files were materialized under `$SMU_HOME_DIR` | `false` |
| `SMU_HOME_DIR` | Install directory inside the container | `$HOME/set-me-up` |
| `SMU_INSTALLER_REF` | Installer GitHub ref used by the bootstrap URL | `main` |
| `SMU_INSTALLER_URL` | Full installer URL, for candidate branches or forks | `https://raw.githubusercontent.com/smeltery/set-me-up-installer/$SMU_INSTALLER_REF/install.sh` |
| `SMU_SUBMODULE_SCOPE` | Blueprint submodule scope passed to installer (`all` or `platform`) | `all` |

## Built-in scenarios

### `default`

Uses the official `smeltery/set-me-up-blueprint` on the `master` branch with the `example` module. Idempotency is enabled.

### `dotfiles` and `dotfiles-macos`

Uses the public `smeltery/set-me-up-blueprint` on `master` with the `example`
module. Idempotency and update smoke checks are disabled so these jobs stay a
lightweight second-path smoke (Docker/Linux and native macOS) without depending
on a private personal blueprint.

### `vps`, `vps-ubuntu`, and `vps-debian`

Uses the official `smeltery/set-me-up-blueprint` on the `master` branch with
the `vps` setup profile, which provisions the Debian `server/headless` module.
This covers the supported headless Ubuntu/Debian VPS path, including a
DigitalOcean Droplet, without installing workstation packages. The opt-in real
curl smoke additionally checks Ubuntu, Debian, and Arch containers across
`rcm`, `nix`, and `hybrid` plan paths. It also uses
`SMU_SUBMODULE_SCOPE=platform` so the bootstrap skips macOS-only module
submodules, and disables generic update smoke checks to keep the scenario
focused on headless provisioning. The explicit Ubuntu/Debian fixtures also run
rcm or Home Manager preflight assertions and check that no secret-like files are
created by bootstrap or provisioning.

## Adding a new scenario

Create a `.env` file in `scenarios/`:

```bash
SMU_BLUEPRINT=your-org/your-repo
SMU_BLUEPRINT_BRANCH=main
SMU_MODULES=base,php
SMU_RUN_IDEMPOTENCY=true
SMU_EXPECTED_SYMLINKS=/home/smu/.bashrc,/home/smu/.vimrc
```

Run it by name:

```bash
./scripts/run-scenario.sh your-scenario
```

To validate a candidate installer branch before it is merged to `main`, pass
the installer ref through to Docker:

```bash
SMU_PASS_HOST_ENV=true SMU_INSTALLER_REF=my-branch ./scripts/run-scenario.sh default
```

The GitHub Actions `CI` workflow exposes matching `installer_ref` and
`installer_url` dispatch inputs.
Scheduled CI also runs the `default` scenario with `SMU_INSTALLER_REF=candidate`
so the candidate channel is continuously checked.

## Productization smoke surfaces

The test harness treats these `smu` commands as part of the supported dry-run
surface for real machines and downstream blueprints:

```bash
smu release-package --version 1.2.3 --json
smu release-package --version 1.2.3 --output dist/set-me-up-1.2.3 --json
smu fleet plan --profile vps --json
smu fleet apply --hosts hosts.txt --profile vps --dry-run --json
smu blueprint-registry --json
smu blueprint-registry --registry-url https://example.com/smu-blueprints.json --json
smu module-graph base rcm nix --json
smu tui --profile vps --json
smu drift doctor --json
smu post-install doctor --profile vps --json
smu policy check --preset ci --json
smu policy check --root . --preset ci --json
smu rollback-test restore --json
smu product-docs generate --source scripts/docs/EXECUTABLE-WORKFLOWS.md --output product-docs.md --json
smu inventory --json
smu facts collect --json
smu plan diff --from previous-plan.json --to current-plan.json --json
smu approval --preset strict --dry-run --json
smu state timeline --json
smu lock --output smu.lock --json
smu bootstrap bundle --profile vps --output smu-bootstrap.zip --json
smu policy explain --preset ci --json
smu golden-examples --json
smu provenance --version 1.2.3 --json
```
