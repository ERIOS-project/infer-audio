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

## Build pipeline

The [build workflow](.github/workflows/build.yml) runs on:

- every push to `main` that touches the `Dockerfile` or the workflow itself,
- manual trigger via **workflow_dispatch** (Actions tab → *Build, scan and push vLLM audio image* → *Run workflow*).

The order of operations is a security gate:

1. **Build locally** (no push) — the image is loaded into the runner's Docker daemon.
2. **Trivy scan** — the image is scanned with Trivy `0.72.0` (pinned by digest) using `--severity CRITICAL,HIGH --exit-code 1 --ignore-unfixed`. Any **critical or high vulnerability with an available fix fails the job**, and the image is never pushed. The full report is printed in table format in the job log.
3. **Push to GHCR** — only reached if the scan passes. Both `v0.27.1` and `latest` tags are pushed.

The workflow also frees ~15 GB of disk on the `ubuntu-latest` runner before building (the base image is >10 GB) and uses the GitHub Actions buildx cache to avoid re-downloading the base on every run.

## Getting the published digest

Deployments should pin the image **by digest** (e.g. in the Helm chart). After each successful run, the pushed digest is printed in the **job summary** ($GITHUB_STEP_SUMMARY) on the workflow run page.

You can also retrieve it at any time:

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
4. Update `VLLM_VERSION` in `.github/workflows/build.yml` so the image tag follows.
5. Push to `main` — the pipeline builds, scans and (if clean) publishes the new image.
