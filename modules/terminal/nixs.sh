#!/usr/bin/env nix-shell
#! nix-shell -i bash -p bash
# shellcheck shell=bash

NIX_CONFIG_DIR=/home/pebble/home/nix-config

# cd to your config dir without affecting shell outside this script.
pushd $NIX_CONFIG_DIR &>/dev/null

# Check if submodules are up to date and warn the user.
gum log --time timeonly --level info "Checking submodules..."
check_submodule() {
    git diff HEAD --quiet
    if [ $? -eq 0 ]; then
        gum log --time timeonly --level info "Submodule '$name' has no uncommitted files."
    else
        gum log --time timeonly --level warn "Submodule '$name' has uncommitted files."
        gum confirm "Continue?"
        if [ $? -eq 1 ]; then
            exit 1
        fi
    fi

    git fetch --quiet

    # https://stackoverflow.com/a/3278427
    UPSTREAM=${1:-'@{u}'}
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse "$UPSTREAM")
    BASE=$(git merge-base @ "$UPSTREAM")

    if [ $LOCAL = $REMOTE ]; then
        gum log --time timeonly --level info "Submodule '$name' is up to date."
    else
        if [ $LOCAL = $BASE ]; then
            gum log --time timeonly --level warn "Submodule '$name' is outdated."
        elif [ $REMOTE = $BASE ]; then
            gum log --time timeonly --level warn "Submodule '$name' has not pushed its changes."
        else
            gum log --time timeonly --level warn "Submodule '$name' has diverged from origin."
        fi
        gum confirm "Continue?"
        if [ $? -eq 1 ]; then
            exit 1
        fi
    fi
}
export -f check_submodule
git submodule --quiet foreach check_submodule
if [ $? -ne 0 ]; then
    exit 1
fi

# Update files gotten using fetchgit which have a comment on the rev or url attribute.
gum log --time timeonly --level info "Updating fetchgit commit references..."
fd .nix --exec update-nix-fetchgit --only-commented
if [ $? -eq 0 ]; then
    gum log --time timeonly --level info "Updated fetchgit commit references."
else
    gum log --time timeonly --level warn "Failed to update fetchgit commit references."
fi

# Autoformat the nix files.
gum log --time timeonly --level info "Formatting files..."
treefmt
if [ $? -eq 0 ]; then
    gum log --time timeonly --level info "Finished formatting files."
else
    gum log --time timeonly --level error "Failed formatting files."
    exit 1
fi

gum log --time timeonly --level info "Staging files..."
git add .
if [ $? -eq 0 ]; then
    gum log --time timeonly --level info "Staged files."
else
    gum log --time timeonly --level error "Failed staging files."
    exit 1
fi

gum log --time timeonly --level info "Rebuilding..."
# When rebuilding, keep current specialisation.
CURRENT_SYSTEM=$(readlink -f /run/current-system)
DEFAULT_SYSTEM=$(readlink -f /nix/var/nix/profiles/system)
if [[ "$CURRENT_SYSTEM" == "$DEFAULT_SYSTEM" ]]; then
    sudo nixos-rebuild switch --flake . --show-trace
else
    for SPECIALISATION in /nix/var/nix/profiles/system/specialisation/*; do
        if [[ "$(readlink -f "$SPECIALISATION")" == "$CURRENT_SYSTEM" ]]; then
            gum log --time timeonly --level warn "Specialisation being used, config will be built twice."
            # Because switching with '--specialisation' will apply the wrong boot options, I have
            # to build twice. Once to activate the specialisation, the other to apply the boot
            # options.
            sudo nixos-rebuild boot --flake .
            if [ $? -eq 0 ]; then
                sudo nixos-rebuild test --flake . --specialisation "$(basename "$SPECIALISATION")"
            fi
            break
        fi
    done
fi
if [ $? -eq 0 ]; then
    gum log --time timeonly --level info "Finished rebuilding."
else
    gum log --time timeonly --level error "Failed rebuild."
    exit 1
fi
