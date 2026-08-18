# vLLM serving image with audio extras preinstalled, for Cohere Transcribe ASR.
# Base pinned by digest — this is vllm/vllm-openai:v0.27.1.
# When upgrading vLLM: update this digest AND the vllm[audio]==X.Y.Z version below together.
FROM vllm/vllm-openai@sha256:0a51ea5b4ae2dc5d81890e5173f54203d2a3ae0cfffe51b8fd2afd4391bfd967

# Audio dependencies. The extra version MUST match the vLLM version of the base image.
RUN pip install --no-cache-dir "vllm[audio]==0.27.1" librosa

# Non-root runtime user (uid/gid 10001)
RUN groupadd --gid 10001 vllm \
    && useradd --uid 10001 --gid 10001 --create-home --shell /usr/sbin/nologin vllm

USER 10001:10001

# Entrypoint/CMD inherited from the base image (vllm serve / OpenAI-compatible API server)
