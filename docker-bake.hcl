variable "TAG" {
  default = "slim"
}

# Common settings for all targets
target "common" {
  context = "."
  platforms = ["linux/amd64"]
  args = {
    BUILDKIT_INLINE_CACHE = "1"
  }
}

# Regular ComfyUI image (CUDA 12.4)
target "regular" {
  inherits = ["common"]
  dockerfile = "Dockerfile"
  tags = ["madiator2011/better-comfyui:${TAG}"]
}

# RTX 5090 optimized image (CUDA 12.8 + PyTorch Nightly)
target "rtx5090" {
  inherits = ["common"]
  dockerfile = "Dockerfile.5090"
  args = {
    START_SCRIPT = "start.5090.sh"
  }
  tags = ["madiator2011/better-comfyui:${TAG}-5090"]
}
