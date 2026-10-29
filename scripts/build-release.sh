#!/usr/bin/env bash
# Build a release tarball inside a target-arch container.
#
# Required environment:
#   VERSION  — release version string (e.g. v1.0.0)
#   ARCH     — short arch name (amd64 / arm64 / armv7)
#
# Run inside the container with the source tree mounted at /work.
set -euo pipefail

: "${VERSION:?VERSION must be set}"
: "${ARCH:?ARCH must be set}"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
    build-essential cmake pkg-config \
    libsane-dev libusb-dev libusb-1.0-0-dev libjpeg-dev libncurses-dev \
    ca-certificates

cd /work
rm -rf build
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release ..
cmake --build . -j"$(nproc)"

cd /work
STAGE="brscan-${VERSION}-${ARCH}"
DEST="dist/${STAGE}"
rm -rf "${DEST}"
mkdir -p "${DEST}"

# Same tree as "make install": binaries, libraries, the suffix-2 symlinks
# and the /usr/share/sane/brother data (Brsane2.ini, GrayCmData, ...).
DESTDIR="$PWD/${DEST}" cmake --install build

for f in README.md Copying copying.brother copying.lib; do
    [ -f "$f" ] && cp "$f" "${DEST}/"
done

# Plain text install instructions — no heredoc indent traps.
{
    echo 'Install (run as root, from this directory):'
    echo
    echo '    cp -a usr/. /usr/'
    echo '    ldconfig'
    echo '    echo brother >> /etc/sane.d/dll.conf'
    echo
    echo 'Then add a udev rule (see README.md for details).'
} > "${DEST}/INSTALL"

cd dist
tar czf "${STAGE}.tar.gz" "${STAGE}"
sha256sum "${STAGE}.tar.gz" > "${STAGE}.tar.gz.sha256"
ls -la

# Files were created by root (container default user); chmod so the
# GitHub Actions runner can upload them as artifacts.
chmod -R a+rwX .
if [ -n "${HOST_UID:-}" ]; then
    chown -R "${HOST_UID}:${HOST_GID:-${HOST_UID}}" .
fi
