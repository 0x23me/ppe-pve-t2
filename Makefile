.PHONY: deps-image build-docker build-docker-clang build-docker-staged build-docker-staged-clang build-local build-local-clang clean clean-cache help

# Default t2linux commit (can be overridden: make build-docker T2LINUX_COMMIT=abc123)
T2LINUX_COMMIT ?= 699c8fd

# Docker settings
DOCKER_IMAGE := debian:trixie
DOCKER_PLATFORM := linux/amd64

# Local Docker builds: dependencies are baked into a cached image (Dockerfile
# stage1, rebuilt only when build-kernel-stage1.sh changes) and the source
# checkouts (pve-kernel, ubuntu-kernel, zfsonlinux, t2linux) and the ccache
# live in a named volume, so reruns skip the apt install, the multi-GB clones
# and recompiling unchanged code.
DEPS_IMAGE := pve-kernel-deps
CACHE_VOLUME := pve-kernel-build-cache
PVE_KERNEL_TAG ?=

help:
	@echo "Available targets:"
	@echo "  deps-image                - Build/reuse the cached dependency image (Dockerfile stage1)"
	@echo "  build-docker              - Build kernel in Docker (gcc, cached deps image + source volume)"
	@echo "  build-docker-clang        - Build kernel in Docker (clang, cached deps image + source volume)"
	@echo "  build-docker-staged       - Build using multi-stage Dockerfile (gcc, cached layers)"
	@echo "  build-docker-staged-clang - Build using multi-stage Dockerfile (clang, cached layers)"
	@echo "  build-local               - Build kernel locally (gcc, uses cache)"
	@echo "  build-local-clang         - Build kernel locally (clang, uses cache)"
	@echo "  clean                     - Clean up build artifacts in repo"
	@echo "  clean-cache               - Remove persistent build caches (/tmp/pve-build-local, Docker volume)"
	@echo ""
	@echo "Environment variables:"
	@echo "  T2LINUX_COMMIT     - t2linux patches commit (default: 699c8fd)"

deps-image:
	@echo "==> Building/reusing dependency image $(DEPS_IMAGE)"
	docker build --platform $(DOCKER_PLATFORM) --target stage1 -t $(DEPS_IMAGE) .

build-docker: deps-image
	@echo "==> Building kernel in Docker container (gcc, cached deps + sources)"
	@echo "    T2LINUX_COMMIT: $(T2LINUX_COMMIT)"
	@echo "    PVE_KERNEL_TAG: $(if $(PVE_KERNEL_TAG),$(PVE_KERNEL_TAG),newest buildable)"
	docker run --rm \
		--platform $(DOCKER_PLATFORM) \
		-v "$(PWD):/repo" \
		-v $(CACHE_VOLUME):/cache \
		-w /repo \
		-e T2LINUX_COMMIT="$(T2LINUX_COMMIT)" \
		-e PVE_KERNEL_TAG="$(PVE_KERNEL_TAG)" \
		-e SKIP_DEPS=1 \
		-e BUILD_WORK_DIR=/cache/work \
		-e USE_CCACHE=1 \
		-e CCACHE_DIR=/cache/ccache \
		$(DEPS_IMAGE) \
		bash /repo/scripts/build-kernel.sh

build-docker-clang: deps-image
	@echo "==> Building kernel in Docker container (clang, cached deps + sources)"
	@echo "    T2LINUX_COMMIT: $(T2LINUX_COMMIT)"
	@echo "    PVE_KERNEL_TAG: $(if $(PVE_KERNEL_TAG),$(PVE_KERNEL_TAG),newest buildable)"
	docker run --rm \
		--platform $(DOCKER_PLATFORM) \
		-v "$(PWD):/repo" \
		-v $(CACHE_VOLUME):/cache \
		-w /repo \
		-e T2LINUX_COMMIT="$(T2LINUX_COMMIT)" \
		-e PVE_KERNEL_TAG="$(PVE_KERNEL_TAG)" \
		-e SKIP_DEPS=1 \
		-e BUILD_WORK_DIR=/cache/work \
		-e USE_CCACHE=1 \
		-e CCACHE_DIR=/cache/ccache \
		-e COMPILER=clang \
		$(DEPS_IMAGE) \
		bash /repo/scripts/build-kernel.sh

build-docker-staged:
	@echo "==> Building kernel with multi-stage Docker (gcc)"
	@echo "    T2LINUX_COMMIT: $(T2LINUX_COMMIT)"
	@echo "    Platform: $(DOCKER_PLATFORM)"
	docker build \
		--platform $(DOCKER_PLATFORM) \
		--build-arg T2LINUX_COMMIT="$(T2LINUX_COMMIT)" \
		-t pve-kernel-builder .
	docker run --rm \
		--platform $(DOCKER_PLATFORM) \
		-v "$(PWD):/repo" \
		pve-kernel-builder

build-docker-staged-clang:
	@echo "==> Building kernel with multi-stage Docker (clang)"
	@echo "    T2LINUX_COMMIT: $(T2LINUX_COMMIT)"
	@echo "    Platform: $(DOCKER_PLATFORM)"
	docker build \
		--platform $(DOCKER_PLATFORM) \
		--build-arg T2LINUX_COMMIT="$(T2LINUX_COMMIT)" \
		-t pve-kernel-builder .
	docker run --rm \
		--platform $(DOCKER_PLATFORM) \
		-v "$(PWD):/repo" \
		-e COMPILER=clang \
		pve-kernel-builder

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
	-docker volume rm $(CACHE_VOLUME)
	@echo "==> Cache removed"
