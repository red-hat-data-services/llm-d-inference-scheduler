# Build Stage: using Go 1.24 image
FROM registry.access.redhat.com/ubi9/go-toolset:1.24 AS builder
ARG TARGETOS
ARG TARGETARCH
USER root 

WORKDIR /workspace

# Copy Red Hat repository configuration for zeromq packages
COPY rhelai.repo /etc/yum.repos.d/rhelai.repo

# Install build tools including Rust for building libtokenizers from source
# Install only packages not already in the base image (gcc-c++, libstdc++, etc. are already present)
# zeromq-devel is available from Red Hat Enterprise Linux AI repository
# Install Rust and Cargo from Red Hat repositories (conforma compliant)
RUN dnf install -y zeromq-devel rust cargo git && \
    dnf clean all && \
    rustc --version && \
    cargo --version

# Copy the Go Modules manifests
COPY go.mod go.mod
COPY go.sum go.sum

# Copy the go source
COPY cmd/ cmd/
COPY pkg/ pkg/

# Build libtokenizers from source to comply with conforma requirements
# This replaces the GitHub download
# Rust will automatically detect and build for the container's architecture
ARG RELEASE_VERSION=v1.22.1
RUN mkdir -p lib && \
    mkdir -p /tmp/tokenizers-build && \
    cd /tmp/tokenizers-build && \
    git clone --depth 1 --branch ${RELEASE_VERSION} https://github.com/daulet/tokenizers.git . && \
    make build && \
    find target/release -name "libtokenizers.a" -type f | head -1 | xargs -I {} cp {} /workspace/lib/ && \
    ranlib /workspace/lib/*.a && \
    cd /workspace && \
    rm -rf /tmp/tokenizers-build

# Build
# the GOARCH has not a default value to allow the binary be built according to the host where the command
# was called. For example, if we call make image-build in a local env which has the Apple Silicon M1 SO
# the docker BUILDPLATFORM arg will be linux/arm64 when for Apple x86 it will be linux/amd64. Therefore,
# by leaving it empty we can ensure that the container and binary shipped on it will have the same platform.
ENV CGO_ENABLED=1
ENV GOOS=${TARGETOS:-linux}
ENV GOARCH=${TARGETARCH}
ARG COMMIT_SHA=unknown
ARG BUILD_REF
RUN go build -a -o bin/epp -ldflags="-extldflags '-L$(pwd)/lib' -X sigs.k8s.io/gateway-api-inference-extension/version.CommitSHA=${COMMIT_SHA} -X sigs.k8s.io/gateway-api-inference-extension/version.BuildRef=${BUILD_REF}" cmd/epp/main.go

# Use ubi9 as a minimal base image to package the manager binary
# Refer to https://catalog.redhat.com/software/containers/ubi9/ubi-minimal/615bd9b4075b022acc111bf5 for more details
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest
WORKDIR /
COPY --from=builder /workspace/bin/epp /app/epp

# Install zeromq runtime library needed by the manager.
# zeromq is available from Red Hat Enterprise Linux AI repository
USER root

# Copy Red Hat repository configuration for zeromq packages
COPY rhelai.repo /etc/yum.repos.d/rhelai.repo

RUN microdnf install -y dnf && \
    dnf install -y zeromq && \
    dnf clean all && \
    rm -rf /var/cache/dnf /var/lib/dnf

USER 65532:65532

# expose gRPC, health and metrics ports
EXPOSE 9002
EXPOSE 9003
EXPOSE 9090

# expose port for KV-Events ZMQ SUB socket
EXPOSE 5557

ENTRYPOINT ["/app/epp"]
