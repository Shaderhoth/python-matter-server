FROM python:3.12-slim-bookworm

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /app

RUN \
    set -x \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        libuv1 \
        zlib1g \
        libjson-c5 \
        libnl-3-200 \
        libnl-route-3-200 \
        unzip \
        gdb \
        iputils-ping \
        iproute2 \
    && apt-get purge -y --auto-remove \
    && rm -rf \
        /var/lib/apt/lists/* \
        /usr/src/*

ARG PYTHON_MATTER_SERVER

ENV chip_example_url "https://github.com/home-assistant-libs/matter-linux-ota-provider/releases/download/2024.7.2"
ARG TARGETPLATFORM

RUN \
    set -x \
    && echo "${TARGETPLATFORM}" \
    && if [ "${TARGETPLATFORM}" = "linux/amd64" ]; then \
        curl -Lo /usr/local/bin/chip-ota-provider-app "${chip_example_url}/chip-ota-provider-app-x86-64"; \
    elif [ "${TARGETPLATFORM}" = "linux/arm64" ]; then \
        curl -Lo /usr/local/bin/chip-ota-provider-app "${chip_example_url}/chip-ota-provider-app-aarch64"; \
    else \
        exit 1; \
    fi \
    && chmod +x /usr/local/bin/chip-ota-provider-app

# Copy the Python package from the context provided by the workflow
COPY my-python-package/python_matter_server-*.tar.gz /tmp/

# Install the local Python package
RUN pip3 install --no-cache-dir /tmp/python_matter_server-*.tar.gz

VOLUME ["/data"]
EXPOSE 5580

ENTRYPOINT [ "matter-server" ]
CMD [ "--storage-path", "/data", "--paa-root-cert-dir", "/data/credentials" ]
