FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV IMAGEIO_FFMPEG_EXE=/usr/bin/ffmpeg
ENV FILEBROWSER_CONFIG=/workspace/.filebrowser.json

# Update and install minimal dependencies, CUDA, and common tools
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    software-properties-common \
    gpg-agent \
    && add-apt-repository ppa:deadsnakes/ppa && \
    add-apt-repository ppa:cybermax-dexter/ffmpeg-nvenc && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    python3.12 \
    python3.12-venv \
    python3.12-dev \
    build-essential \
    wget \
    gnupg \
    xz-utils \
    openssh-client \
    openssh-server \
    nano \
    wget \
    curl \
    htop \
    tmux \
    ca-certificates \
    less \
    net-tools \
    iputils-ping \
    procps \
    golang \
    make \
    && wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb \
    && dpkg -i cuda-keyring_1.1-1_all.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends cuda-minimal-build-12-4 \
    && apt-get install -y --no-install-recommends ffmpeg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm cuda-keyring_1.1-1_all.deb \
    && curl -sS https://bootstrap.pypa.io/get-pip.py | python3.12

# Install FileBrowser
RUN curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

# Set CUDA environment variables
ENV PATH=/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}

# Install Zasper webapp
RUN wget https://github.com/zasper-io/zasper/releases/download/v0.1.0-alpha/zasper-webapp-linux-amd64.tar.gz \
    && tar xf zasper-webapp-linux-amd64.tar.gz -C /usr/local/bin \
    && rm zasper-webapp-linux-amd64.tar.gz

# Install Jupyter with Python kernel
RUN pip install jupyter

# Configure SSH for root login
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    mkdir -p /run/sshd

# Create workspace directory
RUN mkdir -p /workspace
WORKDIR /workspace

# Expose ports
EXPOSE 8188 22 8048 8080

# Copy and set up start script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Set Python 3.12 as default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 && \
    update-alternatives --set python3 /usr/bin/python3.12

ENTRYPOINT ["/start.sh"]
