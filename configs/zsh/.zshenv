# .zshenv - Loaded by ALL zsh invocations (login, interactive, scripts)

# XDG Base Directory
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"

# zsh configuration directory
export ZDOTDIR="$HOME"

# Application defaults
export EDITOR="nano"
export VISUAL="code"
export BROWSER="google-chrome-stable"
export TERMINAL="kitty"
export PAGER="less"

# Path additions
export PATH="$HOME/.local/bin:$PATH"

# History
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=50000
export SAVEHIST=50000
