FROM ubuntu:24.04

SHELL ["/bin/bash", "-l", "-c"]

# Install essential packages
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    procps \
    file \
    unzip \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create sudoers directory and non-root user
RUN mkdir -p /etc/sudoers.d && \
    useradd -m -s /bin/bash vscode && \
    echo "vscode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vscode

# Switch to non-root user
USER vscode
WORKDIR /home/vscode

# Install Node
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && \
    sudo apt-get install -y nodejs

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/home/vscode/.bun/bin:${PATH}"

# Install Foundry
RUN curl -L https://foundry.paradigm.xyz | bash
RUN /home/vscode/.foundry/bin/foundryup -i nightly