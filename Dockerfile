# vLLM serving image with audio extras preinstalled, for audio models served by vLLM.
# Base pinned by digest — this is vllm/vllm-openai:v0.29.0.
# When upgrading vLLM: update this digest AND the vllm[audio]==X.Y.Z version below together.
FROM vllm/vllm-openai@sha256:c2914767605584b6d8f45686b82de173ecc99e781897aa3d0a66dacd72c51ae1

# Audio dependencies. The extra version MUST match the vLLM version of the base image.
# pip is then removed from the image: it is never invoked at runtime, and the latest
# pip (26.2.1) still vendors vulnerable copies of msgpack 1.1.2 (GHSA-6v7p-g79w-8964)
# and setuptools 70.3.0 (CVE-2025-47273) under pip/_vendor. The real runtime packages
# shipped by the base are already patched (msgpack 1.2.2, setuptools 80.10.2).
# `uv` remains available in the image if a package manager is ever needed.
RUN pip install --no-cache-dir "vllm[audio]==0.29.0" librosa \
    && pip uninstall -y pip \
    && rm -f /usr/local/bin/pip /usr/local/bin/pip3 /usr/local/bin/pip3.12

# Patch OS packages flagged by Trivy. Must run AFTER the pip step above:
# apt reinstalls python3.12 and restores the PEP 668 EXTERNALLY-MANAGED marker,
# which would make any later `pip install` fail.
RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Non-root runtime user (uid/gid 10001). The base image already ships a
# 'vllm' user, so use a distinct name.
RUN groupadd --gid 10001 infer \
    && useradd --uid 10001 --gid 10001 --create-home --shell /usr/sbin/nologin infer

USER 10001:10001

# Entrypoint/CMD inherited from the base image (vllm serve / OpenAI-compatible API server)
