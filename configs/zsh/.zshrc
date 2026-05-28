# .zshrc - Interactive shell configuration

# History
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY

# Completion
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*:*:*:*:*' menu select

# Shell options
setopt AUTO_CD
setopt CORRECT
setopt EXTENDED_GLOB
setopt NO_CASE_GLOB
setopt GLOB_DOTS

# Key bindings (Emacs mode by default)
bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward

# Load zsh plugins from Arch package repos
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Load custom aliases
source "$HOME/.config/zsh/aliases.zsh"

# Initialize prompt (MUST be last line - starship needs to hook precmd/preexec)
eval "$(starship init zsh)"
