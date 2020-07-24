# BGP test env

This was tested using a 5-node dev-scripts cluster with the following settings:

```
# MetalLB BGP IPv6 support has not merged
export IP_STACK=v4
export MASTER_DISK=50
export WORKER_DISK=50
# 4.6 is busted for bare metal IPI at the moment
export OPENSHIFT_RELEASE_STREAM="4.5"
```

Allow MetalLB to connect to the host via BGP:

```
sudo firewall-cmd --zone=libvirt --permanent --add-port=179/tcp
sudo firewall-cmd --zone=libvirt --add-port=179/tcp
```

Install MetalLB by applying the manifests and making the OpenShift specific adjustments:

* https://metallb.universe.tf/installation/#installation-by-manifest
* https://metallb.universe.tf/installation/clouds/#metallb-on-openshift-ocp

Run `frr` in a container along side the cluster.  The `frr` configs used
are in the `frr/` directory.  The container runs on the dev-scripts host with
host networking.

```
./frr.sh
```

Configure MetalLB with a configuration which enables the BGP speakers to peer
with our `frr` BGP router:

```
oc apply -f config.yaml
```

Observe that the BGP speakers have peered with our router:

```
$ sudo podman exec frr vtysh -c "show ip bgp summary"

IPv4 Unicast Summary:
BGP router identifier 192.168.122.1, local AS number 64512 vrf-id 0
BGP table version 1
RIB entries 1, using 192 bytes of memory
Peers 5, using 71 KiB of memory

Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt
192.168.111.20  4      64512        37        36        0    0    0 00:17:14            1        0
192.168.111.21  4      64512        37        36        0    0    0 00:17:14            1        0
192.168.111.22  4      64512        37        36        0    0    0 00:17:14            1        0
192.168.111.23  4      64512        37        36        0    0    0 00:17:14            1        0
192.168.111.24  4      64512        37        36        0    0    0 00:17:14            1        0

Total number of neighbors 5
```

Create an `nginx` Deployment and a corresponding Service LoadBalancer:

```
oc apply -f testsvc.yaml
```

Observe the IP address allocated to the Service by MetalLB:

```
$ oc get svc nginx
NAME    TYPE           CLUSTER-IP      EXTERNAL-IP    PORT(S)        AGE
nginx   LoadBalancer   172.30.74.128   192.168.10.0   80:31304/TCP   17m
```

Ensure a route to this Service has been published by the MetalLB BGP speaker:

```
$ sudo podman exec frr vtysh -c "show ip bgp detail"
BGP table version is 1, local router ID is 192.168.122.1, vrf id 0
Default local pref 100, local AS 64512
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete

   Network          Next Hop            Metric LocPrf Weight Path
*=i192.168.10.0/32  192.168.111.24                  0      0 ?
*=i                 192.168.111.23                  0      0 ?
*=i                 192.168.111.22                  0      0 ?
*=i                 192.168.111.21                  0      0 ?
*>i                 192.168.111.20                  0      0 ?

Displayed  1 routes and 5 total paths
```

Now validate that you can connect to the Service from the router:

```
$ echo "GET /" | nc 192.168.10.0 80
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```
