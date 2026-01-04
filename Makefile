.PHONY: build-docker build-docker-clang build-local build-local-clang clean clean-cache help

# Default t2linux commit (can be overridden: make build-docker T2LINUX_COMMIT=abc123)
T2LINUX_COMMIT ?= 699c8fd

# Docker settings
DOCKER_IMAGE := debian:trixie
DOCKER_PLATFORM := linux/amd64

help:
	@echo "Available targets:"
	@echo "  build-docker       - Build kernel in Docker container (amd64, gcc)"
	@echo "  build-docker-clang - Build kernel in Docker container (amd64, clang)"
	@echo "  build-local        - Build kernel locally (gcc, uses cache)"
	@echo "  build-local-clang  - Build kernel locally (clang, uses cache)"
	@echo "  clean              - Clean up build artifacts in repo"
	@echo "  clean-cache        - Remove persistent build cache (/tmp/pve-build-local)"
	@echo ""
	@echo "Environment variables:"
	@echo "  T2LINUX_COMMIT     - t2linux patches commit (default: 699c8fd)"

build-docker:
	@echo "==> Building kernel in Docker container (gcc)"
	@echo "    T2LINUX_COMMIT: $(T2LINUX_COMMIT)"
	@echo "    Platform: $(DOCKER_PLATFORM)"
	docker run --rm \
		--platform $(DOCKER_PLATFORM) \
		-v "$(PWD):/repo" \
		-w /repo \
		-e T2LINUX_COMMIT="$(T2LINUX_COMMIT)" \
		$(DOCKER_IMAGE) \
		bash -c 'set -e && bash /repo/scripts/build-kernel.sh'

build-docker-clang:
	@echo "==> Building kernel in Docker container (clang)"
	@echo "    T2LINUX_COMMIT: $(T2LINUX_COMMIT)"
	@echo "    Platform: $(DOCKER_PLATFORM)"
	docker run --rm \
		--platform $(DOCKER_PLATFORM) \
		-v "$(PWD):/repo" \
		-w /repo \
		-e T2LINUX_COMMIT="$(T2LINUX_COMMIT)" \
		-e COMPILER=clang \
		$(DOCKER_IMAGE) \
		bash -c 'set -e && bash /repo/scripts/build-kernel.sh'

build-local:
	@echo "==> Building kernel locally (gcc)"
	@echo "    T2LINUX_COMMIT: $(T2LINUX_COMMIT)"
	T2LINUX_COMMIT="$(T2LINUX_COMMIT)" bash scripts/build-kernel.sh

build-local-clang:
	@echo "==> Building kernel locally (clang)"
	@echo "    T2LINUX_COMMIT: $(T2LINUX_COMMIT)"
	T2LINUX_COMMIT="$(T2LINUX_COMMIT)" COMPILER=clang bash scripts/build-kernel.sh

clean:
	@echo "==> Cleaning up build artifacts in repo"
	rm -rf linux-t2-patches pve-kernel
	rm -f *.deb
	@echo "==> Clean complete"

clean-cache:
	@echo "==> Removing persistent build cache"
	rm -rf /tmp/pve-build-local
	@echo "==> Cache removed"
