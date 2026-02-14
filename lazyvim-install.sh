#!/usr/bin/env bash
set -euo pipefail

# LazyVim full install script
# - Backs up existing Neovim config/state
# - Installs LazyVim starter config
# - Optionally launches Neovim to finish setup

LAZYVIM_REPO="https://github.com/LazyVim/starter"

info() { printf "[lazyvim] %s\n" "$*"; }
warn() { printf "[lazyvim] WARN: %s\n" "$*"; }
err() { printf "[lazyvim] ERROR: %s\n" "$*" >&2; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    err "Missing required command: $1"
    return 1
  }
}

os=""
pkg_mgr=""

detect_os() {
  case "$(uname -s)" in
    Darwin) os="macos" ;;
    Linux) os="linux" ;;
    *)
      err "Unsupported OS: $(uname -s)"
      return 1
      ;;
  esac
}

detect_pkg_mgr() {
  if [ "$os" = "macos" ]; then
    if command -v brew >/dev/null 2>&1; then
      pkg_mgr="brew"
    else
      pkg_mgr=""
    fi
    return 0
  fi

  if command -v apt-get >/dev/null 2>&1; then
    pkg_mgr="apt"
  elif command -v dnf >/dev/null 2>&1; then
    pkg_mgr="dnf"
  elif command -v yum >/dev/null 2>&1; then
    pkg_mgr="yum"
  elif command -v pacman >/dev/null 2>&1; then
    pkg_mgr="pacman"
  elif command -v zypper >/dev/null 2>&1; then
    pkg_mgr="zypper"
  elif command -v apk >/dev/null 2>&1; then
    pkg_mgr="apk"
  else
    pkg_mgr=""
  fi
}

need_sudo() {
  if [ "$(id -u)" -ne 0 ] && ! command -v sudo >/dev/null 2>&1; then
    err "sudo is required to install packages but was not found."
    return 1
  fi
}

install_packages() {
  local pkgs=("$@")
  [ "${#pkgs[@]}" -eq 0 ] && return 0

  info "Installing: ${pkgs[*]} via $pkg_mgr"
  case "$pkg_mgr" in
    brew)
      brew install "${pkgs[@]}"
      ;;
    apt)
      need_sudo
      sudo apt-get update
      sudo apt-get install -y "${pkgs[@]}"
      ;;
    dnf)
      need_sudo
      sudo dnf install -y "${pkgs[@]}"
      ;;
    yum)
      need_sudo
      sudo yum install -y "${pkgs[@]}"
      ;;
    pacman)
      need_sudo
      sudo pacman -Sy --noconfirm "${pkgs[@]}"
      ;;
    zypper)
      need_sudo
      sudo zypper install -y "${pkgs[@]}"
      ;;
    apk)
      need_sudo
      sudo apk add "${pkgs[@]}"
      ;;
    *)
      err "No supported package manager found."
      return 1
      ;;
  esac
}

ensure_requirements() {
  detect_os
  detect_pkg_mgr

  if [ -z "$pkg_mgr" ]; then
    err "No supported package manager found. Please install one and re-run."
    if [ "$os" = "macos" ]; then
      err "Homebrew is required on macOS (brew)."
    else
      err "Supported: apt, dnf, yum, pacman, zypper, apk."
    fi
    return 1
  fi

  local missing=()
  command -v git >/dev/null 2>&1 || missing+=("git")
  command -v nvim >/dev/null 2>&1 || missing+=("neovim")

  if [ "${#missing[@]}" -gt 0 ]; then
    info "Missing dependencies: ${missing[*]}"
    install_packages "${missing[@]}"
  fi

  need_cmd git
  need_cmd nvim
}

ensure_requirements

# Detect Neovim config dir
NVIM_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
NVIM_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
NVIM_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/nvim"
NVIM_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nvim"

BACKUP_SUFFIX=".bak.$(date +%Y%m%d_%H%M%S)"

backup_dir() {
  local d="$1"
  if [ -e "$d" ]; then
    info "Backing up $d -> ${d}${BACKUP_SUFFIX}"
    mv "$d" "${d}${BACKUP_SUFFIX}"
  fi
}

# Backup any existing config/state to avoid loss
backup_dir "$NVIM_CONFIG_DIR"
backup_dir "$NVIM_DATA_DIR"
backup_dir "$NVIM_STATE_DIR"
backup_dir "$NVIM_CACHE_DIR"

info "Cloning LazyVim starter to $NVIM_CONFIG_DIR"
mkdir -p "$(dirname "$NVIM_CONFIG_DIR")"
git clone --depth=1 "$LAZYVIM_REPO" "$NVIM_CONFIG_DIR"

info "Cleaning starter git history"
rm -rf "$NVIM_CONFIG_DIR/.git"

info "LazyVim starter installed."
info "Run 'nvim' to finish setup and plugin installation."

# Optional: launch nvim unless NO_LAUNCH=1
if [ "${NO_LAUNCH:-0}" = "0" ]; then
  info "Launching Neovim now (set NO_LAUNCH=1 to skip)"
  nvim
else
  info "Skipping Neovim launch because NO_LAUNCH=1"
fi
