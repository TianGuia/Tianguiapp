FROM debian:trixie-slim

ARG FLUTTER_VERSION=3.47.8
ARG ANDROID_TOOLS_VERSION=13114758
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git unzip xz-utils zip rsync passwd openjdk-21-jdk-headless \
    libglu1-mesa libstdc++6 lib32stdc++6 lib32z1 \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid 1000 dev && useradd --uid 1000 --gid dev --create-home dev \
    && mkdir -p /opt/flutter /opt/android-sdk /workspace /home/dev/.pub-cache /home/dev/.gradle \
    && chown -R dev:dev /opt/flutter /opt/android-sdk /workspace /home/dev
USER dev

ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
    ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    FLUTTER_ROOT=/opt/flutter
ENV PATH="/opt/flutter/bin:/opt/android-sdk/platform-tools:/opt/android-sdk/cmdline-tools/latest/bin:${PATH}"
RUN curl --fail --location --retry 3 \
      "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_TOOLS_VERSION}_latest.zip" -o /tmp/android.zip \
    && echo '7ec965280a073311c339e571cd5de778b9975026cfcbe79f2b1cdcb1e15317ee /tmp/android.zip' | sha256sum -c - \
    && mkdir -p /opt/android-sdk/cmdline-tools \
    && unzip -q /tmp/android.zip -d /opt/android-sdk/cmdline-tools \
    && mv /opt/android-sdk/cmdline-tools/cmdline-tools /opt/android-sdk/cmdline-tools/latest \
    && rm /tmp/android.zip
# Construir esta imagen implica aceptar las licencias del SDK de Android.
RUN yes | JAVA_TOOL_OPTIONS=-Xmx512m sdkmanager --licenses > /dev/null \
    && JAVA_TOOL_OPTIONS=-Xmx512m sdkmanager 'platform-tools' 'platforms;android-36' 'build-tools;36.0.0' 'ndk;28.2.13676358'
RUN git clone --depth 1 --branch "${FLUTTER_VERSION}" https://github.com/flutter/flutter.git /opt/flutter

RUN flutter config --no-analytics --enable-android --no-enable-web \
      --no-enable-linux-desktop --no-enable-windows-desktop --no-enable-macos-desktop \
    && flutter precache --android_gen_snapshot --web
RUN git -C /opt/flutter checkout -b stable \
    && rm /opt/flutter/bin/cache/flutter.version.json \
    && flutter --no-version-check --disable-analytics \
    && flutter --no-version-check --version
# Algunos plugins del proyecto todavía compilan contra Android 35.
RUN JAVA_TOOL_OPTIONS=-Xmx512m sdkmanager 'platforms;android-35'
RUN JAVA_TOOL_OPTIONS=-Xmx512m sdkmanager 'cmake;3.22.1'
COPY --chmod=755 docker/entrypoint.sh /usr/local/bin/tianguia-dev
WORKDIR /workspace
ENTRYPOINT ["tianguia-dev"]
