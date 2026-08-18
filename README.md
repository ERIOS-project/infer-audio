# infer-audio

Custom [vLLM](https://github.com/vllm-project/vllm) serving image with **audio dependencies preinstalled**, running as a **non-root user**, built to serve **any audio model supported by vLLM** (ASR, speech-to-text, audio-language models — e.g. [CohereLabs/cohere-transcribe-03-2026](https://huggingface.co/CohereLabs/cohere-transcribe-03-2026), Whisper, Qwen-Audio, ...) on Kubernetes.

The official `vllm/vllm-openai` image does not ship the audio extras, which forces a `pip install` at container startup. This repo produces an **immutable image** with everything baked in.

## Image

- **Registry:** `ghcr.io/erios-project/infer-audio`
- **Tags:** `v0.27.1` (matches the vLLM version) and `latest`
- **Base image:** `vllm/vllm-openai` **v0.27.1**, pinned by digest (`sha256:0a51ea5b...`) in the [Dockerfile](Dockerfile)
- **Added on top of the base:** `vllm[audio]==0.27.1` extras and `librosa`
- **Runtime user:** non-root, uid/gid `10001:10001`
- **Entrypoint/CMD:** inherited unchanged from the base image (OpenAI-compatible API server)

## Build, scan and push (local)

The image is built, scanned and pushed manually from a workstation. The Trivy scan is a hard gate: **do not push if it fails**.

```bash
IMAGE=ghcr.io/erios-project/infer-audio
VLLM_VERSION=v0.27.1

# 1. Build
docker build -t $IMAGE:$VLLM_VERSION -t $IMAGE:latest .

# 2. Scan (blocks on any fixable CRITICAL/HIGH vulnerability)
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$HOME/.cache/trivy:/root/.cache/trivy" \
  -v "$PWD/.trivyignore:/.trivyignore:ro" \
  ghcr.io/aquasecurity/trivy:0.72.0@sha256:cffe3f5161a47a6823fbd23d985795b3ed72a4c806da4c4df16266c02accdd6f \
  image --ignorefile /.trivyignore --timeout 30m \
  --severity CRITICAL,HIGH --exit-code 1 --ignore-unfixed --format table \
  $IMAGE:$VLLM_VERSION

# 3. Push (only if step 2 exited 0)
docker login ghcr.io   # PAT with write:packages
docker push $IMAGE:$VLLM_VERSION
docker push $IMAGE:latest
```

[`.trivyignore`](.trivyignore) lists the accepted findings: copies of `msgpack`/`setuptools` vendored *inside pip itself* (`pip/_vendor`), which are not importable at runtime. The real runtime packages are patched in the Dockerfile.

## Getting the published digest

Deployments should pin the image **by digest** (e.g. in the Helm chart). `docker push` prints the digest on completion; you can also retrieve it at any time:

```bash
docker buildx imagetools inspect ghcr.io/erios-project/infer-audio:v0.27.1
# or
crane digest ghcr.io/erios-project/infer-audio:v0.27.1
```

Then deploy as:

```yaml
image: ghcr.io/erios-project/infer-audio@sha256:<digest>
```

## Upgrading vLLM

The audio extra version **must match exactly** the vLLM version of the base image. To upgrade, change **both at the same time** in the `Dockerfile`:

1. Find the digest of the new `vllm/vllm-openai:vX.Y.Z` tag:
   ```bash
   crane digest vllm/vllm-openai:vX.Y.Z
   ```
2. Update the `FROM vllm/vllm-openai@sha256:...` line with the new digest.
3. Update the pip line to `"vllm[audio]==X.Y.Z"`.
4. Run the build/scan/push procedure above with `VLLM_VERSION=vX.Y.Z` — push only if the scan passes.
