## Custom Domain Route Setup

### Step 0:  Perform CFMR Installation with a `CUSTOM_DOMAIN` config entry.  

In my testcase, this was populated as `CUSTOM_DOMAIN=prelaunch.cfmr.site`.

### Step 1:  After install completes, extract the ca.crt from CFMR's secret
```
oc get secret var-router-ssl -n cfmr -o json -o=jsonpath="{.data.ca}" | base64 --decode | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > custom_ca.crt
```

### Step 2:  Backup and Delete the existing routes
```
oc get route router -n cfmr -oyaml > coreapi.yaml
oc delete route router -n cfmr
oc get route cfmr-ui -n cfmr-ui -oyaml > cfmr-ui-route.yaml
oc delete route cfmr-ui -n cfmr-ui
```

### We are now jumping into the world of Ingress Sharding ...
[Reference](https://docs.openshift.com/container-platform/4.6/networking/configuring_ingress_cluster_traffic/configuring-ingress-cluster-traffic-ingress-controller.html#nw-ingress-sharding-namespace-labels_configuring-ingress-cluster-traffic-ingress-controller)
---
### Step 3:  Create a custom CFMR-Ingresscontroller using this YAML file as a template.
There are a few key attributes to note:  
-  `namespaceSelector` :  This allows us to "label" any namespaces we want this ingresscontroller to "cover".  By adding a label of `type=sharded`, any newly created routes within that namespace will be under the "supervision/control" of this ingress controller.
-  `nodePlacement` : I don't know if this is the required definition.  I just copied whatever was in the default controller which can be inspected via `oc get ingresscontroller default -n openshift-ingress-operator -oyaml` .  In the doc, there seem to be other yaml representations that allows for running on any worker node for example.  Experimentation is encouraged here.
- `endpointPublishingStrategy` : This leverages the fact that I'm on IBM Cloud and have LB support.  For other environments, this could require other techniques to expose.  In general, I think the smartest strategy is to duplicate whatever the "default" Controller's strategy is here since the OpenShift admins have presumably configured it to allow their console routes to be accessible using this PublishingStrategy.
-  It seemed to be important for me to create/update/recreate this controller and then create the affected routes.  

>Pro Tip: for Testing:  Testing became more confusing if i tried to update the controller and "assumed" that my existing route was now enjoying the effects of the change.  Better to keep deleting the route and then make the change to the controller and then recreate the route.
- I also observed that making changes to the controller has a lag time of ~15-30 seconds while pods are terminated and new ones are spun up.  You can watch this process via `watch oc get pods -n openshift-ingress`

```
apiVersion: v1
items:
- apiVersion: operator.openshift.io/v1
  kind: IngressController
  metadata:
    name: cfmr-shard 
    namespace: openshift-ingress-operator
  spec:
    domain: router.prelaunch.cfmr.site
    endpointPublishingStrategy:
      loadBalancer:
        scope: External
      type: LoadBalancerService
    nodePlacement:
      tolerations:
      - key: dedicated
        value: edge
    namespaceSelector:
      matchLabels:
        type: sharded
    routeAdmission:
      namespaceOwnership: InterNamespaceAllowed
      wildcardPolicy: WildcardsAllowed
  status: {}
kind: List
metadata:
  resourceVersion: ""
  selfLink: ""
```
### Step 4:  Let's create a "defaultCertificate" to be used with this new ingresscontroller.  

We could have just predefined it in the YAML ... but I wanted to make this a separate step to clarify how we provide SSL Certs to associate with this controller.  In my case, I use LetsEncrypt and have the key and fullchain.cer .  I made sure that my SSL Cert was a wildcard certificate and also that I covered the "IdentityZone" subdomains under `uaa` as well.  This was my command using acme.sh. ` acme.sh --issue --dns dns_namecheap -d 'prelaunch.cfmr.site' -d '*.prelaunch.cfmr.site' -d '*.uaa.prelaunch.cfmr.site'`

>IMPORTANT:  This secret MUST reside in the `openshift-ingress` namespace so that the ingresscontroller pods can have access to it.

```
oc create secret tls cfmr-custom-domain-tls --cert /Users/boilerupnc/.acme.sh/prelaunch.cfmr.site/fullchain.cer --key /Users/boilerupnc/.acme.sh/prelaunch.cfmr.site/prelaunch.cfmr.site.key -n openshift-ingress

oc patch ingresscontroller.operator cfmr-shard --type=merge -p '{"spec":{"defaultCertificate": {"name": "cfmr-custom-domain-tls"}}}' -n openshift-ingress-operator
```

### Step 5:  Let's now patch the default controller to "skip" our upcoming routes and let our newly minted one handle the traffic exclusively for our designated namespaces.
```
oc patch \
  -n openshift-ingress-operator \
  IngressController/default \
  --type='merge' \
  -p '{"spec":{"namespaceSelector":{"matchExpressions":[{"key":"type","operator":"NotIn","values":["sharded"]}]}}}'
```
### Step 6:  After waiting for the pods to terminate/restart (`watch oc get pods -n openshift-ingress`), Let's label our namespaces and create our shiny new routes.
```
oc label ns cfmr-ui type=sharded --overwrite=true
oc label ns cfmr type=sharded --overwrite=true

oc create route reencrypt router -n cfmr --hostname router.prelaunch.cfmr.site --insecure-policy Redirect --service router --port router-ssl --dest-ca-cert ./custom_ca.crt --wildcard-policy="Subdomain"

oc create route passthrough cfmr-ui -n cfmr-ui --hostname cfmr-ui.prelaunch.cfmr.site --insecure-policy Redirect --service cfmr-ui-ui-ext --port https
```

### Step 7:  Verify the routes are ONLY exposed via our new ingresscontroller
```
oc describe route cfmr-ui -n cfmr-ui
oc describe route router -n cfmr
```

Sample Response line that you are looking to validate.  If it shows two lines for being exposed on both the default and cfmr-shard routers ... then something is wrong.  Best step is to delete the route and recreate to see if it resolves.  Otherwise, you'll need to see why the "sharding" isn't picking up your namespace label.:
```
[....]
Requested Host:		ui.prelaunch.cfmr.site
			  exposed on router cfmr-shard (host router.prelaunch.cfmr.site) 30 hours ago
[....]
Requested Host:		router.prelaunch.cfmr.site
			  exposed on router cfmr-shard (host router.prelaunch.cfmr.site) 30 hours ago
[....]
```

### Step 8:  Mapping your Custom Domain with an `A Name` record to your newly spunup LoadBalancer Service which was triggered through our choice of an EnpointPublishingStrategy defined in our sharded custom ingresscontroller YAML definition.  We need to find the externalIP created.
```
 oc get svc -n openshift-ingress
```
Example Response:
```
NAME                         TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)                      AGE
router-cfmr-shard            LoadBalancer   172.21.195.202   158.85.92.164   80:31143/TCP,443:32065/TCP   31h
router-default               LoadBalancer   172.21.150.77    158.85.92.162   80:31218/TCP,443:32273/TCP   34h
router-internal-cfmr-shard   ClusterIP      172.21.91.186    <none>          80/TCP,443/TCP,1936/TCP      31h
router-internal-default      ClusterIP      172.21.196.85    <none>          80/TCP,443/TCP,1936/TCP      34h
``` 

Depending on your domain name service provider, you will then create a representative A name to point to the External-IP.  In my case it is:  `158.85.92.164`

![](arecord.png)

### Step 9: Done! Enjoy the fruits of your labor.
