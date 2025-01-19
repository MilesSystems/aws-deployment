#!/bin/bash

set -eEBx

# Step 1: Install prerequisites (Zsh, Git, Curl, Fonts)
echo "Installing prerequisites..."
dnf install --allowerasing -y zsh git curl fontconfig

# Step 2: Set Zsh as the default shell
echo "Setting Zsh as the default shell..."
usermod -s "$(which zsh)" "$(whoami)"

# Step 3: Install PowerLevel10k
echo "Installing PowerLevel10k..."
P10K_DIR="$HOME/.zsh/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
else
    echo "PowerLevel10k is already installed at $P10K_DIR."
fi

# Step 4: Configure Zsh to use PowerLevel10k
echo "Configuring Zsh..."
ZSHRC="$HOME/.zshrc"
if [ ! -f "$ZSHRC" ]; then
    touch "$ZSHRC"
fi

# Ensure PowerLevel10k is sourced in .zshrc
grep -q "source $P10K_DIR/powerlevel10k.zsh-theme" "$ZSHRC" || echo "source $P10K_DIR/powerlevel10k.zsh-theme" >> "$ZSHRC"

curl -o ~/.p10k.zsh https://raw.githubusercontent.com/MilesSystems/aws-deployment/refs/heads/main/.github/assets/shell/.p10k.sh

# Step 5: Clone powerlevel10k-media and install Nerd Fonts
echo "Installing Nerd Font (MesloLGS NF)..."
MEDIA_REPO="$HOME/.zsh/powerlevel10k-media"
if [ ! -d "$MEDIA_REPO" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k-media.git "$MEDIA_REPO"
else
    echo "PowerLevel10k media repository is already cloned at $MEDIA_REPO."
fi

FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"
cp "$MEDIA_REPO/"*.ttf "$FONT_DIR"

# Refresh font cache
fc-cache -fv

# Step 6: Reload Zsh
echo "Reloading Zsh to apply changes..."
if [ -z "$ZSH_NAME" ]; then
    SHELL=$(which zsh)
    export SHELL
    exec zsh
fi

# Step 7: Final message
echo "Installation complete! You can run 'p10k configure' to customize PowerLevel10k."
