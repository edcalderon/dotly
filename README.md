## edcalderon dotfiles

Personal dotfiles and restore scripts, built on top of
[`CodelyTV/dotly`](https://github.com/CodelyTV/dotly).

> **Baseline: Linux Mint 22.3 (Zena) – Cinnamon 6.6.9 – Updated 2026-09-02**
> This README reflects the actual configuration detected on the main
> Linux Mint profile on 2026-09-02. All restoration paths were verified on
> this host (`ed` / `X-Cinnamon`, `X11`, kernel `7.0.0-30-generic`).

---

## What this repo does ( 2026-09-02 baseline )

- **Shell – Zsh as default**
  - `zsh 5.9 (x86_64-ubuntu-linux-gnu)` + `Oh My Zsh` (`agnoster` theme)
  - `ZSH=$HOME/.oh-my-zsh`, `ZSH_THEME="agnoster"`, `SHELL=/usr/bin/zsh`
  - PATH managed via `dotfiles_template/shell/exports.sh` (`$HOME/.opencode/bin` first) and fallback in `dotfiles_template/shell/zsh/.zshrc` – works for both `zsh` and `bash` via `dotfiles_template/shell/init.sh`
  - Nerd Fonts available in session: `FiraCode Nerd Font Mono 12` + `MesloLGS/LGL Nerd Font Mono` (installed to `~/.local/share/fonts/`)
- **Yakuake as primary terminal (auto-started)**
  - `yakuake 23.08.5` with autostart `~/.config/autostart/yakuake.desktop` (`X-GNOME-Autostart-Delay=0`, `Exec=yakuake`)
  - Konsole profile `~/.local/share/konsole/Profile 1.profile`:
    ```
    [Appearance] ColorScheme=GreenOnBlack, Font=FiraCode Nerd Font Mono,12,-1,5,50,0,0,0,0,0
    [General] Command=/usr/bin/zsh, Name=Profile 1, Parent=FALLBACK/
    ```
  - `~/.config/yakuakerc` `DefaultProfile=Profile 1.profile`
- **Dev environment**
  - `nvm` (`$HOME/.nvm`) with `Node 22.22.2` (`npm 10.9.7`) set as default (`nvm alias default 22.22.2`)
  - `opencode 1.18.26` (`~/.opencode/bin/opencode`, `@opencode-ai/plugin 1.18.26`, `~/.config/opencode/opencode.jsonc`) – installed via `https://opencode.ai/install --no-modify-path`, PATH via dotfiles, verified `zsh -ic 'which opencode'`
  - Docker `29.1.3 (0ubuntu3~24.04.2)` (`docker.io` on apt)
  - VS Code `1.136.0` + VSCodium `1.126.04524` (`/usr/bin/codium`) as default IDE (`editor`/`visual` via `update-alternatives`, `xdg-mime`, `git config --global core.editor "codium --wait"`)
- **Browsers & productivity**
  - Chromium `152.0.7977.64`, Google Chrome `152.0.7977.75`, Brave `152.1.94.117`, GNOME Web (`epiphany-browser`)
  - Dropbox (`nautilus-dropbox`), KeepassXC, Super Productivity (Flatpak `com.superproductivity.SuperProductivity`)
- **System**
  - Keyboard: `latam,us` with `grp:alt_caps_toggle` (Alt+Caps toggles), applied to **both** `org.gnome.desktop.input-sources` and `org.cinnamon.desktop.input-sources` (`gsettings` + `dconf` + `setxkbmap latam,us -option grp:alt_caps_toggle`), persisted via `localectl set-x11-keymap` and `/etc/default/keyboard` (`XKBLAYOUT="latam,us"`, `XKBOPTIONS="grp:alt_caps_toggle"` – requires `sudo`)
  - Cinnamon panel favorites pinned: `google-chrome.desktop`, `brave-browser.desktop`, `chromium.desktop`, `org.gnome.Epiphany.desktop` (`org.cinnamon favorite-apps`)
  - NVIDIA drivers via `ubuntu-drivers autoinstall` (best-effort, host has no NVIDIA GPU detected)

Most logic lives in:

- `dotfiles_template/restoration_scripts/01-default_linux_restoration.sh` (idempotent, safe to re-run)
- `dotfiles_template/os/linux/.dotly` (helpers `detect_package_manager`, `pkg_install`)
- `scripts/linux/defaults` (now exports/imports **both** `org.gnome` and `org.cinnamon` input-sources + `cinnamon-keybindings`; auto-applies via `gsettings`/`setxkbmap`)
- Stored defaults: `dotfiles_template/os/linux/settings/gnome-input-sources.dconf` + `cinnamon-input-sources.dconf` + `cinnamon-keybindings.dconf`

---

## Changelog – 2026-09-02

- **OpenCode for Zsh (default shell)**
  - `dotfiles_template/shell/exports.sh:31` – prepend `$HOME/.opencode/bin` to `path` (highest priority)
  - `dotfiles_template/shell/zsh/.zshrc:46` – idempotent fallback `export PATH="$HOME/.opencode/bin:$PATH"` if not present
  - `dotfiles_template/restoration_scripts/01-default_linux_restoration.sh:763` – new `install_opencode()` (checks `command -v opencode`, `curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path`, verifies `1.18.26`)
  - Live `~/.zshrc:111` patched for current session
- **Keyboard layout fix – Linux Mint Cinnamon baseline**
  - Root cause: Mint uses `org.cinnamon.desktop.input-sources`, script only set `org.gnome` → `setxkbmap` stayed `us,us`
  - `configure_keyboard_spanish_latam()` now loops both schemas, `dconf load` both paths, `setxkbmap latam,us -option grp:alt_caps_toggle`, `localectl` + `/etc/default/keyboard`
  - `scripts/linux/defaults` now handles `cinnamon-input-sources.dconf` + fallback `gnome→cinnamon` sync + immediate `gsettings`/`setxkbmap`
  - Stored: `dotfiles_template/os/linux/settings/cinnamon-input-sources.dconf`
  - Restorer defaults invocation now tries 5 candidates (`$DOTLY_PATH`, `$DOTFILES_PATH/../scripts`, etc.)
- **Yakuake/Konsole profile force-update**
  - `configure_yakuake_autostart()` always overwrites autostart (adds `X-GNOME-Autostart-Delay=0`), overwrites `Profile 1.profile`, `fc-cache -f`, restarts `yakuake` if running
  - Verified: `Profile 1.profile` `Font=FiraCode Nerd Font Mono,12` + `Command=/usr/bin/zsh`

---

## Installed apps (via `01-default_linux_restoration.sh`) – verified 2026-09-02

- **Terminal & shell**
  - Yakuake `23.08.5` (autostart `~/.config/autostart/yakuake.desktop`)
  - `st` (suckless, built from source)
  - Zsh `5.9` + Oh My Zsh `agnoster`
  - Powerline / Nerd Fonts: `FiraCode Nerd Font 3.4.0` (`~/.local/share/fonts/FiraCodeNerd/`), `MesloLGS/LGL Nerd Font Mono` (`~/.local/share/fonts/Meslo/`), `fonts-powerline`, `powerline`

- **Browsers**
  - Chromium `152.0.7977.64`
  - Google Chrome `152.0.7977.75`
  - Brave Browser `152.1.94.117`
  - GNOME Web (Epiphany)

- **Productivity & utilities**
  - Dropbox (`nautilus-dropbox`)
  - KeepassXC
  - Super Productivity (Flatpak, best-effort)

- **Developer tools**
  - Docker `29.1.3` (`docker.io` on apt, `usermod -aG docker $USER`)
  - Visual Studio Code `1.136.0`
  - VSCodium `1.126.04524` as default IDE
  - `nvm` + Node `22.22.2` (`npm 10.9.7`)
  - OpenCode `1.18.26` (`~/.opencode/bin/opencode`)

- **System & drivers**
  - NVIDIA drivers (Ubuntu/Mint `ubuntu-drivers autoinstall`, no GPU on this host)
  - Keyboard: `latam,us` `grp:alt_caps_toggle` (Cinnamon + GNOME)
  - Cinnamon favorites: `google-chrome`, `brave-browser`, `chromium`, `org.gnome.Epiphany`

Re-runnable: already-installed checks skip.

---

## Target environment – detected 2026-09-02

```
Distributor: Linuxmint 22.3 (Zena) / Ubuntu noble
Kernel:      7.0.0-30-generic #30~24.04.1-Ubuntu SMP PREEMPT_DYNAMIC
Desktop:     X-Cinnamon 6.6.9 (X11, DISPLAY=:0, DESKTOP_SESSION=cinnamon)
Shell:       zsh 5.9 / Oh My Zsh agnoster (SHELL=/usr/bin/zsh, passwd currently /bin/bash – chsh -s /usr/bin/zsh requires password, handled by restorer via sudo -v)
Fonts:       FiraCode Nerd Font Mono 12, MesloLGS/LGL Nerd Font Mono
Keyboard:    org.cinnamon/desktop/input-sources=[('xkb','latam'),('xkb','us')] xkb-options=['grp:alt_caps_toggle']
            org.gnome/desktop/input-sources same, setxkbmap latam,us grp:alt_caps_toggle
Yakuake:     23.08.5, Profile 1.profile (GreenOnBlack, FiraCode Nerd Font Mono, zsh)
Node:        v22.22.2 via nvm, npm 10.9.7
OpenCode:    1.18.26 ~/.opencode/bin/opencode
Docker:      29.1.3
VS Code/Codium: code 1.136.0, codium 1.126.04524 (git core.editor="codium --wait")
Browsers:    chromium 152, google-chrome 152, brave 152
```

Assumptions:
- `sudo` available
- Desktop honors `~/.config/autostart/*.desktop`

---

## How to restore on a fresh Linux Mint install

1. **Install git**
   ```bash
   sudo apt update
   sudo apt install -y git
   ```
2. **Clone this repo as your dotfiles**
   ```bash
   git clone https://github.com/edcalderon/dotly "$HOME/.dotfiles"
   cd "$HOME/.dotfiles"
   ```
3. **Initialize submodules**
   ```bash
   git submodule update --init --recursive modules/dotly 2>/dev/null || git submodule update --init --recursive
   ```
4. **Install dotfiles via dotly**
   ```bash
   DOTFILES_PATH="$HOME/.dotfiles" \
   DOTLY_PATH="$DOTFILES_PATH/modules/dotly" \
   "$DOTLY_PATH/bin/dot" self install
   # or if dotly is at repo root (this repo): DOTLY_PATH="$HOME/.dotfiles"
   ```
5. **Run the default Linux restoration script**
   ```bash
   cd "$HOME/.dotfiles"
   DOTFILES_PATH="$PWD/dotfiles_template" \
     bash dotfiles_template/restoration_scripts/01-default_linux_restoration.sh
   # Installs: zsh + Oh My Zsh (agnoster), Nerd Fonts, nvm Node 22.22.2, opencode 1.18.26,
   # docker, VS Code, VSCodium (default), yakuake, chromium/chrome/brave, keepassxc, etc.
   # Configures: keyboard latam,us (Cinnamon+GNOME), yakuake Profile 1 (zsh + FiraCode Nerd), panel favorites
   ```
6. **Apply stored desktop defaults (if not already via restorer)**
   ```bash
   # Uses dotfiles_template/os/linux/settings/gnome/cinnamon-input-sources.dconf
   bash scripts/linux/defaults import
   # or: DOTLY_PATH="$PWD" bash scripts/linux/defaults import
   ```
7. **Log out and back in**
   - `chsh -s /usr/bin/zsh` takes effect
   - Yakuake autostart via `~/.config/autostart/yakuake.desktop`
   - Keyboard `Alt+Caps` toggles `latam ↔ us`

After login, `yakuake` -> `zsh` + `agnoster` + Nerd Font, `opencode --version` works, `setxkbmap -query` shows `latam,us`.

---

## Repo layout (short version)

```bash
├── dotfiles_template/
│  ├── os/
│  │  ├── linux/.dotly              # helpers
│  │  └── linux/settings/           # gnome-input-sources.dconf, cinnamon-input-sources.dconf, cinnamon-keybindings.dconf
│  ├── restoration_scripts/
│  │  └── 01-default_linux_restoration.sh  # main Linux Mint baseline (zsh, opencode, keyboard, yakuake, etc.)
│  ├── shell/
│  │  ├── exports.sh                # PATH includes $HOME/.opencode/bin
│  │  ├── zsh/.zshrc                # + opencode fallback, nvm, zim
│  │  └── ...                       # init.sh, aliases.sh, functions.sh
│  ├── symlinks/                    # conf.yaml (→ ~/.zshrc etc.)
│  └── ...                          # editors, symlinks, etc.
├── scripts/
│  ├── linux/defaults               # dconf import/export for keyboard (GNOME + Cinnamon)
│  └── ...                          # package, docker, etc.
└── modules/
   ├── dotbot/
   └── z/
```

Upstream: <https://github.com/CodelyTV/dotly>.

---

## Credits

- Built on top of **[CodelyTV/dotly](https://github.com/CodelyTV/dotly)**.
- Inspired by [denisidoro/dotfiles](https://github.com/denisidoro/dotfiles).
- Baseline captured 2026-09-02 on Linux Mint 22.3 / Cinnamon 6.6.9.
