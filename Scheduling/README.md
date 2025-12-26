## Manual Scheduling

Hello, and welcome to this lecture. In this lecture, we look at the different ways of manually scheduling a pod on a node. What do you do when you do not have a scheduler in your cluster? You probably do not want to rely on the built-in scheduler, and instead want to schedule the pods yourself. So how exactly does a scheduler work in the backend? Let's start with a simple pod definition file. Every pod has a field called node name that by default is not set. You don't typically specify this field when you create the pod manifest file. Kubernetes adds it automatically, the scheduler goes through all the pods and looks for those that do not have this property set. Those are the candidates for scheduling. It then identifies the right node for the pod by running the scheduling algorithm. Once identified, it schedules the pod on the node by setting the node name property to the name of the node by creating a binding object. 

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    name: nginx
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 8080
  nodeName: node02
```

So if there is no scheduler to monitor and schedule nodes, what happens, the pods continue to be in a pending state. So what can you do about it, you can manually assign pods to nodes yourself. Well, without a scheduler, the easiest way to schedule a pod is to simply set the node name field to the name of the node in your pod specification file. While creating the pod, the pod then gets assigned to the specified node, you can only specify the node name at creation time. What if the pod is already created, and you want to assign the pod to a node. Kubernetes won't allow you to modify the node name property of a pod. So another way to assign a node to an existing pod is to create a binding object and send a POST request to the pod's binding API, thus mimicking what the actual scheduler does. In the binding object, you specify a target node with the name of the node, then send a POST request to the pod's binding API with the data set to the binding object in a JSON format. So you must convert the YAML file into its equivalent JSON form. 

```yaml
apiVersion: v1
kind: Binding
metadata:
  name: nginx
target:
  apiVersion: v1
  kind: Node
  name: node02
```

```bash
$ curl --header "Content-Type:application/json" --request POST --data "$BINDING_DATA" http://$SERVER/api/v1/namespaces/default/pods/$PODNAME/binding/
```

## Labels and Selectors

What do we know about labels and selectors already? Labels and selectors are a standard method to group things together. Say, you have a set of different species. A user wants to be able to filter them based on different criteria, such as based on their class or kind, if they are domestic or wild, or, say, by their color and not just group. You want to be able to filter them based on criteria such as all green animals or with multiple criteria such as everything green that is also a bird. Whatever that classification may be, you need the ability to group things together and filter them based on your needs, and the best way to do that is with labels. Labels are properties attached to each item, so you add properties to each item for their class, kind, and color. Selectors help you filter these items. For example, when you say class equals mammal, we get a list of mammals, and when you say color equals green, we get the green mammals. We see labels and selectors used everywhere, such as the keywords you tag to YouTube videos or blogs that help users filter and find the right content. We see labels added to items in an online store that help you add different kinds of filters to view your products. 

So, how are labels and selectors used in Kubernetes? We have created a lot of different types of objects in Kubernetes - pods, services, Replica Sets, deployments, etc. For Kubernetes, all of these are different objects. Over time, you may end up having hundreds or thousands of these objects in your cluster. Then you will need a way to filter and view different objects by different categories, such as to group objects by their type or view objects by application or by their functionality. Whatever it may be, you can group and select objects using labels and selectors. For each object, attach labels as per your needs, like app, function, etc. Then while selecting, specify a condition to filter specific objects. For example, app equals App1. 

So, how exactly do you specify labels in Kubernetes? In a pod definition file under metadata, create a section called labels. Under that, add the labels in a key-value format like this. You can add as many labels as you like. Once the pod is created, to select the pod with the labels, use the kubectl get pods command along with the selector option and specify the condition, like app equals App1. 

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    name: nginx
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 8080
  nodeName: node02
```

```bash
$ kubectl get pods --selector app=app1
```

Now, this is one use case of labels and selectors. Kubernetes objects use labels and selectors internally to connect different objects together. For example, to create a Replica Set consisting of three different pods, we first label the pod definition and use selector in a Replica Set to group the pods. 

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: simple-webapp
  labels:
    app: App1
    function: Front-end
spec:
  replicas: 3
  selector:
    matchLabels:
      app: App1
  template:
    metadata:
      labels:
        app: App1
        function: Front-end
    spec:
      containers:
      - name: simple-webapp
        image: simple-webapp
```

In a replicaset-definition file, you will see labels defined in two places. Note that this is an area where beginners tend to make a mistake. The labels defined under the template section are the labels configured on the pods. The labels you see at the top are the labels of the Replica Set itself. We're not really concerned about the labels of the Replica Set for now because we are trying to get the Replica Set to discover the pods. The labels on the Replica Set will be used if you were to configure some other object to discover the Replica Set. In order to connect the Replica Set to the pod, we configure the selector field under the Replica Set specification to match the labels defined on the pod. A single label will do if it matches correctly. However, if you feel there could be other pods with the same label, but with a different function, then you could specify both the labels to ensure that the right parts are discovered by the Replica Set. On creation, if the labels match, the Replica Set is created successfully. It works the same for other objects like a service. When a service is created, it uses the selector defined in the service-definition file to match the labels set on the pods in the replicaset-definition file. 

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector:
    app: App1
  ports:
    - protocol: TCP
      port: 80
      targetPort: 9376
```

Finally, let's look at annotations. While labels and selectors are used to group and select objects, annotations are used to record other details for informatory purpose. For example, tool details like name, version, build information, etc. or contact details, phone numbers, email IDs, etc. that may be used for some kind of integration purpose. 

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: simple-webapp
  labels:
    app: App1
    function: Front-end
  annotations:
    buioldversion: 1.34
spec:
  replicas: 3
  selector:
    matchLabels:
      app: App1
  template:
    metadata:
      labels:
        app: App1
        function: Front-end
    spec:
      containers:
      - name: simple-webapp
        image: simple-webapp
```

## Taints and Tolerations

In this lecture, we will discuss about the pod-to-node relationship and how you can restrict what pods are placed on what nodes. The concept of taints and tolerations can be a bit confusing for beginners, so we will try to understand what they are using an analogy of a bug approaching a person. Now, my apologies in advance, but this is the best I could come up with. To prevent the bug from landing on the person, we spray the person with a repellent spray or at taint, as we will call it in this lecture. The bug is intolerant to the smell. So, on approaching the person, the taint applied on the person throws the bug off. However, there could be other bugs that are tolerant to the smell, and so the taint doesn't really affect them, and so they end up landing on the person. So, there are two things that decide if a bug can land on a person. First, the taint on the person, and second, the bug's toleration level to that particular taint. Getting back to Kubernetes, the person is a node and the bugs are pods. Now, taints and tolerations have nothing to do with security or intrusion on the cluster. Taints and tolerations are used to set restrictions on what pods can be scheduled on a node. Let us start with a simple cluster with three worker nodes. The nodes are named 1, 2, and 3. We also have a set of pods that are to be deployed on these nodes. Let's call them A, B, C, and D. When the pods are created, Kubernetes scheduler tries to place these pods on the available worker nodes. As of now, there are no restrictions or limitations, and as such, the scheduler places the pods across all of the notes to balance them out equally. Now, let us assume that we have dedicated resources on node for a particular use case or application. So, we would like only those pods that belong to this application to be placed on node 1. First, we prevent all pods from being placed on the node by placing a taint on the node. Let's call it blue. By default, parts have no tolerations, which means unless specified otherwise, none of the pods can tolerate any taint. So, in this case, none of the pods can be placed on node 1, as none of them can tolerate the taint blue. This solves half of our requirement. No unwanted pods are going to be placed on this node. 

The other half is to enable certain pods to be placed on this node. For this, we must specify which pods are tolerant to this particular taint. In our case, we would like to allow only pod D to be placed on this node. So, we add a toleration to pod D. Pod D is now tolerant to blue. So, when the scheduler tries to place this pod on node 1, it goes through. Node can now only accept pods that can tolerate the taint blue. So, with all the taints and tolerations in place, this is how the pods would be scheduled. The scheduler tries to place pod A on node 1, but due to the taint, it is thrown off and it goes to node 2. The scheduler then tries to place pod B on node 1, but again, due to the taint, it is thrown off and is placed on node 3, which happens to be the next free node. The scheduler then tries to place part C to the node 1. It is thrown off again and ends up on node 2. And, finally, the scheduler tries to place part D on node 1. Since the part is tolerant to node 1, it goes through. **So, remember, taints are set on nodes and tolerations are set on pods.** 

So, how do you do this? Use the kubectl taint nodes command to taint a node. Specify the name of the node to taint, followed by the taint itself, which is a key-value pair. For example, if you would like to dedicate the node to pods in application blue, then the key-value pair would be app equals blue. 

```bash
$ kubectl taint nodes node-name key=value:taint-effect
$ kubectl taint nodes node1 app=blue:NoSchedule
```

The taint effect defines what would happen to the pods if they do not tolerate the taint. There are three taunt effects: **NoSchedule**, which means the pods will not be scheduled on the node, which is what we have been discussing. **PreferNoSchedule**, which means the system will try to avoid placing a pod on the node, but that is not guaranteed. And third is **NoExecute**, which means that new pods will not be scheduled on the node and existing pods on the node, if any, will be evicted if they do not tolerate the taint. These pods may have been scheduled on the node before the taint was applied to the node. 

An example command would be to taint node node with the key-value pair app=blue and an effect of NoSchedule. Tolerations are added to pods. To add a toleration to a pod, first, pull up the pod definition file. In the spec section of the pod definition file, add a section called tolerations. Move the same values used while creating the taint under this section. The key is app, operator is equal, value is blue, and the effect is NoSchedule. And, remember, all of these values need to be encoded in double quotes. When the pods are now created or updated with the new tolerations, they are either not scheduled on nodes or evicted from the existing nodes depending on the effect set. 

```yaml
apiVersion:
kind: Pod
metadata:
  name: myapp-pod
spec:
  containers:
    - name: nginx-container
      image: nginx
  tolerations:
    - key: "app"
      operator: "Equal"
      value: "blue"
      effect: "NoSchedule"
```

Let us try to understand the NoExecute taint effect in a bit more depth. In this example, we have three nodes running some workload. We do not have any taints or tolerations at this point, so they're scheduled this way. We then decided to dedicate node for a special application, and as such, we taint the node with the application name and add a toleration to the pod that belongs to the application, which happens to be pod D in this case. While tainting the node, we set the taint effect to NoExecute. And as such, once the taint on the node takes effect, it evicts pod C from the node, which simply means that the pod is killed. The pod D continues to run on the node as it has a toleration to the taint blue. Now, going back to our original scenario where we have taints and tolerations configured, remember, **taints and tolerations are only meant to restrict nodes from accepting certain pods**. In this case, node can only accept pod D, but it does not guarantee that pod D will always be placed on node 1. Since there are no taints or restrictions applied on the other two nodes, pod D may very well be placed on any of the other two nodes. So, remember, taints and tolerations does not tell the pod to go to a particular node. Instead, it tells the node to only accept parts with certain tolerations. If your requirement is to restrict a pod to certain nodes, it is achieved through another concept call as node affinity, which we will discuss in the next lecture. 

Finally, while we are on this topic, let us also take a look at an interesting fact. So far, we have only been referring to the worker nodes, but we also have master nodes in the cluster, which is technically just another node that has all the capabilities of hosting a pod, plus it runs all the management software. Now, I'm not sure if you noticed, **the scheduler does not schedule any pods on the master node**. Why is that? When the Kubernetes cluster is first set up, a taint is set on the master node automatically that prevents any pods from being scheduled on this node. You can see this as well as modify this behavior if required. However, a best practice is to not deploy application workloads on a master server. To see this taint, run a kubectl describe node command with kubemaster as the node name and look for the taint section. You will see a taint set to NoSchedule any pods on the master node.

```bash
kubectl describe node kubemaster | grep Taint
```

## Node Selectors

Hello and welcome to this lecture. In this lecture, we will talk about node selectors in Kubernetes. Let us start with a simple example. You have a three-node cluster of which two are smaller nodes with lower hardware resources, and one of them is a larger node configured with higher resources. You have different kinds of workloads running in your cluster. You would like to dedicate the data processing workloads that require higher horsepower to the larger node, as that is the only node that will not run out of resources in case the job demands extra resources. However, in the current default setup, any pods can go to any nodes, so pod C in this case may very well end up on nodes or 3, which is not desired. 

To solve this, we can set a limitation on the pods so that they only run on particular nodes. There are two ways to do this. The first is using **node selectors**, which is the simple and easier method. For this, we look at the pod definition file we created earlier. This file has a simple definition to create a pod with a data processing image. To limit this pod to run on the larger node, we add a new property called node selector to the spec section and specify the size as large. But wait a minute, where did the size large come from and how does Kubernetes know which is the large node? The key-value pair of size of Large are in fact labels assigned to the nodes. The scheduler uses these labels to match and identify the right node to place the pods on. Labels and selectors are a topic we have seen many times throughout this Kubernetes course, such as with services, Replica Sets, and deployments. To use labels in a node selector like this, you must have first labeled your nodes prior to creating this pod. 

```bash
apiVersion:
kind: Pod
metadata:
  name: myapp-pod
spec:
  containers:
    - name: data-processor
      image: data-processor
  nodeSelector:
    size: Large
```

So, let us go back and see how we can label the nodes. To label a node, use the command kubectl label nodes, followed by the name of the node and the label in a key-value pair format. In this case, it would be kubectl label nodes node-1, followed by the label in a key-value format such as size=Large. 

```bash
$ kubectl label nodes node-name <label-key>=<label-value>
$ kubectl label nodes node1 size=Large
```

Now that we have labeled the node, we can get back to creating the pod, this time, with the node selector set to a size of Large, when the pod is now created, it is placed on Node as desired. Node selector served our purpose, but it has limitations. We used a single label and selector to achieve our goal here, but what if our requirement is much more complex? For example, we would like to say something like place the pod on a large or medium node or something like place the pod on any node that are not small. You cannot achieve this using node selectors. For this, node affinity and anti-affinity features were introduced.

## Node Affinity

Hello and welcome to this lecture. In this lecture, we will talk about node affinity feature in Kubernetes. The primary purpose of node affinity feature is to ensure that pods are hosted on particular nodes, in this case, to ensure the large data processing pod ends up on node 1. In the previous lecture, we did this easily using node selectors. We discussed that you cannot provide advanced expressions like OR or NOT with node selectors. The node affinity feature provides us with advanced capabilities to limit pod placement on specific nodes. With great power comes great complexity. So, the simple node selector specification will now look like this with node affinity, although both do exactly the same thing. Place the pod on the large node. Let us look at it a bit closer. 

Under spec, you have affinity and then node affinity under that. And then you have a property that looks like a sentence called "**required during scheduling, ignored during execution**". No description needed for that. And then you have the node selector terms that is an array, and that is where you will specify the key and value pairs. The key-value pairs are in the form key operator and value where the operator is In. The In operator ensures that the pod will be placed on a node whose label size has any value in the list of values specified here. In this case, it is just one called "large". If you think your pod could be placed on a large or a medium node, you could simply add the value to the list of values like this. You could use the NotIn operator to say something like size NotIn small, where node affinity will match the node with a size not set to small. We know that we have only set the label size to large and medium nodes. The smaller nodes don't even have the label set, so we don't really have to even check the value of the label. As long as we are sure we don't set a label size to the smaller nodes, using the Exists operator will give us the same result. The Exists operator will simply check if the label size exists on the nodes, and you don't need the values section for that, as it does not compare the values. There are a number of other operators as well. Check the documentation for specific details. 

```yaml
apiVersion:
kind:
metadata:
  name: myapp-pod
spec:
  containers:
    - name: data-processor
      image: data-processor
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: size
                operator: In 
                values:
                  - Large
                  - Medium
```
```yaml
- key: size
  operator: NotIn
  values:
    - Small
```
```yaml
# it does not compare the values..
- key: size
  operator: Exists
```

Now, we understand all of this, and we're comfortable with creating a pod with specific affinity rules. When the pods are created, these rules are considered and the pods are placed onto the right nodes. But what if node affinity could not match a node with a given expression? In this case, what if there are no nodes with the label called size? Say, we had the labels and the pods are scheduled. What if someone changes the label on the node at a future point in time? Will the pod continue to stay on the node? All of this is answered by the long sentence-like property under node affinity, which happens to be the type of node affinity. The type of node affinity defines the behavior of the scheduler with respect to node affinity and the stages in the lifecycle of the pod. There are currently two types of node affinity **available - "required during scheduling, ignored during execution" and "preferred during scheduling ignored during execution"**. And there are two additional types of node affinity planned as of this recording: **"required during scheduling required during execution" and "preferred during scheduling required during execution"**. 

We will now break this down to understand further. We will start by looking at the two available affinity types. There are two states in the lifecycle of a pod when considering node affinity: "**DuringScheduling**" and "**DuringExecution**". DuringScheduling is the state where a pod does not exist and is created for the first time. We have no doubt that when a pod is first created, the affinity rules specified are considered to place the pods on the right nodes. Now, what if the nodes with matching labels are not available? For example, we forgot to label the node as large. That is where the type of node affinity used comes into play. If you select the required type, which is the first one, the scheduler will mandate that the pod be placed on a node with the given affinity rules. If it cannot find one, the pod will not be scheduled. This type will be used in cases where the placement of the pod is crucial. If a matching node does not exist, the pod will not be scheduled. But let's say the pod placement is less important than running the workload itself. In that case, you could set it to preferred, and in cases where a matching node is not found, the scheduler will simply ignore node affinity rules and place the pod on any available node. This is a way of telling the scheduler, "Hey, try your best to place the pod on matching node, but if you really cannot find one, just place it anywhere". 

The second part of the property or the other state is DuringExecution. DuringExecution is the state where a pod has been running and a change is made in the environment that affects node affinity, such as a change in the label of a node. For example, say, an administrator removed the label we set earlier called size equals large from the node. Now, what will happen to the pods that are running on the node? As you can see, the two types of node affinity available today has this value set to ignored, which means pods will continue to run and any changes in node affinity will not impact them once they are scheduled. The two new types expected in the future only have a difference in the DuringExecution phase. A new option called "Required DuringExecution" is introduced, which will evict any pods that are running on nodes that do not meet affinity rules. In the earlier example, a pod running on the Large node will be evicted or terminated if the label Large is removed from the node.

## Taints and Tolerations vs Node Affinity

Hello and welcome to this lecture. Now that we have learned about taints and tolerations and node affinity, let us tie together the two concepts through a fun exercise. We have three nodes and three pods each in three colors: blue, red, and green. The ultimate aim is to place the blue pod in the blue node, the red pod in the red node, and likewise for green. We are sharing the same Kubernetes cluster with other teams. So, there are other pods in the cluster as well as other nodes. We do not want any other pod to be placed on our node. Neither do we want our pods to be placed on their nodes. Let us first try to solve this problem using taints and tolerations. We apply a taint to the nodes, marking them with their colors blue, red, and green, and we then set a toleration on the pods to tolerate the respective colors. When the pods are now created, the nodes ensure they only accept the pods with the right toleration. So, the green pod ends up on the green node and the blue pod ends up on the blue node. However, taints and tolerations does not guarantee that the pods will only prefer these nodes. So, the red node ends up on one of the other nodes that do not have a taint or toleration set. This is not desired. 

Let us try to solve the same problem with node affinity. With node affinity, we first label the nodes with their respective colors blue, red, and green. We then set node selectors on the pods to tie the pods to the nodes. As such, the pods end up on the right nodes. However, that does not guarantee that other pods are not placed on these nodes. In this case, there is a chance that one of the other pods may end up on our nodes. This is not something we desire. 

As such, a combination of taints and tolerations and node affinity rules can be used together to completely dedicate nodes for specific pods. We first use taints and tolerations to prevent other pods from being placed on our nodes, and then we use node affinity to prevent our pods from being placed on their nodes. Well, that's it for this lecture. 

## Resource Limits

Let's look at resource requirements. Let us start by looking at a three-node Kubernetes cluster. Each node has a set of CPU and memory resources available. Now, every pod requires a set of resources to run. In this case, for example, this pod requires two CPUs and one memory unit. Now, whenever a pod is placed on a node, it consumes the resources available on that node. Now, as we have discussed before, it is the Kubernetes scheduler that decides which node a pod goes to. The scheduler takes into consideration the amount of resources required by a pod and those available on the nodes and identifies the best node to place a pod on. In this case, the scheduler schedules a new pod on node two because there are sufficient resources available on that node. If nodes have no sufficient resources available, the scheduler avoids placing the pod on those nodes and instead places the pod on one where sufficient resources are available. And if there are no sufficient resources available on any of the nodes, then the scheduler holds back scheduling the pod and you will see the pod in a pending state. And if you look at the events using the kubectl describe pod command, you will see there is insufficient CPU. 

Now, let us now focus on the resource requirements for each pod. So, what are these blocks and what are their values? Now, you can specify the amount of CPU and memory required for a pod when creating one. For example, it could be one CPU and one GB of memory. And this is known as the resource request for a container. So, the minimum amount of CPU or memory requested by the container. So, when the scheduler tries to place the pod on a node, it uses these numbers to identify a node which has sufficient amount of resources available. So, to do this in the sample pod definition file, all you need to do is add a section called resources under which add requests and specify the new values for memory and CPU usage. In this case, I set it to four GB of memory and two cores of CPU. So, when the scheduler gets a request to place this pod, it looks for a node that has this amount of resources available. And when the pod gets placed on a node, the pod gets a guaranteed amount of resources available for it. 

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: simple-webapp-color
  labels:
    name: simple-webapp-color
spec:
  containers:
    - name: simple-webapp-color
      image: simple-webapp-color
      ports:
        - containerPort: 8080
      resources:
        requests:
          memory: "4Gi"
          cpu: 2
```

So, what does one core of CPU really mean? Now, you can specify any value as low as 0.1. So, 0.1 CPU can also be expressed as 100M, where M stands for milli. And you can go as low as 1M, but not lower than that. Now, one core of CPU is equivalent to one vCPU. So, that's one vCPU in AWS. So, if you're looking at the AWS cloud, or it could be referred to as one core in GCP or Azure, or one hyper-thread on other systems. And you could request a higher number of CPUs for the container provided your nodes are sufficiently funded. In this example, I have set it to five. Now, similarly, with memory, you could specify 256 MB using the Mi suffix or specify the same value in memory like this. That's the full number, the whole number and or specify the same value in memory like this as 256M. So, or use the suffix G for gigabyte. So, note the difference between G and Gi. So, 1G is gigabyte and it refers to 1000megabytes, whereas 1Gi refers to gibibyte and that would be equivalent to 1024megabytes. So, the same applies to megabyte and mebibyte and kilobyte and kibibyte. 

```yaml
• 1 G (Gigabyte) = 1,000,000,000 bytes
• 1 M (Megabyte) = 1,000,000 bytes
• 1 K (Kilobyte) = 1,000 bytes

• 1 Gi (Gibibyte) = 1,073,741,824 bytes
• 1 Mi (Mebibyte) = 1,048,576 bytes
• 1 Ki (Kibibyte) = 1,024 bytes
```

Now, let's look at a container running on a node. And by default, a container has no limit to the resources it can consume on a node. So, say a container that's part of a pod starts with one CPU on a node, it can go up and consume as much resources as it requires and that suffocates the native processes on the node or other containers of resources. However, you can set a limit for the resource usage on these pods. For example, if you set a limit of one vCPU to the containers, a container will be limited to consume only one vCPU from that node. So, the same goes with memory. For example, you can set a limit of megabytes on containers like this. Now, you can specify the limits under the limits section, under the resources section in your pod definition file. So, here we specify the new limits for memory and CPU like this. 

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: simple-webapp-color
  labels:
    name: simple-webapp-color
spec:
  containers:
    - name: simple-webapp-color
      image: simple-webapp-color
      ports:
        - containerPort: 8080
      resources:
        requests:
          memory: "1Gi"
          cpu: 1
        limits:
          memory: "2Gi"
          cpu: 2
```

Now, when the pod is created, Kubernetes sets new limits for the container. And remember that the limits and requests are set for each container within a pod. So, if there are multiple containers, then each container can have a request or limit set for its own. So, what happens when a pod tries to exceed resources beyond its specified limit? In case of the CPU, **the system throttles the CPU so that it does not go beyond the specified limit**. A container cannot use more CPU resources than its limit. However, this is not the case with memory. A container can use more memory resources than its limit. So, if a pod tries to consume more memory than its limit constantly, the pod will be terminated. And you'll see that the pod terminated with an **OOM error** in the logs or in the output of the describe command when you run it. So, that's what is OOM refers to, out of memory kill. 

So, now that we have learned what resource requests are and what limits are and how they function and what happens when a particular container or pod hits the limits that were defined, let's see what the default configuration is, right? So, by default, Kubernetes does not have a CPU or memory request or limit set. So, this means that any pod can consume as much resources as required on any node and suffocate other pods or processes that are running on the node of resources. So, this is very, very important to note. So, let's just look at how CPU requests and limits work. Let's say there are two pods competing for CPU resources on the cluster and when I say pod, I mean a container within a pod, right? So, just keep that in mind. So, without a resource request or limit set, one pod can consume all the CPU resources on the node and prevent the second pod of required resources. So, of course, this is not ideal. 

Now, let's look at another case where we have no requests specified but we do have limits specified. In this case, Kubernetes automatically sets requests to the same as limits. For example, requests and limits are assumed to be three in this case and each pod is guaranteed three vCPUs and no more than that as limits are also set to the same. 

The next one is where requests and limits are set. In this case, each pod gets a guaranteed number of CPU requests which is one vCPU and can go up to the limits that are defined which is three vCPU but not more. So, this might look to be the most ideal scenario. However, the issue is that if pod one needs more CPU cycles for some reason and pod two isn't really consuming that many CPU cycles, then we don't want to limit pod one of CPU, right? So, we'd like to allow pod one to use the available CPU cycles as long as pod two doesn't really need it. So, if there are sufficient CPU cycles available on the system, then why not let the pods use them, right? So, we don't want to unnecessarily limit resources of CPU cycles. So, that is not really the ideal scenario and that's where the last scenario comes in. 

So, setting requests but no limits. In this case, because requests are set, each pod is guaranteed one vCPU. However, because limits are not set, when available, any pod can consume as many CPU cycles as available. But at any point in time, if pod two requires additional CPU cycles or whatever it is it has requested, then it will be guaranteed its requested CPU cycles. So, this is the most ideal setup. Of course, there are cases where you absolutely may want to limit a pod of resources and in that case, you may set limits. For example, a good use case for setting limits is our labs themselves where all the labs that you guys have been going through and accessing as part of this course, they are hosted as containers on a cluster, right? And since it's made accessible to the public and users can run any kind of workload that they want, we set limits to prevent a user from misusing the infrastructure to, let's say, perform bitcoin mining or other resource-consuming activities. So, that works for us in that case. But in your case, if you don't want to restrict your application to consume additional CPU, if needed, then you could consider not setting limits. But remember, if you were to do that, you need to make sure that all the pods have some requests set because that's the only way a pod will have resources guaranteed when there are no limits set for other pods, right? So, if there is any pod that has no request set and there are no limits set for all the other pods, then it's possible that any pod could consume all of the memory, all the CPU that's available on the node, and starve the pod. That has no request defined. So, just make sure that you have set requests for all the pods. 

So, a couple of things to note. The requests and limits may be different for each pod, but for the sake of simplicity, we are assuming that it's the same for both pods in these examples that I'm sharing here, right? But you can have absolutely different requests or limits set for containers, for each container within each pod. So, also note that these recommendations are just for CPU. 

So, let's look at how it works for memory next. So, it's kind of similar. So, if you look at the memory, let's say there are two, in the first case, there are two pods competing for memory resources on the cluster, and without a resource or limit set, one pod can consume all the memory resources on the node and prevent the second pod from getting the required resources. So, this is not ideal. 

Now, let's look at the case where we have no requests specified, but we do have limits specified, and in this case, Kubernetes automatically sets requests to the same as limits. So, for example, requests and limits are assumed to be 3GB in this case, and each pod is guaranteed 3GB and no more, as limits are also the same. 

The next one is where requests and limits are set. In this case, each pod gets a guaranteed amount of memory, which is 3GB and can go up to the limits defined, which is 3GB, but not more. 

And the last one is setting requests, but no limits. In this case, because requests are set, each pod is guaranteed 1 GB. However, because limits are not set, when available, any pod can consume as much memory as available, and if pod requests more memory to free up pod 1, the only option available is to kill it, because unlike CPU, we cannot throttle memory. Once memory is assigned to a pod, the only way to kind of retrieve it is to kill the pod and free up all the memory that is used by it. 

Okay, so now, as we discussed before, by default, Kubernetes does not have resource requests or limits configured for pods. But then, how do we ensure that every pod created has some defaults set? Now, this is possible with **limit ranges**. So, limit ranges can help you define default values to be set for containers in pods that are created without a request or limit specified in the pod definition files. This is applicable at the namespace level, so remember that. And this is an object, so you create a definition file with the API version set to v1, kind set to limit range, and we'll give it a name, CPU resource constraint. We then set the default limit to 500M, default request to the same as well. We will also specify a max CPU as 1 and a minimum as 100m. So, the max refers to the maximum limit that can be set on a container in a pod and minimum refers to the minimum request a container in a pod can make. So, these are, of course, some example values, not a recommendation or anything, so you must set whatever is best for your applications. 

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: cpu-resource-constraint
spec:
  limits:
    - default:
        cpu: 500m
      defaultRequest:
        cpu: 500m
      max:
        cpu: "1"
      min:
        cpu: 100m
      type: Container
```

So, the same goes for memory. Use memory instead of CPU and specify the defaults and max and min values in this form. Note that these limits are enforced when a pod is created. So, if you create or change a limit range, it does not affect existing pods. It will only affect newer pods that are created after the limit range is created or updated. 

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: memory-resource-constraint
spec:
  limits:
    - default:
        memory: 1Gi
      defaultRequest:
        memory: 1Gi
      max:
        memory: 1Gi
      min:
        memory: 500Mi
      type: Container
```

And finally, is there any way to restrict the total amount of resources that can be consumed by applications deployed in a Kubernetes cluster? For example, if we had to say that all the pods together shouldn't consume more than this much of CPU or memory, what we could do is create quotas at a namespace level. So, a resource quota is a namespace level object that can be created to set hard limits for requests and limits. 

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: my-resource-quota
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 4Gi
    limits.cpu: "10"
    limits.memory: 10Gi
```

In this example, this resource quota limits the total requested CPU in the current namespace to and memory to GB and it defines a maximum limit of CPU consumed by all the pods together to be and memory to be GB as well, right? So, that's another option that can be explored. Well, that's all for now. Refer to these pages on the Kubernetes documentation site for more information and head over to the Hands on labs and I'll see you in the next one. 

## DaemonSets

Hello, and welcome to this lecture. In this lecture, we look at DaemonSets in Kubernetes. So far, we have deployed various Pods on different nodes in our cluster. With the help of Replica Sets and Deployments, we made sure multiple copies of our applications are made available across various different worker nodes. DaemonSets are like ReplicaSets, as in it helps you deploy multiple instances of Pods. But it runs one copy of your Pod on each node in your cluster. Whenever a new node is added to the cluster, a replica of the Pod is automatically added to that node. And when a node is removed, the Pod is automatically removed. The Daemon Set ensures that one copy of the Pod is always present in all nodes in the cluster. So what are some use cases of DaemonSets? Say you would like to deploy a monitoring agent or log collector on each of your nodes in the cluster. So you can monitor your cluster better. A DaemonSet is perfect for that as it can deploy your monitoring agent in the form of a Pod in all the Nodes in your cluster. Then you don't have to worry about adding or removing monitoring agents from these Nodes when there are changes in your cluster, as the DaemonSet will take care of that for you. Earlier, while discussing the Kubernetes Architecture, we learned that one of the Worker Node components that is required on every Node in the cluster is a Kube Proxy. That is one good use case of DaemonSets, the kube-proxy component can be deployed as a daemon set in the cluster. Another use case is for networking, networking solutions like VNet require an agent to be deployed on each node in the cluster. We will discuss networking concepts in much more detail later during this course. But I just wanted to point it out here for now. 

Creating a DaemonSet is similar to the ReplicaSet creation process. It has nested pod specification under the template section and selectors to link the DaemonSet to the pods. A DaemonSet definition file has a similar structure. We start with the API version, kind, metadata, and spec. The API version is apps. We want kind is DaemonSet instead of ReplicaSet, we will set the name to monitoring daemon. Under spec, you have a selector and a pod specification template. It's almost exactly like the ReplicaSet definition, except that the kind is a DaemonSet. Ensure the labels in the selector match the ones in the Pod template. Once ready, create the DaemonSet using the kubectl create daemonset command. To view the created DaemonSet, run the kubectl get daemonset command. And of course to view more details on the kubectl describe daemonset command. 

So how does a DaemonSet work? How does it schedule Pods on each Node? And how does it ensure that every Node has a Pod? If you were asked to schedule a Pod on each Node in the cluster, how would you do it? In one of the previous lectures in this section, we discussed that we could set the node name property on the Pod to bypass the scheduler and get the Pod placed on a Node directly. So that's one approach. On each Pod, set the node name property in its specification before it is created. And when they are created, they automatically land on the respective Nodes. So that's how it used to be until Kubernetes version 1.12. From version 1.12 onwards, the DaemonSets uses the default scheduler and node affinity rules that we learned in one of the previous lectures to schedule Pods on nodes. 

## Static Pods

In this lecture, we discuss static pods in Kubernetes. Earlier in this course, we talked about the architecture and how the kubelet functions as one of the many control plane components in Kubernetes. The kubelet relies on the kube API server for instructions on what pods to load on its node, which was based on a decision made by the kube scheduler, which was stored in the etcd data store. What if there was no kube API server and kube scheduler and no controllers and no etcd cluster? What if there was no master at all? What if there were no other nodes? What if you're all alone in the sea by yourself, not part of any cluster? Is there anything that the kubelet can do as the captain on the ship? Can it operate as an independent node? If so, who would provide the instructions required to create those pods? Well, the kubelet can manage a node independently on the ship host, we have the kubelet installed. And of course, we have Docker as well to run containers. There is no Kubernetes cluster. So there are no kube API server or anything like that. The one thing that the kubelet knows to do is create pods. But we don't have an API server here to provide pod details. By now, we know that to create a pod, you need the details of the pod in a pod definition file. 

But how do you provide the pod definition file to the kubelet without a kube API server? You can configure the kubelet to read the pod definition files from a directory on the server designated to store information about pods. Place the pod definition files in this directory. The kubelet periodically checks this directory for files, reads these files, and creates pods on the host. Not only does it create the pod, it can ensure that the pod stays alive. If the application crashes, the kubelet attempts to restart it. If you make a change to any of the files within this directory, the kubelet recreates the pod for those changes to take effect. If you remove a file from this directory, the pod is deleted automatically. So these pods that are created by the kubelet on its own without the intervention from the API server or rest of the Kubernetes cluster components are known as **static pods**. 

Remember, you can only create pods this way; you cannot create ReplicaSets or Deployments or Services by placing a definition file in the designated directory. They're all concepts part of the whole Kubernetes architecture that requires other cluster plane components like the replication and deployment controllers, etc. 

The kubelet works at a pod level and can only understand pods, which is why it is able to create static pods this way. So what is that designated folder and how do you configure it? It could be any directory on the host. And the location of that directory is passed into the kubelet as an option while running the service. The option is named pod manifest path. And here it is set to etc Kubernetes manifest folder. 

```bash
# kubelet.service

ExecStart=/usr/local/bin/kubelet \
  --container-runtime=remote \
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \
  --pod-manifest-path=/etc/kubernetes/manifests \
  --kubeconfig=/var/lib/kubelet/kubeconfig \
  --network-plugin=cni \
  --register-node=true \
  --v=2
```

There's also another way to configure this. Instead of specifying the option directly in the kubelet.service file, you could provide a path to another config file using the config option and define the directory path as **static pod path** in that file. Clusters set up by the kubeadm tool use this approach. If you're inspecting an existing cluster, you should inspect this option of the kubelet to identify the path to the directory, you will then know where to place the definition file for your static pods. So keep this in mind when you go through the labs, you should know to view and configure this option, irrespective of the method used to set up the cluster. First, check the option pod manifest path in the kubelet service file. If it's not there, then look for the config option and identify the file used as the config file. And then within the config file, look for the static pod path option. Either of this should give you the right path. 

```bash
# kubelet.service

ExecStart=/usr/local/bin/kubelet \
  --container-runtime=remote \
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \
  --config=kubeconfig.yaml \
  --kubeconfig=/var/lib/kubelet/kubeconfig \
  --network-plugin=cni \
  --register-node=true \
  --v=2

# kubeconfig.yaml
staticPodPath: /etc/kubernetes/manifests
```


Once the static pods are created, you can view them by running the docker ps command. So why not the kubectl command as we have been doing so far. Remember, we don't have the rest of the Kubernetes cluster yet. So the kubectl utility works with the Kubernetes API server. Since we don't have an API server now, no kubectl utility, which is why we're using the Docker command. So then how does it work when the node is part of a cluster? When there is an API server requesting the kubelet to create pods, can the kubelet create both kinds of pods at the same time? Well, the way the kubelet works is it can take in requests for creating pods from different inputs. The first is through the pod definition files from the static pods folder, as we just saw. The second is through an HTTP API endpoint. And that is how the kube API server provides input to kubelet. The kubelet can create both kinds of pods, the static pods and the ones from the API server at the same time. Well, in that case, is the API server aware of the static pods created by the kubelet? Yes, it is. If you run the kubectl get pods command on the master node, the static pods will be listed as any other pod. 

Well, how is that happening? When the kubelet creates a static pod, if it is a part of a cluster, it also creates a mirror object in the kube API server. What you see from the kube API server is just a read-only mirror of the pod. You can view details about the pod, but you cannot edit or delete it like the usual pods. You can only delete them by modifying the files from the nodes manifest folder. Note that the name of the pod is automatically appended with the node name, in this case, node 01. 

So then why would you want to use static pods? Since static pods are not dependent on the Kubernetes control plane, you can use static pods to deploy the control plane components themselves as pods on a node. We'll start by installing kubelet on all the master nodes, then create pod definition files that use Docker images of the various control plane components, such as the API server, controller, etc. Place the definition files in the designated manifest folder. 

And the kubelet takes care of deploying the control plane components themselves as pods on the cluster. This way, you don't have to download the binaries, configure services, or worry about the services crashing. If any of these services were to crash, since it's a static pod, it will automatically be restarted by the kubelet. Neat and simple. That's how the kube admin tool sets up a Kubernetes cluster. Which is why when you list the pods in the kube-system namespace, you see the control plane components as pods in a cluster setup by the kube admin tool. We will explore that setup in the upcoming practice test. 

Before I let you go, one question that I get often is about the difference between static pods and DaemonSets. DaemonSets, as we saw earlier, are used to ensure one instance of an application is available on all nodes in the cluster. It is handled by a DaemonSet controller through the kube API server. Whereas static pods, as we saw in this lecture, are created directly by the kubelet without any interference from the kube API server or rest of the Kubernetes control plane components. Static pods can be used to deploy the Kubernetes control plane components itself. **Both static pods and pods created by DaemonSets are ignored by the kube scheduler.** The kube scheduler has no effect on these pods. Well, that's it for this lecture. Head over to the practice test and practice working with static Pods. 

## Multiple Schedulers

Hello and welcome to this lecture. In this lecture, we look at deploying multiple schedulers in a Kubernetes cluster. Now, we have seen how the default scheduler works in Kubernetes in the previous lectures. It has an algorithm that distributes pods across nodes evenly as well as takes into consideration various conditions we specify through taints and tolerations and node affinity, etc. But what if none of these satisfy your needs? Say you have a specific application that requires its components to be placed on nodes after performing some additional checks. So you decide to have your own scheduling algorithm to place pods on nodes so that you can add your own custom conditions and checks in it. **Kubernetes is highly extensible.** You can write your own Kubernetes scheduler program, package it and deploy it as the default scheduler or as an additional scheduler in the Kubernetes cluster. That way, all of the other applications can go through the default scheduler. However, some specific applications that you may choose can use your own custom scheduler. So your Kubernetes cluster can have multiple schedulers at a time. When creating a pod or a deployment, you can instruct Kubernetes to have the pod scheduled by a specific scheduler. 

So let's see how that's done. Now, when there are multiple schedulers, they must have different names so that we can identify them as separate schedulers. **So the default scheduler is named default scheduler**. And this name is configured in a kube-scheduler configuration file that looks like this. Now, the default scheduler doesn't really need one because if you don't specify a name, it sets the name to a default scheduler. But this is how it would look if you were to create one. And for the other schedulers, we could create a separate configuration file and set the scheduler name like this. 

```yaml
# my-scheduler-config.yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
profiles:
- schedulerName: my-scheduler
---
# my-scheduler-config2.yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
profiles:
- schedulerName: my-scheduler-2
```

```bash
# kube-scheduler.service
ExecStart=/usr/local/bin/kube-scheduler \
--config=/etc/kubernetes/config/kube-scheduler.yaml
```

```bash
# my-scheduler.service
ExecStart=/usr/local/bin/kube-scheduler \
--config=/etc/kubernetes/config/my-scheduler-config.yaml
# my-scheduler-2.service
ExecStart=/usr/local/bin/kube-scheduler \
--config=/etc/kubernetes/config/my-scheduler-2-config.yaml
```

```bash
wget https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/linux/amd64/kube-scheduler
```

So let's start with the most simple way of deploying an additional scheduler. Now, earlier, we saw how to deploy the Kubernetes kube-scheduler. We download the kube-scheduler binary and run it as a service with a set of options. Now, to deploy an additional scheduler, you may use the same kube-scheduler binary or use one that you might have built for yourself, which is what you would do if you needed the scheduler to work differently. In this case, we're going to use the same binary to deploy the additional scheduler. And this time, we point the configuration to the custom configuration file that we created. So each scheduler uses a separate configuration file, and with each file having its own scheduler name. And note that there are other options to be passed in such as the kubeconfig file to authenticate into the Kubernetes API. But I'm just keeping that for now just to keep it super simple. 

This is not how you would deploy a custom scheduler 99% of the time today, because with kubeadm deployment, all the control plane components run as a pod or a deployment within the Kubernetes cluster. So let's look at another way. So let's look at how it works if you were to deploy the scheduler as a pod. So we create a pod definition file and specify the kubeconfig property, which is the path to the scheduler.conf file that has the authentication information to connect to the Kubernetes API server. We then pass in our custom kube scheduler configuration file as a config option to the scheduler. Note that we have the scheduler name specified in the file. So that's how the name gets picked up by the scheduler. 

```yaml
# my-custom-scheduler.yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-custom-scheduler
  namespace: kube-system
spec:
  containers:
    - command:
        - kube-scheduler
        - --address=127.0.0.1
        - --kubeconfig=/etc/kubernetes/scheduler.conf
        - --config=/etc/kubernetes/my-scheduler-config.yaml
      image: k8s.gcr.io/kube-scheduler-amd64:v1.11.3
      name: kube-scheduler
---
# my-scheduler-config.yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
profiles:
  - schedulerName: my-scheduler
```


Now, another important option to look here is the leader elect option. And this goes into the kube scheduler configuration. The leader elect option is used when you have multiple copies of the scheduler running on different master nodes as in a high availability setup where you have multiple master nodes with the kube scheduler process running on both of them. If multiple copies of the same scheduler are running on different nodes, only one can be active at a time. And that's where the leader elect option helps in choosing a leader who will lead the scheduling activities. So we will discuss more about HA setup in another section. In case you do have multiple masters, just remember that you can pass in this additional parameter to set a log object name. And this is to differentiate the new custom scheduler from the default election process. 

```yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
profiles:
  - schedulerName: my-scheduler
leaderElection:
  leaderElect: true
  resourceNamespace: kube-system
  resourceName: lock-object-my-scheduler
```

So just proceeding with our lecture. So when you run the get pods command in the kube-system namespace, you can then see the new custom scheduler running. So this is if you run it as a pod. And if you run it as a deployment, then you'll probably see a slightly different naming convention, but you'll be able to see the pod there. Just make sure you're checking the right namespace. Now once we have deployed that custom scheduler, the next step is to configure a pod or a deployment to use this new scheduler. So how do you use our custom scheduler? So here we have a pod definition file. And what we need to do is add a new field called scheduler name and specify the name of the new scheduler. And that's basically it. This way, when the pod is created, the right scheduler gets picked up and the scheduling process works. Now, we now create the pod using the kubectl create command. If the scheduler was not configured correctly, the pod will continue to remain in a pending state. And if everything is good, then the pod will be in a running state. So if the pod is in a pending state, then you can look at the logs on the pod under the pod describe command, the kubectl describe command. And you'll mostly notice that the scheduler isn't configured correctly. 

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
    - image: nginx
      name: nginx
  schedulerName: my-custom-scheduler
```

Now, how do you know which scheduler picked it up? So we have multiple schedulers. How do you know which scheduler picked up scheduling a particular pod? Now, we can view this in the events using the kubectl get events command with the -o wide option. And this will list all the events in the current namespace and look for the scheduled events. And as you can see, the source of the event is the custom scheduler that we created. That's the name that we gave to the custom scheduler. And the message says that successfully assigned the image. So that indicates that it's working. You could also view the logs of the scheduler in case you run into issues. So for that, view the logs using the kubectl logs command and provide the scheduler name, either the pod name or the deployment name, and then the right namespace.

## Configuring Kubernetes Scheduler

Let us now look at what scheduler profiles are. So let's first recap how the Kubernetes scheduler works using this simple example of scheduling a Pod to one of these four nodes that you can see here that are part of the Kubernetes cluster. So here we have our pod definition file and there's our pod. It is waiting to be scheduled on one of these four nodes. Now it has a resource requirement of CPU. So it's only going to be scheduled on a node that has CPU remaining. And you can see the available CPU on all of these nodes that are listed here. Now it is not alone. There are some other Pods that are waiting to be scheduled as well. 

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: simple-webapp-color
spec:
  priorityClassName: high-priority
  containers:
    - name: simple-webapp-color
      image: simple-webapp-color
      resources:
        requests:
          memory: "1Gi"
          cpu: 10
```

So the first thing that happens is that when these Pods are created, the Pods end up in a **scheduling queue**. So this is where the Pods wait to be scheduled. So at this stage, Pods are sorted based on the priority defined on the Pods. So in this case, our pod has a high priority set. So to set a priority, you must first create a **priority class** that looks like this. And you should set it a name and set it a priority value. In this case, it's set to 1 million. So that's really high priority. So this is how pods with higher priority get to the beginning of the queue to be scheduled first. And so that sorting happens in this scheduling phase. 

Then our pod enters the **filter phase**. This is where nodes that cannot run the Pods are filtered out. So in our case, the first two nodes do not have sufficient resources or do not have 27 CPU remaining. So they are filtered out. 

The next phase is the **scoring phase**. So this is where nodes are scored with different weights. From the two remaining nodes, the scheduler associates a score to each node based on the free space that it will have after reserving the CPU required for that pod. So in this case, the first one has two left and the second node will have six left. So the second node gets a higher score. And so that's the node that gets picked up. 

And finally, in the **binding phase**, this is where the pod is finally bound to a node with the highest score. 

Now all of these operations are achieved with certain plugins. For example, while in the scheduling queue, it's the **priority sort plugin** that sorts the Pods in an order based on the priority configured on the Pods. This is how pods with a priority class get a higher priority over the other pods when scheduling. In the filtering stage, it's the **node resources fit plugin** that identifies the nodes that have sufficient resources required by the pods and filters out the nodes that don't. Now some other plugin examples that come into this particular stage are the **Node Name plugin** that checks if a Pod has a Node Name mentioned in the Pod spec and filters out all the nodes that do not match this name. Another example is the **node unschedulable plugin** that filters out nodes that have the unschedulable flag set to true. So this is when you run the drain, the cordon command on a node, which we will discuss later. All the nodes that have the unschedulable flag set to true, it's this particular plugin that makes sure that no pods are scheduled on those nodes. 

Now in the scoring phase, again, the node resources fit plugin associates a score to each node based on the resources available on it and after the pod is allocated to it. So as you can see, a single plugin can be associated in multiple different phases. Another example of a plugin in this stage would be the **image locality plugin** that associates a high score to the nodes that already have the container image used by the pods among the different nodes. Now note that at this phase, the plugins do not really reject the pod placement on a particular node. For example, in case of the image locality node, it ensures that Pods are placed on a node that already has the image, but if there are no Nodes available, it will anyway place the Pod on a node that does not even have the image. So it's just a scoring that happens at this stage. And finally, in the binding phase, you have the **default binder plugin** that provides the binding mechanism. 

Now the highly extensible nature of Kubernetes makes it possible for us to customize what plugins go where and for us to write our own plugin and plug them in here. And that is achieved with the help of what is called as **extension points**. So at each stage, there is an extension point to which a plugin can be plugged in. In the scheduling queue, we have a queue sort extension to which the priority sort plugin is plugged to. And then we have the filter extension, the score and the bind extension to which each of these plugins that we just talked about are plugged to. As a matter of fact, there's more. So there are extensions before entering the filter phase called the **pre-filter extension** and after the filter phase called **post-filter**. And then there are pre-score before the score extension point and reserve after the extension point and the score extension point. And then there is pre-bind and post-bind before the bind and post-bind after the binding phase. So there are so many options available. Basically, you can get a custom code of your own to run anywhere in these pods by just creating a plugin and plugging it into the respective kind of service that you want to plug it to. 

And here is a little bit more detail on some additional plugins that come by default that are associated with the different extension points. As you can see, some of the plugins span across multiple extension points and some of them are just within a specific extension point. So that's what scheduling plugins and extension points are. So the highly extensible nature of Kubernetes allows us to customize the way that these plugins are called and write our own scheduling plugin if needed. 

So having learned that, let's look at how we can change the default behavior of how these plugins are called and how we can get our own plugins in there if it's really needed. So taking a step back, earlier we talked about deploying three separate schedulers each with a separate scheduler binary. So we have the default scheduler and then the my scheduler and then the my scheduler 2. Now all of these are three separate scheduler binaries that are run with a separate scheduler configuration file associated with each of them. Now that's one way to deploy multiple schedulers. Now the problem here is that since these are separate processes, there is an additional effort required to maintain these separate processes. And also, more importantly, since they are separate processes, they may run into race conditions while making scheduling decisions. For example, one scheduler may schedule a workload on a node without knowing that there's another scheduler scheduling a workload on that same node at the same time. So with the 1.18 release of Kubernetes, a feature to support multiple profiles in a single scheduler was introduced. So now you can configure multiple profiles within a single scheduler in the schedule configuration file by adding more entries to the list of profiles. And for each profile, specify a separate scheduler name. So this creates a separate profile for each scheduler, which acts as a separate scheduler itself, except that now multiple schedulers are run in the same binary as opposed to creating separate binaries for each scheduler. 

```yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
profiles:
  - schedulerName: my-scheduler-2
    plugins:
      score:
        disabled:
          - name: TaintToleration
        enabled:
          - name: MyCustomPluginA
          - name: MyCustomPluginB

  - schedulerName: my-scheduler-3
    plugins:
      preScore:
        disabled:
          - name: '*'
      score:
        disabled:
          - name: '*'

  - schedulerName: my-scheduler-4
```

Now how do you configure these different scheduler profiles to work differently? Because right now all of them just simply have different names. So they're going to work just like the default scheduler. How do you configure them to work differently? Under each scheduler profile, we can configure the plugins the way we want to. For example, for the MyScheduler2 profile, I'm going to disable certain plugins like the Taints and Tolerations plugin and enable my own custom plugins. For the MyScheduler3 profile, I'm going to disable all the Prescore and Score plugins. So this is how that's going to look. Under the plugin section, specify the extension point and enable or disable the plugins by name or a pattern as shown in this case. So yeah, so that's about it. I hope that gives you an overview of how schedulers and scheduler profiles work and how you can configure multiple scheduler profiles in Kubernetes. To read more about this, check out the Kubernetes enhancement proposal that introduced multi-scheduling profiles. It's the CAP-1451 that introduced the multi-scheduling profiles and the article on the scheduling framework. Well, that's all for now, and I will see you in the next one. 

> https://github.com/kubernetes/enhancements/blob/0e4d5df19d396511fe41ed0860b0ab9b96f46a2d/keps/sig-scheduling/1451-multi-scheduling-profiles/README.md

> https://kubernetes.io/docs/concepts/scheduling-eviction/scheduling-framework/