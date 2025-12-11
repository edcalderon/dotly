#!/usr/bin/env bash

set -euo pipefail

# Load shared Linux helpers (detect_package_manager, pkg_install, ...)
if [ -n "${DOTFILES_PATH:-}" ] && [ -f "$DOTFILES_PATH/os/linux/.dotly" ]; then
  # shellcheck source=/dev/null
  . "$DOTFILES_PATH/os/linux/.dotly"
fi

# Try to infer DOTLY_PATH if not already set (typical layout: modules/dotly)
if [ -z "${DOTLY_PATH:-}" ] && [ -n "${DOTFILES_PATH:-}" ] && [ -d "$DOTFILES_PATH/modules/dotly" ]; then
  DOTLY_PATH="$DOTFILES_PATH/modules/dotly"
fi

install_yakuake() {
  if command -v yakuake >/dev/null 2>&1; then
    echo "[yakuake] Already installed"
    return 0
  fi

  local pm
  pm=$(detect_package_manager)

  case "$pm" in
    apt)
      pkg_install "$pm" yakuake
      ;;
    dnf)
      pkg_install "$pm" yakuake
      ;;
    pacman)
      pkg_install "$pm" yakuake
      ;;
    *)
      echo "[yakuake] Install manually for your distro" >&2
      ;;
  esac
}

configure_yakuake_autostart() {
  if ! command -v yakuake >/dev/null 2>&1; then
    echo "[yakuake] Not installed, skipping autostart configuration" >&2
    return 0
  fi

  local autostart_dir
  autostart_dir="$HOME/.config/autostart"
  mkdir -p "$autostart_dir"

  local desktop_file
  desktop_file="$autostart_dir/yakuake.desktop"

  if [ ! -f "$desktop_file" ]; then
    cat > "$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Exec=yakuake
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Yakuake
Comment=Start Yakuake at login
EOF
    echo "[yakuake] Autostart entry created at $desktop_file"
  else
    echo "[yakuake] Autostart entry already exists at $desktop_file"
  fi
}

install_st() {
  if command -v st >/dev/null 2>&1; then
    echo "[st] Already installed"
    return 0
  fi

  local pm
  pm=$(detect_package_manager)

  case "$pm" in
    apt)
      pkg_install "$pm" build-essential libx11-dev libxft-dev libxinerama-dev
      ;;
    dnf)
      pkg_install "$pm" @"Development Tools" libX11-devel libXft-devel libXinerama-devel
      ;;
    pacman)
      pkg_install "$pm" base-devel libx11 libxft libxinerama
      ;;
    *)
      echo "[st] Please ensure a build toolchain and X11 dev headers are installed" >&2
      ;;
  esac

  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT

  git clone https://git.suckless.org/st "$tmpdir/st"
  (cd "$tmpdir/st" && make && sudo make install)

  echo "[st] Installed from source"
}

install_oh_my_zsh() {
  if [ -d "$HOME/.oh-my-zsh" ]; then
    echo "[oh-my-zsh] Already installed"
    return 0
  fi

  if ! command -v zsh >/dev/null 2>&1; then
    local pm
    pm=$(detect_package_manager)

    case "$pm" in
      apt)
        pkg_install "$pm" zsh
        ;;
      dnf)
        pkg_install "$pm" zsh
        ;;
      pacman)
        pkg_install "$pm" zsh
        ;;
      *)
        echo "[oh-my-zsh] Please install zsh manually" >&2
        ;;
    esac
  fi

  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

  if [ -f "$HOME/.zshrc" ]; then
    if grep -q '^ZSH_THEME=' "$HOME/.zshrc"; then
      sed -i 's/^ZSH_THEME=.*/ZSH_THEME="agnoster"/' "$HOME/.zshrc"
    else
      echo 'ZSH_THEME="agnoster"' >> "$HOME/.zshrc"
    fi
    echo "[oh-my-zsh] Configured ZSH_THEME=agnoster in ~/.zshrc"
  else
    echo "[oh-my-zsh] ~/.zshrc not found to set agnoster theme" >&2
  fi

  # Ensure zsh is the default shell so terminals (like Yakuake) use it
  if command -v zsh >/dev/null 2>&1 && command -v chsh >/dev/null 2>&1; then
    current_shell="${SHELL:-}"
    zsh_path="$(command -v zsh)"

    if [ -n "$zsh_path" ] && [ "$current_shell" != "$zsh_path" ]; then
      echo "[oh-my-zsh] Changing default shell to zsh ($zsh_path) for user $USER"
      chsh -s "$zsh_path" "$USER" || echo "[oh-my-zsh] Failed to change default shell. You may need to run: chsh -s $zsh_path $USER" >&2
    else
      echo "[oh-my-zsh] zsh is already the default shell ($current_shell)"
    fi
  fi

  echo "[oh-my-zsh] Installed (won't auto-change shell or run zsh)"
}

install_powerline_fonts() {
  local pm
  pm=$(detect_package_manager)

  case "$pm" in
    apt)
      pkg_install "$pm" fonts-powerline fonts-firacode || true
      ;;
    dnf)
      pkg_install "$pm" powerline-fonts || true
      ;;
    pacman)
      pkg_install "$pm" powerline ttf-dejavu ttf-liberation || true
      ;;
    *)
      echo "[fonts] Please install a Powerline / Nerd Font manually for your terminal" >&2
      ;;
  esac

  echo "[fonts] Installed powerline-compatible fonts (select them in your terminal/yakuake profile)."
}

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    echo "[docker] Already installed"
    return 0
  fi

  local pm
  pm=$(detect_package_manager)

  case "$pm" in
    apt)
      # On Ubuntu/Linux Mint use the distro Docker package to avoid repo 404 issues
      pkg_install "$pm" docker.io || true
      ;;
    dnf)
      pkg_install "$pm" dnf-plugins-core
      sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || true
      sudo dnf install -y docker-ce docker-ce-cli containerd.io || true
      ;;
    pacman)
      pkg_install "$pm" docker
      ;;
    *)
      echo "[docker] Please install Docker manually for your distro" >&2
      ;;
  esac

  if getent group docker >/dev/null 2>&1; then
    sudo usermod -aG docker "$USER" || true
  fi

  echo "[docker] Installed. You may need to log out/in to use docker without sudo."
}

install_vscode() {
  if command -v code >/dev/null 2>&1; then
    echo "[vscode] Already installed"
    return 0
  fi

  local pm
  pm=$(detect_package_manager)

  case "$pm" in
    apt)
      pkg_install "$pm" wget gpg
      wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /usr/share/keyrings/packages.microsoft.gpg >/dev/null
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | \
        sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
      sudo apt-get update -y
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y code
      ;;
    dnf)
      pkg_install "$pm" wget gpg
      sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc || true
      sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
      sudo dnf check-update || true
      sudo dnf install -y code || true
      ;;
    pacman)
      echo "[vscode] On Arch-based distros use the AUR (code or code-insiders)." >&2
      ;;
    *)
      echo "[vscode] Please install VS Code manually for your distro" >&2
      ;;
  esac
}

install_chromium() {
  if command -v chromium >/dev/null 2>&1 || command -v chromium-browser >/dev/null 2>&1; then
    echo "[chromium] Already installed"
    return 0
  fi

  local pm
  pm=$(detect_package_manager)

  case "$pm" in
    apt)
      pkg_install "$pm" chromium-browser || pkg_install "$pm" chromium || true
      ;;
    dnf)
      pkg_install "$pm" chromium || true
      ;;
    pacman)
      pkg_install "$pm" chromium
      ;;
    *)
      echo "[chromium] Please install Chromium manually for your distro" >&2
      ;;
  esac
}

install_gnome_web() {
  if command -v epiphany-browser >/dev/null 2>&1; then
    echo "[gnome-web] Already installed"
    return 0
  fi

  local pm
  pm=$(detect_package_manager)

  case "$pm" in
    apt)
      pkg_install "$pm" epiphany-browser || true
      ;;
    dnf)
      echo "[gnome-web] Please install epiphany / gnome-web via your distro packages" >&2
      ;;
    pacman)
      echo "[gnome-web] Please install epiphany / gnome-web (e.g. from community/aur)" >&2
      ;;
    *)
      echo "[gnome-web] Please install GNOME Web manually" >&2
      ;;
  esac
}

install_dropbox() {
  if command -v dropbox >/dev/null 2>&1; then
    echo "[dropbox] Already installed"
    return 0
  fi

  local pm
  pm=$(detect_package_manager)

  case "$pm" in
    apt)
      # On Ubuntu/Mint this is usually provided as nautilus-dropbox or dropbox
      pkg_install "$pm" nautilus-dropbox || pkg_install "$pm" dropbox || true
      ;;
    dnf|pacman)
      echo "[dropbox] Please install Dropbox using your distro packages or the official .deb/.rpm package" >&2
      ;;
    *)
      echo "[dropbox] Please install Dropbox manually" >&2
      ;;
  esac
}

install_chrome() {
  if command -v google-chrome >/dev/null 2>&1 || command -v google-chrome-stable >/dev/null 2>&1; then
    echo "[chrome] Already installed"
    return 0
  fi

  local pm
  pm=$(detect_package_manager)

  case "$pm" in
    apt)
      pkg_install "$pm" wget gpg ca-certificates || true
      wget -qO- https://dl.google.com/linux/linux_signing_key.pub | \
        gpg --dearmor | sudo tee /usr/share/keyrings/google-chrome.gpg >/dev/null || true
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" | \
        sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null || true
      sudo apt-get update -y || true
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y google-chrome-stable || true
      ;;
    dnf|pacman)
      echo "[chrome] Please install Google Chrome via your distro instructions or official package" >&2
      ;;
    *)
      echo "[chrome] Please install Google Chrome manually" >&2
      ;;
  esac
}

install_brave() {
  if command -v brave-browser >/dev/null 2>&1; then
    echo "[brave] Already installed"
    return 0
  fi

  local pm
  pm=$(detect_package_manager)

  case "$pm" in
    apt)
      pkg_install "$pm" curl gnupg ca-certificates || true
      sudo install -m 0755 -d /etc/apt/keyrings || true
      curl -fsSL https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg | \
        sudo tee /etc/apt/keyrings/brave-browser-archive-keyring.gpg >/dev/null || true
      echo "deb [signed-by=/etc/apt/keyrings/brave-browser-archive-keyring.gpg arch=$(dpkg --print-architecture)] https://brave-browser-apt-release.s3.brave.com/ stable main" | \
        sudo tee /etc/apt/sources.list.d/brave-browser-release.list >/dev/null || true
      sudo apt-get update -y || true
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y brave-browser || true
      ;;
    dnf|pacman)
      echo "[brave] Please install Brave via your distro instructions or official repo" >&2
      ;;
    *)
      echo "[brave] Please install Brave manually" >&2
      ;;
  esac
}

install_keepassxc() {
  if command -v keepassxc >/dev/null 2>&1; then
    echo "[keepassxc] Already installed"
    return 0
  fi

  local pm
  pm=$(detect_package_manager)

  case "$pm" in
    apt)
      pkg_install "$pm" keepassxc || true
      ;;
    dnf)
      pkg_install "$pm" keepassxc || true
      ;;
    pacman)
      pkg_install "$pm" keepassxc || true
      ;;
    *)
      echo "[keepassxc] Please install KeepassXC manually for your distro" >&2
      ;;
  esac
}

install_superproductivity() {
  if command -v superproductivity >/dev/null 2>&1; then
    echo "[superproductivity] Already installed"
    return 0
  fi

  local pm
  pm=$(detect_package_manager)

  case "$pm" in
    apt)
      # On Ubuntu/Linux Mint prefer Flatpak from Flathub
      if ! command -v flatpak >/dev/null 2>&1; then
        echo "[superproductivity] flatpak not found. Installing flatpak..."
        pkg_install "$pm" flatpak || true
      fi

      if command -v flatpak >/dev/null 2>&1; then
        echo "[superproductivity] Ensuring Flathub remote is configured"
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true

        echo "[superproductivity] Installing via Flatpak (Flathub)"
        flatpak install -y flathub com.superproductivity.SuperProductivity || \
          echo "[superproductivity] Failed to install via Flatpak" >&2
      else
        echo "[superproductivity] flatpak still not available, please install Super Productivity manually" >&2
      fi
      ;;
    dnf)
      pkg_install "$pm" superproductivity || true
      ;;
    pacman)
      pkg_install "$pm" superproductivity || true
      ;;
    *)
      echo "[superproductivity] Please install Super Productivity manually for your distro" >&2
      ;;
  esac
}

configure_keyboard_spanish_latam() {
  if ! command -v gsettings >/dev/null 2>&1; then
    echo "[keyboard] gsettings not available, skipping keyboard layout configuration" >&2
    return 0
  fi

  # Best-effort: set US + Spanish (Latin America) layouts
  if gsettings writable org.gnome.desktop.input-sources sources >/dev/null 2>&1; then
    echo "[keyboard] Setting keyboard layouts to US + Spanish (Latin America)"
    gsettings set org.gnome.desktop.input-sources sources "[(\"xkb\", \"us\"), (\"xkb\", \"latam\")]" || \
      echo "[keyboard] Failed to set keyboard layouts via gsettings" >&2
  else
    echo "[keyboard] org.gnome.desktop.input-sources.sources not writable, skipping" >&2
  fi
}

pin_browsers_to_panel() {
  if ! command -v gsettings >/dev/null 2>&1; then
    echo "[panel] gsettings not available, skipping browser pinning" >&2
    return 0
  fi

  # This is Cinnamon-specific (Linux Mint). For other desktops it will just no-op / fail harmlessly.
  if gsettings writable org.cinnamon favorite-apps >/dev/null 2>&1; then
    echo "[panel] Setting Cinnamon favorite apps to main browsers (overwriting existing list)"

    local favorites
    favorites="['google-chrome.desktop', 'brave-browser.desktop', 'chromium.desktop', 'org.gnome.Epiphany.desktop']"

    gsettings set org.cinnamon favorite-apps "$favorites" || \
      echo "[panel] Failed to update Cinnamon favorite apps" >&2
  else
    echo "[panel] org.cinnamon.favorite-apps not writable; skipping panel pinning" >&2
  fi
}

install_nvidia_drivers() {
  if command -v nvidia-smi >/dev/null 2>&1; then
    echo "[nvidia] Drivers already installed"
    return 0
  fi

  local pm
  pm=$(detect_package_manager)

  case "$pm" in
    apt)
      pkg_install "$pm" ubuntu-drivers-common || true
      if command -v ubuntu-drivers >/dev/null 2>&1; then
        sudo ubuntu-drivers autoinstall || true
      else
        echo "[nvidia] Please install appropriate nvidia-driver-* package for your GPU" >&2
      fi
      ;;
    dnf)
      echo "[nvidia] For Fedora/RHEL-based distros, enable RPM Fusion and install akmod-nvidia." >&2
      ;;
    pacman)
      echo "[nvidia] For Arch-based distros, install nvidia/nvidia-lts and related packages." >&2
      ;;
    *)
      echo "[nvidia] Please install NVIDIA drivers manually for your distro" >&2
      ;;
  esac
}

install_nvm_node() {
  local nvm_dir
  nvm_dir="${NVM_DIR:-$HOME/.nvm}"

  if [ ! -d "$nvm_dir" ]; then
    echo "[nvm] Installing NVM..."
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
  else
    echo "[nvm] Already installed"
  fi

  # Load nvm into current shell session
  if [ -s "$nvm_dir/nvm.sh" ]; then
    # shellcheck source=/dev/null
    . "$nvm_dir/nvm.sh"
  fi

  if ! command -v nvm >/dev/null 2>&1; then
    echo "[nvm] nvm command not available after installation. Please check your shell config." >&2
    return 1
  fi

  local node_version
  node_version="22.18.0"

  if nvm ls "$node_version" >/dev/null 2>&1; then
    echo "[nvm] Node $node_version already installed"
  else
    echo "[nvm] Installing Node $node_version..."
    nvm install "$node_version"
  fi

  nvm alias default "$node_version"
  nvm use "$node_version" >/dev/null 2>&1 || true

  echo "[nvm] Set default Node version to $node_version"
}

main() {
  echo "[restore] Starting Linux environment restoration..."

  local pm
  pm=$(detect_package_manager)
  echo "[restore] Detected package manager: $pm"

  install_yakuake
  configure_yakuake_autostart
  install_st
  install_oh_my_zsh
  install_powerline_fonts
  install_docker
  install_vscode
  install_chromium
  install_gnome_web
  install_dropbox
  install_chrome
  install_brave
  install_keepassxc
  install_superproductivity
  configure_keyboard_spanish_latam
  pin_browsers_to_panel
  install_nvidia_drivers
  install_nvm_node

  # Apply stored Linux defaults (keyboard layouts & shortcuts) if script exists
  if [ -n "${DOTLY_PATH:-}" ] && [ -x "$DOTLY_PATH/scripts/linux/defaults" ]; then
    "$DOTLY_PATH/scripts/linux/defaults" import || true
  fi

  echo "[restore] Done. Some changes (like docker group membership or drivers) may require a reboot or re-login."
}

main "$@"
