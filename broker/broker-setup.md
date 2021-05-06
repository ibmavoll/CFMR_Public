# Broker Setup

##### Step 1:  Let's create the namespaces and their necessary annotations/sccs for the desired services (redis, rabbitmq, mysql, spring-config, eureka (registry))

`oc apply -f ./prereq-namespaces.yaml`

##### Step 2:  The redis workloads need to have an ability for privileged SCC for their initContainers to set a sysctl value
 
`oc adm policy add-scc-to-user privileged -z default -n redis-deploy`

##### Step 3:  Install RabbitMQ Operator

```
oc apply -f ./rabbitmq-cluster-operator.yml
oc annotate --overwrite namespace rabbitmq-system "openshift.io/sa.scc.mcs=s0:c26,c5"
oc annotate --overwrite namespace rabbitmq-system "openshift.io/sa.scc.supplemental-groups=1000/1"
oc annotate --overwrite namespace rabbitmq-system "openshift.io/sa.scc.uid-range=1000/1"
```

##### Step 4:  Apply the service broker's custom resource definition
`oc apply -f servicebroker.couchbase.com_servicebrokerconfigs.yaml`

>  At this point, it is advisable to open and edit the broker-config.yaml file and make necessary image, domain, service tweaks/changes desired.

##### Step 5:  Apply the service configuration file
`cat broker-config.yaml | sed 's/REPLACE_ME/'$(oc get configmap console-config -n openshift-console -o jsonpath='{.data.console-config\.yaml}' | grep consoleBaseAddress | awk '{print $2}' | cut -d"." -f2- | cut -d":" -f1)'/g' | sed 's/REPLACE_CUSTOM/your.custom.site/g' | oc apply -f -`

##### Step 6:  Let's install the broker now.
`oc apply -f ./broker-deploy.yaml`

Let's look at the logs ....

`oc logs <broker-pod> -n cfmr-broker`

```
# Spinup Time to deploy:  <1min
# Happy Log Messages
#I0408 06:54:38.641013       1 main.go:104] couchbase-service-broker 0.0.0 (git commit 0f99c3e80bd664fef19f5856f754cb1d2e5a0281)
#I0408 06:54:52.481059       1 config.go:175] configuring service broker
#I0408 06:54:52.776546       1 config.go:96] service broker configuration created, service ready
#I0408 06:54:52.816339       1 config.go:136] service broker configuration updated
#I0408 06:54:59.015127       1 broker.go:261] HTTP req: "GET /readyz HTTP/2.0" 10.114.174.171:33055
#I0408 06:54:59.015220       1 broker.go:270] HTTP rsp: "200 OK" 97.41µs
#I0408 06:55:09.015548       1 broker.go:261] HTTP req: "GET /readyz HTTP/2.0" 10.114.174.171:36493
#I0408 06:55:09.015747       1 broker.go:270] HTTP rsp: "200 OK" 203.514µs
```

##### Step 7:  Let's setup the route for the broker ...
`cat broker-route.yaml | sed 's/REPLACE_ME/'$(oc get configmap console-config -n openshift-console -o jsonpath='{.data.console-config\.yaml}' | grep consoleBaseAddress | awk '{print $2}' | cut -d"." -f2- | cut -d":" -f1)'/g' | oc create -f -`

##### Step 8:  Let's now Test that the catalog is working ok
`curl -k -H "X-Broker-API-Version: 2.16" https://username:password@cfmr-service-broker-default.$(oc get configmap console-config -n openshift-console -o jsonpath='{.data.console-config\.yaml}' | grep consoleBaseAddress | awk '{print $2}' | cut -d"." -f2- | cut -d":" -f1)/v2/catalog`

```
# Happy Response
#{"services":[{"name":"p-rabbitmq","id":"a4ee6be4-06d1-4b6f-822d-81199ae59c73",
#"description":"An open-source message-broker software using AMQP",  ...
#}
```

##### Step 9: Let's now test to see if we can see all the plans from the endpoint via the CF CLI
```
cf api https://api.cfmr.$(oc get route -n openshift-console --no-headers | awk '{print $2}' | cut -d"." -f2-) --skip-ssl-validation
cf auth admin $(oc get secrets var-cf-admin-password -n cfmr --template={{.data.password}} | base64 --decode)
cf create-org myorg && cf target -o myorg
cf create-space myspace && cf target -s myspace
cf target -o myorg -s myspace

# Let's register the broker
cf create-service-broker cfmr-broker username password https://cfmr-service-broker-default.$(oc get configmap console-config -n openshift-console -o jsonpath='{.data.console-config\.yaml}' | grep consoleBaseAddress | awk '{print $2}' | cut -d"." -f2- | cut -d":" -f1)

# NO TRAILING SLASH in the URL above. If you accidentally do use one, you will receive a "The service broker returned an invalid response. Status Code: 301 Moved Permanently, Body: Moved Permanently. response"

cf service-access -b cfmr-broker | grep none | awk '{print $1}' | xargs -L 1 -I {} cf enable-service-access {}

cf service-access -b cfmr-broker

# Happy Response
#Getting service access for broker cfmr-broker as admin...
#broker: cfmr-broker
#   service              plan          access   orgs
#   p-rabbitmq           single        all
#   p-rabbitmq           standard      all
#   p-redis              small-cache   all
#   p-service-registry   standard      all
#   p.config-server      standard      all
#   p.mysql              db-small      all
```

##### Step 9: Let's now test instantiating all of them and verifying that all plans will run

```
cf create-service p-redis small-cache redis-test
cf create-service p.mysql db-small mysql-test
cf create-service p-rabbitmq single rabbitmq-sing-test
cf create-service p-rabbitmq standard rabbitmq-std-test
cf create-service p-service-registry standard registry-test
# cf create-service p.config-server standard config-server-test -c '{ "git": { "uri": "https://github.com/spring-cloud-services-samples/cook-config.git", "label": "master"  } }'
```


