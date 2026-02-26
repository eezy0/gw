#!/usr/bin/env bash
set -euo pipefail

REPO="eezy0/gw"
RAW_URL="https://raw.githubusercontent.com/$REPO/main/gw.plugin.zsh"

echo "Installing gw..."
echo ""

# oh-my-zsh
if [[ -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins" ]]; then
  DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/gw"
  mkdir -p "$DIR"
  curl -fsSL "$RAW_URL" -o "$DIR/gw.plugin.zsh"
  echo "Installed to: $DIR"
  echo ""
  echo "Add 'gw' to your plugins in ~/.zshrc:"
  echo '  plugins=(... gw)'
else
  DIR="$HOME/.zsh-functions"
  mkdir -p "$DIR"
  curl -fsSL "$RAW_URL" -o "$DIR/gw.zsh"
  echo "Installed to: $DIR/gw.zsh"
  echo ""
  if ! grep -q 'gw.zsh' "$HOME/.zshrc" 2>/dev/null; then
    echo "source $DIR/gw.zsh" >> "$HOME/.zshrc"
    echo "Added source line to ~/.zshrc"
  fi
fi

echo ""
echo "Restart your shell or run: source ~/.zshrc"
