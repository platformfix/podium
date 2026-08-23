# podium's default shell config for the k8s user.
# Kept deliberately small: this pod is meant to feel like a normal terminal,
# not carry a full personal dotfiles framework.

export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=9999
export SAVEHIST=9999
# Write each command to HISTFILE as it runs (not just on shell exit) so the
# broadcast sidecar can tail it live.
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt INTERACTIVE_COMMENTS

autoload -Uz compinit && compinit -C

[ -f "$HOME/.aliases" ] && source "$HOME/.aliases"

if command -v kubectl >/dev/null 2>&1; then
  source <(kubectl completion zsh)
  compdef kubecolor=kubectl
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
