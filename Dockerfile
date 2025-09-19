FROM ubuntu:20.04

# Create necessary directories
RUN mkdir -p /volume1/.srv/unifi-protect/video/2025 \
    && mkdir -p /usr/share/unifi-protect/app \
    && mkdir -p /usr/share/unifi-protect/bin \
    && mkdir -p /data/unifi-protect \
    && mkdir -p /output

# Set environment variables
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    NODE_ENV="production" \
    UFP_MAX_OLD_SPACE="2048"

WORKDIR /app

# Copy UBV tools
COPY ./usr/local/bin/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*ubv*

# Copy conversion scripts
COPY ./scripts/ /app/
RUN chmod +x /app/*.sh

# Configure apt
RUN echo 'Acquire::Retries "3";' > /etc/apt/apt.conf.d/80-retries \
    && echo 'APT::Install-Suggests "0";' > /etc/apt/apt.conf.d/99local \
    && echo 'APT::Install-Recommends "0";' >> /etc/apt/apt.conf.d/99local \
    && echo 'Acquire::https::Verify-Peer "false";' >> /etc/apt/apt.conf.d/99local

# Install required packages
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        lsof \
        ffmpeg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

CMD ["/bin/bash"]
