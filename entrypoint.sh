#!/usr/bin/env bash
set -e

# If there is a tty, give us a shell.
# (This happens e.g. when you "kubectl attach -it" or "docker run -ti".)
# Otherwise, keep the container alive, and start sshd only if explicitly
# enabled (ssh.enabled in the Helm chart). Attaching or exec-ing in remains
# the primary, always-available way in.

if tty >/dev/null 2>&1; then
  # -p preserves the environment busybox login would otherwise wipe,
  # including KUBERNETES_SERVICE_HOST/PORT - without it, kubectl inside
  # the shell can't find the in-cluster API server at all.
  exec login -f -p k8s
fi

if [ "${SSH_ENABLED:-false}" = "true" ]; then
  if ! [ -f /etc/ssh/ssh_host_rsa_key ]; then
    ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N ""
  fi
  if [ "$AUTHORIZED_KEYS" ]; then
    echo 'Environment variable $AUTHORIZED_KEYS found. Adding keys.'
    sudo -u k8s mkdir -p ~k8s/.ssh
    sudo -u k8s touch ~k8s/.ssh/authorized_keys
    while read -r KEY; do
      if [ "$KEY" ] && ! grep -q "$KEY" ~k8s/.ssh/authorized_keys; then
        echo "$KEY" >> ~k8s/.ssh/authorized_keys
      fi
    done <<< "$AUTHORIZED_KEYS"
  fi
  if [ "$PASSWORD" ]; then
    echo 'Environment variable $PASSWORD found. Setting user password.'
  elif [ ! "$AUTHORIZED_KEYS" ] && [ "${GENERATE_PASSWORD_LENGTH:-0}" -gt 0 ]; then
    echo 'Environment variable $PASSWORD not found. Generating a password.'
    PASSWORD=$(base64 /dev/urandom | tr -d +/ | head -c "$GENERATE_PASSWORD_LENGTH")
    echo "PASSWORD=$PASSWORD"
  else
    echo 'Environment variable $PASSWORD not found. User password will not be set.'
  fi
  if [ "$PASSWORD" ]; then
    echo "k8s:$PASSWORD" | chpasswd
  fi
  exec /usr/sbin/sshd -D -e
fi

echo "SSH is disabled (the default). Attach with:"
echo "  kubectl attach -it <pod>"
echo "or exec in directly:"
echo "  kubectl exec -it <pod> -- login -f -p k8s"
exec sleep infinity
