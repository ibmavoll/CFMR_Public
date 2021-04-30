# Cloud Foundry Migration Runtime - Helm based Operator
IBM Cloud Foundry Migration Runtime is a Cloud Foundry platform built to run on Red Hat OpenShift. 

## Introduction
IBM Cloud Foundry Migration Runtime gives developers the productivity from Cloud Foundry and allows platform operators to manage the infrastructure abstraction with OpenShift tools and APIs.

## Details
This operator deploys a Cloud Foundry Migration Runtime platform.

## Prerequisites

### Supported OpenShift versions and platforms
You can install your product on Linux® x86_64, Linux® with a supported version of OpenShift Container Platform.

Table 1. Supported OpenShift versions

|Platform|OpenShift Container Platform versions|
|--------|-------------------------------------|
|Linux® x86_64|4.6 and above|

### Entitled Registry
The CFMR installer image can be accessed via the Entitled Registry.

Getting a key to the entitled registry
  * Log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software.
  * In the Entitlement keys section, select Copy key to copy the entitlement key to the clipboard.
  * An imagePullSecret must be created to be able to authenticate and pull images from the Entitled Registry.  Once this secret has been created you will specify the secret name as the value for the `global.image.pullSecret` parameter in the values.yaml you provide to 'helm install ...'  
  
Note: Secrets are namespace scoped, so they must be created in the namespace/project you plan to install CFMR from. This secret will be copied over to subsequent CFMR namespaces during installation.
Example Docker registry secret to access Entitled Registry with an Entitlement key. 

```bash
$ oc create secret docker-registry <pull_secret_name> --docker-username=iamapikey --docker-password=<entitlement_key> --docker-server=cp.icr.io -n cfmr-operator
``` 

## Resources Required

### Cluster Sizing

A OpenShift cluster to support a basic workload will require:

|         |Master Nodes|Worker Nodes|vCPUs per node|RAM per node|
|---------|------------|------------|--------------|------------|
|Minimal  | 3*         |3	        |4	           |16GB        |
|Preferred|	3*         |3	        |8	           |32GB        |

* In some configurations such as ROKS on IBM Cloud OpenShift nodes can have duel master and worker nodes.

### Storage Requirements

#### `cfmr` Persistent Volumes
There are two Persistent Volumes created for the CFMR project which requires storage type `block storage`.
* First persistent volume is created with access mode of RWO and with a capacity of 20Gi. The reclaim policy for this persistent volume is Delete, status as Bound and it’s persistent volume claim name is pxc-data-database-0
* Second persistent volume is created with access mode of RWO and with a capacity of 100Gi. The reclaim policy for this persistent volume is Delete, status as Bound and it’s persistent volume claim name is singleton-blobstore-pvc-singleton-blobstore-0

#### `cfmr-ui` Persistent Volumes
There is only one Persistent Volume created for the cfmr-ui project with access mode of RWO and with a capacity of 20Gi. The reclaim policy for this PV is Delete, status as Bound and it's persistent volume claim name is console-mariadb

## PodSecurityPolicy Requirements
The predefined PodSecurityPolicy name [`ibm-restricted-psp`](https://ibm.biz/cpkspec-psp) has been verified for this chart. If your target namespace is bound to this PodSecurityPolicy, you can proceed to install the chart.

## SecurityContextConstraints Requirements
This chart requires adding `restricted`, `cluster-admin`, `self-provisioner` policy to service account `ibm-cfmr-serviceaccount` in the namespace CFMR installs from. Details are in the Installing section.

* From the user interface, you can copy and paste the following snippets to enable the custom `SecurityContextConstraints`
  * Custom SecurityContextConstraints definition:

  ```yaml
  apiVersion: security.openshift.io/v1
  kind: SecurityContextConstraints
  metadata:
    annotations:
    name: ibm-cfmr-prod-scc
  allowHostDirVolumePlugin: false
  allowHostIPC: false
  allowHostNetwork: false
  allowHostPID: false
  allowHostPorts: false
  allowPrivilegedContainer: false
  allowedCapabilities: []
  allowedFlexVolumes: []
  defaultAddCapabilities: []
  defaultPrivilegeEscalation: false
  forbiddenSysctls:
    - "*"
  fsGroup:
    type: MustRunAs
    ranges:
    - max: 65535
      min: 1
  readOnlyRootFilesystem: false
  requiredDropCapabilities:
  - ALL
  runAsUser:
    type: MustRunAsNonRoot
  seccompProfiles:
  - docker/default
  seLinuxContext:
    type: RunAsAny
  supplementalGroups:
    type: MustRunAs
    ranges:
    - max: 65535
      min: 1
  volumes:
  - configMap
  - downwardAPI
  - emptyDir
  - persistentVolumeClaim
  - projected
  - secret
  priority: 0
  ```
  
## Installing

This operator can be installed in an on-line or air-gapped cluster through either of the following install paths :
1. Operator Lifecycle Manager (default)
2. Kubernetes CLI

### Configuration
| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `global.image.repository` | Global image repository. Overrides `image.repository` | `` |
| `global.image.pullSecret` | Global image pull secret. | `` |
| `image.repository` | Docker repository | `cfmr-installer` |
| `image.tag` | Docker image tag | `{check values.yaml}` |
| `image.digest` | Docker image digest | `{check values.yaml}` |
| `image.pullPolicy` | Image pull policy | `Always` |
| `action` | Action to perform by installer. Available actions are `install`, `check`, `verify`, `upgrade` | `install` |
| `features.cfoVersion` | CF-Operator version | `{check values.yaml}` |
| `features.cfmrVersion` | Cloud Foundry Migration version | `{check values.yaml}` |
| `features.stratosVersion` | Stratos UI version | `{check values.yaml}` |
| `features.storageClass` | Specified name of storage class | `~` |
| `features.enableHighAvailability` | Enable highly available installation of cfmr | `false` |
| `features.ldap.enableIntegration` | Enable LDAP integration with cfmr | `false` |
| `features.ldap.bindDN` | LDAP bind DN - Leave blank if search can be performed without a bind_dn | `~` |
| `features.ldap.bindPassword` | LDAP bind DN - Leave blank if search can be performed without a bind_dn | `~` |
| `features.ldap.attributes.id` | Base attribute to map - Example: dn | `~` |
| `features.ldap.attributes.name` | Name attribute to map - Example: cn | `~` |
| `features.ldap.attributes.preferredUsername` | Preferred user name to map - Example: uid | `~` |
| `features.ldap.ipAddress` | IP address of the LDAP server | `~` |
| `features.ldap.port` | Port of the LDAP server | `~` |
| `features.ldap.filterParams` | LDAP filter parameters for OpenShift to search for users - Example: ou=users,dc=..,dc=..?uid | `~` |
| `features.ldap.userDN` | Entire LDAP admin CN information here - Example: cn=LDAPadmin,dc=..,dc=.. | `~` |
| `features.ldap.userPassword` | Entire LDAP admin CN information here - Example: cn=LDAPadmin,dc=..,dc=.. | `~` |
| `features.ldap.searchBase` | Main base DN information | `~` |
| `features.ldap.searchFilter` | LDAP search filter for UAA to search user information - Example: uid{0} | `~` |
| `features.ldap.groups.groupSearchFilter` | The LDAP group search filter for UAA to search for member users in a group - Example: memberUid{0} | `~` |
| `features.ldap.groups.maxSearchDepth` | Maximum group search depth - Example: 15 | `~` |
| `features.ldap.groups.searchBase` | LDAP group search base - the base DN to start the group search | `~` |
| `features.ldap.ccAdminFilter` | CN for cloudcontroller.admin group - This is for UAA to add this as a group for external users | `~` |
| `features.multiEnvironments` | Enabled multiple environments to be setup. For example, `dev test` will create two environments `dev-cfmr` and `test-cfmr` | `~` |
| `features.stack` | Stack definition deployed is either`cflinuxfs3` or `ubi`. | `cflinuxfs3` |
| `features.embeddedDatabase.enabled` | Enable the embedded database. If this is disabled, then `features.externalDatabase` should be configured to use an external database | `true` |
| `features.externalDatabase.enabled` | Enable the external database. If this is enabled, then `features.embeddedDatabase` must be disabled | `false` |
| `features.externalDatabase.requireSSL` | Require secure SSL connection to external database | `~` |
| `features.externalDatabase.caCert` | External database CA certificate | `~` |
| `features.externalDatabase.type` | External database type; it can be either 'mysql' or 'postgres' | `~` |
| `features.externalDatabase.host` | External database host name | `~` |
| `features.externalDatabase.port` | External database port number | `~` |
| `features.externalDatabase.databases.uaa.name` | UAA database name | `uaa` |
| `features.externalDatabase.databases.uaa.password` | UAA database password | `~` |
| `features.externalDatabase.databases.uaa.username` | UAA database username | `~` |
| `features.externalDatabase.databases.cc.name` | CC database name | `cc` |
| `features.externalDatabase.databases.cc.password` | CC database password | `~` |
| `features.externalDatabase.databases.cc.username` | CC database username | `~` |
| `features.externalDatabase.databases.bbs.name` | BBS database name | `bbs` |
| `features.externalDatabase.databases.bbs.password` | BBS database password | `~` |
| `features.externalDatabase.databases.bbs.username` | BBS database username | `~` |
| `features.externalDatabase.databases.routingApi.name` | Routing API database name | `routing-api` |
| `features.externalDatabase.databases.routingApi.password` | Routing API database password | `~` |
| `features.externalDatabase.databases.routingApi.username` | Routing API database username | `~` |
| `features.externalDatabase.databases.policyServer.name` | Policy server database name | `network_policy` |
| `features.externalDatabase.databases.policyServer.password` | Policy server database password | `~` |
| `features.externalDatabase.databases.policyServer.username` | Policy server database username | `~` |
| `features.externalDatabase.databases.silkController.name` | Silk controller database name | `network_connectivity` |
| `features.externalDatabase.databases.silkController.password` | Silk controller database password | `~` |
| `features.externalDatabase.databases.silkController.username` | Silk controller database username | `~` |
| `features.externalDatabase.databases.locket.name` | Locket controller database name | `locket` |
| `features.externalDatabase.databases.locket.password` | Locket controller database password | `~` |
| `features.externalDatabase.databases.locket.username` | Locket controller database username | `~` |
| `features.externalDatabase.databases.credhub.name` | Credhub controller database name | `credhub` |
| `features.externalDatabase.databases.credhub.password` | Credhub controller database password | `~` |
| `features.externalDatabase.databases.credhub.username` | Credhub controller database username | `~` |
| `features.customDomain` | Custom Domain to set for CFMR | `~` |
| `features.customCertNamespace` | Namespace where the custom certificate user for routes is placed | `openshift-ingress` |
| `features.customCertSecret` | Secret name which contains the custom certificate used for routes | `default` |
| `features.chartRepository` | Helm Chart Repository used for air-gapping capability | `~` |
| `features.chartRepositoryName` | Helm Chart Repository Name used for air-gapping capability | `~` |
| `features.persiBrokerRWXstorageClass` | Specified name of persistence broker RWX storage class | `~` |
| `features.persiBrokerRWOstorageClass` | Specified name of persistence broker RWO storage class | `~` |
| `resources.requests.cpu` | Installer job CPU request | `1000m` |
| `resources.requests.memory` | Installer job memory request | `2Gi` |
| `resources.limits.cpu` | Installer job CPU limit | `2000m` |
| `resources.limits.memory` | Installer job memory limit | `4Gi` |
| `rbac.create` | Create roles and bind to created cfmr installer job service account | `true` |
| `rbac.existingServiceAccount` | Name of existing service account to use | `` |

### External Database

By default, Cloud Foundry Migration Runtime includes an internal single-availability database. Cloud Foundry Migration Runtime also exposes a way to use an external database via the Helm property `features.externalDatabase`.

You must manually create all necessary databases externally, and then provide the individual credentials. It will error out if any of the required database credentials are missing. An example configuration is below

```bash
features:
  external_database:
    enabled: true
    type: mysql
    host: mariadb-server.corp.example.com
    port: 3306
    databases:
      uaa:
        name: uaa
        username: uaa-database-user
        password: PAWjxQst5l16J3w3vJdfX7fXY8HyHtyb
      cc:
        name: cloud_controller
        username: cc-database-user
        password: qj5KI3qwVe+XVFENAuEU9AfSkpUK/nzb
      bbs:
        name: diego
        username: diego-database-user
        password: z7gvkjWNUgX+xcn3Ia0loMEnAD7MXBgE
      routing_api:
        name: routing-api
        username: routing-api-database-user
        password: bTL6DhK89F+G05OZtHbvEdR1uwkyRMJt
      policy_server:
        name: network_policy
        username: network-policy-database-user
        password: EYviLFS/F4dAyVry5Stm8wrpOI64Xmnz
      silk_controller:
        name: network_connectivity
        username: silk-database-user
        password: ah7nbU1wsHuZ4BtmcdU1vV37KgVV2lLf
      locket:
        name: locket
        username: locket-database-user
        password: rWicBxhg8mIrhkuSR/aDlqljOMORuyL
      credhub:
        name: credhub
        username: credhub-database-user
        password: 5tJcIWHCR1QTLdfQDiN1Mz8K8jB+clD
```

### What is Installed?

#### Namespaces
Cloud Foundry Migration Runtime uses five namespaces (OpenShift projects). By default these start with the prefix `cfmr`.

|Namespace                                 |Purpose|
|------------------------------------------|-------|
|cfmr                                      |Contains Cloud Foundry system components|
|cfmr-cf-operator                          |Operator for managing the system deployed to cfmr|
|cfmr-eirini                               |Contains user applications deployed by the system installed in cfmr|
|cfmr-ui                                   |Cloud Foundry Migration Runtime UI components|


### Running an Install

### Download the case and case dependencies

Create a directory to save cases to a local directory and export `CFMR_VERSION`

```bash
$ mkdir /tmp/cases
$ export CFMR_VERSION=<cfmr version, e.g. 1.0.0>
```

Download case bundle

```bash
$ cloudctl case save                       \
    --case ibm-cfmr-case                  \
    --version "${CFMR_VERSION}"             \
    --repo https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case \
    --outputdir /tmp/cases
```

Verify the case, dependency cases and images csv has been downloaded under the
`/tmp/cases` directory.

### Unpack case bundle

Unpack case bundle to access files

```bash
$ tar -xvzf /tmp/cases/ibm-cfmr-"${CFMR_VERSION}".tgz
$ cd /tmp/cases/ibm-cfmr/
```

### Accept license agreement

Prior to installation, license must be viewed and accepted here: [http://ibm.biz/cfmr-license](http://ibm.biz/cfmr-license)

Once accepted, set the license flag `license.accept` to `true` in your Custom Resource file `cfmr.ibm.com_<version>_ibmcfmrprod_cr.yaml`

```yaml
spec:
  license:
    accept: true
```

### Point to entitled registry

Update your Custom Resource file `cfmr.ibm.com_<version>_ibmcfmrprod_cr.yaml` to use the name of Entitled Registry secret created earlier.

```yaml
spec:
  global:
    image:
      # Needs to be updated
      pullSecret: "<pull_secret_name>"
```

Create new project `cfmr-operator` to install CFMR from

```bash
$ oc new-project cfmr-operator
```

### Set default certificates for routes creation

Use the cluster's default certificates as the certificates for CFMR's routes. This can be found in namespace `openshift-ingress`. 

```bash
$ oc get secrets -n openshift-ingress
NAME              TYPE                 DATA  AGE
...
router-certs-default      kubernetes.io/tls           2   2d21h
...
```

Update custom resource file `cfmr.ibm.com_<version>_ibmcfmrprod_cr.yaml` to use the name of the default certificate.

```yaml
spec: 
  features:
    customCertNamespace: "openshift-ingress"
    customCertSecret: "router-certs-default"
```

If there are custom certificates generated and point to that certificate's name and location.

### Set SCC for operator

This chart requires adding `restricted`, `cluster-admin`, `self-provisioner` policy to service account `*-ibm-cfmr-serviceaccount` in the namespace CFMR installs from.
Note that `CUSTOM_RESOURCE_NAME` is the name `metadata.name` of your Custom Resource file `cfmr.ibm.com_<version>_ibmcfmrprod_cr.yaml`

```bash
$ export CUSTOM_RESOURCE_NAME=<custom_resource_name>
$ oc adm policy add-scc-to-user restricted system:serviceaccount:cfmr-operator:"${CUSTOM_RESOURCE_NAME}"-ibm-cfmr-serviceaccount
$ oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:cfmr-operator:"${CUSTOM_RESOURCE_NAME}"-ibm-cfmr-serviceaccount
$ oc adm policy add-cluster-role-to-user self-provisioner system:serviceaccount:cfmr-operator:"${CUSTOM_RESOURCE_NAME}"-ibm-cfmr-serviceaccount

```

### Deploy

Deploy an operator and custom resource:

```bash
# Update and deploy the Operator Custom Resource Definition and resources.
# When running the operator on OpenShift with the default restricted SCC we
# need to remove the runAsUser specification.
$ export PULL_SECRET=<pull_secret_name>   # entitled registry pull secret
$ oc apply -f deploy/crds/cfmr.ibm.com_ibmcfmrprods_crd.yaml
$ sed -e 's|REPLACE_SECRET|${PULL_SECRET}|g' deploy/service_account.yaml | oc apply -f -
$ oc apply -f deploy/role.yaml
$ oc apply -f deploy/role_binding.yaml
$ sed -e '/runAsUser/d' deploy/operator.yaml | oc apply -f -

# Set values in, then create the CFMR Custom Resource
$ oc apply -f deploy/crds/cfmr.ibm.com_<version>_ibmcfmrprod_cr.yaml
```

### Verify Install
Check to see if you can access the CFMR UI `https://cfmr-ui.<my_domain>`

```bash
# Fetch CFMR UI url.
$ oc get routes -n cfmr-ui --no-headers | awk '{print $2}'
```

Check to see if you can access the CFMR API endpoint

```bash
$ oc get routes -n cfmr --no-headers | awk '{print $2}'
api.<my_domain>
$ cf api api.<my_domain>
```

Or if you've provided a custom domain `features.customDomain`, check to see if you can access the UI and API using that.

```bash
$ curl https://cfmr-ui.<custom_domain>
$ cf api api.<custom_domain>
```

### Uninstall
To uninstall/delete the Custom Resource and update Custom Resource with `spec.action=uninstall` to be deployed

Update CR `cfmr.ibm.com_<version>_ibmcfmrprod_cr.yaml`

```yaml
spec:
  action: uninstall
```

```bash
# Delete CR then apply updated CR
$ oc delete IbmCfmrProd ${CUSTOM_RESOURCE_NAME}
$ oc apply -f deploy/crds/cfmr.ibm.com_<version>_ibmcfmrprod_cr.yaml
```
# Installing in an air-gapped cluster

This operator can be installed in an on-line or air-gapped cluster through either of the following install paths :
1. Operator Lifecycle Manager (default)
2. Kubernetes CLI

## Download the case and case dependencies

Create a directory to save cases to a local directory and export `CFMR_VERSION`

```bash
$ mkdir /tmp/cases
$ export CFMR_VERSION=<cfmr version, e.g. 1.0.0>
```

Run

```bash
$ cloudctl case save                       \
    --case ibm-cfmr-case                  \
    --version "${CFMR_VERSION}"             \
    --repo https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case \
    --outputdir /tmp/cases
```

Verify the case, dependency cases and images csv has been downloaded under the
`/tmp/cases` directory.

### Configure Air-Gapped OpenShift Cluster With a Bastion

#### Prepare Bastion Host

* Logon to the bastion machine

* Verify that the bastion machine has access
  * to public internet (to download CASE and images)
  * a target image registry ( where the images will be mirrored)
  * a target OpenShift cluster to install the operator

All the following steps should be run from the bastion machine

#### Set environment variables

Export the TARGET_REGISTRY, TARGET_REGISTRY_USER and TARGET_REGISTRY_SECRET environment variable with the location of
the private registry and it's username/password.

```bash
$ export TARGET_REGISTRY_USER=<registry user>
$ export TARGET_REGISTRY_SECRET=<registry secret>
$ export TARGET_REGISTRY=<my.private-registry.org>
```

(Optional) The OpenShift image registry isn't recommended due to limitations such as lack of
support for fat manifest. Quay.io enterprise is an opensource alternative. To use
the image registry anyways:

1. Expose the OpenShift image registry externally

```bash
$ oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge
```

2. Set the environment variable of the target registry.

```bash
$ export TARGET_REGISTRY=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}')
```


#### Configure Registry Auth

Log on to cluster and create new project `cfmr-operator` to install from, if you haven't already done so previously

```bash
$ export TARGET_NAMESPACE=cfmr-operator
$ oc new-project "${TARGET_NAMESPACE}"
```

Create auth secret for the source image registry

```bash
$ cloudctl case launch                                     \
    --case /tmp/cases/ibm-cfmr-"${CFMR_VERSION}".tgz             \
    --namespace "${TARGET_NAMESPACE}"                      \
    --inventory cfmrOperatorSetup                        \
    --action configure-creds-airgap                      \
    --args "--registry cp.icr.io --user iamapikey --pass <entitlement_key>"
```

Create auth secret for target image registry

```bash
$ cloudctl case launch                                     \
    --case /tmp/cases/ibm-cfmr-"${CFMR_VERSION}".tgz             \
    --namespace "${TARGET_NAMESPACE}"                       \
    --inventory cfmrOperatorSetup                        \
    --action configure-creds-airgap                      \
    --args "--registry "${TARGET_REGISTRY}" --user "${TARGET_REGISTRY_USER}" --pass "${TARGET_REGISTRY_SECRET}""
```

The credentials are now saved to `~/.airgap/secrets/<registry-name>.json`

#### Set the path of the target registry

If using OpenShift image registry, set the project to load the images to:

```bash
$ export TARGET_REGISTRY="${TARGET_REGISTRY}"/cfmr
```

#### Mirror Images

In this step, images from saved CASE (ibm-cfmr-"${CFMR_VERSION}"-images.csv) are copied to target registry in the air-gapped environment.

```bash
$ cloudctl case launch                                   \
    --case /tmp/cases/ibm-cfmr-"${CFMR_VERSION}".tgz           \
    --namespace "${TARGET_NAMESPACE}"                     \
    --inventory cfmrOperatorSetup                      \
    --action mirror-images                             \
    --args "--registry $TARGET_REGISTRY --inputDir /tmp/cases"
```

#### Configure Cluster for Air-gapping

This steps does the following

* creates a global image pull secret for the target registry (skipped if target registry is unauthenticated)
* creates a imagesourcecontentpolicy

WARNING:

* Cluster resources must adjust to the new pull secret, which can temporarily limit the usability of the cluster. Authorization credentials are stored in $HOME/.airgap/secrets and /tmp/airgap* to support this action

* Applying imagesourcecontentpolicy causes cluster nodes to recycle.

```bash
$ cloudctl case launch                                   \
    --case /tmp/cases/ibm-cfmr-"${CFMR_VERSION}".tgz           \
    --namespace "${TARGET_NAMESPACE}"                     \
    --inventory cfmrOperatorSetup                      \
    --action configure-cluster-airgap                  \
    --args "--registry "${TARGET_REGISTRY}" --inputDir /tmp/cases"
```

(Optional) If you are using an insecure registry, you must add the local registry to the cluster insecureRegistries list.

```bash
$ oc patch image.config.openshift.io/cluster --type=merge -p '{"spec":{"registrySources":{"insecureRegistries":["'${TARGET_REGISTRY}'"]}}}'
```

#### Configure Helm Repository

Prepare a private helm chart repository on the OpenShift cluster that can be used during installation. 

Locate chartmuseum helm chart in `/tmp/cases/charts` folder. Should be named `chartmuseum-3.1.0.tgz`.

Initialize helm chart repository on the cluster

```bash
$ cloudctl case launch                                   \
    --case /tmp/cases/ibm-cfmr-"${CFMR_VERSION}".tgz     \
    --namespace "${TARGET_NAMESPACE}"                    \
    --inventory cfmrOperatorSetup                        \
    --action init-helm-repository                        \
    --args "-chartmuseum chartmuseum-3.1.0.tgz"          
```

After helm repo is initialized, helm repository URL and username/password are created

```bash
[INFO] Route URL for private-helm-repo to be used during loading of helm charts
http://private-helm-repo-chartmuseum-private-helm-repo.mycluster.myorg
[INFO] username = admin
[INFO] password = feb92d0ebc038522f407c4642a4acf14
```

#### Load Helm Repository

Loads helm charts for `quarks`, `kubecf`, and `console` in defaults charts `/tmp/cases/charts` into helm repository.

Export helm repo URL and credentials.

```bash
$ export HELM_REPO_URL=<private-helm-repo URL e.g. http://private-helm-repo-chartmuseum-private-helm-repo.mycluster.myorg>
$ export HELM_REPO_USERNAME=<e.g. admin>
$ export HELM_REPO_PASSWORD=<e.g. feb92d0ebc038522f407c4642a4acf14>
```

Load helm charts into helm repository
```bash
$ cloudctl case launch                                   \
    --case /tmp/cases/ibm-cfmr-"${CFMR_VERSION}".tgz     \
    --namespace "${TARGET_NAMESPACE}"                    \
    --inventory cfmrOperatorSetup                        \
    --action load-helm-repository                        \
    --args "-u "${HELM_REPO_USERNAME}" -p "${HELM_REPO_PASSWORD}" --url "${HELM_REPO_URL}""          
```

Once complete, this should list loaded charts. This will be used in the custom resource during installation.

Update your Custom Resource file `cfmr.ibm.com_<version>_ibmcfmrprod_cr.yaml` to use the helm repository.
```yaml
spec:
  features:
    chartRepository: "http://private-helm-repo-chartmuseum-private-helm-repo.mycluster.myorg"
    chartRepositoryName: "private-helm-repo"
```

### In Air-Gapped OpenShift Cluster Without a Bastion

#### Prepare a portable device

Prepare a portable device (such as laptop) that can be used to download the case and images and can be carried into the air-gapped environment

* Verify that the portable device has access
  * to public internet (to download CASE and images)
  * a target image registry ( where the images will be mirrored)
  * a target OpenShift cluster to install the operator

All the following steps should be run from the portable device

#### Configure Registry Auth

See instructions from previous [Configure Registry Auth](configure-registry-auth) section

#### Set environment variables

See instructions from previous [Set environment variables](set-environment-variables) section

#### Mirror Images

See instructions from previous [Mirror Images](mirror-images) section

#### Configure Cluster for Air-gapping

See instructions from previous [Configure Cluster for Air-gapping](configure-cluster-for-air-gapping) section

#### Configure Helm Repository

See instructions from previous [Configure Helm Repository](configure-helm-repository) section

#### Load Helm Repository

See instructions from previous [Load Helm Repository](load-helm-repository) section

## Limitations

## Documentation

## Copyright

© Copyright IBM Corporation 2020. All Rights Reserved.

