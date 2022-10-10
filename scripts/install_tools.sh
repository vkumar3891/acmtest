#!/usr/bin/env bash

set -e
set -x

# set KUBECONFIG location
export KUBECONFIG="$1"

# to overcome gcloud not on PATH in Ansible Tower and add other tools
# AT gcloud is 299 and it does not allow install Anthos PolicyManager
#
# export PATH=$PATH:/var/lib/awx/venv/SabreAutomation/google-cloud-sdk/bin:/tmp/bin
export PATH=/tmp/gcloud-anthos/google-cloud-sdk/bin:/tmp/bin:$PATH

# fails on AT:
# "ERROR: (gcloud.components.install) You cannot perform this action because you do not have permission to modify the Google Cloud SDK installation directory [/var/lib/awx/venv/SabreAutomation/google-cloud-sdk].",
# google-cloud-sdk/bin/gcloud components install kpt

[ -d /tmp/bin ] || {
    mkdir -p /tmp/bin
}

[ -e /tmp/bin/kpt ] || {
    curl -sSL -o /tmp/bin/kpt https://storage.googleapis.com/kpt-dev/latest/linux_amd64/kpt
    chmod u+x /tmp/bin/kpt
}

[ -e /tmp/bin/jq ] || {
    curl -sSL -o /tmp/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
    chmod u+x /tmp/bin/jq
}

[ -e /tmp/gcloud/google-cloud-sdk/bin ] || {
    mkdir -p /tmp/gcloud-anthos && cd /tmp/gcloud-anthos && curl -sSL -o gcloud.tar.gz  https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-393.0.0-linux-x86_64.tar.gz
    tar -zxvf gcloud.tar.gz
    rm -rf gcloud.tar.gz
    gcloud components install alpha --quiet
    gcloud components install beta --quiet
}

command -v nomos || {
  gsutil cp gs://config-management-release/released/latest/linux_amd64/nomos /tmp/bin/nomos
  chmod u+x /tmp/bin/nomos
}


jq --version
kpt version
kubectl version
gcloud version
nomos --help
