# podium's default shell config for the k8s user.
# Kept deliberately small: this pod is meant to feel like a normal terminal,
# not carry a full personal dotfiles framework.

# If we don't already have a kubeconfig, build one from the ServiceAccount
# token rather than relying on KUBERNETES_SERVICE_HOST/PORT being present -
# login -f -p preserves them, but a file-based kubeconfig doesn't depend on
# that at all, and (per shpod, which hit the same problem) is also what
# makes "kubectl --as=someone-else" work correctly.
if [ ! -f "$HOME/.kube/config" ]; then
  (
    umask 077
    mkdir -p "$HOME/.kube"
    if kubectl get configmap kubeconfig >/dev/null 2>&1; then
      kubectl get configmap kubeconfig -o json |
        jq -r '.data | to_entries | .[0].value' > "$HOME/.kube/config"
    else
      SADIR=/var/run/secrets/kubernetes.io/serviceaccount
      if [ -r "$SADIR/token" ]; then
        kubectl config set-cluster podium \
          --server=https://kubernetes.default.svc \
          --certificate-authority="$SADIR/ca.crt" >/dev/null
        kubectl config set-credentials podium \
          --token="$(cat "$SADIR/token")" >/dev/null
        kubectl config set-context podium --cluster=podium --user=podium >/dev/null
        kubectl config use-context podium >/dev/null
      fi
    fi
  )
fi

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
