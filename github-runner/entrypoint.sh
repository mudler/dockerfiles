#!/bin/bash
ARCH=${ARCH:-x64}
VERSION=${VERSION:-2.309.0}
CHECKSUM=${CHECKSUM:-2974243bab2a282349ac833475d241d5273605d3628f0685bd07fb5530f9bb1a}
ORG=${ORG:-}
REPO=${REPO:-}
OS=${OS:-linux}

if [ -z "${ORG}" ]; then
    echo "WARN: missing ORG"
    exit 1
fi

if [ -z "${REPO}" ]; then
    echo "WARN: missing REPO"
fi

if [ -z "${TOKEN}" ]; then
    echo "ERROR: missing TOKEN, bailing out!"
    exit 1
fi

FILE="actions-runner-${OS}-${ARCH}-${VERSION}.tar.gz"
curl -o ${FILE} -L https://github.com/actions/runner/releases/download/v${VERSION}/${FILE}
echo "${CHECKSUM}  ${FILE}" | shasum -a 256 -c
tar xzf ./${FILE}
./bin/installdependencies.sh

# Make sure that if /var/run is mounted it has the correct permissions for the runner user
chgrp docker /var/run/docker.sock

su runner -c "./config.sh --unattended --url https://github.com/${ORG}/${REPO} --token ${TOKEN} --name docker-runner-$(hostname) --labels ${ARCH},${OS},self-hosted"
while true; do
    su runner -c "./run.sh"
done