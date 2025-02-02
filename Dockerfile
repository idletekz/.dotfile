##############################
# Stage 1: Build Neovim
##############################
FROM ubuntu:20.04 AS builder

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install packages required for building Neovim (includes git, make, unzip, gcc)
RUN apt-get update && \
    apt-get install -y \
      gcc \
      make \
      build-essential \
      cmake \
      ninja-build \
      libtool \
      libtool-bin \
      autoconf \
      automake \
      pkg-config \
      gettext \
      doxygen \
      git \
      curl \
      unzip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Clone and build Neovim from source
RUN git clone https://github.com/neovim/neovim.git /tmp/neovim && \
    cd /tmp/neovim && \
    make CMAKE_BUILD_TYPE=Release && \
    make install && \
    cd / && rm -rf /tmp/neovim

##############################
# Stage 2: Create lean runtime image
##############################
FROM ubuntu:20.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies, including ripgrep and xclip
RUN apt-get update && \
    apt-get install -y \
      tmux \
      golang-go \
      unzip \
      python3 \
      python3-pip \
      git \
      curl \
      jq \
      ripgrep \
      xclip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy the built Neovim from the builder stage (installed under /usr/local)
COPY --from=builder /usr/local /usr/local

# Install yq by downloading its binary from GitHub
RUN curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/bin/yq && \
    chmod +x /usr/bin/yq

# Install Python packages: colorlog, deepdiff, requests, and pyyaml
RUN pip3 install colorlog deepdiff requests pyyaml

# Create necessary directories for Neovim and tmux configuration
RUN mkdir -p /root/.config/nvim && \
    mkdir -p /root/.tmux/plugins

# Copy your Neovim configuration file into the appropriate directory
COPY init.lua /root/.config/nvim/init.lua

# Pre-install lazy.nvim (the Neovim plugin manager) into Neovim's data directory
RUN mkdir -p /root/.local/share/nvim/lazy && \
    git clone --filter=blob:none --branch=stable https://github.com/folke/lazy.nvim.git /root/.local/share/nvim/lazy/lazy.nvim

# Copy your tmux configuration file
COPY tmux.conf /root/.tmux.conf

# Clone the Tmux Plugin Manager (TPM)
RUN git clone https://github.com/tmux-plugins/tpm /root/.tmux/plugins/tpm

# Pre-install Neovim plugins (including lazy.nvim managed plugins) headlessly.
# The '|| true' prevents the build from failing if the plugin sync exits with a non-zero status.
RUN nvim --headless +Lazy\ sync +qall || true

# Install all tmux plugins by starting a temporary tmux session, triggering TPM's installation, and then closing the session.
RUN tmux new-session -d -s dummy && \
    tmux run-shell "/root/.tmux/plugins/tpm/scripts/install_plugins.sh" && \
    tmux kill-session -t dummy

# Set the default command to open Neovim
CMD ["nvim"]
