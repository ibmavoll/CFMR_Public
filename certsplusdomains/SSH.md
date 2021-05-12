### Ensuring Proper CF SSH Access

##### Step 1:  Validate that the `eirinix-ssh-proxy` service has a proper External IP defined.  

```
▶ oc get svc eirinix-ssh-proxy -n cfmr
NAME                TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)          AGE
eirinix-ssh-proxy   LoadBalancer   172.21.66.40   169.11.117.108   2222:30088/TCP   7d5h
```

If it is in a state of pending, this needs to be resolved/fixed.

###### Tip 1:  Inspect existing configuration/YAMLs of successfully configured LoadBalancers within the cluster.  A good usual suspect to learn from is:  `oc -n openshift-ingress get svc router-default -o yaml` and look at the `spec` section of the output.  This should give you a close blueprint for what tweaks are needed within the `eirinix-ssh-proxy` service YAML definition to resolve the `pending` state.

##### Step 2:  Map an A-Record or CNAME for the `ssh` subdomain (e.g. `ssh.your.cfmr.domain`) to the provided EXTERNAL-IP/FQDN

```
▶ nslookup ssh.your.cfmr.domain
Server:		2600:1700:ba0:c190::1
Address:	2600:1700:ba0:c190::1#53

Non-authoritative answer:
Name:	ssh.your.cfmr.domain
Address: 169.11.117.108
```

##### Step 3:  Profit

```
▶ cf ssh frontend
vcap@frontend-myspace-8598170858-0:/$ whoami
vcap
vcap@frontend-myspace-8598170858-0:/$ echo $VCAP_SERVICES
{}
vcap@frontend-myspace-8598170858-0:/$ echo $CF_INSTANCE_GUID
0541e3fd-3990-4f4c-961f-94b428587280
vcap@frontend-myspace-8598170858-0:/$ exit
exit
```  