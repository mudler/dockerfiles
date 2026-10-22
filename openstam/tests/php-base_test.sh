#!/bin/sh
# Static regression checks only: this does not build or run the image.
set -eu

here=$(unset CDPATH; cd -- "$(dirname -- "$0")" && pwd)
root=${1:-"$here/../.."}

if [ "$(head -n 1 "$root/openstam/Dockerfile")" != 'FROM php:8.3.36-apache' ]; then
    echo 'FAIL: OpenStaManager must use php:8.3.36-apache' >&2
    exit 1
fi
if ! grep -Fq 'https://github.com/devcode-it/openstamanager/releases/download/v2.6.1/openstamanager-2.6.1.zip' "$root/openstam/Dockerfile"; then
    echo 'FAIL: OpenStaManager 2.6.1 release must be retained' >&2
    exit 1
fi
if ! grep -Fq 'PHP 8.3.36 with Apache' "$root/README.md"; then
    echo 'FAIL: README must document PHP 8.3.36 with Apache' >&2
    exit 1
fi
echo 'PASS: static PHP base, application release, and README checks'
