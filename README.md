# Better ComfyUI Slim

A compact and optimized Docker container designed as an easy-to-use RunPod template for ComfyUI. Images are highly optimized for size, only ~650MB while including all features!

## Quick Deploy on RunPod

[![Deploy Regular on RunPod](https://img.shields.io/badge/Deploy%20on%20RunPod-Regular%20(CUDA%2012.4)-4B6BDC?style=for-the-badge&logo=docker)](https://runpod.io/console/deploy?template=cndsag8ob0&ref=vfker49t)

[![Deploy 5090 on RunPod](https://img.shields.io/badge/Deploy%20on%20RunPod-RTX%205090%20(CUDA%2012.8)-1BB91F?style=for-the-badge&logo=docker)](https://runpod.io/console/deploy?template=tm7neqjjww&ref=vfker49t)


Choose your template:
- 🖥️ [Regular Template](https://runpod.io/console/deploy?template=cndsag8ob0&ref=vfker49t) - For most GPUs (CUDA 12.4)
- 🎮 [RTX 5090 Template](https://runpod.io/console/deploy?template=tm7neqjjww&ref=vfker49t) - Optimized for RTX 5090 (CUDA 12.8)

## Why Better ComfyUI Slim?

- 🎯 Purpose-built for RunPod deployments
- 📦 Ultra-compact: Only ~650MB image size (compared to multi-GB alternatives)
- 🚀 Zero configuration needed: Works out of the box
- 🛠️ Includes all essential tools for remote work

## Features

- 🚀 Two optimized variants:
  - Regular: CUDA 12.4 with stable PyTorch
  - RTX 5090: CUDA 12.8 with PyTorch Nightly (optimized for latest NVIDIA GPUs)
- 🔧 Built-in tools:
  - FileBrowser for easy file management (port 8080)
  - Zasper (Jupiter Replacement) (port 8048)
  - SSH access
- 🎨 Pre-installed custom nodes:
  - ComfyUI-Manager
  - ComfyUI-Crystools
  - ComfyUI-KJNodes
- ⚡ Performance optimizations:
  - UV package installer for faster dependency installation
  - NVENC support in FFmpeg
  - Optimized CUDA configurations

## Ports

- `8188`: ComfyUI web interface
- `8080`: FileBrowser interface
- `8048`: Zasper file access
- `22`: SSH access

## Custom Arguments

You can customize ComfyUI startup arguments by editing `/workspace/madapps/comfyui_args.txt`. Add one argument per line:
```
--max-batch-size 8
--preview-method auto
```

## Directory Structure

- `/workspace/madapps/ComfyUI`: Main ComfyUI installation
- `/workspace/madapps/comfyui_args.txt`: Custom arguments file
- `/workspace/madapps/filebrowser.db`: FileBrowser database

## License

This project is licensed under the GPLv3 License.
