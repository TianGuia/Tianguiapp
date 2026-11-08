FROM debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2

# Misma revisión que Flutter 3.47.8, independiente de cambios de canal.
ARG FLUTTER_REVISION=737ba8f885dc774b53b442759999a312c9461e4e
# Congelar también Python y las bibliotecas del sistema entre construcciones.
ARG DEBIAN_SNAPSHOT=20261101T000000Z
ENV DEBIAN_FRONTEND=noninteractive \
    FLUTTER_ROOT=/opt/flutter \
    PUB_CACHE=/home/dev/.pub-cache \
    CI=true \
    TZ=UTC \
    LANG=C.UTF-8
ENV PATH="/opt/flutter/bin:${PATH}"
RUN sed -i "s|http://deb.debian.org/debian-security|http://snapshot.debian.org/archive/debian-security/${DEBIAN_SNAPSHOT}|g; s|http://deb.debian.org/debian|http://snapshot.debian.org/archive/debian/${DEBIAN_SNAPSHOT}|g" /etc/apt/sources.list.d/debian.sources \
    && apt-get -o Acquire::Check-Valid-Until=false update && apt-get install -y --no-install-recommends \
    ca-certificates curl git unzip xz-utils zip rsync python3 libglu1-mesa \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 1000 dev && useradd --uid 1000 --gid dev --create-home dev \
    && mkdir -p /opt/flutter /workspace /home/dev/.pub-cache \
    && chown -R dev:dev /opt/flutter /workspace /home/dev
USER dev
RUN git -C /opt/flutter init \
    && git -C /opt/flutter remote add origin https://github.com/flutter/flutter.git \
    && git -C /opt/flutter fetch --depth 1 origin "${FLUTTER_REVISION}" \
    && git -C /opt/flutter checkout --detach FETCH_HEAD \
    && git -C /opt/flutter tag 3.47.8 \
    && git -C /opt/flutter checkout -b stable \
    && flutter config --no-analytics --no-enable-android --no-enable-web \
        --no-enable-linux-desktop --no-enable-windows-desktop --no-enable-macos-desktop \
    && flutter precache \
    && flutter --version
WORKDIR /workspace
ENTRYPOINT ["bash", "/source/docker/verify-entrypoint.sh"]
