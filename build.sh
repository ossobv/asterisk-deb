#!/bin/sh
cd "$(dirname "$0")"  # jump to curdir

# Pass these on the command line.
osdistro=debian
oscodename=buster
upname=asterisk
upversion=${1:-16.6.2}      # asterisk version, e.g. 13.22.0
debversion=${2:-0osso0}     # deb build version, e.g. 0osso1
# echo "Usage: $0 11.25.3 0osso1" >&2

# Docker disallows certain tokens in versions.
dockversion=$(echo build-${upname}-${upversion}-${debversion}-${oscodename} |
    sed -e 's/[^0-9A-Za-z_.-]/_/g')

# Will build files.
if ! docker build \
    --ulimit nofile=512 \
    --build-arg osdistro=$osdistro \
    --build-arg oscodename=$oscodename \
    --build-arg upversion=$upversion \
    --build-arg debversion=$debversion \
    -t $dockversion \
    -f Dockerfile \
    .
then
    ret=$?
    echo "fail" >&2
    exit $?
fi

# Copy files to ./dist.
test -d dist/$oscodename || mkdir -p dist/$oscodename
docker run \
    -e UID=$(id -u) -v "$(pwd)/dist/$oscodename:/dist/$oscodename" \
    $dockversion
