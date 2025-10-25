# Use Alpine as the base image
FROM alpine:latest

# Install dependencies 
RUN apk add --no-cache \
        gcc \
        bash \
        curl \
        openrc \
        groff \
        less \
        python3 \
        py3-pip \
        python3-dev \
        musl-dev \
        libffi-dev \
        openssl-dev \
        bind-tools

# Create a virtual environment and install Azure CLI
RUN python3 -m venv /venv && \
    source /venv/bin/activate && \
    pip install --upgrade pip && \
    pip install azure-cli

# Copy your update script into the Docker image
COPY update_lb.sh /usr/local/bin/update_lb.sh
RUN chmod +x /usr/local/bin/update_lb.sh

# Set the entrypoint to your script, with the virtual environment activated
ENTRYPOINT ["/bin/bash", "-c", "source /venv/bin/activate && exec /usr/local/bin/update_lb.sh \"$@\"", "--"]
