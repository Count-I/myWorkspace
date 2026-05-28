#!/usr/bin/env bash
# Cheatsheet viewer - displays keybindings in a floating window

kitty --class "kitty" --title "cheatsheet" \
      --override "background_opacity=0.95" \
      --override "font_size=11.0" \
      bash -c "bat --style=plain ~/.config/hypr/keybinds.conf | less -R"
