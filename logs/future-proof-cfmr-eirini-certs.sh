#!/bin/bash
# ----------------------------------------------------------------------------------------------------\\
# Description:
#   A script to futureproof your CFMR Eirini webhook client certs, keys and CAs in anticipation of a
#   future cluster restart
#
#   Options:
#     None
#
#   Example:
#     ./future-proof-cfmr-eirini-certs.sh
#
#   Reference: None
#
# ----------------------------------------------------------------------------------------------------\\
set -e

## Let's Attach the parent pod as the ownerReference to the webhook configuration and setupCertificates

# Patching eirini-persi-mutating-hook
oc get pods -l app.kubernetes.io/component=persi -o go-template="{{range .items}}\"\"kubectl patch mutatingwebhookconfiguration eirini-persi-mutating-hook -n cfmr --type=JSON -p '[{\"op\":\"add\",\"path\":\"/metadata/ownerReferences\",\"value\":[{\"apiVersion\":\"v1\",\"blockOwnerDeletion\":false,\"controller\":true,\"kind\":\"Pod\",\"name\":\"{{.metadata.name}}\",\"uid\":\"{{.metadata.uid}}\"}]}]'\"\"{{\"\n\"}}{{end}}" | xargs -0 -L1 sh -c

# Patching eirini-persi-setupcertificate
oc get pods -l app.kubernetes.io/component=persi -o go-template="{{range .items}}\"\"kubectl patch secret eirini-persi-setupcertificate -n cfmr --type=JSON -p '[{\"op\":\"add\",\"path\":\"/metadata/ownerReferences\",\"value\":[{\"apiVersion\":\"v1\",\"blockOwnerDeletion\":false,\"controller\":true,\"kind\":\"Pod\",\"name\":\"{{.metadata.name}}\",\"uid\":\"{{.metadata.uid}}\"}]}]'\"\"{{\"\n\"}}{{end}}" | xargs -0 -L1 sh -c

# Patching eirini-dns-aliases-mutating-hook
oc get pods -l app.kubernetes.io/component=eirini-dns-aliases -o go-template="{{range .items}}\"\"kubectl patch mutatingwebhookconfiguration eirini-dns-aliases-mutating-hook -n cfmr --type=JSON -p '[{\"op\":\"add\",\"path\":\"/metadata/ownerReferences\",\"value\":[{\"apiVersion\":\"v1\",\"blockOwnerDeletion\":false,\"controller\":true,\"kind\":\"Pod\",\"name\":\"{{.metadata.name}}\",\"uid\":\"{{.metadata.uid}}\"}]}]'\"\"{{\"\n\"}}{{end}}" | xargs -0 -L1 sh -c

# Patching eirini-dns-aliases-setupcertificate
oc get pods -l app.kubernetes.io/component=eirini-dns-aliases -o go-template="{{range .items}}\"\"kubectl patch secret eirini-dns-aliases-setupcertificate -n cfmr --type=JSON -p '[{\"op\":\"add\",\"path\":\"/metadata/ownerReferences\",\"value\":[{\"apiVersion\":\"v1\",\"blockOwnerDeletion\":false,\"controller\":true,\"kind\":\"Pod\",\"name\":\"{{.metadata.name}}\",\"uid\":\"{{.metadata.uid}}\"}]}]'\"\"{{\"\n\"}}{{end}}" | xargs -0 -L1 sh -c

# Patching eirini-ssh-mutating-hook
oc get pods -l app.kubernetes.io/component=ssh -o go-template="{{range .items}}\"\"kubectl patch mutatingwebhookconfiguration eirini-ssh-mutating-hook -n cfmr --type=JSON -p '[{\"op\":\"add\",\"path\":\"/metadata/ownerReferences\",\"value\":[{\"apiVersion\":\"v1\",\"blockOwnerDeletion\":false,\"controller\":true,\"kind\":\"Pod\",\"name\":\"{{.metadata.name}}\",\"uid\":\"{{.metadata.uid}}\"}]}]'\"\"{{\"\n\"}}{{end}}" | xargs -0 -L1 sh -c

# Patching eirini-ssh-setupcertificate
oc get pods -l app.kubernetes.io/component=ssh -o go-template="{{range .items}}\"\"kubectl patch secret eirini-ssh-setupcertificate -n cfmr --type=JSON -p '[{\"op\":\"add\",\"path\":\"/metadata/ownerReferences\",\"value\":[{\"apiVersion\":\"v1\",\"blockOwnerDeletion\":false,\"controller\":true,\"kind\":\"Pod\",\"name\":\"{{.metadata.name}}\",\"uid\":\"{{.metadata.uid}}\"}]}]'\"\"{{\"\n\"}}{{end}}" | xargs -0 -L1 sh -c

# Patching eirini-x-mutating-hook
oc get pods -l app.kubernetes.io/component=instance-index-env-injector -o go-template="{{range .items}}\"\"kubectl patch mutatingwebhookconfiguration eirini-x-mutating-hook -n cfmr --type=JSON -p '[{\"op\":\"add\",\"path\":\"/metadata/ownerReferences\",\"value\":[{\"apiVersion\":\"v1\",\"blockOwnerDeletion\":false,\"controller\":true,\"kind\":\"Pod\",\"name\":\"{{.metadata.name}}\",\"uid\":\"{{.metadata.uid}}\"}]}]'\"\"{{\"\n\"}}{{end}}" | xargs -0 -L1 sh -c

# Patching eirini-x-setupcertificate
oc get pods -l app.kubernetes.io/component=instance-index-env-injector -o go-template="{{range .items}}\"\"kubectl patch secret eirini-x-setupcertificate -n cfmr --type=JSON -p '[{\"op\":\"add\",\"path\":\"/metadata/ownerReferences\",\"value\":[{\"apiVersion\":\"v1\",\"blockOwnerDeletion\":false,\"controller\":true,\"kind\":\"Pod\",\"name\":\"{{.metadata.name}}\",\"uid\":\"{{.metadata.uid}}\"}]}]'\"\"{{\"\n\"}}{{end}}" | xargs -0 -L1 sh -c

# Patching eirinix-annotation-mutating-hook
oc get pods -l app.kubernetes.io/name=eirini-annotate-extension -o go-template="{{range .items}}\"\"kubectl patch mutatingwebhookconfiguration eirinix-annotation-mutating-hook -n cfmr --type=JSON -p '[{\"op\":\"add\",\"path\":\"/metadata/ownerReferences\",\"value\":[{\"apiVersion\":\"v1\",\"blockOwnerDeletion\":false,\"controller\":true,\"kind\":\"Pod\",\"name\":\"{{.metadata.name}}\",\"uid\":\"{{.metadata.uid}}\"}]}]'\"\"{{\"\n\"}}{{end}}" | xargs -0 -L1 sh -c

# Patching eirinix-annotation-setupcertificate
oc get pods -l app.kubernetes.io/name=eirini-annotate-extension -o go-template="{{range .items}}\"\"kubectl patch secret eirinix-annotation-setupcertificate -n cfmr --type=JSON -p '[{\"op\":\"add\",\"path\":\"/metadata/ownerReferences\",\"value\":[{\"apiVersion\":\"v1\",\"blockOwnerDeletion\":false,\"controller\":true,\"kind\":\"Pod\",\"name\":\"{{.metadata.name}}\",\"uid\":\"{{.metadata.uid}}\"}]}]'\"\"{{\"\n\"}}{{end}}" | xargs -0 -L1 sh -c

