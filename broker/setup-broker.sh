#!/bin/bash
# ----------------------------------------------------------------------------------------------------\\
# Description:
#   A basic script to setup your amazin' CFMR Broker
#
#   Options:
#     Nada
#
#   Example:
#     ./setup-broker.sh
#
#   Reference: None
#
# ----------------------------------------------------------------------------------------------------\\
set -e

############
# Colors  ##
############
Green='\x1B[0;32m'
Red='\x1B[0;31m'
Yellow='\x1B[0;33m'
Cyan='\x1B[0;36m'
no_color='\x1B[0m' # No Color
beer='\xF0\x9f\x8d\xba'
delivery='\xF0\x9F\x9A\x9A'
beers='\xF0\x9F\x8D\xBB'
eyes='\xF0\x9F\x91\x80'
cloud='\xE2\x98\x81'
crossbones='\xE2\x98\xA0'
litter='\xF0\x9F\x9A\xAE'
fail='\xE2\x9B\x94'
harpoons='\xE2\x87\x8C'
tools='\xE2\x9A\x92'
present='\xF0\x9F\x8E\x81'
#############

clear

oc login --token="${OPENSHIFT_TOKEN}" --server="${OPENSHIFT_URL}"

# Let's first start by setting up the desired Namespaces within the OpenShift Cluster
oc apply -f ./prereq-namespaces.yaml

# The redis workloads need to have an ability for privileged SCC for their initContainers to set a sysctl value
# TODO: Worth investigating if its better to "annotate" the namespace itself or better to attach to the default 
oc adm policy add-scc-to-user privileged -z default -n redis-deploy

# We now need to tackle pushing the necessary images into their appropriate cluster namespaced image registry locations
# First lets make sure we can access the registry itself.  
# TODO: This was a bit different on either Satellite or CloudPak Systems - can't recall.  But need to look at past notes

oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{"spec":{"defaultRoute":true}}'

# Assuming that we have all of our images already built or locally available to push

# Login to the local cluster registry
docker login -u $(oc whoami) -p $(oc whoami -t) $(oc get routes -n openshift-image-registry --no-headers | awk 'NR==1{print $2}')

## CFMR BROKER IMAGE MANIPULATION ##
# Build Image - `make ubi`
# Tag the local CFMR-Broker Image
docker tag $(docker images | grep "cfmr-service-broker" | grep "1.0.0" | awk '{print $3}') $(oc get routes -n openshift-image-registry --no-headers | awk '{print $2}')/cfmr-broker/cfmr-service-broker:1.0.0
# Push the local CFMR-Broker Image
docker push $(oc get routes -n openshift-image-registry --no-headers | awk 'NR==1{print $2}')/cfmr-broker/cfmr-service-broker:1.0.0

## Spring Cloud Config Server (Spring Boot v2.2.6 RELEASE)
# Build Image - `docker build -t cfmr-p-config-server:2.2.6 -f ubiDockerfile .`
# Run Image - `docker run -it --name=configserver -p 8888:8888 -v /path/to/config/application/props/folder:/config cfmr-p-config-server:2.2.6`
# Tag the local Config Server Image
docker tag $(docker images | grep "cfmr-p-config-server" | grep "2.2.6" | awk '{print $3}') $(oc get routes -n openshift-image-registry --no-headers | awk '{print $2}')/spring-services-deploy/cfmr-p-config-server:2.2.6
# Push the local Config Server Image
docker push $(oc get routes -n openshift-image-registry --no-headers | awk 'NR==1{print $2}')/spring-services-deploy/cfmr-p-config-server:2.2.6

## Spring Cloud Eureka (Registry v2.1.3)
# Build Image - `docker build -t cfmr-p-registry:2.1.3 -f ubiDockerfile .`
# Run Image - `docker run -it -p 8761:8761 cfmr-p-registry:2.1.3`
# Tag the local Eureka Image
docker tag $(docker images | grep "cfmr-p-registry" | grep "2.1.3" | awk 'NR==1{print $3}') $(oc get routes -n openshift-image-registry --no-headers | awk '{print $2}')/spring-services-deploy/cfmr-p-registry:2.1.3
# Push the local Eureka Image
docker push $(oc get routes -n openshift-image-registry --no-headers | awk 'NR==1{print $2}')/spring-services-deploy/cfmr-p-registry:2.1.3

## MySQL (MariaDB 10.5.9)
# Build Image - Public Image.  `docker pull mariadb:10.5.9`
# Run Image - Public Image
# Tag the local MySQL Image
docker tag $(docker images | grep "mariadb" | grep "10.5.9" | awk 'NR==1{print $3}') $(oc get routes -n openshift-image-registry --no-headers | awk '{print $2}')/mysql-deploy/cfmr-p-mysql:10.5.9
# Push the local MySQL Image
docker push $(oc get routes -n openshift-image-registry --no-headers | awk 'NR==1{print $2}')/mysql-deploy/cfmr-p-mysql:10.5.9

## RabbitMQ 
# Build Image - Public Image. Pull via `docker pull rabbitmq:3.8.14-management`
# Run Image - Public Image
# TODO:   Look at override for image value in config - https://www.rabbitmq.com/kubernetes/operator/using-operator.html#override
# Tag the local RabbitMQ Image

# Install RabbitMQ Operator
# Options for RabbitMQ Operator Instances - https://www.rabbitmq.com/kubernetes/operator/using-operator.html
curl -s -L https://github.com/rabbitmq/cluster-operator/releases/download/v1.6.0/cluster-operator.yml | oc apply -f -
oc annotate --overwrite namespace rabbitmq-system "openshift.io/sa.scc.mcs=s0:c26,c5"
oc annotate --overwrite namespace rabbitmq-system "openshift.io/sa.scc.supplemental-groups=1000/1"
oc annotate --overwrite namespace rabbitmq-system "openshift.io/sa.scc.uid-range=1000/1"
# Question?  Is it better to curl and annotate OR download a hard copy, modify and lock it down?

# Push the local RabbitMQ Image
# TODO

## Redis (Redis 6.2.1)
# Build Image - Public Image.  `docker pull redis:6.2.1`
# Run Image - Public Image
# Tag the local Redis Image
docker tag $(docker images | grep "redis" | grep "6.2.1" | awk 'NR==1{print $3}') $(oc get routes -n openshift-image-registry --no-headers | awk '{print $2}')/redis-deploy/cfmr-p-redis:6.2.1
# Push the local Redis Image
docker push $(oc get routes -n openshift-image-registry --no-headers | awk 'NR==1{print $2}')/redis-deploy/cfmr-p-redis:6.2.1

## Redis Prometheus Exporter
# Build Image - Public Image. `docker pull oliver006/redis_exporter:v1.20.0-alpine`
# Run Image - Public Image
# Tag the local Redis Prom. Exporter Image
docker tag $(docker images | grep "redis_exporter" | grep "1.20.0-alpine" | awk 'NR==1{print $3}') $(oc get routes -n openshift-image-registry --no-headers | awk '{print $2}')/redis-deploy/cfmr-p-redis-exporter:1.20.0-alpine
# Push the local Redis Metrics Exporter Image
docker push $(oc get routes -n openshift-image-registry --no-headers | awk 'NR==1{print $2}')/redis-deploy/cfmr-p-redis-exporter:1.20.0-alpine

# Next Step is to roll out the CFMR Broker
# Let's check the imagestream is present in the namespace
oc get is -n cfmr-broker
# Looking for `image-registry.openshift-image-registry.svc:5000/cfmr-broker/cfmr-service-broker:1.0.0`

# Install the Couchbase Custom Resource Definitions Required by the broker
oc apply -f servicebroker.couchbase.com_servicebrokerconfigs.yaml

# Next install the Broker's Configuration.  This ideally should be done before the broker's deploy is completed.
# TODO:  Need to consider where to host icon images for the services.  Currently referring to a github url.
# Install the Config Yaml found in the repo under <repo>/ibm/doppelganger/broker-config.yaml

# This approach allows you to substitute the domain name for the environment within the config file dynamically
cat broker-config.yaml | sed 's/REPLACE_ME/'$(oc get configmap console-config -n openshift-console -o jsonpath='{.data.console-config\.yaml}' | grep consoleBaseAddress | awk '{print $2}' | cut -d"." -f2- | cut -d":" -f1)'/g' | sed 's/REPLACE_CUSTOM/your.custom.site/g' | oc apply -f -
# TODO:  CHANGE DEFAULT BROKER USERNAME:PASSWORD found within Secret YAML definition of broker.
# TODO:  Defaults:     username: username        password:  password


# Install the Broker Yaml found in the repo under <repo>/ibm/doppelganger/broker-deploy.yaml
oc apply -f broker-deploy.yaml
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

# Setup the Broker's Route
# This approach allows you to substitute the domain name for the environment within the route file dynamically
cat broker-route.yaml | sed 's/REPLACE_ME/'$(oc get configmap console-config -n openshift-console -o jsonpath='{.data.console-config\.yaml}' | grep consoleBaseAddress | awk '{print $2}' | cut -d"." -f2- | cut -d":" -f1)'/g' | oc create -f -

# Let's now Test that the catalog is working ok
curl -k -H "X-Broker-API-Version: 2.16" https://username:password@cfmr-service-broker-default.$(oc get configmap console-config -n openshift-console -o jsonpath='{.data.console-config\.yaml}' | grep consoleBaseAddress | awk '{print $2}' | cut -d"." -f2- | cut -d":" -f1)/v2/catalog

# Happy Response
#{"services":[{"name":"p-rabbitmq","id":"a4ee6be4-06d1-4b6f-822d-81199ae59c73",
#"description":"An open-source message-broker software using AMQP",  ...
#}

# Let's now test to see if we can see all the plans from the endpoint via the CF CLI
cf api https://api.cfmr.$(oc get route -n openshift-console --no-headers | awk '{print $2}' | cut -d"." -f2-) --skip-ssl-validation
cf auth admin $(oc get secrets var-cf-admin-password -n cfmr --template={{.data.password}} | base64 --decode)
cf create-org myorg && cf target -o myorg
cf create-space myspace && cf target -s myspace
cf target -o myorg -s myspace

# Let's register the broker
cf create-service-broker cfmr-broker username password https://cfmr-service-broker-default.$(oc get configmap console-config -n openshift-console -o jsonpath='{.data.console-config\.yaml}' | grep consoleBaseAddress | awk '{print $2}' | cut -d"." -f2- | cut -d":" -f1)

# NO TRAILING SLASH in the URL above. If you accidentally do use one, you will receive a "The service broker returned an invalid response. Status Code: 301 Moved Permanently, Body: Moved Permanently. response"

cf service-access -b cfmr-broker | grep none | awk '{print $1}' | xargs -L 1 -I {} cf enable-service-access {}

# Happy Response
#Enabling access to all plans of service p-rabbitmq for all orgs as admin...
#OK

#Enabling access to all plans of service p-rabbitmq for all orgs as admin...
#OK

#Enabling access to all plans of service p-redis for all orgs as admin...
#OK

#Enabling access to all plans of service p-service-registry for all orgs as admin...
#OK

#Enabling access to all plans of service p.config-server for all orgs as admin...
#OK

#Enabling access to all plans of service p.mysql for all orgs as admin...
#OK

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

# Let's now test instantiating all of them and verifying that all plans will run

cf create-service p-redis small-cache redis-test
cf create-service p.mysql db-small mysql-test
cf create-service p-rabbitmq single rabbitmq-sing-test
cf create-service p-rabbitmq standard rabbitmq-std-test
cf create-service p-service-registry standard registry-test
cf create-service p.config-server standard config-server-test -c '{ "git": { "uri": "https://github.com/spring-cloud-services-samples/cook-config.git", "label": "master"  } }'

# TODO:  Need to figure out consistent naming scheme for using dots vs hyphens

# Let's snoop from the CF API side
cf services

# Let's snoop from the openshift side to make sure the broker is doing its job
watch -n 15 "oc get pods,secrets -n redis-deploy && oc get pods -n mysql-deploy && oc get pods -n rabbitmq-deploy && oc get pods -n spring-services-deploy && oc get pods -n cfmr-broker"

oc get pods -n redis-deploy
oc get pods -n mysql-deploy
oc get pods -n rabbitmq-deploy
oc get pods -n spring-services-deploy

# Happy Response
#NAME                 READY   STATUS    RESTARTS   AGE
#p-redis-t1sedqjw-0   2/2     Running   0          5h17m
#NAME                                READY   STATUS    RESTARTS   AGE
#p-mysql-l4qm6mgw-6bf7b6b669-mdjx7   1/1     Running   0          5h25m
#NAME                           READY   STATUS    RESTARTS   AGE
#p-rabbitmq-e1233ask-server-0   1/1     Running   1          4h25m
#p-rabbitmq-e1233ask-server-1   1/1     Running   0          4h25m
#p-rabbitmq-e1233ask-server-2   1/1     Running   1          4h25m
#p-rabbitmq-tn5uz8e8-server-0   1/1     Running   0          4h25m
#NAME                                        READY   STATUS    RESTARTS   AGE
#p-config-server-536o20gi-8458cfc7b4-p9g8g   1/1     Running   1          4h23m
#p-config-server-536o20gi-8458cfc7b4-wfwsm   1/1     Running   0          4h23m
#p-service-registry-7oi03t36-0               1/1     Running   0          4h1m
#p-service-registry-7oi03t36-1               1/1     Running   0          4h1m
#p-service-registry-7oi03t36-2               1/1     Running   0          4h

# Test Config Server
curl $(oc get route -n spring-services-deploy --no-headers | grep 'config' | awk '{print $2}')/default/production

# TODO: After this result, the next step is to generate service-keys for all provisioned services and validate their JSON payload.

cf create-service-key config-server-test test-key
cf create-service-key mysql-test test-key
cf create-service-key rabbitmq-sing-test test-key
cf create-service-key rabbitmq-std-test test-key
cf create-service-key redis-test test-key
cf create-service-key registry-test test-key

# Lets looks at the JSON credentials now and make sure the key structure is right.  This may be easier using Schemas to validate ...
# but this is a visually easy quick and dirty that the keys look right.
# You can change the jq statement to a simpler form of "jq ." if you'd like to compare to raw JSON snippets which include values

cf service-key config-server-test test-key | awk 'NR > 2 { print }' | jq 'select(objects)|=[.] | map( paths(scalars) ) | map( map(select(numbers)="[]") | join(".")) | unique'
cf service-key mysql-test test-key | awk 'NR > 2 { print }' |jq 'select(objects)|=[.] | map( paths(scalars) ) | map( map(select(numbers)="[]") | join(".")) | unique' 
cf service-key rabbitmq-sing-test test-key | awk 'NR > 2 { print }' | jq 'select(objects)|=[.] | map( paths(scalars) ) | map( map(select(numbers)="[]") | join(".")) | unique' 
cf service-key rabbitmq-std-test test-key | awk 'NR > 2 { print }' | jq 'select(objects)|=[.] | map( paths(scalars) ) | map( map(select(numbers)="[]") | join(".")) | unique'
cf service-key redis-test test-key | awk 'NR > 2 { print }' | jq 'select(objects)|=[.] | map( paths(scalars) ) | map( map(select(numbers)="[]") | join(".")) | unique'
cf service-key registry-test test-key | awk 'NR > 2 { print }' | jq 'select(objects)|=[.] | map( paths(scalars) ) | map( map(select(numbers)="[]") | join(".")) | unique'

# Happy Response
#[
#  "access_token_uri",
#  "client_id",
#  "client_secret",
#  "uri"
#]
#[
#  "hostname",
#  "jdbcUrl",
#  "name",
#  "password",
#  "port",
#  "rootpassword",
#  "uri",
#  "username"
#]
#[
#  "dashboard_url",
#  "hostname",
#  "hostnames.[]",
#  "http_api_uri",
#  "http_api_uris.[]",
#  "password",
#  "protocols.amqp.host",
#  "protocols.amqp.hosts.[]",
#  "protocols.amqp.password",
#  "protocols.amqp.port",
#  "protocols.amqp.uri",
#  "protocols.amqp.uris.[]",
#  "protocols.amqp.username",
#  "protocols.amqp.vhost",
#  "protocols.management.host",
#  "protocols.management.hosts.[]",
#  "protocols.management.password",
#  "protocols.management.path",
#  "protocols.management.port",
#  "protocols.management.uri",
#  "protocols.management.uris.[]",
#  "protocols.management.username",
#  "uri",
#  "uris.[]",
#  "username",
#  "vhost"
#]
#[
#  "dashboard_url",
#  "hostname",
#  "hostnames.[]",
#  "http_api_uri",
#  "http_api_uris.[]",
#  "password",
#  "protocols.amqp.host",
#  "protocols.amqp.hosts.[]",
#  "protocols.amqp.password",
#  "protocols.amqp.port",
#  "protocols.amqp.uri",
#  "protocols.amqp.uris.[]",
#  "protocols.amqp.username",
#  "protocols.amqp.vhost",
#  "protocols.management.host",
#  "protocols.management.hosts.[]",
#  "protocols.management.password",
#  "protocols.management.path",
#  "protocols.management.port",
#  "protocols.management.uri",
#  "protocols.management.uris.[]",
#  "protocols.management.username",
#  "uri",
#  "uris.[]",
#  "username",
#  "vhost"
#]
#[
#  "host",
#  "password",
#  "port"
#]
#[
#  "access_token_uri",
#  "client_id",
#  "client_secret",
#  "uri"
#]

#  TODO: Future - We have different compelling (old, rather ancient apps untouched in years) lift-and-shift that
#  can be used to bind with these services to validate their behavior and VCAP structure further.

#  RabbitMQ:        https://github.com/rabbitmq/rabbitmq-perf-test-for-cf
#  Redis:           https://github.com/komushi/cf-redis-commander
#  Redis:           https://github.com/pivotal-cf/cf-redis-example-app
#  MySQL:           https://github.com/cloudfoundry-samples/cf-ex-phpmyadmin
#  MySQL:           https://github.com/pivotal-cf/PivotalMySQLWeb
#  SpringConfig:    https://github.com/spring-cloud-services-samples/cook
#  SpringConfig:    https://github.com/spring-cloud-services-samples/cook-config
#  Registry:        https://github.com/vicsz/eureka-pcf-example
#  Registry:        https://medium.com/@fede.lopez/service-discovery-in-pivotal-cloud-foundry-d1c81f5ade59


echo -e "Done.  Celebrate.  ${beers}"
