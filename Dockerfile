FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    unzip \
 && rm -rf /var/lib/apt/lists/*

# Install ECX Amiga E cross-compiler
ARG ECX_VERSION=3.3.0
RUN wget -q https://github.com/jj1bdx/ecx/releases/download/v${ECX_VERSION}/ecx_${ECX_VERSION}_linux.zip \
    && unzip ecx_${ECX_VERSION}_linux.zip -d /opt/ecx \
    && rm ecx_${ECX_VERSION}_linux.zip

ENV PATH="/opt/ecx:${PATH}"

WORKDIR /src
COPY mandelbrot.e /src/

CMD ["ecx", "mandelbrot.e", "-o", "Mandelbrot"]
