# CFMR_Public

IBM Cloud Foundry Migration Runtime - Public Repository

Notes ...

```
export TARGET_NAMESPACE=cfmr-operator
oc new-project "${TARGET_NAMESPACE}"
cloudctl case launch -t 1 --case /some/path/to/CFMR_Public/poc-case-bundle/ibm-cfmr/ --namespace cfmr-operator --inventory cfmrOperatorSetup --action init-helm-repository -- --chart_dir /some/path/to/CFMR_Public --chartmuseumImage ghcr.io/helm/chartmuseum --chartmuseum chartmuseum/chartmuseum-3.1.0.tgz

export HELM_REPO_URL=<generated-from-cloudctl>
export HELM_REPO_USERNAME=admin
export HELM_REPO_PASSWORD=<generated-from-cloudctl>
cloudctl case launch -t 1 --case /some/path/to/CFMR_Public/poc-case-bundle/ibm-cfmr/ --namespace cfmr-operator --inventory cfmrOperatorSetup --action load-helm-repository -- '--chart_dir /Users/boilerup/CFMR-Services/CFMR_Public/chartmuseum --helmusername "${HELM_REPO_USERNAME}" --helmpassword "${HELM_REPO_PASSWORD}" --helmurl "${HELM_REPO_URL}"'

export CUSTOM_RESOURCE_NAME=<custom_resource_name - same as meta.name on CR>
oc adm policy add-scc-to-user restricted system:serviceaccount:cfmr-operator:"${CUSTOM_RESOURCE_NAME}"-ibm-cfmr-serviceaccount
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:cfmr-operator:"${CUSTOM_RESOURCE_NAME}"-ibm-cfmr-serviceaccount
oc adm policy add-cluster-role-to-user self-provisioner system:serviceaccount:cfmr-operator:"${CUSTOM_RESOURCE_NAME}"-ibm-cfmr-serviceaccount


# Example Secret Creation
# oc create secret docker-registry prod-entitled-registry --docker-username=cp --docker-password=<key> --docker-server=cp.icr.io -n cfmr-operator
export PULL_SECRET=<pull_secret_name>   # entitled registry pull secret.  <Same one in CR>
oc apply -f inventory/cfmrOperatorSetup/files/op-cli/cfmr.ibm.com_ibmcfmrprods_crd.yaml
sed -e 's|REPLACE_SECRET|${PULL_SECRET}|g' inventory/cfmrOperatorSetup/files/op-cli/service_account.yaml | oc apply -f -
oc apply -f inventory/cfmrOperatorSetup/files/op-cli/role.yaml
oc apply -f inventory/cfmrOperatorSetup/files/op-cli/role_binding.yaml
oc apply -f inventory/cfmrOperatorSetup/files/op-cli/operator.yaml
# Find External-IP
oc get svc router-default -n openshift-ingress -o=jsonpath='{.status.loadBalancer.ingress[0].ip}'
# Map your CNAME/A Record Accordingly
# Find your default route certificate for the cluster or create your own custom one before install
oc get ingresscontroller -n openshift-ingress-operator default -o=jsonpath='{.spec.defaultCertificate.name}'
# Set values in, then create the CFMR Custom Resource
oc apply -f inventory/cfmrOperator/files/cfmr.ibm.com_v2_ibmcfmrprod_cr.yaml
```