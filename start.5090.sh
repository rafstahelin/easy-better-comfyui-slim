#!/bin/bash
set -e  # Exit the script if any statement returns a non-true return value

COMFYUI_DIR="/workspace/ComfyUI"
VENV_DIR="$COMFYUI_DIR/.venv"
FILEBROWSER_CONFIG="/root/.config/filebrowser/config.json"
DB_FILE="/workspace/filebrowser.db"

# ---------------------------------------------------------------------------- #
#                          Function Definitions                                  #
# ---------------------------------------------------------------------------- #

# Build CONFIG bashrc (if available on network volume)
build_config_bashrc() {
    if [ -f /workspace/CONFIG/bashrc/deploy/build-bashrc.sh ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🔧 Building CONFIG Bashrc"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        /workspace/CONFIG/bashrc/deploy/build-bashrc.sh > /root/.bashrc
        echo "✅ CONFIG bashrc installed"
        echo ""
    else
        echo "⚠️  CONFIG bashrc not found (skipping)"
        # Create minimal bashrc
        echo '# Minimal bashrc for ComfyUI pod' > /root/.bashrc
    fi

    # Add tools to PATH (for Claude CLI and code-server if installed on network volume)
    echo 'export PATH="/usr/local/cuda/bin:/workspace/tools/node/bin:/workspace/tools/npm-global/bin:$PATH"' >> /root/.bashrc
    echo 'export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"' >> /root/.bashrc
}

# Setup SSH with optional key or random password
setup_ssh() {
    mkdir -p ~/.ssh
    
    # Generate host keys if they don't exist
    for type in rsa dsa ecdsa ed25519; do
        if [ ! -f "/etc/ssh/ssh_host_${type}_key" ]; then
            ssh-keygen -t ${type} -f "/etc/ssh/ssh_host_${type}_key" -q -N ''
            echo "${type^^} key fingerprint:"
            ssh-keygen -lf "/etc/ssh/ssh_host_${type}_key.pub"
        fi
    done

    # If PUBLIC_KEY is provided, use it
    if [[ $PUBLIC_KEY ]]; then
        echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys
        chmod 700 -R ~/.ssh
    else
        # Generate random password if no public key
        RANDOM_PASS=$(openssl rand -base64 12)
        echo "root:${RANDOM_PASS}" | chpasswd
        echo "Generated random SSH password for root: ${RANDOM_PASS}"
    fi

    # Configure SSH to preserve environment variables
    echo "PermitUserEnvironment yes" >> /etc/ssh/sshd_config

    # Start SSH service
    /usr/sbin/sshd
}

# Export environment variables
export_env_vars() {
    echo "Exporting environment variables..."
    
    # Create environment files
    ENV_FILE="/etc/environment"
    PAM_ENV_FILE="/etc/security/pam_env.conf"
    SSH_ENV_DIR="/root/.ssh/environment"
    
    # Backup original files
    cp "$ENV_FILE" "${ENV_FILE}.bak" 2>/dev/null || true
    cp "$PAM_ENV_FILE" "${PAM_ENV_FILE}.bak" 2>/dev/null || true
    
    # Clear files
    > "$ENV_FILE"
    > "$PAM_ENV_FILE"
    mkdir -p /root/.ssh
    > "$SSH_ENV_DIR"
    
    # Export to multiple locations for maximum compatibility
    # Include Easy CLI API keys and tokens
    printenv | grep -E '^RUNPOD_|^PATH=|^_=|^CUDA|^LD_LIBRARY_PATH|^PYTHONPATH|^HF_API_TOKEN|^CIVITAI_API_TOKEN|^GITHUB_TOKEN|^ANTHROPIC_API_KEY|^GEMINI_API_KEY|^GROQ_API_KEY|^CEREBRAS_API_KEY|^OPENROUTER_API_KEY|^DEEPSEEK_API_KEY' | while read -r line; do
        # Get variable name and value
        name=$(echo "$line" | cut -d= -f1)
        value=$(echo "$line" | cut -d= -f2-)

        # Add to /etc/environment (system-wide)
        echo "$name=\"$value\"" >> "$ENV_FILE"

        # Add to PAM environment
        echo "$name DEFAULT=\"$value\"" >> "$PAM_ENV_FILE"

        # Add to SSH environment file
        echo "$name=\"$value\"" >> "$SSH_ENV_DIR"

        # Add to current shell
        echo "export $name=\"$value\"" >> /etc/rp_environment
    done
    
    # Add sourcing to shell startup files
    echo 'source /etc/rp_environment' >> ~/.bashrc
    echo 'source /etc/rp_environment' >> /etc/bash.bashrc
    
    # Set permissions
    chmod 644 "$ENV_FILE" "$PAM_ENV_FILE"
    chmod 600 "$SSH_ENV_DIR"
}

# Setup Easy CLI integrations (rclone, HF, GitHub, Git config)
setup_easy_cli() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎨 Easy CLI Setup - Automated Configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 1. Setup rclone (copy from workspace volume - already there permanently)
    if [ -f /workspace/rclone.conf ]; then
        echo "📦 Setting up rclone..."
        mkdir -p /root/.config/rclone
        cp /workspace/rclone.conf /root/.config/rclone/rclone.conf
        chmod 600 /root/.config/rclone/rclone.conf
        echo "✅ Rclone configured (dbx profile)"
    else
        echo "⚠️  No rclone.conf found at /workspace/rclone.conf"
        echo "💡 Upload your rclone.conf to the network volume at /workspace/rclone.conf"
    fi

    echo ""

    # 2. Setup Hugging Face CLI
    if [ -n "$HF_API_TOKEN" ]; then
        echo "🤗 Setting up Hugging Face CLI..."
        if command -v hf &> /dev/null; then
            hf auth login --token "$HF_API_TOKEN" --add-to-git-credential 2>/dev/null && \
                echo "✅ Hugging Face CLI authenticated" || \
                echo "⚠️  Hugging Face CLI authentication failed"
        else
            echo "📥 Installing Hugging Face CLI..."
            pip install --no-cache-dir "huggingface_hub[cli]" > /dev/null 2>&1 && \
                echo "✅ Hugging Face CLI installed" || \
                echo "❌ Failed to install Hugging Face CLI"

            if command -v hf &> /dev/null; then
                hf auth login --token "$HF_API_TOKEN" --add-to-git-credential 2>/dev/null && \
                    echo "✅ Hugging Face CLI authenticated" || \
                    echo "⚠️  Hugging Face CLI authentication failed"
            fi
        fi
    else
        echo "⚠️  HF_API_TOKEN not set in environment"
    fi

    echo ""

    # 3. Setup Git config (common for all methods)
    echo "🔧 Setting up Git configuration..."
    git config --global user.name "rafstahelin"
    git config --global user.email "64715158+rafstahelin@users.noreply.github.com"
    echo "✅ Git config set"

    echo ""

    # 4. Setup GitHub credentials (SSH or HTTPS)
    echo "🔐 Setting up GitHub credentials..."

    # Method 1: SSH Private Key (preferred - more secure)
    SSH_KEY="${SSH_PRIVATE_KEY_BASE64:-$RUNPOD_SECRET_SSH_PRIVATE_KEY_BASE64}"
    if [ -n "$SSH_KEY" ]; then
        echo "Setting up SSH authentication..."
        mkdir -p /root/.ssh
        chmod 700 /root/.ssh

        # Decode and install SSH key
        echo "$SSH_KEY" | base64 -d > /root/.ssh/id_ed25519
        chmod 600 /root/.ssh/id_ed25519

        # Add GitHub to known_hosts
        ssh-keyscan -H github.com >> /root/.ssh/known_hosts 2>/dev/null

        echo "✅ GitHub SSH credentials configured"

    # Method 2: HTTPS Token (fallback)
    elif [ -n "$GITHUB_TOKEN" ]; then
        echo "Setting up HTTPS authentication..."

        # Configure credential helper
        git config --global credential.helper store

        # Store credentials for HTTPS
        echo "https://rafstahelin:${GITHUB_TOKEN}@github.com" > /root/.git-credentials
        chmod 600 /root/.git-credentials

        echo "✅ GitHub HTTPS credentials configured"

    else
        echo "⚠️  Neither SSH_PRIVATE_KEY_BASE64 nor GITHUB_TOKEN set"
        echo "💡 GitHub authentication is optional for ComfyUI pods"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Easy CLI setup complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Start Zasper
start_zasper() {
    mkdir -p /workspace
    echo "Starting Zasper on port 8048..."
    nohup zasper --port 0.0.0.0:8048 --cwd /workspace &> /zasper.log &
    echo "Zasper started on port 8048"
}

# ---------------------------------------------------------------------------- #
#                               Main Program                                     #
# ---------------------------------------------------------------------------- #

# Setup environment
build_config_bashrc  # Build CONFIG bashrc FIRST (before env vars)
setup_ssh
export_env_vars
setup_easy_cli

# Initialize FileBrowser if not already done
if [ ! -f "$DB_FILE" ]; then
    echo "Initializing FileBrowser..."
    filebrowser config init
    filebrowser config set --address 0.0.0.0
    filebrowser config set --port 8080
    filebrowser config set --root /workspace
    filebrowser config set --auth.method=noauth
    filebrowser users add admin admin --perm.admin
else
    echo "Using existing FileBrowser configuration..."
fi

# Start FileBrowser
echo "Starting FileBrowser on port 8080..."
nohup filebrowser &> /filebrowser.log &

# Start code-server (Claude Code)
if command -v code-server &> /dev/null; then
    echo "Starting code-server (Claude Code) on port 8443..."
    mkdir -p /root/.config/code-server
    cat > /root/.config/code-server/config.yaml <<EOF
bind-addr: 0.0.0.0:8443
auth: none
cert: false
EOF
    nohup code-server /workspace &> /code-server.log &
    echo "✅ Code-server started"
else
    echo "⚠️  code-server not found (skipping)"
fi

start_zasper

# Create default comfyui_args.txt if it doesn't exist
ARGS_FILE="/workspace/ComfyUI/comfyui_args.txt"
if [ ! -f "$ARGS_FILE" ]; then
    echo "# Add your custom ComfyUI arguments here (one per line)" > "$ARGS_FILE"
    echo "Created empty ComfyUI arguments file at $ARGS_FILE"
fi

# Setup ComfyUI if needed
# Check if venv is valid (directory exists AND activate script exists)
if [ ! -d "$COMFYUI_DIR" ] || [ ! -d "$VENV_DIR" ] || [ ! -f "$VENV_DIR/bin/activate" ]; then
    echo "First time setup: Installing ComfyUI and dependencies..."

    # If venv directory exists but is broken, remove it
    if [ -d "$VENV_DIR" ] && [ ! -f "$VENV_DIR/bin/activate" ]; then
        echo "⚠️  Detected broken venv (directory exists but activate script missing)"
        echo "Removing broken venv at $VENV_DIR..."
        rm -rf "$VENV_DIR"
        echo "✅ Broken venv removed"
    fi
    
    # Clone ComfyUI if not present
    if [ ! -d "$COMFYUI_DIR" ]; then
        cd /workspace
        git clone https://github.com/comfyanonymous/ComfyUI.git
        
        # Comment out torch packages from requirements.txt
        cd ComfyUI
        sed -i 's/^torch/#torch/' requirements.txt
        sed -i 's/^torchvision/#torchvision/' requirements.txt
        sed -i 's/^torchaudio/#torchaudio/' requirements.txt
        sed -i 's/^torchsde/#torchsde/' requirements.txt
    fi
    
    # Install ComfyUI-Manager if not present
    if [ ! -d "$COMFYUI_DIR/custom_nodes/ComfyUI-Manager" ]; then
        echo "Installing ComfyUI-Manager..."
        mkdir -p "$COMFYUI_DIR/custom_nodes"
        cd "$COMFYUI_DIR/custom_nodes"
        git clone https://github.com/ltdrdata/ComfyUI-Manager.git
    fi

    # Install additional custom nodes
    CUSTOM_NODES=(
        "https://github.com/crystian/ComfyUI-Crystools"
        "https://github.com/kijai/ComfyUI-KJNodes"
    )

    for repo in "${CUSTOM_NODES[@]}"; do
        repo_name=$(basename "$repo")
        if [ ! -d "$COMFYUI_DIR/custom_nodes/$repo_name" ]; then
            echo "Installing $repo_name..."
            cd "$COMFYUI_DIR/custom_nodes"
            git clone "$repo"
        fi
    done
    
    # Create and setup virtual environment if not present
    if [ ! -d "$VENV_DIR" ]; then
        cd $COMFYUI_DIR
        python3.12 -m venv $VENV_DIR
        source $VENV_DIR/bin/activate
        
        # Use pip first to install uv
        pip install -U pip
        pip install uv
        
        # Configure uv to use copy instead of hardlinks
        export UV_LINK_MODE=copy
        
        # Install the requirements
        uv pip install --no-cache -r requirements.txt
        
        # Install PyTorch Nightly
        uv pip install --no-cache --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128
        
        # Install dependencies for custom nodes
        echo "Installing/updating dependencies for custom nodes..."
        uv pip install --no-cache GitPython numpy pillow opencv-python torchsde  # Common dependencies
        
        # Install dependencies for all custom nodes
        cd "$COMFYUI_DIR/custom_nodes"
        for node_dir in */; do
            if [ -d "$node_dir" ]; then
                echo "Checking dependencies for $node_dir..."
                cd "$COMFYUI_DIR/custom_nodes/$node_dir"
                
                # Check for requirements.txt
                if [ -f "requirements.txt" ]; then
                    echo "Installing requirements.txt for $node_dir"
                    uv pip install --no-cache -r requirements.txt
                fi
                
                # Check for install.py
                if [ -f "install.py" ]; then
                    echo "Running install.py for $node_dir"
                    python install.py
                fi
                
                # Check for setup.py
                if [ -f "setup.py" ]; then
                    echo "Running setup.py for $node_dir"
                    uv pip install --no-cache -e .
                fi
            fi
        done
    fi
else
    # Just activate the existing venv
    source $VENV_DIR/bin/activate
    
    # Always install/update dependencies for custom nodes
    echo "Installing/updating dependencies for custom nodes..."
    uv pip install --no-cache GitPython numpy pillow  # Common dependencies
    
    # Install dependencies for all custom nodes
    cd "$COMFYUI_DIR/custom_nodes"
    for node_dir in */; do
        if [ -d "$node_dir" ]; then
            echo "Checking dependencies for $node_dir..."
            cd "$COMFYUI_DIR/custom_nodes/$node_dir"
            
            # Check for requirements.txt
            if [ -f "requirements.txt" ]; then
                echo "Installing requirements.txt for $node_dir"
                uv pip install --no-cache -r requirements.txt
            fi
            
            # Check for install.py
            if [ -f "install.py" ]; then
                echo "Running install.py for $node_dir"
                python install.py
            fi
            
            # Check for setup.py
            if [ -f "setup.py" ]; then
                echo "Running setup.py for $node_dir"
                uv pip install --no-cache -e .
            fi
        fi
    done
fi

# Start ComfyUI with custom arguments if provided
cd $COMFYUI_DIR
FIXED_ARGS="--listen 0.0.0.0 --port 8188"
if [ -s "$ARGS_FILE" ]; then
    # File exists and is not empty, combine fixed args with custom args
    CUSTOM_ARGS=$(grep -v '^#' "$ARGS_FILE" | tr '\n' ' ')
    if [ ! -z "$CUSTOM_ARGS" ]; then
        echo "Starting ComfyUI with additional arguments: $CUSTOM_ARGS"
        nohup python main.py $FIXED_ARGS $CUSTOM_ARGS &> /workspace/ComfyUI/comfyui.log &
    else
        echo "Starting ComfyUI with default arguments"
        nohup python main.py $FIXED_ARGS &> /workspace/ComfyUI/comfyui.log &
    fi
else
    # File is empty, use only fixed args
    echo "Starting ComfyUI with default arguments"
    nohup python main.py $FIXED_ARGS &> /workspace/ComfyUI/comfyui.log &
fi

# Tail the log file
tail -f /workspace/ComfyUI/comfyui.log
