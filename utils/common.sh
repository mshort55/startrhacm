#!/bin/bash

# Loads QUAY_TOKEN from utils/.docker/config.json
function load_quay_token_from_file() {
  local utils_dir docker_config_path
  utils_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  docker_config_path="${utils_dir}/.docker/config.json"
  if [[ -f "${docker_config_path}" ]]; then
    QUAY_TOKEN=$(cat "${docker_config_path}" | base64 -w0)
    export QUAY_TOKEN
  else
    printlog error "${docker_config_path} does not exist"
    exit 1
  fi
}

# Formats and outputs logs
function printlog() {
  case ${1} in
  title)
    printf "\n##### "
    ;;
  info)
    printf "* "
    ;;
  error)
    printf "^^^^^ "
    ;;
  *)
    printlog error "Unexpected error in printlog function. Invalid input given: ${1}"
    exit 1
    ;;
  esac
  printf "%b\n" "${2}"
}

# Sets up secret for quay.io:443
function setup_pull_secret() {
  local quay_token="${1}"

  if [[ -z "${quay_token}" ]]; then
    printlog error "QUAY_TOKEN must be provided to setup_pull_secret"
    return 1
  fi

  printlog info "Updating Openshift pull-secret in namespace openshift-config with a token for quay.io:443"
  QUAY443_TOKEN=$(echo "${quay_token}" | base64 --decode | sed "s/quay\.io/quay\.io:443/g")
  OPENSHIFT_PULL_SECRET=$(oc get -n openshift-config secret pull-secret -o jsonpath='{.data.\.dockerconfigjson}' | base64 --decode)
  FULL_TOKEN="${QUAY443_TOKEN}${OPENSHIFT_PULL_SECRET}"
  oc set data secret/pull-secret -n openshift-config --from-literal=.dockerconfigjson="$(jq -s '.[1] * .[0]' <<<"${FULL_TOKEN}")"
}

# Applies ImageDigestMirrorSet for quay.io:443/acm-d
function setup_image_mirrors() {
  printlog info "Applying ImageDigestMirrorSet"
  oc apply -f - <<EOF
apiVersion: config.openshift.io/v1
kind: ImageDigestMirrorSet
metadata:
  name: image-mirror-custom
spec:
  imageDigestMirrors:
    - mirrors:
        - quay.io:443/acm-d
        - registry.stage.redhat.io/rhacm2
        - brew.registry.redhat.io/rh-osbs/rhacm2
      source: registry.redhat.io/rhacm2
    - mirrors:
        - quay.io:443/acm-d
        - registry.stage.redhat.io/multicluster-engine
        - brew.registry.redhat.io/rh-osbs/multicluster-engine
      source: registry.redhat.io/multicluster-engine
    - mirrors:
        - quay.io:443/acm-d
        - registry.stage.redhat.io/openshift4
      source: registry.redhat.io/openshift4
    - mirrors:
        - registry.stage.redhat.io/gatekeeper
      source: registry.redhat.io/gatekeeper
EOF
}
