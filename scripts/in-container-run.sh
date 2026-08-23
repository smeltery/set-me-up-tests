#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "/opt/harness/scripts/lib/assertions.sh" ]]; then
    # shellcheck disable=SC1091
    source /opt/harness/scripts/lib/assertions.sh
else
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/lib/assertions.sh"
fi

require_env() {
    local var_name="$1"
    [[ -n "${!var_name:-}" ]] || fail "missing required env var: $var_name"
}

normalize_list() {
    local raw="${1:-}"
    raw="${raw//,/ }"
    # shellcheck disable=SC2206
    local list=($raw)
    printf "%s\n" "${list[@]}"
}

installer_url() {
    local ref="${SMU_INSTALLER_REF:-main}"
    printf "%s\n" "${SMU_INSTALLER_URL:-https://raw.githubusercontent.com/smeltery/set-me-up-installer/${ref}/install.sh}"
}

run_installer() {
    export SMU_HOME_DIR="${SMU_HOME_DIR:-${HOME}/set-me-up}"
    export SMU_BLUEPRINT
    export SMU_BLUEPRINT_BRANCH
    export SMU_INSTALLER_REF="${SMU_INSTALLER_REF:-main}"
    export SMU_INSTALLER_URL="${SMU_INSTALLER_URL:-$(installer_url)}"
    export smu_home_dir="${SMU_HOME_DIR}"
    export TERM="${TERM:-xterm}"

    echo "▶ Running installer for ${SMU_BLUEPRINT}@${SMU_BLUEPRINT_BRANCH}"
    bash <(curl -s -L "$(installer_url)") --no-header --skip-confirm --plan
    bash <(curl -s -L "$(installer_url)") --no-header --skip-confirm

    assert_path_exists "${SMU_HOME_DIR}"
    assert_git_repo "${SMU_HOME_DIR}"
    assert_path_exists "${SMU_HOME_DIR}/set-me-up-installer/smu"
}

assert_bootstrap_refuses_dirty_blueprint() {
    local dirty_file="${SMU_HOME_DIR}/smu-dirty-check.tmp"
    local output_file

    echo "▶ Checking installer refuses dirty blueprint updates"
    printf "dirty\n" > "$dirty_file"
    output_file="$(mktemp)"

    if ! bash <(curl -s -L "$(installer_url)") --no-header --skip-confirm >"$output_file" 2>&1; then
        rm -f "$dirty_file"
        rm -f "$output_file"
        return 0
    fi

    if grep -q "Existing blueprint checkout has local changes" "$output_file"; then
        rm -f "$dirty_file" "$output_file"
        return 0
    fi

    cat "$output_file" >&2
    rm -f "$dirty_file" "$output_file"
    fail "installer updated a dirty blueprint checkout without --force-reset"
}

assert_update_commands() {
    local smu_cmd="${SMU_HOME_DIR}/set-me-up-installer/smu"

    echo "▶ Checking update command plans"
    "$smu_cmd" update blueprint --dry-run
    "$smu_cmd" update installer --dry-run
    "$smu_cmd" update modules --dry-run
    "$smu_cmd" update --all --dry-run
}

run_update_smoke() {
    [[ "${SMU_RUN_UPDATE_SMOKE:-true}" == "true" ]]
}

assert_blueprint_update_fast_forwards() {
    local smu_cmd="${SMU_HOME_DIR}/set-me-up-installer/smu"
    local branch
    local remote_dir
    local work_dir
    local smoke_file="smu-update-smoke.txt"

    git -C "${SMU_HOME_DIR}" reset --hard HEAD >/dev/null
    git -C "${SMU_HOME_DIR}" clean -fd >/dev/null
    git -C "${SMU_HOME_DIR}" submodule update --init --recursive >/dev/null
    git -C "${SMU_HOME_DIR}" submodule foreach --recursive \
        'git reset --hard HEAD >/dev/null && git clean -fd >/dev/null' >/dev/null

    branch="$(git -C "${SMU_HOME_DIR}" branch --show-current)"
    remote_dir="$(mktemp -d)"
    work_dir="$(mktemp -d)"

    echo "▶ Checking blueprint update fast-forwards from a local remote"
    git -C "${SMU_HOME_DIR}" clone --bare "${SMU_HOME_DIR}" "${remote_dir}/blueprint.git" >/dev/null
    git clone "${remote_dir}/blueprint.git" "${work_dir}/blueprint" >/dev/null
    git -C "${work_dir}/blueprint" config user.name "set-me-up tests"
    git -C "${work_dir}/blueprint" config user.email "tests@example.invalid"
    printf "updated\n" > "${work_dir}/blueprint/${smoke_file}"
    git -C "${work_dir}/blueprint" add "${smoke_file}"
    git -C "${work_dir}/blueprint" commit -m "test: advance blueprint smoke" >/dev/null
    git -C "${work_dir}/blueprint" push origin "${branch}" >/dev/null
    git -C "${SMU_HOME_DIR}" remote set-url origin "${remote_dir}/blueprint.git"

    "$smu_cmd" update blueprint
    assert_path_exists "${SMU_HOME_DIR}/${smoke_file}"
}

assert_blueprint_force_reset_discards_local_commit() {
    local smu_cmd="${SMU_HOME_DIR}/set-me-up-installer/smu"
    local reset_file="${SMU_HOME_DIR}/smu-force-reset-smoke.txt"

    echo "▶ Checking blueprint force-reset discards local commits"
    git -C "${SMU_HOME_DIR}" config user.name "set-me-up tests"
    git -C "${SMU_HOME_DIR}" config user.email "tests@example.invalid"
    printf "local\n" > "$reset_file"
    git -C "${SMU_HOME_DIR}" add "$reset_file"
    git -C "${SMU_HOME_DIR}" commit -m "test: local force reset smoke" >/dev/null

    "$smu_cmd" update blueprint --force-reset

    if [[ -e "$reset_file" ]]; then
        fail "force-reset did not discard local-only blueprint commit"
    fi
}

pin_sha_if_requested() {
    if [[ -z "${SMU_BLUEPRINT_SHA:-}" ]]; then
        return 0
    fi

    echo "▶ Pinning blueprint checkout to SHA ${SMU_BLUEPRINT_SHA}"
    git -C "${SMU_HOME_DIR}" fetch --all --tags --quiet
    git -C "${SMU_HOME_DIR}" checkout "${SMU_BLUEPRINT_SHA}"
    git -C "${SMU_HOME_DIR}" submodule update --init --recursive
}

run_provision() {
    local smu_cmd="${SMU_HOME_DIR}/set-me-up-installer/smu"
    export smu_home_dir="${SMU_HOME_DIR}"
    chmod +x "$smu_cmd"

    local -a modules=()
    while IFS= read -r module; do
        [[ -n "$module" ]] && modules+=("$module")
    done < <(normalize_list "${SMU_MODULES:-}")

    local -a cmd=("$smu_cmd")
    if [[ -n "${SMU_SETUP_PROFILE:-}" ]]; then
        cmd+=(--setup-profile "${SMU_SETUP_PROFILE}")
    else
        cmd+=(--provision)
    fi
    if (( ${#modules[@]} > 0 )) && [[ -z "${SMU_SETUP_PROFILE:-}" ]]; then
        cmd+=(--modules "${modules[@]}")
    fi

    local log_file
    log_file="$(mktemp)"
    echo "▶ Running provision command: ${cmd[*]}"
    "${cmd[@]}" | tee "$log_file"

    if [[ "${SMU_RUN_IDEMPOTENCY:-true}" == "true" ]]; then
        echo "▶ Re-running provision command for idempotency check"
        "${cmd[@]}" | tee -a "$log_file"
    fi

    for module in "${modules[@]}"; do
        assert_log_contains "$log_file" "$module"
    done
    if [[ -n "${SMU_SETUP_PROFILE:-}" ]]; then
        assert_log_contains "$log_file" "${SMU_SETUP_PROFILE}"
    fi

    rm -f "$log_file"
}

assert_expected_commands() {
    local -a commands=()
    while IFS= read -r command_name; do
        [[ -n "$command_name" ]] && commands+=("$command_name")
    done < <(normalize_list "${SMU_EXPECTED_COMMANDS:-}")

    if (( ${#commands[@]} == 0 )); then
        echo "ℹ No explicit command assertions configured."
        return 0
    fi

    for command_name in "${commands[@]}"; do
        command -v "$command_name" >/dev/null 2>&1 || fail "expected command not found: $command_name"
    done
}

assert_expected_symlinks() {
    local -a symlinks=()
    while IFS= read -r path; do
        [[ -n "$path" ]] && symlinks+=("$path")
    done < <(normalize_list "${SMU_EXPECTED_SYMLINKS:-}")

    if (( ${#symlinks[@]} == 0 )); then
        echo "ℹ No explicit symlink assertions configured."
        return 0
    fi

    for path in "${symlinks[@]}"; do
        assert_symlink "$path"
    done
}

assert_provisioning_preflight() {
    local adapter="${SMU_EXPECTED_PREFLIGHT_ADAPTER:-}"
    if [[ -z "$adapter" ]]; then
        echo "ℹ No provisioning preflight assertion configured."
        return 0
    fi

    local smu_cmd="${SMU_HOME_DIR}/set-me-up-installer/smu"
    local -a modules=()
    while IFS= read -r module; do
        [[ -n "$module" ]] && modules+=("$module")
    done < <(normalize_list "${SMU_EXPECTED_PREFLIGHT_MODULES:-}")
    echo "▶ Checking provisioning preflight for ${adapter}"
    local -a cmd=("$smu_cmd" provisioning-adapter preflight --adapter "$adapter" --profile "${SMU_EXPECTED_PREFLIGHT_PROFILE:-default}" --json)
    if (( ${#modules[@]} > 0 )); then
        cmd+=(--modules "${modules[@]}")
    fi
    if [[ "${SMU_EXPECTED_PREFLIGHT_ALLOW_FAILURE:-false}" == "true" ]]; then
        "${cmd[@]}" || return 0
        return 0
    fi
    "${cmd[@]}"
}

assert_golden_path_commands() {
    local machine="${SMU_EXPECTED_PLAN_MACHINE:-}"
    if [[ -z "$machine" ]]; then
        echo "ℹ No golden-path plan assertion configured."
        return 0
    fi

    local smu_cmd="${SMU_HOME_DIR}/set-me-up-installer/smu"
    echo "▶ Checking golden-path plan and doctor for ${machine}"
    "$smu_cmd" plan --machine "$machine" --json
    "$smu_cmd" doctor --json
}

assert_no_secret_materialization() {
    if [[ "${SMU_EXPECTED_NO_SECRETS:-false}" != "true" ]]; then
        echo "ℹ No secret-materialization assertion configured."
        return 0
    fi

    echo "▶ Checking no secrets were materialized"
    if find "${SMU_HOME_DIR}" \
        \( -path "${SMU_HOME_DIR}/.git" -o \
           -path "${SMU_HOME_DIR}/set-me-up-installer" -o \
           -name '__pycache__' \) -prune -o \
        -type f \( -name '.env' -o -name '*secret*' -o -name '*credential*' \) -print | grep -q .; then
        fail "secret-like files were materialized under ${SMU_HOME_DIR}"
    fi
}

main() {
    require_env "SMU_BLUEPRINT"
    require_env "SMU_BLUEPRINT_BRANCH"

    run_installer
    assert_bootstrap_refuses_dirty_blueprint
    if run_update_smoke; then
        assert_update_commands
        assert_blueprint_update_fast_forwards
        assert_blueprint_force_reset_discards_local_commit
    else
        echo "ℹ Update checks disabled for this scenario."
    fi
    pin_sha_if_requested
    run_provision
    assert_golden_path_commands
    assert_provisioning_preflight
    assert_expected_commands
    assert_expected_symlinks
    assert_no_secret_materialization

    echo "✅ Scenario completed successfully."
}

main "$@"
