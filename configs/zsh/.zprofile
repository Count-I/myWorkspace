# .zprofile - TTY autologin gate for Hyprland launch
# Executed by login shells before .zshrc

# Auto-launch Hyprland on TTY1 (TTY autologin configuration)
if [[ -z $DISPLAY && -z $WAYLAND_DISPLAY && $(tty) == /dev/tty1 ]]; then
    exec Hyprland
fi
