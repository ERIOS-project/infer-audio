# vLLM serving image with audio extras preinstalled, for audio models served by vLLM.
# Base pinned by digest — this is vllm/vllm-openai:v0.27.1.
# When upgrading vLLM: update this digest AND the vllm[audio]==X.Y.Z version below together.
FROM vllm/vllm-openai@sha256:0a51ea5b4ae2dc5d81890e5173f54203d2a3ae0cfffe51b8fd2afd4391bfd967

# Audio dependencies. The extra version MUST match the vLLM version of the base image.
RUN pip install --no-cache-dir "vllm[audio]==0.27.1" librosa

# Patch OS packages and vulnerable Python deps flagged by Trivy
# (GnuPG CVE-2025-68973, OpenSSL CVE-2026-45447, msgpack GHSA-6v7p-g79w-8964,
# setuptools CVE-2025-47273)
RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir "msgpack>=1.2.1" "setuptools>=78.1.1"

# Non-root runtime user (uid/gid 10001). The base image already ships a
# 'vllm' user, so use a distinct name.
RUN groupadd --gid 10001 infer \
    && useradd --uid 10001 --gid 10001 --create-home --shell /usr/sbin/nologin infer

USER 10001:10001

# Entrypoint/CMD inherited from the base image (vllm serve / OpenAI-compatible API server)
