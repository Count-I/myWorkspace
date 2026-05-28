# Shell aliases - eza, bat, ripgrep, modern alternatives

# File listing
alias ls='eza --icons=auto'
alias ll='eza -lh --icons=auto'
alias la='eza -lha --icons=auto --sort=name --group-directories-first'
alias lt='eza --icons=auto --tree'
alias lta='eza --icons=auto --tree -a'

# File content
alias cat='bat --style=plain'
alias grep='rg'
alias find='fd'

# System monitoring
alias top='btop'
alias df='duf'
alias du='dust'

# Version control
alias g='git'
alias lg='lazygit'
alias ga='git add'
alias gc='git commit'
alias gs='git status'
alias gd='git diff'
alias gl='git log'

# Container tools
alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias di='docker images'

# System information
alias ff='fastfetch'
alias psg='ps aux | grep'

# Update system
alias update='~/.local/bin/update.sh'

# Wayland debugging
alias wl-clip-show='wl-paste'

# Logs
alias logs='journalctl -n 50 -f'
alias logerr='journalctl -p err -n 50'
alias syslog='sudo journalctl -n 50 -f'

# Snapshots
alias snap-list='snapper -c root list'
alias snap-create='snapper -c root create -d'
