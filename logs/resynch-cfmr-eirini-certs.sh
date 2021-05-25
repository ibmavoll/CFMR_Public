#!/bin/bash
# ----------------------------------------------------------------------------------------------------\\
# Description:
#   A script to resynchronize CFMR webhook client certs, keys and CAs after a cluster restart
#
#   Options:
#     None
#
#   Example:
#     ./resynch-cfmr-eirini-certs.sh
#
#   Reference: None
#
# ----------------------------------------------------------------------------------------------------\\
set -e
# Scale Pertinent Deployments to 0 replicas
oc -n cfmr scale deploy persi --replicas=0
oc -n cfmr scale deploy eirini-dns-aliases --replicas=0
oc -n cfmr scale deploy ssh --replicas=0
oc -n cfmr scale deploy instance-index-env-injector --replicas=0
oc -n cfmr scale deploy eirini-annotate-extension --replicas=0
oc -n cfmr scale deploy eirini-annotate-extension --replicas=0


# Remove cluster scoped mutatingwebhookconfiguration with stale client config
oc delete mutatingwebhookconfigurations eirini-persi-mutating-hook --ignore-not-found=true
oc delete mutatingwebhookconfigurations eirini-dns-aliases-mutating-hook --ignore-not-found=true
oc delete mutatingwebhookconfigurations eirini-ssh-mutating-hook --ignore-not-found=true
oc delete mutatingwebhookconfigurations eirini-x-mutating-hook --ignore-not-found=true
oc delete mutatingwebhookconfigurations eirinix-annotation-mutating-hook --ignore-not-found=true
oc delete mutatingwebhookconfigurations eirini-loggregator-bridge-mutating-hook --ignore-not-found=true


# Remove stale *-setupcertificates
oc -n cfmr delete secret eirini-persi-setupcertificate --ignore-not-found=true
oc -n cfmr delete secret eirini-dns-aliases-setupcertificate --ignore-not-found=true
oc -n cfmr delete secret eirini-ssh-setupcertificate --ignore-not-found=true
oc -n cfmr delete secret eirini-x-setupcertificate --ignore-not-found=true
oc -n cfmr delete secret eirinix-annotation-setupcertificate --ignore-not-found=true
# No need to delete ...
# oc -n cfmr delete secret eirini-loggregator-bridge-setupcertificate --ignore-not-found=true

# Regenerate new synchronized certificates and client configs for the mutatingwebhookconfiguration
oc -n cfmr scale deploy persi --replicas=1
oc -n cfmr scale deploy eirini-dns-aliases --replicas=1
oc -n cfmr scale deploy ssh --replicas=1
oc -n cfmr scale deploy instance-index-env-injector --replicas=1
oc -n cfmr scale deploy eirini-annotate-extension --replicas=1

# Rollout logregator-bridge restart with a 3 minute sleep and then patch the hook
oc -n cfmr rollout restart deployment/loggregator-bridge && \
  oc -n cfmr rollout status deployment/loggregator-bridge && \
  sleep 180 && \
  oc -n cfmr get pods --field-selector=status.phase=Running -l app.kubernetes.io/component=loggregator-bridge -o go-template="{{range .items}}\"\"oc patch mutatingwebhookconfiguration eirini-loggregator-bridge-mutating-hook -n cfmr --type=JSON -p '[{\"op\":\"add\",\"path\":\"/metadata/ownerReferences\",\"value\":[{\"apiVersion\":\"v1\",\"blockOwnerDeletion\":false,\"controller\":true,\"kind\":\"Pod\",\"name\":\"{{.metadata.name}}\",\"uid\":\"{{.metadata.uid}}\"}]}]'\"\"{{\"\n\"}}{{end}}" | xargs -0 -L1 sh -c

echo "Begin validation ..."
# Validate
oc get mutatingwebhookconfiguration eirini-persi-mutating-hook
sleep 2
oc get mutatingwebhookconfigurations eirini-dns-aliases-mutating-hook
sleep 2
oc get mutatingwebhookconfigurations eirini-ssh-mutating-hook
sleep 2
oc get mutatingwebhookconfigurations eirini-x-mutating-hook
sleep 2
oc get mutatingwebhookconfigurations eirinix-annotation-mutating-hook
sleep 2
oc get mutatingwebhookconfigurations eirini-loggregator-bridge-mutating-hook
sleep 2

oc -n cfmr get secret eirini-persi-setupcertificate
oc -n cfmr get secret eirini-dns-aliases-setupcertificate
oc -n cfmr get secret eirini-ssh-setupcertificate
oc -n cfmr get secret eirini-x-setupcertificate
oc -n cfmr get secret eirinix-annotation-setupcertificate
oc -n cfmr get secret eirini-loggregator-bridge-setupcertificate

echo ""
echo "Persi Logs ..."
oc -n cfmr logs -l app.kubernetes.io/component=persi
echo ""
echo "Eirini DNS Aliases Logs ..."
oc -n cfmr logs -l app.kubernetes.io/component=eirini-dns-aliases
echo ""
echo "Eirini SSH Logs ..."
oc -n cfmr logs -l app.kubernetes.io/component=ssh
echo ""
echo "Eirini Instance Index Env Injector Logs ..."
oc -n cfmr logs -l app.kubernetes.io/component=instance-index-env-injector
echo ""
echo "Eirini Annotate Logs ..."
oc -n cfmr logs -l app.kubernetes.io/name=eirini-annotate-extension
echo ""
