#!/bin/bash
set -e

red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

istio_version=1.1.4

function check_dep {

  if ! [ -x "$(command -v helm)" ]; then
    echo -e "\n${red}ERROR: Helm CLI is not installed${reset}" >&2
    echo -e "\n${green}Instructions on:${reset}https://helm.sh/docs/using_helm/#installing-helm"
    exit 1
  fi

  if ! [ -f "${HOME}/.kube/config" ]; then
    echo -e "\n${red}ERROR: Set Kubectl context before proceeding${reset}" >&2
    exit 1
  fi
}

function install_istio {
  check_dep #check dependencies

  echo -e "\n${green}Enter Istio version to be installed, just press [ENTER] for default version${reset}${red}[$istio_version]:${reset}"
  read ISTIO_VERSION

  if [ -z "$ISTIO_VERSION" ]; then
      echo -e "\n${green}Using default Istio version $istio_version${reset}"
      export ISTIO_VERSION=$istio_version
  else
    export ISTIO_VERSION=$ISTIO_VERSION
  fi

  if [ ! -d "istio-$ISTIO_VERSION" ]; then
    echo -e "\n${green}Downloading Istio release $ISTIO_VERSION...${reset}"
    curl -L https://git.io/getLatestIstio | sh -
  fi

pushd istio-$ISTIO_VERSION

echo -e "\n${green}Creating service account for Helm cli...${reset}"
kubectl apply -f install/kubernetes/helm/helm-service-account.yaml

echo -e "\n${green}Installing tiller for helm...${reset}"
helm init --service-account tiller --wait

echo -e "\n${green}Verify helm tiller status...${reset}"
helm version

#create namespace for istio components
echo -e "\n${green}Creating namespace for istio...${reset}"
if [ "$(kubectl get ns | awk '{print $1}' | grep istio-system)" == "" ]; then
    kubectl create namespace istio-system
fi

#create clusterrole & clusterrolebinding
echo -e "\n${green}Creating Cluster role for Istio-init service account with psp pks-privileged...${reset}"
if [ "$(kubectl get clusterroles | awk '{print $1}' | grep istio-system:privileged-user)" == "" ]; then
    kubectl create clusterrole istio-system:privileged-user --verb=use --resource=podsecuritypolicies --resource-name=pks-privileged
fi

echo -e "\n${green}Creating Cluster role for tiller service account with psp pks-privileged...${reset}"
if [ "$(kubectl get clusterroles | awk '{print $1}' | grep kube-system:tiller:privileged-user)" == "" ]; then
    kubectl create clusterrole kube-system:tiller:privileged-user --verb=use --resource=podsecuritypolicies --resource-name=pks-privileged
fi

echo -e "\n${green}Assigning clusterrolebinding to all authenticated users in istio-system namespace...${reset}"
if [ "$(kubectl get clusterrolebindings | awk '{print $1}' | grep istio-system:priviliged-user)" == "" ]; then
    kubectl create clusterrolebinding istio-system:priviliged-user \
    --clusterrole=istio-system:privileged-user \
    --group system:authenticated \
    --namespace istio-system
fi

echo -e "\n${green}Assigning clusterrolebinding to tiller serviceaccount in kube-system...${reset}"
if [ "$(kubectl get clusterrolebindings | awk '{print $1}' | grep kube-system:tiller:priviliged-user)" == "" ]; then
    kubectl create clusterrolebinding kube-system:tiller:priviliged-user \
    --clusterrole=kube-system:tiller:privileged-user \
    --serviceaccount=kube-system:tiller
fi

#Steps to install istio components
echo -e "\n${green}Install the istio-init to bootstrap all the Istio’s CRDs...${reset}"
for i in install/kubernetes/helm/istio-init/files/crd*yaml; do kubectl apply -f $i; done

echo -e "\n${green}Install the istio chart to bootstrap all the Istio’s components...${reset}"

if [ "$(helm list -q | grep istio)" == "" ]; then
    helm install install/kubernetes/helm/istio --name istio \
         --namespace istio-system \
         --set certmanager.enabled=true \
         --set grafana.enabled=true \
         --set prometheus.enabled=true \
         --set kiali.enabled=true \
         --set kiali.createDemoSecret=true \
         --set kiali.dashboard.grafanaURL=http://grafana:3000
fi

popd

echo -e "\n${green}Istio setup is complete, verify the installation using:${reset} ./istio.sh verify"
}

function verify_istio {
  echo -e "\n${green}Verify Istio Kubernetes services...${reset}\n"
  kubectl get svc -n istio-system

  echo -e "\n${green}Verify Istio component pods...${reset}\n"
  kubectl get pods -n istio-system
}

function upgrade_istio {
  echo -e "\n${green}Listing available clusters...${reset}"
  pks clusters

  echo -e "\n${green}Enter pks cluster name from above list and press [ENTER]:${reset}"
  read CLUSTER_NAME

  echo -e "\n${green}Enter Istio version to be upgraded and press [ENTER]:${reset}"
  read ISTIO_VERSION

  if [ -z "$ISTIO_VERSION" ]; then
      echo -e "\n${red}Provide a proper Istio version${reset}"
      exit 1
  else
    export ISTIO_VERSION=$ISTIO_VERSION
  fi

  if [ ! -d "istio-$ISTIO_VERSION" ]; then
    echo -e "\n${green}Downloading Istio release $ISTIO_VERSION...${reset}"
    curl -L https://git.io/getLatestIstio | sh -
  fi

  pushd istio-$ISTIO_VERSION

  CURRENT_VERSION=$(./bin/istioctl version -c ~/.kube/config --context $CLUSTER_NAME --remote --output json | \
  jq -r '.meshVersion[] | select(.Component=="ingressgateway") | .Info.version')

  if [[ "$CURRENT_VERSION" == "$ISTIO_VERSION" ]]; then
    echo -e "\n${green}Upgrade version of Istio is same as installed version, run the script with a different version${reset}"
  else
    echo -e "\n${green}Upgrading Istio CRDs to newer version...${reset}"
    for i in install/kubernetes/helm/istio-init/files/crd*yaml; do kubectl apply -f $i; done

    echo -e "\n${green}Adding Istio core components to kubernetes manifest file...${reset}"
    helm template install/kubernetes/helm/istio --name istio \
    --namespace istio-system > $HOME/istio.yml

    echo -e "\n${green}Upgrading the Istio control plane components via the manifest...${reset}"
    kubectl apply -f $HOME/istio.yml

    echo -e "\n${green}Upgrade complete, Now you can upgrade side car by using:${reset} ./istio.sh upgrade-sidecar"
  fi

  popd
}

function upgrade_sidecar {
  echo -e "\n${green}Enter Namespace name where you want to refresh pods and press [ENTER]:${reset}"
  read NS

  echo
  DEPLOYMENT_LIST=$(kubectl -n $NS get deployment -o jsonpath='{.items[*].metadata.name}')
  for deployment_name in $DEPLOYMENT_LIST ; do
    TERMINATION_GRACE_PERIOD_SECONDS=$(kubectl -n $NS get deployment "$deployment_name" -o jsonpath='{.spec.template.spec.terminationGracePeriodSeconds}')
    if [ "$TERMINATION_GRACE_PERIOD_SECONDS" -eq 30 ]; then
      TERMINATION_GRACE_PERIOD_SECONDS='31'
    else
      TERMINATION_GRACE_PERIOD_SECONDS='30'
    fi
    patch_string="{\"spec\":{\"template\":{\"spec\":{\"terminationGracePeriodSeconds\":$TERMINATION_GRACE_PERIOD_SECONDS}}}}"
    kubectl -n $NS patch deployment $deployment_name -p $patch_string
  done
  echo
}

function cleanup {
  echo -e "\n${green}Cleaning up istio components...${reset}"
  helm delete --purge istio --no-hooks

  echo -e "\n${green}Cleaning up crd...${reset}"
  for crd in `kubectl get crds | grep 'istio.io\|certmanager.k8s.io' | awk '{print $1}'`; do kubectl delete crd $crd; done

  echo -e "\n${green}Delete clusterrole and bindings...${reset}";
  kubectl delete clusterrole istio-system:privileged-user
  kubectl delete clusterrole kube-system:tiller:privileged-user
  kubectl delete clusterrolebinding istio-system:priviliged-user
  kubectl delete clusterrolebinding kube-system:tiller:priviliged-user

  echo -e "\n${green}Cleanup istio-system namespace...${reset}"
  kubectl delete ns istio-system

  echo -e "\n${green}Cleaning up helm tiller...${reset}"
  helm reset
}

operation=$1

case $operation in
  -i|install)
    install_istio
    ;;
  -v|verify)
    verify_istio
    ;;
  -u|upgrade)
    upgrade_istio
    ;;
  -usc|upgrade-sidecar)
    upgrade_sidecar
    ;;
  -c|cleanup)
    cleanup
    ;;
  *)
    echo -e $"Usage: $0 {install|verify|upgrade|upgrade-sidecar|cleanup}"
    exit 1
esac
