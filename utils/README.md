# PKS Utilities
* [Manage PKS users](#manage-pks-users)
* Istio
  * [Istio setup](#instructions-to-use-istiosh-script)
  * [Deploy sample app](#instructions-to-use-deploy-sample-application)
  * [Grafana metrics](#instructions-to-visualize-metrics-using-grafana)
  * [Visualize service mesh](#instructions-to-visualize-service-mesh-using-kiali)

## Manage PKS Users

Automate Uaac configuration for PKS user creation

### Before you begin
You need:

* [PKS cli](https://docs.pivotal.io/runtimes/pks/1-3/installing-pks-cli.html)
* [OM cli](https://github.com/pivotal-cf/om#installation)
* [uaa cli](https://github.com/cloudfoundry-incubator/uaa-cli/releases)
* [jq](https://stedolan.github.io/jq/download/)

### Instructions to use `manage-users` script

1.  Configure environment variables before using script
  ```
  export OM_TARGET= Opsman Hostname
  export OM_USERNAME=
  export OM_PASSWORD=
  export PKS_API= PKS API Hostname
  ```
2. Start by configuring uaac access, this step will configure uaac client with PKI API uaac target
  ```
  ./manage-users configure
  ```
3. Once uaac client is configured, you can create PKS user using
  ```
  ./manage-users create-user
  ```
  and follow instructions. This step will:

  * Create a user with `pks.clusters.admin` & `pks.clusters.manage` permissions.


4. This utility can also be used to login to PKS API using PKS_API env variable.
```
./manage-users login
```

## Manage [Istio](https://istio.io/) installation

### Instructions to use `istio.sh` script

1. Start by installing Helm cli from https://helm.sh/docs/using_helm/#installing-helm

2. Install Istio components using
  ```
  ./istio.sh install
  ```
  This script will create Service account for Helm, install Helm tiller, ClusterRole, ClusterRoleBindings, CRDs for Istio and install Istio components.

3. You can verify the status for Istio components using
  ```
  ./istio.sh verify
  ```
4. Upgrade of Istio control plane can be done using
  ```
  ./istio upgrade
  ```
5. Upgrade of Envoy sidecars can be done using
  ```
  ./istio upgrade-sidecar
  ```
6. Cleanup for Istio components, istio-system namespace & tiller can be done using
  ```
  ./istio.sh cleanup
  ```

### Instructions to use deploy sample application

We will deploy sample Bookinfo application which is same as on [Istio docs](https://istio.io/docs/examples/bookinfo/)


1. Change directory to the root of the Istio installation.
  ```
  cd istio-1.1.4
  ```
2. The default Istio installation uses automatic sidecar        injection. Label the namespace that will host the application with istio-injection=enabled:
  ```
  kubectl label namespace default istio-injection=enabled
  ```
3. Deploy your application using the kubectl command:
  ```
  kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
  ```
4. Confirm all services and pods are correctly defined and running:
  ```
  kubectl get svc
  kubectl get pods
  ```
5. To confirm that the Bookinfo application is running, send a request to it by a curl command from some pod, for example from ratings:
  ```
  kubectl exec -it $(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}') -c ratings -- curl productpage:9080/productpage | grep -o "<title>.*</title>"
  ```
 Now that the Bookinfo services are up and running, you need to make the application accessible from outside of your Kubernetes cluster, e.g., from a browser. An Istio Gateway is used for this purpose.

6. Define the ingress gateway for the application:
  ```
  kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
  ```
  check the status of gateway using
  ```
  kubectl get svc istio-ingressgateway -n istio-system
  ```
7. Determining the ingress Hostname and ports
  ```
  export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
  export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].port}')
  ```
8. Set GATEWAY_URL:
  ```
  export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT
  ```
9. To confirm that the Bookinfo application is accessible from outside the cluster, run the following curl command:
  ```
  curl -s http://${GATEWAY_URL}/productpage | grep -o "<title>.*</title>"
  ```
  If everything works fine, you should see output like
  `<title>Simple Bookstore App</title>`

Voila!! you have an application running with Service Mesh

### Instructions to Visualize metrics using [Grafana](https://istio.io/docs/tasks/telemetry/metrics/using-istio-dashboard/)

1. Verify that the prometheus service is running in your cluster
  ```
  kubectl -n istio-system get svc prometheus
  ```
2. Verify that the Grafana service is running in your cluster
  ```
  kubectl -n istio-system get svc grafana
  ```
3. Open the Istio Dashboard via the Grafana UI.
  ```
  kubectl -n istio-system port-forward $(kubectl -n istio-system get pod -l app=grafana -o jsonpath='{.items[0].metadata.name}') 3000:3000 &
  ```
  Visit http://localhost:3000/dashboard/db/istio-mesh-dashboard in your web browser.

### Instructions to Visualize service mesh using [Kiali](https://istio.io/docs/tasks/telemetry/kiali/)

1. To verify the service is running in your cluster, run the following command:
    ```
    kubectl -n istio-system get svc kiali
    ```

2. To determine the Bookinfo URL, follow the instructions to determine the Bookinfo ingress GATEWAY_URL.

    To send traffic to the mesh, you have three options

    Visit http://$GATEWAY_URL/productpage in your web browser

    Use the following command multiple times:
    ```
    curl http://$GATEWAY_URL/productpage
    ```

    If you installed the watch command in your system, send requests continually with:
    ```
    watch -n 1 curl -o /dev/null -s -w %{http_code} $GATEWAY_URL/productpage
    ```

3. To open the Kiali UI, execute the following command in your Kubernetes environment:
    ```
    kubectl -n istio-system port-forward $(kubectl -n istio-system get pod -l app=kiali -o jsonpath='{.items[0].metadata.name}') 20001:20001
    ```
    Visit http://localhost:20001/kiali/console in your web browser.

4. To log into the Kiali UI, go to the Kiali login screen and enter the username and passphrase as `admin` & `admin`.
