#!/bin/sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Running preflight checks..."
if [ ! -f "$SCRIPT_DIR/.ssh/config" ]; then
    echo "!! Missing $SCRIPT_DIR/.ssh/config -- it's gitignored (held a real internal IP/username, stripped from the repo)." >&2
    echo "!! Copy the template and fill in real values before continuing:" >&2
    echo "!!   cp $SCRIPT_DIR/.ssh/config.example $SCRIPT_DIR/.ssh/config" >&2
    echo "!!   \$EDITOR $SCRIPT_DIR/.ssh/config" >&2
    echo "!! Without it, the iclinic-tunnel systemd service enabled later in this script has no host to connect to." >&2
    exit 1
fi

echo "==> Installing packages from official repositories..."
sudo pacman -S --needed - < "$SCRIPT_DIR/.packages" && \

echo "==> Setting up /etc/theme-assets (shared avatar)..." && \
sudo mkdir -p /etc/theme-assets && \
sudo chown "$USER:$USER" /etc/theme-assets && \
sudo chmod 755 /etc/theme-assets && \
cp "$HOME/Pictures/lockscreen/pfp-1.png" /etc/theme-assets/avatar.png && \

echo "==> Installing AUR Helper (yay)..."
git clone https://aur.archlinux.org/yay.git /tmp/yay && \
cd /tmp/yay && \
makepkg -si && \
cd "$SCRIPT_DIR" && \
rm -rf /tmp/yay && \

echo "==> Installing AUR packages..."
yay -S --needed - < "$SCRIPT_DIR/.aur_packages" && \

echo "==> Installing Oh My Zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && \

echo "==> Installing Powerlevel10k theme..."
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
    "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" && \

echo "==> Adding user to docker group..."
sudo usermod -aG docker "$USER" && \

echo "==> Enabling system services..."
sudo systemctl enable NetworkManager.service bluetooth.service docker.service ollama.service udisks2.service fstrim.timer paccache.timer && \

echo "==> Setting ZSH as default shell..."
chsh -s "$(which zsh)" && \

echo "==> Stowing dotfiles..."
rm -f "$HOME/.zshrc" && \
cd "$SCRIPT_DIR" && \
stow --no-folding -t "$HOME" \
    --ignore='^\.git$' \
    --ignore='^\.claude$' \
    --ignore='^docs$' \
    --ignore='^\.oh-my-zsh$' \
    . && \

echo "==> Symlinking hyprland.lua..."
ln -sf "$SCRIPT_DIR/.config/hypr/hyprland.lua" "$HOME/.config/hypr/hyprland.lua" && \

echo "==> Generating machine-local secrets (~/.zshrc.local)..." && \
if [ ! -f "$HOME/.zshrc.local" ]; then
    touch "$HOME/.zshrc.local" && \
    chmod 600 "$HOME/.zshrc.local" && \
    echo "export CAPY_DB_KEY='$(openssl rand -base64 48)'" >> "$HOME/.zshrc.local" && \
    echo "Generated a new CAPY_DB_KEY in ~/.zshrc.local (never tracked in the repo)." && \
    echo "Run 'capy encrypt' after installing capy to apply it."
fi && \

echo "==> Enabling PipeWire filter-chain for noise suppression..."
systemctl --user enable --now filter-chain && \

echo "==> Enabling iclinic SSH tunnel service..."
systemctl --user daemon-reload && \
systemctl --user enable --now iclinic-tunnel.service && \

echo "==> Enabling SearxNG local search backend..."
systemctl --user enable --now searxng.service && \

echo "==> Enabling Wayscriber screen annotation daemon..."
systemctl --user enable --now wayscriber.service && \

echo "==> Setting up ly..." && \
sudo mkdir -p /etc/ly && \
sudo chown "$USER:$USER" /etc/ly && \
sudo chmod 755 /etc/ly && \

echo "==> Enabling ly..." && \
sudo systemctl enable ly@tty1.service && \

echo "==> Post-install complete!"
echo "Reboot or log out and log back in for all changes to take effect."
