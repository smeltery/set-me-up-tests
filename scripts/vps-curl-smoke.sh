#!/usr/bin/env bash

set -euo pipefail

installer_ref="${SMU_INSTALLER_REF:-main}"
installer_url="${SMU_INSTALLER_URL:-https://raw.githubusercontent.com/smeltery/set-me-up-installer/${installer_ref}/install.sh}"
matrix="${SMU_VPS_SMOKE_MATRIX:-ubuntu:24.04|apt|rcm ubuntu:24.04|apt|nix ubuntu:24.04|apt|hybrid debian:stable-slim|apt|rcm debian:stable-slim|apt|nix debian:stable-slim|apt|hybrid archlinux:latest|pacman|rcm archlinux:latest|pacman|nix archlinux:latest|pacman|hybrid}"

if ! command -v docker >/dev/null 2>&1; then
    echo "SKIP vps curl smoke: docker unavailable"
    exit 0
fi

for entry in $matrix; do
    IFS='|' read -r image package_manager mode <<< "$entry"
    echo "vps curl smoke ${image} ${mode}"
    docker run --rm \
        -e "SMU_INSTALLER_URL=${installer_url}" \
        -e SMU_BLUEPRINT=smeltery/set-me-up-blueprint \
        -e SMU_BLUEPRINT_BRANCH=master \
        -e "SMU_VPS_MODE=${mode}" \
        -e "SMU_PACKAGE_MANAGER=${package_manager}" \
        "$image" \
        bash -lc '
            set -euo pipefail
            case "$SMU_PACKAGE_MANAGER" in
                apt)
                    apt-get update >/dev/null
                    apt-get install -y bash curl git ca-certificates python3 >/dev/null
                    ;;
                pacman)
                    pacman -Sy --noconfirm bash curl git ca-certificates python >/dev/null
                    ;;
                *)
                    echo "unsupported package manager: $SMU_PACKAGE_MANAGER" >&2
                    exit 2
                    ;;
            esac
            bash <(curl -fsSL "$SMU_INSTALLER_URL") --profile vps --provisioning-adapter "$SMU_VPS_MODE" --plan --no-header --skip-confirm
        '
done
