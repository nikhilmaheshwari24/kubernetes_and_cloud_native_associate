## Cluster Networking

Hello, and welcome to this lecture. In this lecture, we look at the networking configurations required on the master and worker nodes in a Kubernetes cluster. The Kubernetes cluster consists of master and worker nodes. Each node must have at least one interface connected to a network. Each interface must have an address configured, the hosts must have a unique host name set, as well as a unique MAC address. You should note this especially if you created the VMs by cloning from existing ones. There are some ports that need to be opened as well. These are used by the various components in the control plane; the master should accept connections on 6443 for the API server. The worker nodes, kubectl tool, external users, and all other control plane components access the kube API server. For this port, the kubelets on the master and worker nodes listen on port 10250. Yes, in case we didn't discuss this, the kubelets can be present on the master node as well. The kube scheduler requires port 10259 to be open; the kube controller manager requires port 10257 to be open. The worker nodes expose services for external access on ports 30000 to 32767. So this should be open as well. Finally, the etcd server listens on port 2379. If you have multiple master nodes, all of these ports need to be open on those as well. And you also need an additional port 2380 open so the etcd clients can communicate with each other. The list of ports to be opened is also available in the Kubernetes documentation page. So consider these when you set up networking for your nodes in your firewalls or IP table rules or network security group in a cloud environment such as GCP or Azure or AWS. And if things are not working, this is one place to look for while you're investigating. 

## Pod Networking

Hello and welcome to this lecture. In this lecture we discuss pod networking in Kubernetes. So far we have set up several Kubernetes master and worker nodes and configured networking between them so they are all on a network that can reach each other. We also made sure the firewall and network security groups are configured correctly to allow for the Kubernetes control plane components to reach each other. Assume that we have also set up all the Kubernetes control plane components such as the kube-apiserver, the etcd servers, kubelets, etc. and we are finally ready to deploy our applications. But before we can do that there is something that we must address. We talked about the network that connects the nodes together but there is also another layer of networking that is crucial to the cluster's functioning and that is the networking at the pod layer. Our Kubernetes cluster is soon going to have a large number of pods and services running on it. How are the pods addressed? How do they communicate with each other? How do you access the services running on these pods internally from within the cluster as well as externally from outside the cluster? These are challenges that Kubernetes expects you to solve. As of today Kubernetes does not come with a built-in solution for this. It expects you to implement a networking solution that solves these challenges. However Kubernetes has laid out clearly the requirements for pod networking. Let's take a look at what they are. 

**Kubernetes expects every pod to get its own unique IP address** and **that every pod should be able to reach every other pod within the same node using that IP address** and **every pod should be able to reach every other pod on other nodes as well using the same IP address.** It doesn't care what IP address that is and what range or subnet it belongs to. As long as you can implement a solution that takes care of automatically assigning IP addresses and establish connectivity between the pods in a node as well as pods on different nodes you're good without having to configure any NAT rules. So how do you implement a model that solves these requirements? Now there are many networking solutions available out there that do these but we've already learned about networking concepts, routing, IP address management, namespaces and CNI. So let's try to use that knowledge to solve this problem by ourselves first. This will help in understanding how other solutions work. I know there is a bit of repetition but I'm trying to relate the same concept and approach all the way from plain network namespaces on Linux all the way to Kubernetes. 

So we have a three-node cluster it doesn't matter which one is master or worker they all run pods either for management or workload purposes. As far as networking is concerned we're going to consider all of them as the same. So first let's plan what we're going to do. The nodes are part of an external network and have IP addresses in the 192.168.1. series. Node 1 is assigned 11, node 2 is 12 and node 3 is 13. Next step when containers are created Kubernetes creates network namespaces for them. To enable communication between them we attach these namespaces to a network. But what network? We've learned about bridge networks that can be created within nodes to attach namespaces. So we create a bridge network on each node and then bring them up. It's time to assign an IP address to the bridge interfaces or networks. But what IP address? We decide that each bridge network will be on its own subnet. Choose any private address range say 10.244.1, 10.244.2 and 10.244.3. Next we set the IP address for the bridge interface. So we have built our base the remaining steps are to be performed for each container and every time a new container is created. So we write a script for it. Now you don't have to know any kind of complicated scripting it's just a file that has all commands we will be using and we can run this multiple times for each container going forward. To attach a container to the network we need a pipe or virtual network cable. We create that using the ip link add command. Don't focus on the options as they are similar to what we saw in our previous lectures. Assume that they vary depending on the inputs. We then attach one end to the container and another end to the bridge using the ip link set command. We then assign IP address using the ip addr command and add a route to the default gateway. But what IP do we add? We either manage that ourselves or store that information in some kind of database. For now we will assume it is 10.244.1.2 which is a free IP in the subnet. We discuss IP address management in detail in one of the upcoming lectures. 

Finally, we bring up the interface. We then run the same script this time for the second container with its information and get the container connected to the network. The two containers can now communicate with each other. We copy the script to the other nodes and run the script on them to assign IP addresses and connect those containers to their own internal networks. So we have solved the first part of the challenge. The pods all get their own unique IP address and are able to communicate with each other on their own nodes. 

The next part is to enable them to reach other pods on other nodes. Say for example the pod at 10.244.1.2 on node 1 wants to ping pod 10.244.2.2 on node 2. As of now the first has no idea where the address 10.244.2.2 is because it is on a different network than its own. So it routes to node 1's IP as it is said to be the default gateway. Node 1 doesn't know either since 10.244.2.2 is a private network on node 2. Add a route to node 1's routing table to route traffic to 10.244.2.2 via the second node's IP at 192.168.1.12. Once the route is added the blue Pods are able to ping across. Similarly, we configure routes on all hosts to all the other hosts with information regarding the respective networks within them. Now this works fine in this simple setup but this will require a lot more configuration as and when your underlying network architecture gets complicated. Instead of having to configure routes on each server a better solution is to do that on a router if you have one in your network and point all hosts to use that as the default gateway. That way you can easily manage routes to all networks in the routing table on the router. With that the individual virtual networks we created with the address 10.244.1.0/24 on each node now form a single large network with the address 10.244.0.0/16. It's time to tie everything together. 

We performed a number of manual steps to get the environment ready with the bridge networks and routing tables. We then wrote a script that can be run for each container that performs the necessary steps required to connect each container to the network and we executed the script manually. Of course we don't want to do that as in large environments where thousands of Pods are created every minute. So how do we run the script automatically when a pod is created on Kubernetes? That's where CNI comes in acting as the middleman. CNI tells Kubernetes that this is how you should call a script as soon as you create a container and CNI tells us this is how your script should look. So we need to modify the script a little bit to meet CNI standards. It should have an add section that will take care of adding a container to the network and a delete section that will take care of deleting container interfaces from the network and freeing the IP addresses etc. So our script is ready. The container runtime on each node is responsible for creating containers. Whenever a container is created the container runtime looks at the CNI configuration passed as a command line argument when it was run and identifies our script's name. It then looks in the CNI's bin directory to find our script and then executes the script with the add command and the name and namespace ID of the container and then our script takes care of the rest. We will look at how and where the CNI is configured in Kubernetes in the next lecture along with practice tests. For now that's it from the pod networking concepts lecture. Hopefully that should give you enough knowledge on inspecting networking within pods in a Kubernetes cluster.

## CNI in Kubernetes

Hello, and welcome to this lecture. In this lecture, we will discuss CNI in Kubernetes. In the prerequisite lectures, we started all the way from the absolute basics of network namespaces, then we saw how it is done in Docker, we then discussed why you need standards for networking containers, and how the Container Network Interface came to be. And then we saw a list of supported plugins available with CNI. In this lecture, we will see how Kubernetes is configured to use these network plugins. 

As we discussed in the prerequisite lecture, CNI defines the responsibilities of container runtimes. As per CNI, container runtimes, in our case, Kubernetes is responsible for creating container network namespaces, identifying and attaching those namespaces to the right network by calling the right network plugin. So where do we specify the CNI plugins for Kubernetes to use? The CNI plugin must be invoked by the component within Kubernetes that is responsible for creating containers, because that component must then invoke the appropriate network plugin. After the container is created, the CNI plugin is configured in the kubelet service on each node in the cluster. If you look at the kubelet service file, you will see an option called network plugin set to CNI, you can see the same information on viewing the running kubelet service, you can see the network plugin set to CNI and a few other options related to CNI such as the CNI bin directory and the CNI config directory. The CNI bin directory has all the supported CNI plugins as executables, such as the bridge, DHCP, flannel, etc. The CNI config directory has a set of configuration files. This is where kubelet looks to find out which plugin needs to be used. In this case, it finds the bridge configuration file. If there are multiple files here, it will choose the one in alphabetical order. 

If you look at the bridge config file, it looks like this. This is a format defined by the CNI standard for a plugin configuration file. Its name is mynettype is bridge. It also has a set of other configurations which can be related to the concepts we discussed in the prerequisite lectures on bridging, routing, and masquerading in that the gateway defines whether the bridge network should get an IP address assigned to it so that it can act as a gateway. The IP masquerade defines if a NAT rule should be added for IP masquerading. The IPAM section defines IPAM configuration. This is where you specify the subnet or the range of IP addresses that will be assigned to Pods and any necessary routes. The type host-local indicates that the IP addresses are managed locally on this host unlike a DHCP server maintaining it remotely. The type can also be set to DHCP to configure an external DHCP server. Well, that's it for this lecture. 

```json
{
  "cniVersion": "0.2.0",
  "name": "mynet",
  "type": "bridge",
  "bridge": "cni0",
  "isGateway": true,
  "ipMasq": true,
  "ipam": {
    "type": "host-local",
    "subnet": "10.22.0.0/16",
    "routes": [
      { "dst": "0.0.0.0/0" }
    ]
  }
}
```

## CNI Weave

Hello, and welcome to this lecture. In this lecture, we will discuss one solution based on CNI, in particular, **Weaveworks**, the Weaveworks Weave CNI plugin. In the previous practice test, we saw how it is configured. Now we will see more details about how it works. We will start where we left off in the pod networking concept section; we had our own custom CNI script that we've built and integrated into kubelet through CNI. In the previous lecture, we saw how instead of our own custom script, we integrated the Weave plugin. Let us now see how the Weave solution works as it is important to understand at least one solution. Well, you should then be able to relate this to other solutions as well. 

So the networking solution we set up manually had a routing table which mapped what networks are on what hosts. So when a packet is sent from one pod to the other, it goes out to the network to the router and finds its way to the node that hosts that pod. Now that works for a small environment and in a simple network. But in larger environments with hundreds of nodes in a cluster and hundreds of pods on each node, this is not practical. The routing table may not support so many entries. And that is where you need to get creative and look for other solutions. Think of the Kubernetes cluster as our company and the nodes as different office sites. With each site, we have different departments. And within each department, we have different offices, someone in office one wants to send a packet to office three and hands it over to the office boy, all he knows is it needs to go to office three, and he doesn't care who or how it is transported, the office boy takes the package, gets in his car, looks up the address for the target office in GPS uses directions on the streets and finds his way to the destination site delivers the package to the payroll department, who in turn forwards the package to office three, this works just fine. For now, we soon expand to different regions and countries. And this process no longer works. It's hard for the office boy to keep track of so many routes to these large number of offices across different countries. And of course, he can't drive to these offices by himself. That's where we decide to outsource all mailing and shipping activities to a company who does it best. Once the shipping company is engaged, the first thing that they do is place their agents in each of our company's sites. These agents are responsible for managing all shipping activities between sites. They also keep talking to each other and are well connected. So they all know about each other's sites, the departments in them and the offices in them. And so when a package is sent from say office 10 to office 3, the shipping agent in that site intercepts the package and looks at the target office name. He knows exactly in which site and department that office is in through his little internal network with his peers on the other sites. He then places this package into his own new package with the destination address set to the target site's location and then sends the package through once the package arrives at the destination. It is again intercepted by the agent on that site, he opens the packet retrieves the original packet and delivers it to the right department. 

Back to our world where the Weave CNI plugin is deployed on a cluster, it deploys an agent or service on each node, they communicate with each other to exchange information regarding the nodes and networks and pods within them. Each agent or peer stores a topology of the entire setup that way they know the pods and their IPs on the other nodes. Weave creates its own bridge on the nodes and names it Weave then assigns IP addresses to each network. The IPs shown here are just examples. In the upcoming practice test, you will figure out the exact range of IP addresses Weave assigned on each node. We will talk about IP address management and how IP addresses are handed out to pods and containers in the next lecture. 

Remember that a single pod may be attached to multiple bridge networks. For example, you could have a pod attached to the weave bridge as well as the Docker bridge created by Docker. What path a packet takes to reach its destination depends on the route configured on the container. Weave makes sure that it gets the correct route configured to reach the agent and the agent then takes care of other pods. Now when a packet is sent from one pod to another on another node, weave intercepts the packet and identifies that it's on a separate network. It then encapsulates this packet into a new one with new source and destination and sends it across the network. Once on the other side, the other weave agent retrieves the packet, decapsulates it and routes the packet to the right pod. 

So how do we deploy weave on a Kubernetes cluster? Weave and weave peers can be deployed as services or daemons on each node in the cluster manually or if Kubernetes is set up already, then an easier way to do that is to deploy it as pods in the cluster. Once the base Kubernetes system is ready with nodes and networking configured correctly between the nodes and the basic control plane components are deployed, weave can be deployed in the cluster with a single kubectl apply command. This deploys all the necessary components required for weave in the cluster. Most importantly, the weave peers are deployed as a DaemonSet. A DaemonSet ensures that one pod of the given kind is deployed on all nodes in the cluster. This works perfectly for the weave peers. If you deployed your cluster with a kubeadm tool and weave plugin, you can see the weave peers as pods deployed on each node. For troubleshooting purposes, view the logs using the kubectl logs command. 

## DNS in Kubernetes

Hello, and welcome to this lecture. In this lecture, we will discuss DNS in the Kubernetes cluster. In this lecture, we will see what names are assigned to what objects, what our service DNS records, pod DNS records, and what are the different ways you can reach one pod from another. So we have a three-node Kubernetes cluster with some pods and services deployed on them. Each node has a node name and IP address assigned to it. The node names and IP addresses of the cluster are probably registered in a DNS server in your organization. Now how that is managed, who accesses them are not of concern in this lecture. In this lecture, we discuss DNS resolution within the cluster, between the different components in the cluster such as pods and services. Kubernetes deploys a built-in DNS server by default, when you set up a cluster. If you set up Kubernetes manually, then you do it by yourself. As far as this lecture is concerned, we will see how it helps pods resolve other pods and services within the cluster. So we don't really care about nodes, we focus purely on pods and services within the cluster. As long as our cluster networking is set up correctly, following the best practices we learned so far in the section, and all pods and services can get their own IP addresses and can reach each other, we should be good. Let's start with just two pods and a service. I have a test pod on the left with the IP set to 10.44.1.5. And I have a web pod on the right with the IP set to 10.44.2.5. Looking at their IPs, you can guess that they're probably hosted on two different nodes. But that doesn't really matter. As far as DNS is concerned, we assume that all pods and services can reach each other using their IP addresses. To make the web server accessible to the test pod, we create a service, we name it web service, the service gets an IP 10.107.37.188. Whenever a service is created, the Kubernetes DNS service creates a record for the service, it maps the service name to the IP address. So within the cluster, any pod can now reach this service using its service name. 

Remember, we talked about namespaces earlier, that everyone within the namespace addresses each other just with their first names. And to address anyone in another namespace, you use their full names. In this case, since the test pod and the web pod and its associated service are all in the same namespace, the default namespace, you were able to simply reach the web service from the test pod using just the service name web dash service. Let's assume the web service was in a separate namespace named apps. Then to refer to it from the default namespace, you would have to say web service.apps. The last name of the service is now the name of the namespace. So here, web service is the name of the service and apps is the name of the namespace. For each namespace, the DNS server creates a subdomain. All the services are grouped together into another subdomain called SVC. So what was that about? Let's take a closer look. Web service is the name of the service and apps is the name of the namespace. For each namespace, the DNS server creates a subdomain with its name. All pods and services for a namespace are those grouped together within a subdomain in the name of the namespace. All the services are further grouped together into another subdomain called SVC. So you can reach your application with the name web service.apps.SVC. Finally, all the services and pods are grouped together into a root domain for the cluster, which is set to cluster.local by default. So you can access the service using the URL web service.apps.SVC.cluster.local. And that's the fully qualified domain name for the service. So that's how services are resolved within the cluster. What about pods? Records for pods are not created by default. But we can enable that explicitly. Once enabled, records are created for pods as well. It does not use the pod name though. For each pod, Kubernetes generates a name by replacing the dots in the IP address with dashes. The namespace remains the same and type is set to Pod. The root domain is always cluster.local. Similarly, the test pod in the default namespace gets a record in the DNS server with its IP converted to a dashed hostname 10-244-1-5, and namespace set to default type is Pod and the root is cluster.local. This resolves to the IP address of the pod. 

## Ingress

And in this lecture, we will discuss ingress in Kubernetes. One of the common questions that students reach out about usually is regarding services and ingress. What's the difference between the two? And when to use what? So we're going to briefly revisit services and work our way towards ingress. We will start with a simple scenario. You are deploying an application on Kubernetes for a company that has an online store selling products. Your application would be available at say myonlinestore.com. You build the application into a Docker image and deploy it on the Kubernetes cluster as a pod in a deployment. Your application needs a database. So you deploy a MySQL database as a pod and create a service of type ClusterIP called MySQL service to make it accessible to your application. Your application is now working. 

To make the application accessible to the outside world, you create another service, this time of type NodePort and make your application available on a high port on the nodes in the cluster. In this example, port is allocated for the service. The users can now access your application using the URL http://IP of any of your nodes followed by the port 38080. That setup works and users are able to access the application. Whenever traffic increases, we increase the number of replicas of the pod to handle the additional traffic and the service takes care of splitting traffic between the pods. 

However, if you have deployed a production grade application before, you know that there are many more things involved. In addition to simply splitting the traffic between the pods. For example, we do not want the users to have to type in the IP address every time. So you configure your DNS server to point to the IP of the nodes. Your users can now access your application using the URL myonlinestore.com and port 38080. Now, you don't want your users to have to remember the port number either. However, service node ports can only allocate high numbered ports, which are greater than 30,000. So you then bring in an additional layer between the DNS server and your cluster like a proxy server that proxies requests on port to port 38080. On your nodes, you then point your DNS to the server. And users can now access your application by simply visiting myonlinestore.com. Now this is if your application is hosted on-prem in your data center. 

Let's take a step back and see what you could do if you were on a public cloud environment like Google Cloud Platform. In that case, instead of creating a service of type NodePort for your verification, you could set it to type LoadBalancer. When you do that, Kubernetes would still do everything that it has to do for a NodePort, which is to provision a high port for the service. But in addition to that, Kubernetes also sends a request to Google Cloud Platform to provision a network load balancer for this service. On receiving the request, GCP would then automatically deploy a load balancer configured to route traffic to the service ports on all the nodes and return its information to Kubernetes. The load balancer has an external IP that can be provided to users to access the application. In this case, we set the DNS to point to this IP and users access the application using the URL myonlinestore.com. Perfect. 

Your company's business grows and you now have new services for your customers. For example, a video streaming service, you want your users to be able to access your new video streaming service by going to myonlinestore.com/watch. You'd like to make your old application accessible at my onlinestore.com/wear your developers developed the new video streaming application as a completely different application as it has nothing to do with the existing one. However, in order to share the same cluster resources, you deploy the new application as a separate deployment within the same cluster. You create a service called video service of type LoadBalancer. Kubernetes provisions port for this service and also provisions a network load balancer on the cloud. The new load balancer has a new IP. Remember, you must pay for each of these load balancers and having many such load balancers can inversely affect your cloud bill. 

So how do you direct traffic between each of these load balancers based on the URL that the users type in? You need yet another proxy or load balancer that can redirect traffic based on URLs to the different services. Every time you introduce a new service, you have to reconfigure the load balancer. And finally, you also need to enable SSL for your applications so your users can access your application using HTTPS. Where do you configure that? It can be done at different levels, either at the application level itself or at the load balancer or proxy server level. But which one? You don't want your developers to implement it in their application as they would do it in different ways. You want it to be configured in one place with minimal maintenance. 

Now that's a lot of different configurations. And all of these become difficult to manage when your application scales. It requires involving different individuals in different teams; you need to configure your firewall rules for each new service. And it's expensive as well as for each service in a new cloud-native load balancer that needs to be provisioned. Wouldn't it be nice if you could manage all of that within the Kubernetes cluster and have all that configuration as just another Kubernetes definition file that lives along with the rest of your application deployment files. That's where Ingress comes in. 

Ingress helps your users access your application using a single externally accessible URL that you can configure to route to different services within your cluster based on the URL path. At the same time, implement SSL security as well. Simply put, think of Ingress as a layer seven load balancer built into the Kubernetes cluster that can be configured using native Kubernetes primitives, just like any other object in Kubernetes. Now, remember, even with Ingress, you still need to expose it to make it accessible outside the cluster. So you still have to either publish it as a node port, or with a cloud-native load balancer. But that is just a one-time configuration. Going forward, you're going to perform all your load balancing, authentication, SSL and URL-based routing configurations on the Ingress controller. So how does it work? What is it? Where is it? How can you see it? How can you configure it? How does it load balance? How does it implement TLS? Without Ingress, how would you do all of this? I would use a reverse proxy or a load balancing solution like **NGINX** or **HAProxy** or **Traefik**. I would deploy them on a Kubernetes cluster and configure them to route traffic to other services. The configuration involves defining URL routes, configuring SSL certificates, etc. 

Ingress is implemented by Kubernetes in kind of the same way. You first deploy a supported solution, which happens to be any of these listed here (Nginx, HAProxy, Traefik), and then specify a set of rules to configure Ingress. The solution you deploy is called an **Ingress controller**. And the set of rules you configure are called **Ingress** resources. Ingress resources are created using definition files like the ones we used to create pods, deployments, and services earlier in this course. 

Now remember, a Kubernetes cluster does not come with an Ingress controller by default. If you set up a cluster following the demos in this course, you won't have an Ingress controller built into it. So if you simply create Ingress resources and expect them to work, they won't. Let's look at each of these in a bit more detail. 

As I mentioned, you do not have an Ingress controller on Kubernetes by default, so you must deploy one. What do you deploy? There are a number of solutions available for Ingress, a few of them being GCE, which is **Google's Layer HTTP load balancer**, **NGINX**, **Contour**, **HAProxy**, **Traefik**, and **Istio**. Out of this, GCE and NGINX are currently being supported and maintained by the Kubernetes project. And in this lecture, we will use NGINX as an example. These Ingress controllers are not just another load balancer or NGINX server. The load balancer components are just a part of it. The Ingress controllers have additional intelligence built into them to monitor the Kubernetes cluster for new definitions or Ingress resources and configure the NGINX server accordingly. 

An NGINX controller is deployed as just another deployment in Kubernetes. So, we start with a deployment definition file named NGINX Ingress Controller with one replica and a simple pod definition template. We will label it NGINX Ingress and the image used is NGINX Ingress Controller with the right version. Now, this is a special build of NGINX built specifically to be used as an Ingress Controller in Kubernetes. So, it has its own set of requirements. Within the image, the NGINX program is stored at location NGINX Ingress Controller. So, you must pass that as the command to start the NGINX controller service. If you have worked with NGINX before, you know that it has a set of configuration options such as the path to store the logs, keep-alive threshold, SSL settings, session timeouts, etc. In order to decouple these configuration data from the NGINX controller image, you must create a config map object and pass that in. Now, remember, the config map object need not have any entries at this point. A blank object will do. But creating one makes it easy for you to modify a configuration setting in the future. You will just have to add it into this config map and not have to worry about modifying the NGINX configuration files. You must also pass in two environment variables that carry the pod's name and namespace it is deployed to. The NGINX service requires these to read the configuration data from within the pod. And finally, specify the ports used by the Ingress controller which happens to be and 443.
```yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: nginx-ingress-controller
spec:
  replicas: 1
  selector:
    matchLabels:
      name: nginx-ingress
  template:
    metadata:
      labels:
        name: nginx-ingress
    spec:
      containers:
      - name: nginx-ingress-controller
        image: quay.io/kubernetes-ingress-controller/nginx-ingress-controller:0.21.0
        args:
        - /nginx-ingress-controller
        - --configmap=$(POD_NAMESPACE)/nginx-configuration
    env:
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    - name: POD_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
    ports:
    - name: http
      containerPort: 80
    - name: https
      containerPort: 443
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
```

We then need a service to expose the Ingress controller to the external world. So, we create a service of type NodePort with the NGINX Ingress label selector to link the service to the deployment. As mentioned before, the Ingress controllers have additional intelligence built into them to monitor the Kubernetes cluster for Ingress resources and configure the underlying NGINX server when something is changed. 


```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-ingress
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
  - port: 443
    targetPort: 443
    protocol: TCP
    name: https
  selector:
    name: nginx-ingress
```

But for the Ingress controller to do this, it requires a service account with the right set of permissions. For that, we create a service account with the correct roles and role bindings. 

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nginx-ingress-serviceaccount
```

So, to summarize, with a deployment of the NGINX Ingress image, a service to expose it, a config map to feed NGINX configuration data, and a service account with the right permissions to access all of these objects, we should be ready with an Ingress controller in its simplest form. Now, on to the next part of creating Ingress resources. An Ingress resource is a set of rules and configurations applied on the Ingress controller. You can configure rules to say simply forward all incoming traffic to a single application or route traffic to different applications based on the URL. So, if a user goes to myonlinestore.com/wear, then route to one of the applications or if the user visits the watch URL, then route to the video app, etc. Or you could route users based on the domain name itself. For example, if the user visits where.myonlinestore.com, then route the user to the where application or else route them to the video app. 

Let us look at how to configure these in a bit more detail. The Ingress resource is created with a Kubernetes definition file. In this case, Ingress-wear.yaml. As with any other object, we have API version, kind, metadata, and spec. The API version is extensions/v1beta one. Kind is Ingress. We will name it Ingress-wear. And under spec, we have backend. So, the traffic is of course routed to the application services and not pods directly as you might know already. The backend section defines where the traffic will be routed to. So, if it's a single backend, then you don't really have any rules. You can simply specify the service name and port of the backend service. Create the Ingress resource by running the kubectl create command. View the created Ingress resource by running the kubectl get Ingress command. The new Ingress is now created and routes all incoming traffic directly to the backend service. 

```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ingress-wear
spec:
  backend:
    serviceName: wear-service
    servicePort: 80
```

```bash
kubectl create -f Ingress-wear.yaml
kubectl get ingress
```

You use rules when you want to route traffic based on different conditions. For example, you create one rule for traffic originating from each domain or host name. That means when users reach your cluster using the domain name, myonlinestore.com, you can handle that traffic using rule one. When users reach your cluster using the domain name, where.myonlinestore.com, you can handle that traffic using a separate rule, rule two. Use rule three to handle traffic from watch.myonlinestore.com and say use a fourth rule to handle everything else. Now, within each rule, you can handle different paths. For example, within rule one, you can handle the /wear path to route that traffic to the clothes application and a /watch path to route traffic to the video streaming application and a third path that routes anything other than the first two to a 404 not found page. 

Similarly, the second rule handles all traffic from where.myonlinestore.com. You can have path definitions within this rule to route traffic based on different paths. For example, say you have different applications and services within the apparel section for shopping or returns or support. When a user goes to where.myonlinestore.com, by default, they reach the shopping page, but if they go to exchange or support URL, they reach different backend services. The same goes for rule three, where you route traffic to watch.myonlinestore.com to the video streaming application, but you can have additional paths in it, such as /movies or /TV. And finally, anything other than the ones listed here will go to the fourth rule that would simply show a 404 not found error page. 

So remember, you have rules at the top for each host or domain name, and within each rule, you have different paths to route traffic based on the URL. Now let's look at how we configure ingress resources in Kubernetes. We will start where we left off. We start with a similar definition file. This time under spec, we start with a set of rules. Now our requirement here is to handle all traffic coming to myonlinestore.com and route it based on the URL path. So we just need a single rule for this since we are only handling traffic to a single domain name, which is myonlinestore.com. Under rules, we have one item, which is an HTTP rule in which we specify different paths. So paths is an array of multiple items, one path for each URL. Then we move the backend we used in the first example under the first path. The backend specification remains the same. It has a service name and service port. Similarly, we create a similar backend entry to the second URL path for the watch service to route all traffic coming in through the watch URL to the watch service. Create the ingress resource using the kubectl create command. Once created, view additional details about the ingress resource by running the kubectl describe ingress command. 

```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ingress-wear-watch
spec:
  rules:
    - http:
        paths:
          - path: /wear
            backend:
              serviceName: wear-service
              servicePort: 80
          - path: /watch
            backend:
              serviceName: watch-service
              servicePort: 80
```

You now see two backend URLs under the rules and the backend service they are pointing to just as we created it. Back in your application, say a user visits the URL myonlinestore.com slash listen or eat and you don't have an audio streaming or a food delivery service, you might want to show them a nice message. You can do this by configuring a default backend service to display this not found error page. The third type of configuration is using domain names or host names. We start by creating a similar definition file for ingress. Now that we have two domain names, we create two rules, one for each domain. To split traffic by domain name, we use the host field. The host field in each rule matches the specified value with the domain name used in the request URL and routes traffic to the appropriate backend. Now remember, in the previous case, we did not specify the host field. If you don't specify the host field, it will simply consider it as a star or accept all the incoming traffic through that particular rule without matching the host name. In this case, note that we only have a single backend path for each rule, which is fine. All traffic from these domain names will be routed to the appropriate backend irrespective of the URL path. You can still have multiple path specifications in each of these to handle different URL paths, as we saw in the example earlier. So let's compare the two. Splitting traffic by URL had just one rule and we split the traffic with two paths. To split traffic by host name, we used two rules and one path specification in each rule. Well, that's it for this lecture. 

```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ingress-wear-watch
spec:
  rules:
    - host: wear.my-online-store.com
      http:
        paths:
          - backend:
              serviceName: wear-service
              servicePort: 80
    - host: watch.my-online-store.com
      http:
        paths:
          - backend:
              serviceName: watch-service
              servicePort: 80
```

Let us now head over to the practice test section and practice working on Ingress. Now there are two types of labs in this section. The first one is where an Ingress controller, resources, and applications are already deployed and you basically view and walk through the environment, gather data, and answer questions. Towards the end, you would create or modify Ingress resources based on the needs. In the second practice test, which is a bit more challenging, and that is where you will be deploying an Ingress controller and resources from scratch.
