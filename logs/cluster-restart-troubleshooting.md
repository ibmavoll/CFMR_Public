#### Background
As a result of a cluster restart, certain CFMR pods dynamically regenerate assets such as mutatingwebhookconfigurations and secrets.  Unfortunately, if a cluster is shutdown - the pods restart - however the existing assets are not overwritten.  This results in a mismatched (out-of-synch) condition.  We'll be opening an issue with dev to improve this experience.  We think linking the ownership of these resources to their parent owning deploy or pod could cause the K8s GC to cleanup these out-of-synch resources during cluster shutdown automatically.  

#### Decreasing the sensitivity to warnings on the mutatingwebhookconfiguration

```
oc -n cfmr patch mutatingwebhookconfiguration eirini-persi-mutating-hook --type=JSON -p '[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Ignore"}]'
```

Reference:  [https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#failure-policy](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#failure-policy)


#### Re-synchronize (regenerate) the webhook certificates, keys and CAs and the setup secret with the `persi` deployment (running cluster)

```
# Scale Deployment of eirini-persi to 0 replicas
oc -n cfmr scale deploy persi --replicas=0
# Remove stale cluster scoped mutatingwebhookconfiguration with stale client config
oc delete mutatingwebhookconfigurations eirini-persi-mutating-hook 
# Remove stale eirini-persi-setupcertificate
oc -n cfmr delete secret eirini-persi-setupcertificate
# Regenerate new synchronized certificates and client configs for the mutatingwebhookconfiguration
oc -n cfmr scale deploy persi --replicas=1
# Validate
oc -n cfmr get pods | grep persi
oc get mutatingwebhookconfiguration eirini-persi-mutating-hook
oc -n cfmr get secret eirini-persi-setupcertificate
```

#### Troubleshooting tips
Example Logs from Eirini-Persi Pod

```
▶ oc logs persi-6ff46f54cd-z6knj
2021-05-03T16:25:54.303Z	INFO	internal/start.go:41	Starting v0.0.0-dirty+76.g6b229dd with namespace cfmr-eirini
{"level":"info","ts":1620059154.3038177,"caller":"kubeconfig/getter.go:53","msg":"Using in-cluster kube config"}
{"level":"info","ts":1620059154.3038573,"caller":"kubeconfig/checker.go:36","msg":"Checking kube config"}
{"level":"info","ts":1620059154.30802,"caller":"kubeconfig/getter.go:53","msg":"Using in-cluster kube config"}
{"level":"info","ts":1620059154.3081286,"caller":"kubeconfig/checker.go:36","msg":"Checking kube config"}
{"level":"info","ts":1620059154.9382117,"caller":"ctxlog/context.go:51","msg":"Creating webhook server certificate"}
```

Symptom

![](webhook-out-of-synch-symptom.png)
