#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

if [[ -z "${QUAY_TOKEN}" ]]; then
  load_quay_token_from_file
fi

printlog title "Setting up pull secret and ImageDigestMirrorSet for spoke cluster"

if [[ -z "${QUAY_TOKEN}" ]]; then
  printlog error "QUAY_TOKEN must be set"
  exit 1
fi

setup_pull_secret "${QUAY_TOKEN}"
setup_image_mirrors

printlog title "Setup complete!"
