FROM python:3.12-slim

# Set working directory
WORKDIR /ansible

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    openssh-client \
    git \
    rsync \
    sshpass \
    && rm -rf /var/lib/apt/lists/*

# Install Ansible and dependencies
RUN pip install --no-cache-dir \
    ansible>=9.0.0 \
    ansible-lint \
    jmespath \
    netaddr

# Create SSH directory for keys
RUN mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh

# Set default command
CMD ["/bin/bash"]
