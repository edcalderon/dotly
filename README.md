## edcalderon dotfiles

Personal dotfiles and restore scripts, built on top of
[`CodelyTV/dotly`](https://github.com/CodelyTV/dotly).

These configs are tailored for **Linux Mint** (Ubuntu‑
based) fresh installations, but most things should work
on other Debian/Ubuntu systems too.

---

## What this repo does

- **Manages my shell and tooling**
  - Zsh + Oh My Zsh with `agnoster` theme
  - Powerline‑compatible fonts (Fira Code, powerline)
  - Yakuake as primary terminal (auto‑started)
- **Sets up my dev environment**
  - `nvm` with default Node.js `22.18.0`
  - Docker (via distro package on apt‑based systems)
  - VS Code
  - Chromium
  - NVIDIA drivers (best‑effort, Ubuntu/Mint focused)

Most of this logic is in the **default Linux
restoration script**:

`dotfiles_template/restoration_scripts/01-default_linux_restoration.sh`

Shared Linux helpers live in:

`dotfiles_template/os/linux/.dotly`

---

## Installed apps (via default Linux restoration)

The script `01-default_linux_restoration.sh` installs
and configures (best‑effort, mainly tested on Linux
Mint):

- **Terminal & shell**
  - Yakuake (with autostart enabled)
  - `st` terminal (suckless, built from source)
  - Zsh + Oh My Zsh (`agnoster` theme)
  - Powerline‑compatible fonts (Fira Code, powerline)

- **Browsers**
  - Chromium
  - Google Chrome
  - Brave Browser
  - GNOME Web (Epiphany)

- **Productivity & utilities**
  - Dropbox (nautilus‑dropbox / dropbox, where
    available)
  - KeepassXC
  - Super Productivity (best‑effort via Flatpak;
    may require manual install if not found)

- **Developer tools**
  - Docker (`docker.io` on apt‑based systems)
  - Visual Studio Code
  - `nvm` + Node.js `22.18.0` (set as default)

- **System & drivers**
  - NVIDIA GPU drivers (Ubuntu/Mint best‑effort via
    `ubuntu-drivers`)
  - Keyboard layouts: US + Spanish (Latin America)
  - Cinnamon panel favorites: main browsers pinned

Everything is written to be safe to re‑run: already
installed apps are usually detected and skipped.

---

## Target environment

- **Primary**: Linux Mint (Ubuntu‑based), clean
  installation.
- **Assumptions**:
  - You are comfortable running scripts that use `sudo`.
  - You are using a desktop session that honors
    `~/.config/autostart/*.desktop` (for Yakuake
    autostart).

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

3. **Initialize dotly submodule** (if not already)

   ```bash
   git submodule update --init --recursive modules/dotly
   ```

4. **Install dotfiles via dotly**

   ```bash
   DOTFILES_PATH="$HOME/.dotfiles" \
   DOTLY_PATH="$DOTFILES_PATH/modules/dotly" \
   "$DOTLY_PATH/bin/dot" self install
   ```

5. **Run the default Linux restoration script**

   This will install and configure Yakuake, Oh My Zsh
   (`agnoster`), fonts, Docker, VS Code, Chromium,
   NVIDIA drivers (where possible) and NVM + Node
   `22.18.0`.

   ```bash
   cd "$DOTFILES_PATH"
   DOTFILES_PATH="$PWD/dotfiles_template" \
     bash dotfiles_template/restoration_scripts/01-default_linux_restoration.sh
   ```

6. **Log out and back in**

   - Ensures `chsh` (default shell = zsh) takes effect.
   - Allows Yakuake autostart via
     `~/.config/autostart/yakuake.desktop`.

After logging back in, open Yakuake and you should get
Zsh + Oh My Zsh with the `agnoster` theme and proper
powerline fonts.

---

## Repo layout (short version)

```bash
├── dotfiles_template/
│  ├── os/
│  │  └── linux/.dotly              # Linux helpers
│  ├── restoration_scripts/
│  │  └── 01-default_linux_restoration.sh
│  ├── shell/                       # Shell config
│  ├── editors/                     # Editor config (VS Code, etc.)
│  ├── symlinks/                    # Symlink configuration
│  └── ...                          # Other dotly pieces
└── modules/dotly/                  # Upstream dotly framework
```

For more details about how dotly itself works, see the
upstream project: <https://github.com/CodelyTV/dotly>.

---

## Credits

- Built on top of **[CodelyTV/dotly](https://github.com/CodelyTV/dotly)**.
- Many concepts also inspired by
  [denisidoro/dotfiles](https://github.com/denisidoro/dotfiles).

