# syntax=docker/dockerfile:1
# Multi-stage Dockerfile for building PVE kernel with T2 support
#
# Stage 1: Install packages and dependencies
# Stage 2: Clone repos and prepare patches (requires T2LINUX_COMMIT)
# Stage 3: Compile kernel (runtime, compiler selectable)
#
# Usage:
#   # Build image (stages 1 & 2)
#   docker build --build-arg T2LINUX_COMMIT=<commit> -t pve-kernel-builder .
#
#   # Run compilation with gcc (default)
#   docker run --rm -v $(pwd):/repo pve-kernel-builder
#
#   # Run compilation with clang
#   docker run --rm -v $(pwd):/repo -e COMPILER=clang pve-kernel-builder

FROM debian:trixie AS stage1
LABEL stage=stage1

# Copy stage 1 script
COPY scripts/build-kernel-stage1.sh /tmp/

# Run stage 1: Install packages and dependencies.
# The image layer is cached until build-kernel-stage1.sh changes; the apt
# download cache mount keeps the .debs across rebuilds of this layer too.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache && \
    bash /tmp/build-kernel-stage1.sh

# Stage 2: Clone repos and prepare patches
FROM stage1 AS stage2
LABEL stage=stage2

# Copy patches directory (needed for stage 2)
COPY patches /repo/patches

# Copy stage 2 script
COPY scripts/build-kernel-stage2.sh /tmp/

# Set working directory for cloning
WORKDIR /src

# Set environment variables
ARG T2LINUX_COMMIT
ENV T2LINUX_COMMIT=${T2LINUX_COMMIT}
ENV REPO_ROOT=/repo
ENV WORK_DIR=/src

# Run stage 2: Clone repositories and prepare patches
RUN bash /tmp/build-kernel-stage2.sh

# Stage 3: Compile kernel
FROM stage2 AS stage3
LABEL stage=stage3

# Copy stage 3 script
COPY scripts/build-kernel-stage3.sh /tmp/

# Set working directory
WORKDIR /src

# Default command runs stage 3 only (repos already cloned in stage 2)
# When run with mounted /repo volume, output .deb files will be accessible on host:
#   docker run --rm -v $(pwd):/repo pve-kernel-builder
#
# To use clang instead of gcc:
#   docker run --rm -v $(pwd):/repo -e COMPILER=clang pve-kernel-builder
CMD ["bash", "/tmp/build-kernel-stage3.sh"]
