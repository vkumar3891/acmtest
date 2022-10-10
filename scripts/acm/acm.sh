#!/usr/bin/env bash
set -x
#set -o errexit
set -o pipefail

export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
# set KUBECONFIG location
export KUBECONFIG="/tmp/anthos-kubeconfig"

# to overcome gcloud not on PATH in Ansible Tower and add other tools
if [[ -z "${NGP_SRE_TF_CI}" ]]; then
export PATH=/tmp/gcloud-anthos/google-cloud-sdk/bin:/tmp/bin:$PATH
else
export PATH=/tmp/bin:$PATH
fi

export MEMBERSHIP_NAME=${1}
export PROJECT_ID=${2}
export NEW_CONTROLLER_MEMORY_LIMIT=${3}
export NEW_CONTROLLER_CPU_LIMIT=${4}
export NEW_CONTROLLER_MEMORY_REQUEST=${5}
export NEW_CONTROLLER_CPU_REQUEST=${6}
export GATEKEEPER_CONTROLLER_REPLICAS_COUNT=${7}
export NEW_AUDIT_CPU_LIMIT=${8}
export NEW_AUDIT_MEMORY_LIMIT=${9}
export NEW_AUDIT_CPU_REQUEST=${10}
export NEW_AUDIT_MEMORY_REQUEST=${11}

export GATEKEEPER_AUDIT_REPLICAS_COUNT=1


# https://cloud.google.com/anthos-config-management/docs/downloads#released_version_matrix
POLICY_CONTROLLER_PRODUCT_VERSION="1.12.2"
POLICY_CONTROLLER_VERSION="anthos1.12.2-8f1ef8c.g0"

function wait_for_policycontroller_installed(){
    runtime="4 minute"
    endtime=$(date -ud "$runtime" +%s)
    while [ "$(gcloud beta container hub config-management status --project=${PROJECT_ID} --filter="acm_status.policy_controller_state:INSTALLED" |grep -c ${MEMBERSHIP_NAME})" -eq 0 ] && [[ $(date -u +%s) -le $endtime ]]; do
      sleep 25
      echo "Awaiting for policycontroller being installed in ${MEMBERSHIP_NAME}"
    done
    if [ "$(gcloud beta container hub config-management status --project=${PROJECT_ID} --filter="acm_status.policy_controller_state:INSTALLED" |grep -c ${MEMBERSHIP_NAME})" -eq 0 ]; then
      echo "PolicyController not present?"
      exit 1
    fi
}

function wait_for_gatekeeper_image(){
  runtime="4 minute"
  endtime=$(date -ud "$runtime" +%s)
  while [ "$(kubectl get deployments -n gatekeeper-system gatekeeper-controller-manager -o="jsonpath={.spec.template.spec.containers[0].image}" |grep -c "${POLICY_CONTROLLER_VERSION}")" -eq 0 ] && [[ $(date -u +%s) -le $endtime ]]; do
    sleep 25
    echo "Awaiting for gatekeeper image version ${POLICY_CONTROLLER_PRODUCT_VERSION} being installed in ${MEMBERSHIP_NAME}"
  done
  if [ "$(kubectl get deployments -n gatekeeper-system gatekeeper-controller-manager -o="jsonpath={.spec.template.spec.containers[0].image}" |grep -c "${POLICY_CONTROLLER_VERSION}")" -eq 0 ]; then
      echo "Gatekeeper image ${POLICY_CONTROLLER_PRODUCT_VERSION} not present?"
      exit 1
  fi

}

function wait_for_gatekeeper_audit_pods(){
  auditPodsNumber="${1:-1}"
  forceExit="${2:-no}"
  runtime="3 minute"
  endtime=$(date -ud "$runtime" +%s)
  while [ "$(kubectl get pods -l control-plane=audit-controller -n gatekeeper-system -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}' | grep -o 'True' | wc -l)" -ne "${auditPodsNumber}" ] && [[ $(date -u +%s) -le $endtime ]]; do
    echo "Awaiting for audit gatekeeper pod to be up"
    sleep 25
  done

  if [ "$(kubectl get pods -l control-plane=audit-controller -n gatekeeper-system -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}' | grep -o 'True' | wc -l)" -ne "${auditPodsNumber}" ]; then
      echo "Gatekeeper audit gatekeeper pod is not up."
      if [ "$forceExit" = "yes" ]; then
        echo "Exiting ..."
        exit 1
      fi
  fi
}

function wait_for_gatekeeper_pods(){
  controllerPodsNumber="${1:-1}"
  auditPodsNumber="${2:-1}"
  forceExit="${3:-no}"
  runtime="3 minute"
  endtime=$(date -ud "$runtime" +%s)
  while [ "$(kubectl get pods -l control-plane=controller-manager -n gatekeeper-system -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}' | grep -o 'True' | wc -l)" -ne "${controllerPodsNumber}" ] && [[ $(date -u +%s) -le $endtime ]]; do
    echo "Awaiting for controller manager gatekeeper pods to be up"
    sleep 25
  done
  endtime=$(date -ud "$runtime" +%s)
  while [ "$(kubectl get pods -l control-plane=audit-controller -n gatekeeper-system -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}' | grep -o 'True' | wc -l)" -ne "${auditPodsNumber}" ] && [[ $(date -u +%s) -le $endtime ]]; do
    echo "Awaiting for audit gatekeeper pods to be up"
    sleep 30
  done

  if [ "$(kubectl get pods -l control-plane=controller-manager -n gatekeeper-system -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}' | grep -o 'True' | wc -l)" -ne "${controllerPodsNumber}" ] || [ "$(kubectl get pods -l control-plane=audit-controller -n gatekeeper-system -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}' | grep -o 'True' | wc -l)" -ne "${auditPodsNumber}" ]; then
      echo "Gatekeeper pods are not up."
      if [ "$forceExit" = "yes" ]; then
        echo "Exiting ..."
        exit 1
      fi
  fi
}

function upgrade_policy_controller(){
  echo "Trying to upgrade policy controller to version ${POLICY_CONTROLLER_PRODUCT_VERSION}"
  runtime="5 minute"
  endtime=$(date -ud "$runtime" +%s)
  while [ "$(gcloud beta container hub config-management upgrade --membership="${MEMBERSHIP_NAME}"  --version="${POLICY_CONTROLLER_PRODUCT_VERSION}" --project="${PROJECT_ID}" --quiet 2>&1 | grep -ic "already has version.*of the Config Management Feature installed")" -eq 0 ] && [[ $(date -u +%s) -le $endtime ]]; do
    sleep 20
    echo "Repeating a policy controller upgrade to a version ${POLICY_CONTROLLER_PRODUCT_VERSION} "
    # To debug output
    gcloud beta container hub config-management upgrade --membership="${MEMBERSHIP_NAME}"  --version="${POLICY_CONTROLLER_PRODUCT_VERSION}" --project="${PROJECT_ID}" --quiet
  done
}

function install_config_management(){
  echo "Installation of config management and policy controller"
  runtime="4 minute"
  endtime=$(date -ud "$runtime" +%s)
  while [ "$(gcloud beta container hub config-management apply --membership="${MEMBERSHIP_NAME}" --config=/tmp/acm-config-sync.yaml --project="${PROJECT_ID}" 2>&1 | grep -ic "Waiting for Feature Config Management to be updated")" -eq 0 ] && [[ $(date -u +%s) -le $endtime ]]; do
    sleep 20
    echo "Repeating the installation of config management and policy controller"
    # To debug output
    gcloud beta container hub config-management apply --membership="${MEMBERSHIP_NAME}" --config=/tmp/acm-config-sync.yaml --project="${PROJECT_ID}"
  done
}

function wait_for_gatekeeper_resources(){
  newCpuLimit="${1}"
  newMemoryLimit="${2}"
  newCpuRequest="${3}"
  newMemoryRequest="${4}"
  replicasCount="${5}"
  podLabel="${6}"

  runtime="4 minute"
  endtime=$(date -ud "$runtime" +%s)
  declare -A pods
  while [[ $(date -u +%s) -le $endtime ]]; do
    echo "Awaiting for new resources for gatekeeper pods"
    out=$(kubectl get pods -l ${podLabel}  -n gatekeeper-system | grep '1/1.*Running' | cut -d ' ' -f 1)
    while IFS= read -r line; do
      memoryLimit=$(kubectl get pods $line  -n gatekeeper-system -o jsonpath='{.spec.containers[0].resources.limits.memory}')
      cpuLimit=$(kubectl get pods $line  -n gatekeeper-system -o jsonpath='{.spec.containers[0].resources.limits.cpu}')
      memoryRequest=$(kubectl get pods $line  -n gatekeeper-system -o jsonpath='{.spec.containers[0].resources.requests.memory}')
      cpuRequest=$(kubectl get pods $line  -n gatekeeper-system -o jsonpath='{.spec.containers[0].resources.requests.cpu}')
      if [ "$memoryLimit" = "${newMemoryLimit}" ] && [ "$cpuLimit" = "${newCpuLimit}" ] && [ "$memoryRequest" = "${newMemoryRequest}" ] && [ "$cpuRequest" = "${newCpuRequest}" ]; then
          pods["${line}"]="true"
      fi
    done <<< "$out"
    arraySize=${#pods[@]}
    if [ "${arraySize}" -eq "${replicasCount}" ]; then
      break
    fi
    sleep 25
  done

}

cd ${SCRIPT_DIR}
echo "Ensure Anthos Config Management is enabled"
[ "$(gcloud beta container hub config-management status --project=${PROJECT_ID} 2>&1 | grep -c "is not enabled")" -gt 0 ] && {
    gcloud beta container hub config-management enable --project=${PROJECT_ID}
}

# Upgrading policy controller
upgrade_policy_controller
wait_for_gatekeeper_image
wait_for_gatekeeper_audit_pods ${GATEKEEPER_AUDIT_REPLICAS_COUNT}

# Install actually policy controller configuration
install_config_management
wait_for_policycontroller_installed
wait_for_gatekeeper_audit_pods ${GATEKEEPER_AUDIT_REPLICAS_COUNT}

# Increasing gatekeeper resources
kubectl apply -f /tmp/cm-updated-resources.yaml
wait_for_gatekeeper_resources ${NEW_CONTROLLER_CPU_LIMIT} ${NEW_CONTROLLER_MEMORY_LIMIT} ${NEW_CONTROLLER_CPU_REQUEST} ${NEW_CONTROLLER_MEMORY_REQUEST} ${GATEKEEPER_CONTROLLER_REPLICAS_COUNT} "control-plane=controller-manager"
wait_for_gatekeeper_resources ${NEW_AUDIT_CPU_LIMIT} ${NEW_AUDIT_MEMORY_LIMIT} ${NEW_AUDIT_CPU_REQUEST} ${NEW_AUDIT_MEMORY_REQUEST} ${GATEKEEPER_AUDIT_REPLICAS_COUNT} "control-plane=audit-controller"
wait_for_gatekeeper_pods ${GATEKEEPER_CONTROLLER_REPLICAS_COUNT} ${GATEKEEPER_AUDIT_REPLICAS_COUNT} yes

wait_for_policycontroller_installed

# Install gatekeeper monitoring
POD_MONITORING_API_ENABLED=$(kubectl api-resources | grep podmonitorings | wc -l)
if [[ "${POD_MONITORING_API_ENABLED}" -gt 0 ]]; then
  kubectl apply -f /tmp/gatekeeper-monitoring.yaml
fi
#cleanup outdated monitoring resources
kubectl delete deploy gatekeeper-monitoring-sidecar -n gatekeeper-system --ignore-not-found=true
kubectl delete svc gatekeeper-monitoring -n gatekeeper-system --ignore-not-found=true
kubectl delete sa gatekeeper-monitoring-sidecar-sa -n gatekeeper-system --ignore-not-found=true

# When ConfigSync is installed
#kubectl apply -f /tmp/root-sync.yaml

echo OK
