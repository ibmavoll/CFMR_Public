### Broker Files and Guidance

Collection of configuration files, snippets and commands to help with fine tuning of the broker configuration.

Setup for Config Server ...

```
uaac target https://uaa.your.custom.domain
uaac token client get admin -s $(oc get secrets var-uaa-admin-client-secret -n cfmr --template={{.data.password}} | base64 --decode)
uaac -t curl -k -X POST -H "Content-Type:application/json" -H "Accept:application/json" --data '{ "id":"SpringCloudServices", "subdomain":"p-spring-cloud-services", "name":"SpringCloudServices", "version":0, "description":"Default Zone for Spring Cloud Services [p-spring-cloud-services]."}' /identity-zones

# Adding admin to Identity Zone
uaac -t curl -k -H "X-Identity-Zone-Id:SpringCloudServices" -X POST -H "Content-Type:application/json" -H"Accept:application/json" --data '{ "client_id" : "admin", "client_secret" :"'$(oc get secrets var-uaa-admin-client-secret -n cfmr --template={{.data.password}} | base64 --decode)'", "scope" : ["uaa.none"], "resource_ids" : ["none"], "authorities" : ["uaa.admin","clients.read","clients.write","clients.secret","scim.read","scim.write","clients.admin","password.write"], "authorized_grant_types" : ["client_credentials"]}' /oauth/clients

uaac target https://p-spring-cloud-services.uaa.your.custom.domain
uaac token client get admin -s $(oc get secrets var-uaa-admin-client-secret -n cfmr --template={{.data.password}} | base64 --decode)
uaac client add "p-spring-cloud-services-worker" --name "p-spring-cloud-services-worker" --authorized-grant-types client_credentials --access_token_validity 43200 --authorities clients.read,clients.write,uaa.admin --secret "DWiPkHI83ZVg"
```
