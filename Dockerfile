FROM --platform=$BUILDPLATFORM golang:alpine AS builder
RUN apk add curl git make
ARG BUILDARCH TARGETARCH
ENV BUILDARCH=$BUILDARCH \
    CGO_ENABLED=0 \
    GOARCH=$TARGETARCH \
    TARGETARCH=$TARGETARCH
COPY helper-* /bin/
RUN chmod +x /bin/helper-curl /bin/helper-unsupported

# https://github.com/argoproj/argo-cd/releases/latest
FROM builder AS argocd
RUN helper-curl bin argocd \
    https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-@GOARCH

# https://github.com/google/go-containerregistry/tree/main/cmd/crane
FROM builder AS crane
RUN go install github.com/google/go-containerregistry/cmd/crane@latest
RUN cp $(find bin -name crane) /usr/local/bin

# https://github.com/fluxcd/flux2/releases
FROM builder AS flux
ARG FLUX_VERSION=2.9.4
RUN helper-curl tar flux \
    https://github.com/fluxcd/flux2/releases/download/v$FLUX_VERSION/flux_${FLUX_VERSION}_linux_@GOARCH.tar.gz

# https://github.com/helm/helm/releases
FROM builder AS helm
ARG HELM_VERSION=4.2.4
RUN helper-curl tar "--strip-components=1 linux-@GOARCH/helm" \
    https://get.helm.sh/helm-v${HELM_VERSION}-linux-@GOARCH.tar.gz

# https://github.com/derailed/k9s/releases
FROM builder AS k9s
RUN helper-curl tar k9s \
    https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_@GOARCH.tar.gz

# https://github.com/kubernetes/kubernetes/releases
FROM builder AS kubectl
ARG KUBECTL_VERSION=1.36.4
RUN helper-curl tar "--strip-components=3 kubernetes/client/bin/kubectl" \
    https://dl.k8s.io/v${KUBECTL_VERSION}/kubernetes-client-linux-@GOARCH.tar.gz

# https://github.com/kubecolor/kubecolor/releases
FROM builder AS kubecolor
ARG KUBECOLOR_VERSION=0.6.0
RUN helper-curl tar kubecolor \
    https://github.com/kubecolor/kubecolor/releases/download/v${KUBECOLOR_VERSION}/kubecolor_${KUBECOLOR_VERSION}_linux_@GOARCH.tar.gz

# https://github.com/stackrox/kube-linter/releases
FROM builder AS kube-linter
ARG KUBELINTER_VERSION=v0.8.3
RUN go install golang.stackrox.io/kube-linter/cmd/kube-linter@$KUBELINTER_VERSION
RUN cp $(find bin -name kube-linter) /usr/local/bin

# https://github.com/bitnami-labs/sealed-secrets/releases
FROM builder AS kubeseal
ARG KUBESEAL_VERSION=0.39.1
RUN helper-curl tar kubeseal \
    https://github.com/bitnami-labs/sealed-secrets/releases/download/v$KUBESEAL_VERSION/kubeseal-$KUBESEAL_VERSION-linux-@GOARCH.tar.gz

# https://github.com/kubernetes-sigs/kustomize/releases
FROM builder AS kustomize
ARG KUSTOMIZE_VERSION=5.8.1
RUN helper-curl tar kustomize \
    https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v$KUSTOMIZE_VERSION/kustomize_v${KUSTOMIZE_VERSION}_linux_@GOARCH.tar.gz

# https://github.com/derailed/popeye/releases
FROM builder AS popeye
RUN helper-curl tar popeye \
    https://github.com/derailed/popeye/releases/latest/download/popeye_linux_@GOARCH.tar.gz

# https://github.com/regclient/regclient/releases
FROM builder AS regctl
ARG REGCLIENT_VERSION=0.11.5
RUN helper-curl bin regctl \
    https://github.com/regclient/regclient/releases/download/v$REGCLIENT_VERSION/regctl-linux-@GOARCH

# https://github.com/stern/stern/releases
FROM builder AS stern
ARG STERN_VERSION=1.34.0
RUN helper-curl tar stern \
    https://github.com/stern/stern/releases/download/v${STERN_VERSION}/stern_${STERN_VERSION}_linux_@GOARCH.tar.gz

# https://github.com/vmware-tanzu/velero/releases
FROM builder AS velero
ARG VELERO_VERSION=1.18.2
RUN helper-curl tar "--strip-components=1 velero-v${VELERO_VERSION}-linux-@GOARCH/velero" \
    https://github.com/vmware-tanzu/velero/releases/download/v${VELERO_VERSION}/velero-v${VELERO_VERSION}-linux-@GOARCH.tar.gz

# https://github.com/starship/starship/releases
FROM builder AS starship
ARG STARSHIP_VERSION=1.26.0
RUN helper-curl tar starship \
    https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/starship-@UARCH-unknown-linux-musl.tar.gz

# https://github.com/joewalnes/websocketd/releases
# Ships as a zip, not a tarball, so helper-curl's tar handling doesn't apply.
FROM builder AS websocketd
RUN apk add --no-cache unzip
ARG WEBSOCKETD_VERSION=0.4.1
RUN curl -fsSL -o /tmp/websocketd.zip \
    https://github.com/joewalnes/websocketd/releases/download/v${WEBSOCKETD_VERSION}/websocketd-${WEBSOCKETD_VERSION}-linux_${GOARCH}.zip \
 && unzip -p /tmp/websocketd.zip websocketd > /usr/local/bin/websocketd \
 && chmod +x /usr/local/bin/websocketd \
 && rm /tmp/websocketd.zip

FROM alpine AS podium
ENV COMPLETIONS=/usr/share/bash-completion/completions
RUN apk add --no-cache bash bash-completion curl fzf gettext git iputils jq \
    libintl ncurses openssh openssl sudo tmux tree unzip vim yq zsh

COPY --from=argocd      /usr/local/bin/argocd         /usr/local/bin
COPY --from=crane       /usr/local/bin/crane          /usr/local/bin
COPY --from=flux        /usr/local/bin/flux           /usr/local/bin
COPY --from=helm        /usr/local/bin/helm           /usr/local/bin
COPY --from=k9s         /usr/local/bin/k9s            /usr/local/bin
COPY --from=kubectl     /usr/local/bin/kubectl        /usr/local/bin
COPY --from=kubecolor   /usr/local/bin/kubecolor      /usr/local/bin
COPY --from=kube-linter /usr/local/bin/kube-linter    /usr/local/bin
COPY --from=kubeseal    /usr/local/bin/kubeseal       /usr/local/bin
COPY --from=kustomize   /usr/local/bin/kustomize      /usr/local/bin
COPY --from=popeye      /usr/local/bin/popeye         /usr/local/bin
COPY --from=regctl      /usr/local/bin/regctl         /usr/local/bin
COPY --from=stern       /usr/local/bin/stern          /usr/local/bin
COPY --from=velero      /usr/local/bin/velero         /usr/local/bin
COPY --from=starship    /usr/local/bin/starship       /usr/local/bin
COPY --from=websocketd  /usr/local/bin/websocketd     /usr/local/bin

RUN set -e ; for BIN in \
    argocd \
    crane \
    flux \
    helm \
    kubectl \
    kube-linter \
    kustomize \
    velero \
    ; do echo $BIN ; $BIN completion bash > $COMPLETIONS/$BIN.bash ; done ;\
    stern --completion bash > $COMPLETIONS/stern

RUN cd /tmp \
 && git clone --depth=1 https://github.com/ahmetb/kubectx \
 && cd kubectx \
 && mv kubectx /usr/local/bin/kctx \
 && mv kubens /usr/local/bin/kns \
 && mv completion/kubectx.bash $COMPLETIONS/kctx.bash \
 && mv completion/kubens.bash $COMPLETIONS/kns.bash \
 && cd .. \
 && rm -rf kubectx

# A real binary, not a shell alias, so "k" resolves to kubecolor even
# outside the k8s user's zsh (e.g. "kubectl exec <pod> -- sh"), which
# doesn't source .aliases the way "login -f -p k8s" does.
RUN printf '#!/bin/sh\nexec kubecolor "$@"\n' > /usr/local/bin/k \
 && chmod +x /usr/local/bin/k

# Create the k8s user and finalize setup.
RUN echo k8s:x:1000: >> /etc/group \
 && echo k8s:x:1000:1000::/home/k8s:/bin/zsh >> /etc/passwd \
 && echo "k8s ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/k8s \
 && mkdir /home/k8s \
 && chown -R k8s:k8s /home/k8s/ \
 && sed -i 's/#MaxAuthTries 6/MaxAuthTries 42/' /etc/ssh/sshd_config \
 && sed -i 's/AllowTcpForwarding no/AllowTcpForwarding yes/' /etc/ssh/sshd_config

COPY --chown=1000:1000 zshrc    /home/k8s/.zshrc
COPY --chown=1000:1000 aliases  /home/k8s/.aliases
COPY --chown=1000:1000 starship.toml /home/k8s/.config/starship.toml
COPY --chown=1000:1000 vimrc    /home/k8s/.vimrc
COPY --chown=1000:1000 tmux.conf /home/k8s/.tmux.conf
COPY motd /etc/motd
COPY entrypoint.sh /entrypoint.sh
COPY broadcast.sh /usr/local/bin/broadcast.sh
COPY assets/broadcast.html /opt/podium/broadcast/index.html
RUN chmod +x /entrypoint.sh /usr/local/bin/broadcast.sh

# Generate a list of all installed versions, for the MOTD and troubleshooting.
RUN ( \
    bash --version | head -n1 ;\
    zsh --version ;\
    starship --version | head -n1 ;\
    curl --version | head -n1 ;\
    envsubst --version | head -n1 ;\
    flux --version ;\
    git --version ;\
    jq --version ;\
    ssh -V ;\
    tmux -V ;\
    yq --version ;\
    echo "argocd $(argocd version --client | head -n1)" ;\
    echo "crane $(crane version)" ;\
    echo "Helm $(helm version --short)" ;\
    echo "k9s $(k9s version | grep Version)" ;\
    echo "kubecolor $(kubecolor --kubecolor-version)" ;\
    echo "kubectl $(kubectl version --client | head -n1)" ;\
    echo "kube-linter $(kube-linter version)" ;\
    kubeseal --version ;\
    echo "kustomize $(kustomize version | head -n1)" ;\
    echo "popeye $(popeye version | grep Version)" ;\
    echo "regctl $(regctl version --format={{.VCSTag}})" ;\
    echo "stern $(stern --version | grep ^version)" ;\
    echo "velero $(velero version --client-only | grep Version)" ;\
    ) > /home/k8s/versions.txt \
 && chown 1000:1000 /home/k8s/versions.txt

# Pre-create the history file so the broadcast sidecar (which mounts $HOME
# read-only) has something to tail even before anyone attaches.
RUN touch /home/k8s/.zsh_history && chown 1000:1000 /home/k8s/.zsh_history

VOLUME /home/k8s
CMD ["/entrypoint.sh"]
EXPOSE 22/tcp
EXPOSE 1088/tcp
ENV GENERATE_PASSWORD_LENGTH=20
