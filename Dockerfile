FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    xz-utils \
 && rm -rf /var/lib/apt/lists/*

ARG VBCC_URL="http://phoenix.owl.de/vbcc/vbcc_bin_linux.tar.gz"
ARG VBCC_TARGET_URL="http://phoenix.owl.de/vbcc/targets/m68k-amigaos.tar.gz"

RUN mkdir -p /opt/vbcc && \
    wget -q ${VBCC_URL} && \
    tar -xzf vbcc_bin_linux.tar.gz -C /opt/vbcc --strip-components=1 && \
    rm vbcc_bin_linux.tar.gz && \
    wget -q ${VBCC_TARGET_URL} && \
    tar -xzf m68k-amigaos.tar.gz -C /opt/vbcc && \
    rm m68k-amigaos.tar.gz

ENV PATH="/opt/vbcc/bin:${PATH}"
ENV VBCC="/opt/vbcc"

WORKDIR /src
COPY mandelbrot.c /src/

CMD ["vc", "mandelbrot.c", "-O2", "-lamiga", "-o", "Mandelbrot"]
