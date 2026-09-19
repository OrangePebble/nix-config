#!/usr/bin/env nix-shell
#! nix-shell -i bash -p bash
# shellcheck shell=bash

NIX_CONFIG_DIR=${NIX_CONFIG_DIR:-/home/pebble/home/nix-config}

# cd to your config dir without affecting shell outside this script.
if ! pushd -- "$NIX_CONFIG_DIR" &>/dev/null; then
    gum log --time timeonly --level error "Cannot enter config directory: $NIX_CONFIG_DIR"
    exit 1
fi

# Check submodule state and warn the user of possible problems.
gum log --time timeonly --level info "Checking submodules..."
check_submodule() {
    local name="$1" status upstream local_commit remote base

    if ! status=$(git status --porcelain --untracked-files=all); then
        gum log --time timeonly --level warn "Could not determine whether submodule '$name' has local changes."
    elif [[ -n "$status" ]]; then
        gum log --time timeonly --level warn "Submodule '$name' has uncommitted or untracked files."
    else
        gum log --time timeonly --level info "Submodule '$name' has no uncommitted files."
    fi

    if ! git fetch --quiet; then
        gum log --time timeonly --level warn "Could not fetch submodule '$name'; skipping its remote-state check."
        return 0
    fi

    # https://stackoverflow.com/a/3278427
    if ! upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null); then
        gum log --time timeonly --level warn "Submodule '$name' has no tracking branch; skipping its remote-state check."
        return 0
    fi
    if ! local_commit=$(git rev-parse @) || ! remote=$(git rev-parse "$upstream") || ! base=$(git merge-base @ "$upstream"); then
        gum log --time timeonly --level warn "Could not determine the remote state of submodule '$name'."
        return 0
    fi

    if [ "$local_commit" = "$remote" ]; then
        gum log --time timeonly --level info "Submodule '$name' is up to date."
    elif [ "$local_commit" = "$base" ]; then
        gum log --time timeonly --level warn "Submodule '$name' is outdated."
    elif [ "$remote" = "$base" ]; then
        gum log --time timeonly --level warn "Submodule '$name' has not pushed its changes."
    else
        gum log --time timeonly --level warn "Submodule '$name' has diverged from origin."
    fi
}
export -f check_submodule
if ! git submodule --quiet foreach "check_submodule \"\$name\""; then
    gum log --time timeonly --level warn "Some submodules could not be checked; continuing."
fi

# Update files gotten using fetchgit which have a comment on the rev or url attribute.
gum log --time timeonly --level info "Updating fetchgit commit references..."
if fd --extension nix --exec update-nix-fetchgit --only-commented; then
    gum log --time timeonly --level info "Updated fetchgit commit references."
else
    gum log --time timeonly --level warn "Failed to update fetchgit commit references."
fi

# Autoformat the nix files.
gum log --time timeonly --level info "Formatting files..."
if treefmt; then
    gum log --time timeonly --level info "Finished formatting files."
else
    gum log --time timeonly --level error "Failed formatting files."
    exit 1
fi

gum log --time timeonly --level info "Staging files..."
if git add --all; then
    gum log --time timeonly --level info "Staged files."
else
    gum log --time timeonly --level error "Failed staging files."
    exit 1
fi

gum log --time timeonly --level info "Rebuilding..."
# When rebuilding, keep current specialisation.
CURRENT_SYSTEM=$(readlink -f /run/current-system)
DEFAULT_SYSTEM=$(readlink -f /nix/var/nix/profiles/system)
REBUILD_STATUS=1
if [[ "$CURRENT_SYSTEM" == "$DEFAULT_SYSTEM" ]]; then
    sudo nixos-rebuild switch --flake . --show-trace
    REBUILD_STATUS=$?
else
    FOUND_SPECIALISATION=false
    shopt -s nullglob # If the glob ahead doesn't match anything it now expands to 0 arguments
    for SPECIALISATION in /nix/var/nix/profiles/system/specialisation/*; do
        if [[ "$(readlink -f "$SPECIALISATION")" == "$CURRENT_SYSTEM" ]]; then
            FOUND_SPECIALISATION=true
            gum log --time timeonly --level warn "Specialisation being used, config will be built twice."
            # Because switching with '--specialisation' will apply the wrong boot options, I have
            # to build twice. Once to activate the specialisation, the other to apply the boot
            # options.
            sudo nixos-rebuild boot --flake .
            REBUILD_STATUS=$?
            if [ "$REBUILD_STATUS" -eq 0 ]; then
                sudo nixos-rebuild test --flake . --specialisation "$(basename "$SPECIALISATION")"
                REBUILD_STATUS=$?
            fi
            break
        fi
    done
    if [[ "$FOUND_SPECIALISATION" != true ]]; then
        gum log --time timeonly --level error "Current system does not match the default system or a known specialisation."
    fi
fi
if [ "$REBUILD_STATUS" -eq 0 ]; then
    gum log --time timeonly --level info "Finished rebuilding."
else
    gum log --time timeonly --level error "Failed rebuild."
    exit 1
fi
