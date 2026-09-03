FROM --platform=$BUILDPLATFORM golang:alpine@sha256:4c9fe60190a2a3350ddc51de80d0224b8a6698d12bdfc999fee45ea9d6c46dbc AS builder
RUN apk add curl git make
ARG BUILDARCH TARGETARCH
# hadolint ignore=DL3044
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
ARG CRANE_VERSION=v0.21.9
RUN go install github.com/google/go-containerregistry/cmd/crane@$CRANE_VERSION
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

FROM alpine@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS podium
ENV COMPLETIONS=/usr/share/bash-completion/completions
RUN apk add --no-cache bash bash-completion curl fzf gettext git iputils jq \
    libintl ncurses openssh openssl python3 py3-pip sudo tmux tree unzip vim yq zsh

# https://github.com/rohitg00/kubectl-mcp-server
#
# Installed directly in this stage, not as its own "FROM builder AS X" stage
# like the tools above - those are all statically-linked Go binaries that
# copy cleanly between stages; a Python venv is dynamically linked against
# the interpreter and shared libraries of whatever stage built it, so
# building it anywhere other than this final image (and copying it in) risks
# a musl/libc mismatch at runtime. Building it here, against this stage's own
# python3, sidesteps that entirely.
#
# fastmcp is pinned below <4 because kubectl-mcp-server's own dependency pin
# (fastmcp>=3.0.0b1) has no upper bound: an unconstrained install resolves
# fastmcp 4.x, which pulls in a breaking mcp 2.x rewrite that
# kubectl_mcp_tool's own code can't import - the tool never starts. Both
# versions pinned exactly (not just fastmcp's ceiling) so a new
# kubectl-mcp-server release can't reintroduce a break like that one
# silently; Dependabot will open a PR to review instead. Confirmed working
# 2026-09-03 against a real cluster - see platformfix/k8s-training's
# slides/ai-demo/ai-demo.migration-notes.md for the full dry-run, including
# a real bug found in kubectl-mcp-server's own --disable-destructive flag
# (it blocks every write, not just deletes - not something this image can
# fix, just something worth knowing before relying on it live).
ARG KUBECTL_MCP_SERVER_VERSION=1.24.0
RUN python3 -m venv /opt/kubectl-mcp-server \
 && /opt/kubectl-mcp-server/bin/pip install --no-cache-dir \
    "kubectl-mcp-server==${KUBECTL_MCP_SERVER_VERSION}" "fastmcp<4" \
 && ln -s /opt/kubectl-mcp-server/bin/kubectl-mcp-serve /usr/local/bin/kubectl-mcp-serve

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
    echo "kubectl-mcp-server $(kubectl-mcp-serve version)" ;\
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
