## Security - Kubernetes Security

Hello, and welcome to this lecture. In this lecture, we look at the security primitives in Kubernetes. Kubernetes being the go-to platform for hosting production-grade applications, security is of prime concern. In this lecture, we look at the various security primitives in Kubernetes at a high level before diving deeper into those in the upcoming lectures. 

Let's begin with the hosts that form the cluster itself. Of course, all access to these hosts must be secured, root access disabled, password-based authentication disabled, and only SSH key-based authentication to be made available. And of course, any other measures you need to take to secure your physical or virtual infrastructure that hosts Kubernetes. Of course, if that is compromised, everything is compromised. Our focus in this lecture is more on Kubernetes-related security. What are the risks? And what measures do you need to take to secure the cluster? As we have seen already, the kube API server is at the center of all operations within Kubernetes, we interact with it through the kubectl utility or by accessing the API directly. And through that you can perform almost any operation on the cluster. So that's the first line of defense, controlling access to the API server itself. 

We need to make two types of decisions, who can access the cluster? And what can they do? Who can access the API server is defined by the authentication mechanisms. There are different ways that you can authenticate to the API server, starting with user IDs and passwords stored in static files or tokens, certificates, or even an integration with external authentication providers like LDAP. Finally, for machines, we create service accounts. We will look at these in more detail in the upcoming lectures. Once they gain access to the cluster, what can they do is defined by authorization mechanisms. Authorization is implemented using role-based access controls, where users are associated to groups with specific permissions. In addition, there are other authorization modules like the attribute-based access control, node authorizers, webhooks, etc. Again, we look at these in more detail in the upcoming lectures. 

All communication with a cluster between the various components such as the etcd cluster, the kube controller manager, scheduler API server, as well as those running on the worker nodes such as the kubelet and the kube proxy is secured using TLS encryption. We have a section entirely for this where we discuss and practice how to set up certificates between the various components. What about communication between applications within the cluster? By default, all pods can access all other pods within the cluster. Now you can restrict access between them using network policies. We will look at how exactly that is done later in the network policies section. So that was a high-level overview of the various security primitives in Kubernetes.

## Authentication

Hello, and welcome to this lecture on authentication in a Kubernetes cluster. As we have seen already, the Kubernetes cluster consists of multiple nodes, physical or virtual, and various components that work together. You have users like administrators that access the cluster to perform administrative tasks, the developers that access the cluster to test or deploy applications, we have end users who access the applications deployed on the cluster. And we have third-party applications accessing the cluster for integration purposes. 

Throughout this section, we will discuss how to secure our cluster by securing the communication between internal components and securing management access to the cluster through authentication and authorization mechanisms. In this lecture, our focus is on securing access to the Kubernetes cluster with **authentication mechanisms**. So we talked about the different users that may be accessing the cluster security of end users who access the applications deployed on the cluster is managed by the applications themselves internally. So we will take them out of our discussion. 

Our focus is on users' access to the Kubernetes cluster for administrative purposes. So we are left with two types of users, humans, such as the administrators and developers, and robots such as other processes or services or applications that require access to the cluster. Kubernetes does not manage user accounts natively, it relies on an external source like a file with user details, or certificates or a third-party identity service like LDAP to manage these users. And so you cannot create users in a Kubernetes cluster or view the list of users like this. However, in case of service accounts, Kubernetes can manage them, you can create and manage service accounts using the Kubernetes API, we have a section on service accounts exclusively, where we discuss and practice more about service accounts. 

For this lecture, we will focus on users in Kubernetes, **all user access is managed by the API server**, whether you're accessing the cluster through kubectl tool, or the API directly, all of these requests go through the kube API server, the kube API server authenticates the request before processing it. 

So how does the kube API server authenticate, there are different authentication mechanisms that can be configured, **you can have a list of usernames and passwords in a static password file**, **or usernames and tokens in a static token file**. **Or you can authenticate using certificates.** **And another option is to connect to third-party authentication protocols, like LDAP, Kerberos, etc.**

Let's start with static password and token files, as it is the easiest to understand. Let's start with the simplest form of authentication, you can create a list of users and their passwords in a CSV file, and use that as the source for user information. The file has three columns, password, username, and user ID, we then pass the file name as an option to the kube API server. Remember the kube API server service and the various options we looked at earlier in this course, that is where you must specify this option, you must then restart the kube API server for these options to take effect. If you set up your cluster using the KubeADM tool, then you must modify the Kube API server pod definition file, the KubeADM tool will automatically restart the Kube API server. Once you update this file to authenticate using the basic credentials while accessing the API server, specify the user and password in a curl command like this. 

```bash
# user-details.csv
password123,user1,u0001
password123,user2,u0002
password123,user3,u0003
password123,user4,u0004
password123,user5,u0005
```

```bash
# kube-apiserver.service
ExecStart=/usr/local/bin/kube-apiserver \
--advertise-address=${INTERNAL_IP} \
--allow-privileged=true \
--apiserver-count=3 \
--authorization-mode=Node,RBAC \
--bind-address=0.0.0.0 \
--enable-swagger-ui=true \
--etcd-servers=https://127.0.0.1:2379 \
--event-ttl=1h \
--runtime-config=api/all \
--service-cluster-ip-range=10.32.0.0/24 \
--service-node-port-range=30000-32767 \
--v=2 \
--basic-auth-file=user-details.csv # <--
```

```yaml
# /etc/kubernetes/manifests/kube-apiserver.yaml
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  name: kube-apiserver
  namespace: kube-system
spec:
  containers:
    - command:
      - kube-apiserver
      - --authorization-mode=Node,RBAC
      - --advertise-address=172.17.0.107
      - --allow-privileged=true
      - --enable-admission-plugins=NodeRestriction
      - --enable-bootstrap-token-auth=true
      - --basic-auth-file=user-details.csv
    image: k8s.gcr.io/kube-apiserver-amd64:v1.11.3
    name: kube-apiserver
```

```bash
curl -v -k https://master-node-ip:6443/api/v1/pods -u "user1:password123"
```

In the CSV file with the user details that we saw, we can optionally have a fourth column with the group details to assign users to specific groups. Similarly, instead of a static password file, you can have a static token file here instead of password, you specify a token, pass the token file as an option token auth file to the kube API server. While authenticating specify the token as an authorization bearer token to your requests like this. 

```bash
# user-details.csv
password123,user1,u0001,group1
password123,user2,u0002,group1
password123,user3,u0003,group2
password123,user4,u0004,group2
password123,user5,u0005,group2

# user-token-details.csv
KpjCVB17rCFAHYPKBYTlZRo7gulCUc4B,user10,u0010,group1
rjncHMvtXHC6M1WQDdhtVNyyhqTdxSC,user11,u0011,group1
mjpOFlEiFOkl9toikaRNtt59eEPtczZSQ,user12,u0012,group2
PG41IXhs7QjqwWmBKvgGT9g1OYUqZij,user13,u0013,group2
```

```yaml
--token-auth-file=user-token-details.csv
```

```bash
curl -v -k https://master-node-ip:6443/api/v1/pods --header "Authorization: Bearer KpjCVB17rCFAHYPKBYTlZRo7gulCUc4B"
```

That's it for this lecture. Remember that this authentication mechanism that stores usernames, passwords and tokens in clear text in a static file is not a recommended approach as it is insecure. But I thought this was the easiest way to understand the basics of authentication in Kubernetes. Going forward, we will look at other authentication mechanisms. I also want to point out that if you are trying this out in a kubeadm setup, you must also consider volume mounts to pass in the auth file.

## TLS in Kubernetes - Certificate Creation

In this lecture, we'll look at how to generate the certificates for the cluster. To generate certificates, there are different tools available, such as EasyRSA, OpenSSL, or CFSSL, etc., or many others. In this lecture, we will use the OpenSSL tool to generate the certificates. This is where we left off, we will start with the CA certificates. First, we create a private key using the OpenSSL command, OpenSSL genrsa -out **CA.key**, then we use the OpenSSL request command along with the key we just created to generate a certificate signing request (**ca.csr**). The certificate signing request is like a certificate with all of your details, but with no signature. In the certificate signing request, we specify the name of the component this certificate is for in the common name or CN field. In this case, since we are creating a certificate for the Kubernetes CA, we name it Kubernetes-CA. Finally, we sign the certificate using the OpenSSL x509 command. And by specifying the certificate signing request we generated in the previous command. Since this is for the CA itself, it is self-signed by the CA using its own private key that it generated in the first step(**ca.crt**). Going forward, for all other certificates, we will use the CA key pair to sign them. The CA now has its private key and root certificate file. 

```bash
$ openssl genrsa -out ca.key 2048
$ openssl req -new -key ca.key -subj "/CN=Kubernetes-CA" -out ca.csr
$ openssl x509 -req -in ca.csr -signkey ca.key -out ca.crt
```

Let's now look at generating the client certificates. We start with the admin user, we follow the same process where we create a private key for the admin user using the OpenSSL command, we then generate a CSR and that is where we specify the name of the admin user which is kube admin. A quick note about the name. It doesn't really have to be kube-admin. It could be anything. But remember, this is the name that kubectl client authenticates with and when you run the kubectl command. So in the audit logs and elsewhere, this is the name that you will see. So provide a relevant name in this field. Finally generate a signed certificate using the OpenSSL x509 command. But this time you specify the CA certificate and the CA key you're signing your certificate with the CA key pair. That makes this a valid certificate within your cluster. The signed certificate is then output to admin.crt file. That is the certificate that the admin user will use to authenticate to Kubernetes cluster. If you look at it, this whole process of generating a key and a certificate pair is similar to creating a user account for a new user. The certificate is the validated user ID and the key is like the password. It's just that it's much more secure than a simple username and password. So this is for the admin user. 

```bash
$ openssl genrsa -out admin.key 2048
$ openssl req -new -key admin.key -subj "/CN=kube-admin" -out admin.csr
$ openssl x509 -req -in admin.csr -CA ca.crt -CAkey ca.key -out admin.crt
```

How do you differentiate this user from any other users, the user account needs to be identified as an admin user, and not just another basic user. You do that by adding the group details for the user in the certificate. In this case, a group named **system:masters** exists on Kubernetes with administrative privileges. We will discuss about groups later. But for now, it's important to know that you must mention this information in your certificate signing request. You can do this by adding group details with the OU parameter while generating a certificate signing request. Once it's signed, we now have our certificate for the admin user with admin privileges. We follow the same process to generate client certificates for all other components that access the kube API server, the kube scheduler. 

```bash
$ openssl genrsa -out admin.key 2048
$ openssl req -new -key admin.key -subj "/CN=kube-admin/O=system-masters" -out admin.csr
$ openssl x509 -req -in admin.csr -CA ca.crt -CAkey ca.key -out admin.crt
```

Now the kube scheduler is a system component part of the Kubernetes control plane. So its name must be prefixed with the keyword system. The same with kube controller manager, it is again a system component. So its name must be prefixed with the keyword system. And finally, kube proxy. So far, we have created CA certificates, then all of the client certificates, including the admin user, scheduler, controller manager and kube proxy, we will follow the same procedure to create the remaining three client certificates for API servers and kubelets when we create the server certificates for them. So we will set them aside for now. 

```bash
$ openssl genrsa -out scheduler.key 2048
$ openssl req -new -key scheduler.key -subj "/CN=system:kube-scheduler/O=system-scheduler" -out scheduler.csr
$ openssl x509 -req -in scheduler.csr -CA ca.crt -CAkey ca.key -out scheduler.crt
```

```bash
$ openssl genrsa -out controller-manager.key 2048
$ openssl req -new -key controller-manager.key -subj "/CN=system:kube-controller-manager/O=system-controller-manager" -out controller-manager.csr
$ openssl x509 -req -in controller-manager.csr -CA ca.crt -CAkey ca.key -out controller-manager.crt
```

```bash
$ openssl genrsa -out kube-proxy.key 2048
$ openssl req -new -key kube-proxy.key -subj "/CN=system:kube-proxy/O=system-kube-proxy" -out kube-proxy.csr
$ openssl x509 -req -in kube-proxy.csr -CA ca.crt -CAkey ca.key -out kube-proxy.crt
```

Now what do you do with these certificates, take the admin certificate, for instance, to manage the cluster, you can use this certificate instead of a username and password in a REST API call you make to the kube API server, you specify the key, the certificate and the CA certificate as options. That's one simple way. The other way is to move all of these parameters into a configuration file called **KubeConfig** within that specify the API server endpoint details, the certificates to use, etc. That is what most of the Kubernetes clients use. We will look at KubeConfig in depth in one of the upcoming lectures. 

```bash
curl https://kube-apiserver:6443/api/v1/pods \
--key admin.key --cert admin.crt \
--cacert ca.crt
```

```yaml
# kube-config.yaml
apiVersion: v1
clusters:
- cluster:
certificate-authority: ca.crt
server: https://kube-apiserver:6443
name: kubernetes
kind: Config
users:
- name: kubernetes-admin
user:
client-certificate: admin.crt
client-key: admin.key
```

Okay, so we're now left with the server side certificates. But before we proceed, one more thing. Remember, in the prerequisite lecture, we mentioned that for clients to validate the certificate sent by the server, and vice versa, they all need a copy of the certificate authorities public certificate, the one that we said is already installed within the user's browsers in case of a web application. Similarly, in Kubernetes for these various components to verify each other, they all need a copy of the CA root certificate. So whenever you configure a server or a client with certificates, you will need to specify the CA root certificate as well. 

Let's look at the server-side certificates. Now, let's start with the etcd server, we follow the same procedure as before to generate a certificate for etcd, we will name it etcd-server etcd server can be deployed as a cluster across multiple servers as in a high-availability environment. In that case, to secure communication between the different members in the cluster, we must generate additional peer certificates. Once the certificates are generated, specify them while starting the etcd server. There are key and cert file options where you specify the etcd server keys. There are other options available for specifying the peer certificates. And finally, as we discussed earlier, it requires the CA root certificate to verify that the clients connecting to the etcd server are valid. 

```bash
$ openssl genrsa -out etcdserver.key 2048
$ openssl req -new -key etcdserver.key -subj "/CN=etcdserver" -out etcdserver.csr
$ openssl x509 -req -in etcdserver.csr -CA ca.crt -CAkey ca.key -out etcdserver.crt
```

```bash
$ openssl genrsa -out etcdpeer1.key 2048
$ openssl req -new -key etcdpeer1.key -subj "/CN=etcd-peer" -out etcdpeer1.csr
$ openssl x509 -req -in etcdpeer1.csr -CA ca.crt -CAkey ca.key -out etcdpeer1.crt
```
```bash
$ openssl genrsa -out etcdpeer2.key 2048
$ openssl req -new -key etcdpeer2.key -subj "/CN=etcd-peer" -out etcdpeer2.csr
$ openssl x509 -req -in etcdpeer2.csr -CA ca.crt -CAkey ca.key -out etcdpeer2.crt
```

```bash
# cat /etc/systemd/system/etcd.service or /etc/kubernetes/manifests/etcd.yaml 
etcd
--advertise-client-urls=https://127.0.0.1:2379
--key-file=/path-to-certs/etcdserver.key
--cert-file=/path-to-certs/etcdserver.crt
--client-cert-auth=true
--data-dir=/var/lib/etcd
--initial-advertise-peer-urls=https://127.0.0.1:2380
--initial-cluster=master=https://127.0.0.1:2380
--listen-client-urls=https://127.0.0.1:2379
--listen-peer-urls=https://127.0.0.1:2380
--name=master
--peer-cert-file=/path-to-certs/etcdpeer1.crt
--peer-client-cert-auth=true
--peer-key-file=/etc/kubernetes/pki/etcd/peer.key
--peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
--snapshot-count=10000
--trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
```

Let's talk about the kube-apiserver. Now, we generate a certificate for the API server like before. But wait, the API server is the most popular of all components within the cluster. Everyone talks to the kube-apiserver, every operation goes through the kube API server, anything moves within the cluster, the API server knows about it, you need information, you talk to the API server. And so it goes by many names and aliases within the cluster. Its real name is kube-apiserver. But some call it Kubernetes. Because for a lot of people who don't really know what goes under the hood of Kubernetes, the kube-apiserver is Kubernetes. Others like to call it **Kubernetes.default**, while some refer to it as **Kubernetes.default.svc.** And some like to call it by its full name, **Kubernetes.default.svc.cluster.local.** Finally, it is also referred to in some places simply by its IP address, the IP address of the host running the Kube API server, or the pod running it. So all of these names must be present in the certificate generated for the Kube API server. Only then those referring to the Kube API server by these names will be able to establish a valid connection. So we use the same set of commands as earlier to generate a key. In the certificate signing request, you specify the name kube-apiserver. But how do you specify all the alternate names for that you must create an OpenSSL config file, create an OpenSSL.cnf file and specify the alternate names in the alt names section of the file include all the DNS names the API server goes by, as well as the IP address. Pass this config file as an option while generating the certificate signing request. Finally sign the certificate using the CA certificate and key you then have the kube API server certificate, it is time to look at where we are going to specify these keys. Remember to consider the API client certificates that are used by the API server while communicating as a client to the etcd and kubelet servers. The location of these certificates are passed into the kube API server's executable or service configuration file. First, the CA file needs to be passed in. Remember, every component needs to see a certificate to verify its clients. Then we provide the API server certificates under the TLS cert options. We then specify the client certificates used by kube API server to connect to the etcd server, again with the CA file. And finally, the kube API server client certificates to connect to the kubelets. 

```bash
$ openssl genrsa -out apiserver.key 2048
$ openssl req -new -key apiserver.key -subj "/CN=kube-apiserver" -out apiserver.csr
```

```bash
# openssl.cnf
[ req ]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation,
subjectAltName = @alt_names

[alt_names]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster.local
IP.1 = 10.96.0.1
IP.2 = 172.17.0.87
```

```bash
$ openssl x509 -req -in apiserver.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out apiserver.crt -extensions v3_req -extfile openssl.cnf -days 1000
```

```bash
# cat /etc/systemd/system/etcd.service or /etc/kubernetes/manifests/etcd.yaml 
kube-apiserver
--advertise-address=172.17.0.87
--allow-privileged=true
--authorization-mode=Node,RBAC
--client-ca-file=/etc/kubernetes/pki/ca.crt
--enable-admission-plugins=NodeRestriction,NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota
--enable-swagger-ui=true
--etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt
--etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt
--etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key
--etcd-servers=https://127.0.0.1:2379
--kubelet-client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt
--kubelet-client-key=/etc/kubernetes/pki/apiserver-kubelet-client.key
--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
--secure-port=6443
--service-account-key-file=/etc/kubernetes/pki/sa.pub
--service-cluster-ip-range=10.96.0.0/12
--tls-cert-file=/etc/kubernetes/pki/apiserver.crt
--tls-private-key-file=/etc/kubernetes/pki/apiserver.key
```

Next comes the kubelet server. The kubelet server is an HTTPS API server that runs on each node responsible for managing the node. That's who the API server talks to, to monitor the node as well as send information regarding what pods to schedule on this node. As such, you need a key certificate pair for each node in the cluster. Now what do you name these certificates? Are they all going to be named kubelets? No, they will be named after their nodes, node 01, node and node 03. Once the certificates are created, use them in the kubelet config file. As always, you specify the root CA certificate and then provide the kubelet node certificates. You must do this for each node in the cluster. We also talked about a set of client certificates that will be used by the kubelet to communicate with a kube API server. These are used by the kubelet to authenticate into the kube API server. They need to be generated as well. What do you name these certificates, the API server needs to know which node is authenticating and give it the right set of permissions. So it requires the nodes to have the right names in the right formats. Since the nodes are system components like the kube scheduler and the controller manager we talked about earlier, the format starts with the system keyword, followed by node and then the node name. In this case, node to node 03. And how would the API server give it the right set of permissions. Remember, we specified a group name for the admin user. So the admin user gets administrative privileges. Similarly, the nodes must be added to a group named system nodes. Once the certificates are generated, they go into the KubeConfig files as we discussed earlier.

```bash
$ openssl genrsa -out kubelet.key 2048
$ openssl req -new -key kubelet.key -subj "/CN=kubelet" -out kubelet.csr
$ openssl x509 -req -in kubelet.csr -CA ca.crt -CAkey ca.key -out kubelet.crt
```

```bash
$ openssl genrsa -out kubelet-node01.key 2048
$ openssl req -new -key kubelet-node01.key -subj "/CN=kubelet-node01" -out kubelet-node01.csr
$ openssl x509 -req -in kubelet-node01.csr -CA ca.crt -CAkey ca.key -out kubelet-node01.crt

$ openssl genrsa -out kubelet-node02.key 2048
$ openssl req -new -key kubelet-node02.key -subj "/CN=kubelet-node02" -out kubelet-node02.csr
$ openssl x509 -req -in kubelet-node02.csr -CA ca.crt -CAkey ca.key -out kubelet-node02.crt

$ openssl genrsa -out kubelet-node03.key 2048
$ openssl req -new -key kubelet-node03.key -subj "/CN=kubelet-node03" -out kubelet-node03.csr
$ openssl x509 -req -in kubelet-node03.csr -CA ca.crt -CAkey ca.key -out kubelet-node03.crt
```

```bash
# kubelet-config.yaml (node01)
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "${POD_CIDR}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/kubelet-node01.crt"
tlsPrivateKeyFile: "/var/lib/kubelet/kubelet-node01.key"
```

```bash
$ openssl genrsa -out kubelet-client.key 2048
$ openssl req -new -key kubelet-client.key -subj "/CN=kubelet-client" -out kubelet-client.csr
$ openssl x509 -req -in kubelet-client.csr -CA ca.crt -CAkey ca.key -out kubelet-client.crt
```

```bash
$ openssl genrsa -out kubelet-node01.key 2048
$ openssl req -new -key kubelet-node01.key -subj "/CN=system:node:node01/O=system:nodes" -out kubelet-node01.csr
$ openssl x509 -req -in kubelet-node01.csr -CA ca.crt -CAkey ca.key -out kubelet-node01.crt

$ openssl genrsa -out kubelet-node02.key 2048
$ openssl req -new -key kubelet-node02.key -subj "/CN=system:node:node02/O=system:nodes" -out kubelet-node02.csr
$ openssl x509 -req -in kubelet-node02.csr -CA ca.crt -CAkey ca.key -out kubelet-node02.crt

$ openssl genrsa -out kubelet-node03.key 2048
$ openssl req -new -key kubelet-node03.key -subj "/CN=system:node:node03/O=system:nodes" -out kubelet-node03.csr
$ openssl x509 -req -in kubelet-node03.csr -CA ca.crt -CAkey ca.key -out kubelet-node03.crt
```

## Kubeconfig

Hello, and welcome to this lecture. In this lecture, we look at KubeConfigs in Kubernetes. So far, we have seen how to generate a certificate for a user. We've seen how a client uses the certificate file and key to query the Kubernetes REST API for a list of pods using curl. In this case, my cluster is called my Kube playground. So send a curl request to the address of the Kubernetes API server, while passing in the pair of files along with the CA certificate as options. This is then validated by the API server to authenticate the user. 

```bash
$ curl https://my-kube-playground:6443/api/v1/pods \
--key admin.key \
--cert admin.crt \
--cacert ca.crt
```

Now, how do you do that while using the kubectl command, you can specify the same information using the options server, client key, client certificate, and certificate authority with the kubectl utility. 

```bash
$ kubectl get pods \
--server my-kube-playground:6443 \
--client-key admin.key \
--client-certificate admin.crt \
--certificate-authority ca.crt
```

Obviously, typing those in every time is a tedious task. So you move this information to a configuration file called as kubeconfig, and then specify this file as the kubeconfig option in your command. By default, the kubectl tool looks for a file named config under a directory .kube under the user's home directory. So if you create the kubeconfig file there, you don't have to specify the paths to the file explicitly in the kubectl command. That's the reason you haven't been specifying any options for your kubectl commands so far. The kubeconfig file is in a specific format. Let's take a look at that. The config file has three sections, clusters, users and contexts. 

Clusters are the various Kubernetes clusters that you need access to. So you have multiple clusters for development environment, or testing environment or prod, or for different organizations or on different cloud providers, etc. All those go there. 

Users are the user accounts with which you have access to these clusters. For example, the admin user, a dev user, a prod user, etc. These users may have different privileges on different clusters. 

Finally, contexts marry these together. Contexts define which user account will be used to access which cluster. For example, you could create a context named admin at production that will use the admin account to access a production cluster. Or I may want to access the cluster I've set up on Google with the dev user's credentials to test deploying the application I built. Remember, you're not creating any new users or configuring any kind of user access or authorization in the cluster. With this process, you're using existing users with their existing privileges and defining what user you're going to use to access what cluster. That way, you don't have to specify the user certificates and server address in each and every kubectl command you run. 

So how does it fit into our example, the server specification in our command goes into the cluster section, the admin user's keys and certificates go into the user section, you then create a context that specifies to use the my kube admin user to access the my kube playground cluster. Let's look at a real kubeconfig file. Now, the kubeconfig file is in a YAML format, it has API version set to v1, the kind is Config. And then it has three sections as we discussed, one for clusters, one for contexts, and one for users. Each of these is in an array format. That way, you can specify multiple clusters, users or contexts within the same file. Under clusters, we add a new item for our kube playground cluster, we name it my kube playground and specify the server address under the server field. It also requires the certificate of the certificate authority, we can then add an entry into the user section to specify details of my kube admin user provide the location of the client certificate and key pair. So we have now defined the cluster and the user to access the cluster. Next, we create an entry under the context section to link the two together. We will name the context my kube admin at my kube playground, we will then specify the same name we used for cluster and user. Follow the same procedure to add all the clusters you daily access the user credentials you use to access them as well as the context. Once the file is ready, remember that you don't have to create any object like you usually do for other Kubernetes objects. The file is left as is, and is read by the kubectl command and the required values are used. 

Now how does kubectl know which context to choose from? We've defined three contexts here, which one should start with, you can specify the default context to use by adding a field current context to the kubeconfig file, specify the name of the context to use in this case, kubectl will always use the context dev user at Google to access the Google clusters using the dev user's credentials. 

```yaml
apiVersion: v1
kind: Config
currentContext: dev-user@google
clusters:
  - name: my-kube-playground (values hidden...)
  - name: development
  - name: production
  - name: google

contexts:
  - name: my-kube-admin@my-kube-playground
  - name: dev-user@google
  - name: prod-user@production

users:
  - name: my-kube-admin
  - name: admin
  - name: dev-user
  - name: prod-user
```

There are command line options available within kubectl to view and modify the kubeconfig files. To view the current file being used, run the kubectl config view command. It lists the clusters context and users as well as the current context that is set. As we discussed earlier, if you do not specify which kubeconfig file to use, it ends up using the default file located in the folder .kube in the user's home directory. Alternatively, you can specify a kubeconfig file by passing the kube config option in the command line like this. We will move our custom config to the home directory. So this becomes our default config file. So how do you update your current context? So you've been using my kubectl admin user to access my Kube playground. How do you change the context to use prod user to access the production cluster from the kubectl config use-context command to change the current context to the prod user at production context. This can be seen in the current context field in the file. So yes, the changes made by kubectl config command actually reflect in the file. You can make other changes in the file, update or delete items in it using other variations of the kubectl config command. Check them out when you get time. 

```bash
$ kubectl get view
$ kubectl get view --kubeconfig=my-custom-config
```

```bash
kubectl config use-context prod-user@production
```

What about namespaces? For example, each cluster may be configured with multiple namespaces within it. Can you configure a context to switch to a particular namespace? Yes. The context section in the KubeConfig file can take an additional field called namespace where you can specify a particular namespace. This way, when you switch to that context, you will automatically be in a specific namespace. 

```yaml
apiVersion: v1
kind: Config
clusters:
  - name: production
    cluster:
      certificate-authority: ca.crt
      server: https://172.17.0.51:6443
contexts:
  - name: admin@production
    context:
      cluster: production
      user: admin
      namespace: finance
users:
  - name: admin
    user:
      client-certificate: admin.crt
      client-key: admin.key
```

Finally, a word on certificates. You have seen paths to certificate files mentioned in KubeConfig like this. Well, it's better to use the full path like this. But remember, there's also another way to specify the certificate credentials. Let's look at the first one for instance, where we configure the path to the certificate authority. We have the contents of the ca.crt file on the right. Instead of using the certificate authority field and the path to the file, you may optionally use the certificate authority data field and provide the contents of the certificate itself. But not the file as is; convert the contents to a base64 encoded format, and then pass that in. Similarly, if you see a file with the certificates data in the encoded format, use the base64 decode option to decode the certificate.

## API Groups

Before we head into authorization, it is necessary to understand about API groups in Kubernetes. But first, what is the Kubernetes API? We learned about the Kube API server; whatever operations we have done so far with the cluster, we've been interacting with the API server one way or the other, either through the Kube control utility or directly via REST. Say we want to check the version, we can access the API server at the master node's address followed by the port, which is by default, and the API version; it returns the version. Similarly, to get a list of pods, you would access the URL API/v1/pods. Our focus in this lecture is about these API pods, the version, and the API. The Kubernetes API is grouped into multiple such groups based on their purpose, such as one for APIs, one for health, one for metrics and logs, etc. The version API is for viewing the version of the cluster. As we just saw, the metrics and health API are used to monitor the health of the cluster. The logs are used for integrating with third-party logging applications. In this video, we will focus on the APIs responsible for the cluster functionality. These APIs are categorized into two, the core group and the named group. 

The core group is where all core functionality exists. Such as namespaces, pods, replication controllers, events and endpoints, nodes, bindings, persistent volumes, persistent volume claims, config maps, secrets, services, etc. 

The named group APIs are more organized. And going forward, all the newer features are going to be made available through these named groups. It has groups under it for apps, extensions, networking, storage, authentication, authorization, etc. Shown here are just a few. Within apps, you have deployments, replica sets, stateful sets. Within networking, you have network policies. Certificates have the certificate signing requests that we talked about earlier in the section. So the ones at the top are API groups, and the ones at the bottom are resources in those groups. Each resource in this has a set of actions associated with them. Things that you can do with these resources, such as list the deployments, get information about one of these deployments, create a deployment, delete a deployment, update a deployment, watch a deployment, etc. These are known as verbs. The Kubernetes API reference page can tell you what the API group is for each object, select an object, and the first section in the documentation page shows its group details. v1 core is just v1. You can also view these on your Kubernetes cluster, access your Kube API server at port without any path, and it will list you the available API groups. And then within the named API groups, it returns all the supported resource groups. 

A quick note on accessing the cluster API like that. If you were to access the API directly through curl, as shown here, then you will not be allowed access except for certain APIs like version, as you have not specified any authentication mechanisms. So you have to authenticate to the API using your certificate files by passing them in the command line like this. An alternate option is to start a kubectl proxy client. The kubectl proxy command launches a proxy service locally on port and uses credentials and certificates from your kubeconfig file to access the cluster. That way, you don't have to specify those in the curl command. Now you can access the kubectl proxy service at port 8001. And the proxy will use the credentials from kubeconfig file to forward your request to the kube API server. This will list all available APIs at root. 

So here are two terms that kind of sound the same. The kube proxy and kubectl proxy. Well, they're not the same. We discussed kube proxy earlier in this course is used to enable connectivity between pods and services across different nodes in the cluster. We discussed kube proxy in much more detail later in this course, whereas kubectl proxy is an HTTP proxy service created by kubectl utility to access the kube API server. So what to take away from this, all resources in Kubernetes are grouped into different API groups. At the top level, you have the core API group and named API group under the named API group, you have one for each section. Under these API groups, you have the different resources. And each resource has a set of associated actions known as verbs. In the next section on authorization, we can see how we use these to allow or deny access to users.

## Authorization

So far we talked about authentication. We saw how someone can gain access to a cluster. We saw different ways that someone, a human or a machine, can get access to the cluster. Once they gain access, what can they do? That's what authorization defines. First of all, why do you need authorization in your cluster? As an administrator of the cluster, we were able to perform all sorts of operations in it, such as viewing various objects like pods and nodes and deployments, creating or deleting objects, such as adding or deleting pods or even nodes in the cluster. As an admin, we're able to perform any operation, but soon we will have others accessing the cluster as well, such as the other administrators, developers, testers, or other applications like monitoring applications or continuous delivery applications like Jenkins, etc. So we will be creating accounts for them to access the cluster by creating usernames and passwords or tokens or signed TLS certificates or Service Accounts as we saw in the previous lectures. But we don't want all of them to have the same level of access as us. For example, we don't want the developers to have access to modify our cluster configuration like adding or deleting nodes or the storage or networking configurations. We can allow them to view but not modify, but they could have access to deploying applications. The same goes with Service Accounts. We only want to provide the external application the minimum level of access to perform its required operations. When we share our cluster between different organizations or teams by logically partitioning it using namespaces, we want to restrict access to the users to their namespaces alone. That is what authorization can help you with in the cluster. There are different authorization mechanisms supported by Kubernetes, such as node authorization, attribute-based authorization, role-based authorization, and webhook. Let us go through these now. 

We know that the Kube API server is accessed by users like us for management purposes, as well as the kubelets or nodes within the cluster for management purposes within the cluster. The kubelet accesses the API server to read information about services and endpoints, nodes and pods. The kubelet also reports to the KubeAPI server with information about the node, such as its status. These requests are handled by a special authorizer known as the node authorizer. In the earlier lectures, when we discussed certificates, we discussed that the kubelets should be part of the system nodes group and have a name prefixed with system node. So any request coming from a user with the name system node and part of the system nodes group is authorized by the node authorizer and is granted these privileges. The privileges required for a kubelet. So that's access within the cluster. Let's talk about external access to the API. For instance, a user. Attribute-based authorization is where you associate a user or a group of users with a set of permissions. In this case, we say the dev user can view, create and delete pods. You do this by creating a policy file with a set of policies defined in a JSON format this way. You pass this file into the API server. Similarly, we create a policy definition file for each user or group in this file. Now, every time you need to add or make a change in the security, you must edit this policy file manually and restart the kube-apiserver. As such, the attribute-based access control configurations are difficult to manage. 

We will look at role-based access controls next. Role-based access controls make this much easier. With role-based access controls, instead of directly associating a user or a group with a set of permissions, we define a role. In this case, for developers. We create a role with the set of permissions required for developers. Then, we associate all the developers to that role. Similarly, create a role for security users with the right set of permissions required for them. Then, associate the users to that role. Going forward, whenever a change needs to be made to the user's access, we simply modify the role and it reflects on all developers immediately. Role-based access controls provide a more standard approach to managing access within the Kubernetes cluster. We will look at role-based access controls in much more detail in the next lecture. 

For now, let's proceed with the other authorization mechanisms. Now, what if you want to outsource all the authorization mechanisms? Say you want to manage authorization externally and not through the built-in mechanisms that we just discussed. For instance, Open Policy Agent is a third-party tool that helps with admission control and authorization. You can have Kubernetes make an API call to the Open Policy Agent with information about the user and his access requirements and have the Open Policy Agent decide if the user should be permitted or not. Based on that response, the user is granted access. 

Now, there are two more modes in addition to what we just saw: AlwaysAllow and AlwaysDeny. As the name states, AlwaysAllow allows all requests without performing any authorization checks. AlwaysDeny denies all requests. So, where do you configure these modes? Which of them are active by default? Can you have more than one at a time? How does authorization work if you do have multiple ones configured? The modes are set using the authorization mode option on the kube-apiserver. If you don't specify this option, it is set to AlwaysAllow by default. You may provide a comma-separated list of multiple modes that you wish to use. In this case, I want to set it to node, RBAC, and webhook. When you have multiple modes configured, your request is authorized using each one in the order it is specified. For example, when a user sends a request, it's first handled by the node authorizer. The node authorizer handles only node requests. So, it denies the request. Whenever a module denies a request, it is forwarded to the next one in the chain. The role-based access control module performs its checks and grants the user permission. Authorization is complete and the user is given access to the requested object. So, every time a module denies a request, it goes to the next one in the chain. And as soon as a module approves the request, no more checks are done and the user is granted permission.

## RBAC

In this lecture, we look at role-based access controls in much more detail. So how do we create a role? We do that by creating a role object. So we create a role definition file with the API version set to RBAC.authorization.k8s.io/v1, and kind set to Role. We name the role developer as we are creating this role for developers. And then we specify rules. Each rule has three sections, API groups, resources, and verbs. The same things that we talked about in one of the previous lectures. For core group, you can leave the API group section as blank. For any other group, you specify the group name. The resources that we want to give developers access to are pods, the actions that they can take are list, get, create, and delete. Similarly, to allow the developers to create ConfigMaps, we add another rule to create ConfigMap, you can add multiple rules for a single role like this. Create the role using the kubectl create role command. 

```yaml
# developer-role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["list", "get", "create", "update", "delete"]
- apiGroups:
  resources: ["ConfigMap"]
  verbs: ["create"]
```

```bash
kubectl create -f developer-role.yaml
```

The next step is to link the user to that role. For this, we create another object called role binding. The role binding object links a user object to a role. We will name it dev-user to developer binding. The kind is role binding. It has two sections. The subjects is where we specify the user details. The roleRef section is where we provide the details of the role we created. Create the role binding using the kubectl create command. Also note that the roles and role bindings fall under the scope of namespaces. So here, the dev user gets access to pods and config maps within the default namespace. If you want to limit the dev user's access within a different namespace, then specify the namespace within the metadata of the definition file while creating them. To view the created roles run the kubectl get roles command. To list role bindings run the kubectl get role bindings command. To view more details about the role from the kubectl describe role developer command. Here you see the details about the resources and permissions for each resource. Similarly, to view details about role bindings, run the kubectl describe role bindings command. Here you can see details about an existing role binding. 

```yaml
# devuser-developer-binding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: devuser-developer-binding
subjects:
- kind: User
  name: dev-user
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer
  apiGroup: rbac.authorization.k8s.io
```

```yaml
kubectl create -f devuser-developer-binding.yaml
```

What if you being a user would like to see if you have access to a particular resource in the cluster? You can use the kubectl auth can I command and check if you can say create deployments or say delete nodes. If you're an administrator, then you can even impersonate another user to check their permission. For instance, say you were tasked to create necessary set of permissions for a user to perform a set of operations and you did that. But you would like to test if what you did is working. You don't have to authenticate as the user to test it. Instead, you can use the same command with the --as=user option like this. Since we did not grant the developer permissions to create deployments, it returns No, the dev user has access to creating pods though. You can also specify the namespace in the command like this. The dev user does not have permission to create a pod in the test namespace. Well, a quick note on resource names. We just saw how you can provide access to users for resources like pods within the namespace. You can go one level down and allow access to specific resources alone. For example, say you have five pods in the namespace, you want to give access to a user to pods, but not all pods. You can restrict access to the blue and orange pods alone by adding a resource names field to the rule.

```bash
kubectl get roles
kubectl get rolebindings
kubectl describe role developer
kubectl describe rolebinding devuser-developer-binding
```

```bash
kubectl auth can-i create deployments
kubectl auth can-i delete nodes
kubectl auth can-i create deployments --as dev-user
kubectl auth can-i delete pods --as dev-user
kubectl auth can-i delete pods --as dev-user --namespace test
```

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "create", "update"]
  resourceNames: ["blue", "orange"]
```

## Cluster Role and Cluster Role Bindings

We discussed roles and role bindings in the previous lecture. In this lecture, we will talk about cluster roles and cluster role bindings. When we talked about roles and role bindings, we said that roles and role bindings are namespaced, meaning they are created within namespaces. If you don't specify a namespace, they're created in the default namespace and control access within that namespace alone. In one of the previous lectures, we discussed namespaces and how they help in grouping or isolating resources like pods, deployments, and services. But what about other resources like nodes? Can you group or isolate nodes within a namespace? Well, can you say node is part of the dev namespace? No, those are cluster-wide or cluster-scoped resources, they cannot be associated to any particular namespace. So the resources are categorized as either namespaced or cluster scoped. 

Now we've seen a lot of namespaced resources throughout this course, like pods and replica sets and jobs, deployments, services, secrets. And in the last lecture, we saw two new roles and role bindings. These resources are created in the namespace you specify when you create them. If you don't specify a namespace, they are created in the default namespace. To view them or delete them or update them, you always specify the right namespace. The cluster scoped resources are those where you don't specify a namespace when you create them like nodes, persistent volumes, versus the cluster roles and cluster role bindings that we're going to look at in this lecture. Certificate signing requests we saw earlier, and namespace objects themselves are of course not namespaced. Note that this is not a comprehensive list of resources. To see a full list of namespaced and non-namespaced resources, run the kubectl API resources command with the namespaced option set. 

```bash
kubectl api-resources --namespaced=true
kubectl api-resources --namespaced=false
```

In the previous lecture, we saw how to authorize a user to namespaced resources. We use roles and role bindings for that. But how do we authorize users to cluster wide resources like nodes or persistent volumes? That is where you use cluster roles and cluster role bindings. Cluster roles are just like roles, except they are for cluster scoped resources. For example, a cluster admin role can be created to provide a cluster administrator permissions to view, create, or delete nodes in a cluster. Similarly, a storage administrator role can be created to authorize a storage admin to create persistent volumes and claims. Create a cluster role definition file with the kind ClusterRole and specify the rules as we did before. In this case, the resources are nodes, then create the ClusterRole. The next step is to link the user to that cluster role. For this, we create another object called cluster role binding. The role binding object links the user to the role, we will name it cluster admin role binding. The kind is cluster role binding. Under subjects, we specify the user details cluster admin user in this case, the role ref section is where we provide the details of the cluster role we created. Create the role binding using the kubectl create command. 

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-administrator
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["list", "get", "create", "delete"]

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-admin-role-binding
subjects:
- kind: User
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-administrator
  apiGroup: rbac.authorization.k8s.io
```

```bash
kubectl create -f cluster-admin-role.yaml
kubectl create -f cluster-admin-role-binding.yaml
```

One thing to note before I let you go, we said that cluster roles and bindings are used for cluster scope resources. But that is not a hard rule, you can create a cluster role for namespace resources as well. When you do that, the user will have access to these resources across all namespaces. Earlier, when we created a role to authorize a user to access pods, the user had access to the pods in a particular namespace alone. With cluster roles, when you authorize a user to access the pods, the user gets access to all pods across the cluster. Kubernetes creates a number of cluster roles by default, when the cluster is first set up.

## Service Accounts

Hello, and welcome to this lecture. In this lecture, we will talk about service accounts in Kubernetes. The concept of service accounts is linked to other security-related concepts in Kubernetes, such as authentication, authorization, role-based access controls, etc. However, as part of the Kubernetes for the application developers exam curriculum, you only need to know how to work with service accounts. We have detailed sections covering the other concepts and security in the Kubernetes administrators course. 

So there are two types of accounts in Kubernetes, a user account and a service account. As you might already know, the user account is used by humans and service accounts are used by machines. A user account could be for an administrator accessing the cluster to perform administrative tasks, or a developer accessing the cluster to deploy applications, etc. A service account could be an account used by an application to interact with the Kubernetes cluster. For example, a monitoring application like Prometheus uses a service account to pull the Kubernetes API for performance metrics. An automated build tool like Jenkins uses service accounts to deploy applications on the Kubernetes cluster. 

Let's take an example. I've built a simple Kubernetes dashboard application named my Kubernetes dashboard. It's a simple application built in Python. And all that it does when deployed is retrieve the list of Pods on a Kubernetes cluster by sending a request to the Kubernetes API and display it on a web page. In order for my application to query the Kubernetes API, it has to be authenticated. For that, we use a service account. To create a service account, run the command kubectl create service account followed by the account name, which is dashboard in this case. To view the service accounts, run the kubectl get service account command. This will list all the service accounts. When the service account is created, it also creates a token automatically. The service account token is what must be used by the external application while authenticating to the Kubernetes API. The token, however, is stored as a Secret object. In this case, it's named dashboard-sa-token-KB-BDM. So when a service account is created, it first creates the service account object and then generates a token for the service account. It then creates a secret object and stores that token inside the secret object. The secret object is then linked to the service account. To view the token, view the secret object by running the command kubectl describe secret. This token can then be used as an authentication bearer token while making a REST call to the Kubernetes API. For example, in this simple example using curl, you could provide the bearer token as an authorization header while making a REST call to the Kubernetes API. In case of my custom dashboard application, copy and paste the token into the tokens field to authenticate the dashboard application. 

So that's how you create a new service account and use it. You can create a service account, assign the right permissions using role-based access control mechanisms, and export your service account tokens and use it to configure your third-party application to authenticate to the Kubernetes API. But what if your third-party application is hosted on the Kubernetes cluster itself? For example, we can have our custom Kubernetes dashboard application or the Prometheus application deployed on the Kubernetes cluster itself. In that case, this whole process of exporting the service account token and configuring the third-party application to use it can be made simple by automatically mounting the service token secret as a volume inside the pod hosting the third-party application. That way the token to access the Kubernetes API is already placed inside the pod and can be easily read by the application. You don't have to provide it manually. If you go back and look at the list of service accounts, you will see that there is a default service account that exists already. 

For every namespace in Kubernetes, a service account named default is automatically created. Each namespace has its own default service account. Whenever a pod is created, the default service account and its token are automatically mounted to that pod as a volume mount. For example, we have a simple pod definition file that creates a pod using my custom Kubernetes dashboard image. We haven't specified any secrets or volume mounts in the definition file. However, when the pod is created, if you look at the details of the pod by running the kubectl describe pod command, you see that a volume is automatically created from the secret named default-token, which is in fact, the secret containing the token for this default service account. The secret token is mounted at location **/var/run/secrets/kubernetes.io/serviceaccount** inside the pod. So from inside the pod, if you run the ls command to list the contents of the directory, you will see the secret mounted as three separate files. The one with the actual token is the file named token. If you view contents of that file, you will see the token to be used for accessing the Kubernetes API. Now remember that the default service account is very much restricted. It only has permission to run basic Kubernetes API queries. If you'd like to use a different service account, such as the one we just created, modify the pod definition file to include a service account field and specify the name of the new service account. 

> **Remember, you cannot edit the service account of an existing pod, you must delete and recreate the pod.** 

However, in the case of a deployment, you will be able to edit the service account as any changes to the pod definition file will automatically trigger a new rollout for the deployment. So the deployment will take care of deleting and recreating new pods with the right service account. When you look at the pod details, now you see that the new service account is being used. So remember, Kubernetes automatically mounts the default service account if you haven't explicitly specified any; you may choose not to mount a service account automatically by setting the **automountServiceAccount** token field to false in the pod spec section. 

Let's now discuss some of the changes that were made in releases version 1.22 and 1.24 of Kubernetes that changed the way service account secrets and tokens worked. Now as we discussed in the previous video, every namespace has a default service account and that service account has a secret object with a token associated with it. When a pod is created, it automatically associates the service account to the pod and mounts the token to a well-known location within the pod. In this case, it's under /var/run/secrets/kubernetes.io /servive-account. This makes the token accessible to a process that's running within the pod and that enables that process to query the Kubernetes API. Now if you list the contents of the directory inside the pod, you will see the secret mounted as three separate files. The one with the actual token is the file named token. So if you list the contents of that file, you'll see the token to be used for accessing the Kubernetes API. So all of that remains the same. This is exactly what we discussed in the previous video. 

Now let's take that token that we just saw and if you decode this token using this command or you could just copy and paste this token in the JWT website at jwt.io, you'll see that it has no expiry date defined in the payload section here on the right. So this is a token that does not have an expiry date set. So this except from the Kubernetes enhancement proposal for creating bound service account tokens describes this form of JWT to be having some security and scalability related issues. So the current implementation of JWT is not bound to any audience and is not time-bound as we just saw. **There was no expiry date for the token.** So the JWT is valid as long as the service account exists. Moreover, **each JWT requires a separate secret object per service account which results in scalability issues**. And as such in version 1.22, the token request API was introduced as part of the Kubernetes enhancement proposal (KEP 1205 - Bound Service Account Tokens) that aimed to introduce a mechanism for provisioning Kubernetes service account tokens that are more secure and scalable via an API. So tokens generated by the TokenRequestAPI are **audience-bound**, they're **time-bound** and **object-bound** and hence are more secure. 

```text
v1.22 - KEP 1205 - Bound Service Account Tokens

Background

- Kubernetes already provisions JWTs to workloads. This functionality is on by default and thus widely deployed. The current workload JWT system has serious issues:

- Security: JWTs are not audience bound. Any recipient of a JWT can masquerade as the presenter to anyone else.

- Security: The current model of storing the service account token in a Secret and delivering it to nodes results in a broad attack surface for the Kubernetes control plane when powerful components are run—giving a service account a permission means that any component that can see that service account's secrets is at least as powerful as the component.

- Security: JWTs are not time bound. A JWT compromised via 1 or 2, is valid for as long as the service account exists. This may be mitigated with service account signing key rotation but is not supported by client-go and not automated by the control plane and thus is not widely deployed.

- Scalability: JWTs require a Kubernetes secret per service account.
```

Now since version 1.22, when a new pod is created it no longer relies on the service account secret token that we just saw. Instead, a token with a defined lifetime is generated through the token request API by the service account admission controller when the pod is created. And this token is then mounted as a projected volume into the pod. So in the past if you look at this space here you'd see a secret that's part of the service account mount as a secret object. But now as you can see it's a projected volume that actually communicates with the token controller API, token request API and it gets a token for the pod. 

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  namespace: default
spec:
  containers:
    - image: nginx
      name: nginx
      volumeMounts:
        - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
          name: kube-api-access-6mtg8
          readOnly: true
  volumes:
    - name: kube-api-access-6mtg8
      projected:
        defaultMode: 420
        sources:
          - serviceAccountToken:
              expirationSeconds: 3607
              path: token
```

Now with version 1.24 another enhancement was made as part of the Kubernetes enhancement proposal (KEP 2799 - Reduction of Secret-Based Service Account Tokens) which dealt with the reduction of secret-based service account tokens. So in the past when the service account was created it automatically created a secret with a token that has no expiry and is not bound to any audience. This was then automatically mounted as a volume to any pod that uses that service account and that's what we just saw. But in version 1.22 that was changed the automatic mounting of the secret object to the pod was changed and instead it then moved to the TokenRequestAPI. 

So with version 1.24 a change was made where when you create **a service account it no longer automatically creates a secret or a token access secret**. So you must run the command kubectl create token followed by the name of the service account to generate a token for that service account if you needed one. And it will then print that token on screen. Now if you copy that token and then if you try to decode this token this time you'll see that it has an expiry date defined and if you haven't specified any time limit then it's usually one hour from the time that you run the command. You can also pass in additional options to the command to increase the expiry of the token.

```bash
kubectl create sa dashboard-sa
kubectl create token dashboard-sa
```

So now post version 1.24 if you would still like to create Secrets the old way with non-expiring token then you could still do that by creating a Secret object with the type set to **kubernetes.io/service-account-token** and the name of the service account specified within annotations in the metadata section like this. So this is how the Secret object will be associated with that particular service account. So when you do this just make sure that you have the service account created first and then create a Secret object otherwise the Secret object will not be created. So this will create a non-expiring token in a Secret object and associate it with that service account.

```yaml
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: mysecretname
  annotations:
    kubernetes.io/service-account.name: dashboard-sa
```

Now you have to be sure if you really want to do that because as per the Kubernetes documentation pages on service account token secrets it says you should only create service account token secrets if you can't use the TokenRequestAPI to obtain a token. So that's either the kubectl create token command we just talked about or it talks to the TokenRequestAPI to generate that token or it's the automated token creation that happens on Pods when they are created post version 1.22. And also you should only create service account token request if the security exposure of persisting a non-expiring token credential is acceptable to you. 

```text
Service account token Secrets

A kubernetes.io/service-account-token type of Secret is used to store a token credential that identifies a service account.

Since 1.22, this type of Secret is no longer used to mount credentials into Pods, and obtaining tokens via the TokenRequest API is recommended instead of using service account token Secret objects. Tokens obtained from the TokenRequest API are more secure than ones stored in Secret objects, because they have a bounded lifetime and are not readable by other API clients. You can use the kubectl create token command to obtain a token from the TokenRequest API.

You should only create a service account token Secret object if you can't use the TokenRequest API to obtain a token, and the security exposure of persisting a non-expiring token credential in a readable API object is acceptable to you.
```

> https://kubernetes.io/docs/concepts/configuration/secret/#service-account-token-secrets

Now the TokenRequestAPI is recommended instead of using the service account token secret objects as they are more secure and have a bounded lifetime unlike the service account token secrets that have no expiry. Well that's all for now.