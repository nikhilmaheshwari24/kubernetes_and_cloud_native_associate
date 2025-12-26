## Autoscaling

Okay, let's look at autoscaling in Kubernetes and the different types of autoscaling features that are available. Now autoscaling refers to automatically adjusting the number of resources such as servers or virtual machines or application instances, based on the demand for an application or service. This ensures that the application can handle spikes or drops in traffic without overloading or underutilizing resources. And to achieve true CloudNative autoscaling, three factors are essential. Firstly, both the application and infrastructure must be designed to scale effectively. This means that as demand fluctuates, the system can easily adjust the number of resources allocated to meet the needs of the user. Secondly, autoscaling must be automatic, of course, to effectively adapt to changing demand. The system should be able to monitor the workload and allocate additional resources as needed without manual intervention. And finally, autoscaling must be bidirectional, allowing the system to scale up and down as demand fluctuates. This ensures that the application can handle sudden spikes in traffic while also efficiently utilizing resources during periods of low demand, saving costs and increasing efficiency. 

Before diving deeper into Kubernetes autoscaling, it's important to first understand the concepts of horizontal and vertical scaling. Adding more resources to each unit is known as vertical scaling. While adding more units itself is known as horizontal scaling. Vertical scaling is often limited by the maximum capacity of the server, whereas horizontal scaling can be more flexible and can provide better fault tolerance. Now, Kubernetes offers three distinct autoscaling features to help manage and optimize resources efficiently. Horizontal Pod Autoscaler and Vertical Pod Autoscaler are for scaling the Pods and Cluster Autoscaler is for scaling the cluster itself. So let's dive deeper into each one of these and understand their unique functionalities. 

## Horizontal Auto Scaling

Let's start by looking at Horizontal Pod Autoscaler. Now, as the name suggests, Horizontal Pod Autoscaler scales the pods horizontally, meaning when load increases, it deploys more pods on the system, and when load decreases, it deletes the pods. Now, the Horizontal Pod Autoscaler is just another controller among the various Kubernetes controllers that we've already seen. So typically, Pods are created as Deployments on the system, so all the HPA needs to do is play around with the number of Replica Sets in the Deployment. So when load increases, increase the number of replicas in the deployment, and when load decreases, it decreases the number of replicas in the system. Now, the Horizontal Pod Autoscaler also needs input on understanding the resource utilization. So it monitors the resource utilization via the metrics server. So the metrics server continuously monitors and collects resource utilization information from the nodes in the cluster as well as the Pods, so that's something that the HPA can rely on to identify how the Pods are consuming resources. 

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myapp:latest
        resources:
          limits:
            cpu: 500m
          requests:
            cpu: 200m
```

So let's take a look at an example. So here we have a Deployment with an image and with a CPU limit set to 500M, and we then create a Horizontal Pod Autoscaler object. This has API version set to **autoscaling/v2beta2**, the kind set to Horizontal Pod Autoscaler, and we specify a name, myapp-hpa. We then specify the scale target ref, which is how we target a specific object. So there may be so many Pods and Deployments in the cluster, but we want this Horizontal Pod Autoscaler to only target a specific Deployment, and only scale up and down that particular Deployment. So that's what this scale target refers to. So you must specify the kind, which is Deployment, and the name. In this case, it's set to myapp. We then specify the minimum replicas as and the max replicas as 10. This defines on what basis the Horizontal Pod Autoscaler will scale the replicas. In this case, it's the CPU resource. The HPA is configured to scale the myapp Deployment based on CPU utilization with a target average utilization of 50%. So it will scale the number of replicas anywhere between and 10. And finally, we create the HPA using the create command. 

```yaml
apiVersion: autoscaling/v2beta2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```

Now, once created, to view the created Horizontal Pod Autoscaler, run the kubectl get hpa command. In this output, the targets column shows the current as well as the average CPU utilization as a percentage of the target utilization. So the min pods and max pods columns show the minimum and maximum number of pods that the Horizontal Pod Autoscaler will maintain. The replicas column shows the current number of replicas, and the age column shows how long the Horizontal Pod Autoscaler has been running. And to delete it, run the kubectl delete-hpa command. 

```bash
kubectl get hpa
kubectl delete hpa myapp-hpa
```

## Vertical Auto Scaler

Let us now look at Vertical Pod Autoscaler. Now let's first revisit resource requirements for Pods in a cluster. So, for instance, let's consider a simple web application deployed in a pod. And in the pod specification, you might specify resource requests and limits. Now resource requests are what the container is guaranteed to get. So if a container requests a resource, Kubernetes will only schedule it on a node that can give it that resource. In this example, the container requests 64 megabytes of memory and 250 CPU units. That's milli of CPU. The resource limits, on the other hand, make sure a container never goes above a certain value. So the container is only allowed to go up to the limit, and then it is restricted. And in this example, it has limits of 128 megabytes of memory and 500 milli CPU units. 

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myapp:latest
        resources:
          limits:
            cpu: 500m
            memory: "128Mi"
          requests:
            cpu: 250m
            memory: "64Mi"

```

Now Kubernetes will try to maintain these limits and requests for the Pods as it's running. Now let's imagine that our web app starts to get a lot more traffic. The current resources might not be enough to handle the increased load, and the app might start to struggle. And if it hits the limits specified, the pod may become unstable or even crash due to lack of resources. And this is a clear problem, and it's where the **Vertical Pod Autoscaler** comes in. 

Now the VPA automatically adjusts the amount of CPU and memory allocated to Pods in response to changing conditions. So this can help to ensure that your pods have the resources they need to operate effectively even as demand increases or decreases. Now let's take a closer look at the VPA. So the VPA has three components. A **recommender** that monitors the resource usage of the Pods from the metric server. So that's how it learns of the resource utilization of the Pods. Suppose after some time the recommender notices that the Pods usage frequently approaches or even exceeds its specified limits. For instance, it consistently uses 190 megabytes of memory of its 192 that's available, or 700 milli of CPU limit of 750 the that's available. So based on this observation, the recommender might determine that the web app pod would benefit from having more resources available to it, and it might recommend increasing the memory request and limit to, say, 128 megabytes of memory and 256 megabytes respectively, and the CPU request and limit to 500 CPU units. 

So the next component is the **VPA updater**. So once the recommender has made its recommendations, the VPA updater checks the current state of the pod, and it sees that the pod's current resource allocation does not match the recommender's suggestion. So if the updater notices that there's a difference, as it is in this case, it will take the necessary actions to align the pod's resources with the recommender's suggestion. However, it's important to note that the updater can't just change the resource request of a running pod directly. Kubernetes does not allow for changing the resource request of a running pod because it could potentially disrupt the scheduling of other pods in the system. But without that, the updater's way of implementing the recommender's suggestion is to evict the pod. **In Kubernetes terms, evicting a pod is a polite way of saying that the pod is asked to shut down.** Now note that there is an update in version 1.28 release of Kubernetes that **allows in-place update of pod resources** (KEP 1287). So with that out, there may not be a need to evict the Pods once the changes have been updated to the VPA. But as of now, this is how it works. 

So the Kubernetes scheduler then automatically creates a new pod, and because the previous one was evicted, as part of the deployment's desired state to maintain a certain number of pods running, and when the new pod is created, it goes through the Kubernetes admission process. So this is where the **VPA admission controller** comes in. So the admission controller intercepts the new pod creation request and updates the pod's resource request to align with the recommender's suggestions, in this case, a CPU request of 500m and memory request to 128Mi, as well as the others that you see here. 

```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: 250m
  limits:
    memory: "128Mi"
    cpu: 500m
```

Now, you can decide if you want the VPA updater to evict the pod or not. You can configure VPA to only recommend and not actually make any changes to the pods. If you want to be safe and if you want to make sure the recommendations are right first before actually making those changes. So that's done by configuring a policy on the VPA called **update policy**. So this update policy has an update mode that can be set to **off**, **initial**, or **auto**. 

- So off means the VPA will not automatically update the resource requests of the Pods. It will only recommend changes and it's up to the administrator to manually apply these changes if desired. So the VPA recommender will still monitor the pod's resource usage and provide recommendations, but the updater will not act on those recommendations. 

- Initial, so this mode allows the VPA to automatically update the resource requests of pods, but only when they're first created. In other words, the updater will not evict running pods to update the resources, and this mode can be useful if you want to avoid the potential disruption of pod evictions, but still want the VPA to set optimal resource requests for new pods. 

- And auto, so this mode allows the VPA to automatically update the resource requests of Pods, both when they're first created and throughout their lifecycle. And if the VPA recommender determines that a running pod's resource should be updated, so the updater will evict the pod to implement the recommended changes, at least prior to version 1.28 release of Kubernetes. And this is the most aggressive mode and can result in frequent pod evictions, but it ensures that the Pods are always running with optimal resource requests as determined by the VPA recommender. 

So let's see how we set this all up. So the first thing that you have to do is deploy the VPA components to the cluster. So this is not running by default. The VPA is not available on a Kubernetes cluster by default. There are some actions that you have to take to deploy the different components that we just discussed. So this can be easily done by cloning the Kubernetes Horizontal Pod Autoscaler GitHub repository, and then CD into the VPA folder, and then there's a hack script that's available that just brings up the VPA components. And what this basically does is deploys the necessary components as Deployments and creates objects like RBAC, Role-Based Access Controls, and other things that are needed for the VPA to work on the cluster. 

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
        memory: "64Mi"
        cpu: 250m
      limits:
        memory: "128Mi"
        cpu: 500m
```

Now once that is done, the first thing that we have to do to configure VPA is to create a VPA object. So the API version is autoscaling.k8s.io, so that's V1. Kind is a Vertical Pod Autoscaler. We will name it webapp-vpa, and the target reference is pod named simple webapp-color. So same as the HPA, this is how you configure the target ref. And note that I'm setting the update mode to off, as I don't want the VPA to make any changes to my Pods, instead only recommend changes. Now once created and after the VPA is running for a while, you can retrieve these recommendations using the kubectl describe command. View the VPA object using the describe command, and you'll see that the target, there's a section called recommendations, and within that you have the recommendations. So the target values represent the current VPA recommendations. The lower bound and upper bound values represent the recommended range for the resources based on the observed usage. So note that these are basic examples, and actual usage may require more complex configurations depending on your use case. 

```yaml
apiVersion: "autoscaling.k8s.io/v1"
kind: VerticalPodAutoscaler
metadata:
  name: webapp-vpa
spec:
  targetRef:
    apiVersion: "v1"
    kind: Pod
    name: simple-webapp-color
  updatePolicy:
    updateMode: "Off"
```

So the VPA needs to be enabled in your Kubernetes cluster, and you need to have the necessary permissions to deploy and manage it. So if you are on a managed cluster or something, make sure you check if it's available on your solution. So that's a higher level overview of vertical pod autoscalers.

## Cluster Autoscaler

Now let's look at Cluster Autoscaler. Now in the resource requirements lesson we talked about how pods consume resources on the cluster and that the Kubernetes scheduler is responsible for placing the pods on the nodes and it places the pods on nodes with resources and with the placement of each pod how resources on a cluster get accumulated. And what if there are no more resources available on the nodes in the cluster? Well the scheduler does not place a pod on the nodes, instead it puts them in a pending state. And this is where the Cluster Autoscaler comes in if you want to automatically scale up the number of nodes in the cluster. So the Cluster Autoscaler can provision additional nodes in the cluster thereby adding more resources in the cluster to provision more pods. 

But because this requires provisioning new compute instances, it is very dependent on the underlying solution or the underlying cloud provider that you have. So a list of supported cloud providers can be found at this link and each may have its own specific requirements and capabilities. For example, this is how a Cluster Autoscaler is configured on Google Cloud. So when you create a Kubernetes cluster, specify the Cluster Autoscaler option and in this case you have the minimum nodes set to and maximum set to 10. And depending on how many pods are pending creation due to insufficient resources, the Cluster Autoscaler increases or decreases the number of nodes in the cluster. Now as mentioned this is different for different cloud providers, so check out more details specific to your cloud provider of interest using the links in the documentation pages. Well that's a quick overview of Cluster Autoscaler for now and that's all required in the scope of this exam. Thanks for watching and I'll see you in the next one. 

## Serverless

Imagine you want to have a birthday party at home, but you don't want to clean up after all your friends leave. So you hire a cleaning team to take care of everything. So before the party, they clean the house from top to bottom and set everything up. And during the party, they keep things tidy and make sure everything is running smoothly. And after the party, they come back and clean up all the mess so you don't have to worry about a thing. 

Now, let's apply this idea to computing. In the traditional model, if a company wanted to have a website or app, they would have to buy or rent a server, set it up, and manage it themselves. But with serverless computing, they don't have to worry about any of that. It's like hiring a cleaning team to take care of everything for you. You don't have to worry about managing the servers or infrastructure. The cloud provider takes care of all of that for you. The routine work of provisioning, maintaining and scaling the server infrastructure and all of that is taken care of by the cloud provider. However, there are still tasks that need to be performed within the application, right? The business logic, such as resizing images or sending notifications, sending emails, you know, the business logic itself. This is where function as a service or FaaS, a serverless way of executing a piece of code, comes in. 

So what is function as a service? So the function as a service or FaaS is like having a team of helpers who take care of specific tasks during the party. Like, for example, you might have a helper who greets guests at the door or when a guest arrives, another helper who serves drinks for new guests and another helper who makes sure everyone is having fun. And each helper has a specific job to do at a specific time and they don't have to worry about anything else. Similarly, with FaaS, a company can write small pieces of code that do specific tasks like resizing pictures, sending emails, or pushing notifications. These pieces of code are uploaded to a cloud provider, which runs them whenever they are needed, where functions are triggered by a specific event, such as messaging queues, HTTP requests, etc. 

Now, one of the benefits of FaaS is the pay-as-you-go model, which means the company only pays for the computing resources they use rather than having to pay for a whole server all the time. It's like having a team of helpers who take care of specific tasks for your website or app, and you only pay them for the time they spend working. Now, this makes it more cost-effective for companies, especially if they have unpredictable traffic or usage patterns. So with FaaS, not only do you get the benefits of serverless computing, but you also get a more flexible and affordable way to manage your computing resources. Now, the most common forms of serverless computing are function-as-a-service, where developers write custom server-side code that is run in containers that are managed by a cloud service provider. 

Now, let's say you run a small online store that sells t-shirts and you want to be able to send a confirmation email to customers after they make a purchase, but you don't want to spend time and money managing an email server or writing code to handle sending the email. Using a platform like FaaS, like AWS Lambda, you can write a simple function that sends the confirmation email using an email service like SendGrid or Amazon SES. The function would be triggered automatically when a customer makes a purchase, and the FaaS platform would handle autoscaling the function based on the number of requests. 

Now, several major public cloud providers, including Amazon Web Services, Microsoft Azure, Google Cloud, and IBM Cloud, offer FaaS offerings for developers. So Amazon has AWS Lambda, AWS Fargate, Azure has Azure Functions, and Google has Google Cloud Functions. Kubernetes serverless is a term that refers to using Kubernetes, an open-source container orchestration platform, to run serverless workloads. Now, in a traditional Kubernetes environment, containers are deployed and managed as part of a cluster of servers or virtual machines. Now, Kubernetes provides features such as automatic scaling, load balancing, and self-healing to ensure that containers are always running and available to serve requests. However, with the rise of serverless computing, Kubernetes has evolved to support serverless workloads as well. This means that developers can write serverless functions or small pieces of code that run in response to events and deploy them to a Kubernetes cluster. 

Now, Kubernetes serverless platforms, such as **Knative** or **OpenFaaS**, provide a way for developers to deploy and manage serverless functions on top of Kubernetes. These platforms handle the scaling, event triggering, and lifecycle management of serverless functions, allowing developers to focus on writing code. By combining the benefits of Kubernetes, such as scalability and reliability, with the benefits of serverless computing, such as reduced operational costs and improved developer productivity, Kubernetes serverless platforms provide a powerful platform for building modern applications.

## Kubernetes Enchancemnet Proposal

As Kubernetes gets more and more popular, people have lots of different ideas about how it can be improved. And we need a standard procedure to collect ideas, document them, identify why it needs to go in in the first place, and discuss them and implement them, and then also make sure that it goes through the different release cycles of alpha, beta, and finally GA. And that's where Kubernetes Enhancement Proposals or KEPs come in. 

Now if you ever wanted to know more about why a big change was made in Kubernetes, for example recently we had a major change where service tokens were not being automatically created, instead you had to create your own manually, and if you wanted to know the motivation behind why this change was made, then you should be looking at the associated KEP. I'll show you how to review that particular KEP later in this video. 

So say you have an idea for a new feature that would make it easier for people to use Kubernetes, or a new way to improve the security of the system, you would write a KEP to explain your idea, and then other people could read and give their own suggestions or feedback. The KEP process makes it easy for users to track ongoing development and improvement efforts, as well as providing a way for Kubernetes to stay up to date with changes in the industry. So KEPs are a way for people to share their ideas and work together to make Kubernetes even better. 

If you have worked with projects on GitHub as it is for Kubernetes, you know that you have GitHub issues where you can report bugs and create feature requests, and then why do we need KEPs? Why not just use GitHub issues? But first, KEPs provide a standard way for members of the community to propose and discuss ideas, which makes it easier for everyone to understand and participate in the process. Secondly, KEPs allow for more detailed and structured discussions, which can help the community to more carefully consider and evaluate proposed changes. GitHub issues are not enough for SIGs to signal their approval or rejection of a proposed change. Anybody can open an issue at any time, and managing changes across multiple releases is cumbersome, as you'll have to label and milestone each one, and it needs to be updated, and each release changes everything. And this leads to a growing number of open issues in Kubernetes features, which then need to be managed. And additionally, it can be difficult to search through the text within an issue, and the flat hierarchy of issues can limit navigation and categorization. 

Now, all KEPs follow a standard naming convention. They have a four-digit number, followed by a short and descriptive title, and every KEP must be properly documented. It must start with a summary, followed by a set of goals and non-goals, which clearly defines what the motivation is behind this proposal, and then a user story as part of the proposal, along with risks and mitigations. And as any feature request, it must have test plans and graduation criteria. 

Now, KEPs are grouped by SIGs. SIGs, if you don't know yet, are **special interest groups** for Kubernetes. So, Kubernetes SIGs are special interest groups that deal with different aspects of the Kubernetes ecosystem. For example, there is a SIG for applications, cluster lifecycle, data management, networking, storage, and security, and each SIG has its own directory where KEPs related to its area of focus are stored. 

So, SIG members vote on whether or not to accept a proposal, and if it is accepted, the change is implemented in the future releases of Kubernetes. And this process ensures that proposed changes are carefully considered before being accepted into the system. For example, this KEP on Kubernetes dry run that was created over two years ago details the need for the dry run feature, which we all know today is very beneficial. It helps send requests to the endpoints and see what would have happened without having it actually happening. As you can see, this proposal includes a test plan, the graduation criteria, and a proposal that details what works or on what API endpoints will have this implemented, and also how it will be implemented. Below it also includes examples of how it could be used with the kubectl command line utility. 

Now, this is another interesting KEP that was recently released called the Bound Service Account Tokens, and this KEP was proposed to mitigate some of the security concerns with the way tokens were provisioned. So, as you might know already, JWT or JSON Web Tokens are like the Wild West of authentication. Once anyone gets their hands on them, they can pretend to be whoever they want. So, this is because JWTs are not tied to a specific audience in this case. On top of that, the way that service account tokens are stored and delivered in Kubernetes is like leaving a giant target on the control plane's back for attackers to aim at. And if a JWT token is stored in a service account, does get stolen, it's like a lifetime supply of free access to whatever it was protecting, unless you manually rotate the keys, which nobody does because it's a huge pain. Plus, using JWTs like this requires creating a ton of secrets, which is just not scalable. So, this particular KEP introduced a token request API that will generate tokens on demand bound to an audience with an expiry date. The KEP then goes on to propose how this will be implemented, and some example code showing this in action. There are test plans defined as well. And below, you have graduation criteria that explains how each feature within this KEP will progress to GA. The token request API goes out as alpha for version 1.10, then beta for version 1.12, and GA in version 1.20. 

Every KEP goes through the following lifecycle. At the **provisional state**, the KEP is proposed and is being defined. At this stage, the SIG has accepted that this work must be done. And after the approvers have approved the KEP for implementation, it moves to the **implementable state**, and then into the **implemented state**. If it's not being worked on, then it goes to the deferred state. And if approvers decide to not proceed with this KEP, then it goes into the rejected state. Withdrawn is when the author withdraws the KEP, and replaced is when the KEP is replaced by a new KEP. 

## Kubernetes SIG

Kubernetes is one of the most popular open source projects today. On GitHub, it has over 80,000 stars, 2,500 contributors, 150,000 comments, 83,000 pull requests, over million contributions as of this recording. As you probably already know, Kubernetes is a platform that helps orchestrate container-based applications. Big companies like Google, Microsoft, and AWS have all been using Kubernetes and providing hosting solutions for Kubernetes and have been the biggest contributors to the Kubernetes project. So back in 2014, Google developed the Kubernetes project to help make it easier to manage containerized applications across lots of different hosts. The idea was to automate and scale distributed systems. So the first commit to the repo was made on June 6th, 2014. And in 2016, Kubernetes joined the CloudNative Computing Foundation or CNCF. This just made it even more popular as a really important platform for container orchestration. 

When Kubernetes first started, there were only a few developers working on it. But as time went on and people began to see the value in the project, more and more developers started contributing to it. With developers working on it in the early days, Kubernetes reached active developers after joining CNCF. And today, the Kubernetes community is thriving with over 3,000 contributors. The growth in contributors has been consistent over time, as shown by the chart published by the CNCF report on Kubernetes that demonstrates how the number of contributors to the Kubernetes project has increased over the past few years. Managing a large scale project like Kubernetes requires careful planning and execution to ensure success. 

Imagine building a massive skyscraper in the heart of a bustling city. You need to manage everything from construction workers to the supply chain, equipment, and safety regulations. If every worker tried to oversee every aspect of the project, it would quickly become chaotic and mistakes would be made. 

Similarly, managing the Kubernetes project with its vast scope and scale requires a similar level of management. There's the architecture to work with, the security, the API and CLI, Autoscaling, integrations with different cloud providers. You need someone to just manage all documentation. And then there is Networking, Storage, and many more. This is where project management comes in. For typical projects, it is essential to have a system in place that manages everything from feature development to bug fixing to testing and release cycles. But managing such a large project can be challenging. There are simply too many areas to manage effectively without a robust system in place, especially considering the fact that it's an open-source project and that there is no single organization or entity responsible for funding and overseeing the project end to end. 

So how is such a large open source project with thousands of contributors working together? This is where the Kubernetes community governance model comes in. At the top, you have the Kubernetes steering committee, which is a group of individuals responsible for overseeing the overall direction of the Kubernetes project. The committee is made up of a diverse group of contributors who are chosen based on their contributions to the Kubernetes community, as well as their expertise in various areas of the project. The Kubernetes steering committee is responsible for making decisions on issues that affect the project as a whole, such as setting priorities for new features and enhancements, resolving conflicts between different parts of the project, and defining the overall architecture of the system. It is this steering committee that provides guidance to working groups and SIGs, or known as special interest groups within the Kubernetes community, which we will discuss in a few minutes. 

As of this recording, the members of the steering committee are Benjamin Elder from Google, Christoph Blecker from Red Hat, Carlos Taddeu Panato Jr. from ChainGuard Inc., Stephen Augustus from Cisco, Bob Killen from Google, Nabarun Pal from VMware, and Tim Pepper from VMware. And then we have working groups and special interest groups or SIGs. Now working groups in the Kubernetes community are like teams that come together to work on specific issues. They're helpful when a problem requires input from people with different expertise and when cuts across different areas of the project, such as across different SIGs. 

And that brings us to the topic of this video, Kubernetes special interest groups called SIGs. SIGs are groups of contributors within the Kubernetes community who are responsible for managing specific areas of the project. For example, just as you would have a team of architects who specialize in designing the structure of a skyscraper, Kubernetes SIG has a SIG for architecture that maintains and evolves the design principles of Kubernetes and provides a consistent body of expertise necessary to ensure architectural consistency over time. So having SIGs ensures that teams can focus on specific areas of the project rather than trying to oversee everything at once. This allows for more streamlined development and a faster pace of innovation. Additionally, SIGs help in ensuring that the project remains organized and that different teams are not stepping on each other's toes. 

So here are some of the key tasks that SIGs typically undertake. Number one, code development. So SIGs may work on developing new features, fixing bugs, and enhancing the codebase of Kubernetes. And number two, testing and validation. So SIGs are responsible for overseeing, testing, and validating the functionality of Kubernetes releases, ensuring that they meet the community quality standards. Documentation. So SIGs work on developing and maintaining the documentation for Kubernetes, including user guides, reference materials, and API documentation. For community outreach and education. So SIGs organize and participate in community events, such as meetups, webinars, and conferences to educate users about Kubernetes and to promote community engagement. Release management. So SIGs are responsible for managing the release process for Kubernetes, including coordinating feature development, bug fixes, and documentation updates. SIGs also provide guidance and leadership on the architecture and design of Kubernetes, ensuring that it remains scalable, reliable, and maintainable. 

So now that you have a group of people under a SIG looking after a specific area, how do they collaborate and go about getting things done? SIGs collaborate in an open and inclusive manner. The discussions and meetings of these SIG groups are open to anyone who wants to participate. They are typically conducted online using video conference tools and chat rooms. And some of the other commonly used communication channels are mailing lists or Slack groups and Slack channels, GitHub issues, and pull requests. SIG members hold regular meetings, which are open to the public and announced on the Kubernetes community calendar. So during these meetings, they discuss ongoing work, review proposals, and make decisions about the future direction of Kubernetes development. SIG meetings are often recorded and made available online for later viewing. We'll add a link here for you to view a few of the previous SIG meetings that are available on YouTube. SIGs collaborate on technical specifications and design proposals using the Kubernetes Enhancement Proposal process, or KEPs. So KEPs are used to propose changes to the Kubernetes project and to gather feedback and consensus from the community. Now SIG members can review and provide feedback on KEPs via GitHub and the Kubernetes mailing list and through the SIG meetings that are held. Now each SIG has its own focus and is led by a chair or co-chairs who help facilitate discussions and make decisions. You can see a list of SIGs and their co-chairs, a link to their Slack channel, mailing list, and meetings on this page. Let's look at a few of them. 

Now SIG Architecture is responsible for the overall architecture of the Kubernetes platform, including defining the API and ensuring that it remains consistent across all components. Now as of this recording, this SIG is chaired by Derek Carr from Red Hat, Davanam Srinivas or DIMMS from AWS, and John Bellamarak from Google. Now SIG Cluster Lifecycle is responsible for the creation, management, and upgrading of Kubernetes clusters, ensuring that they are reliable and easy to use. And this is chaired by Justin Santabarbero from Google and Vince Brignano from Red Hat. SIG Storage is responsible for Kubernetes storage management, including defining the API and ensuring that it remains consistent across all storage providers, and is chaired by Saad Ali from Google, Jing Yang from VMware. SIG Network, for example, is responsible for the networking functionality of Kubernetes, including defining the API and ensuring that it remains consistent across all network providers, and is chaired by Michael Zappa from Microsoft, Shane from Kong, and Tim Hockin from Google. 

So how do they elect SIGs and what is the process behind it? The process of electing Kubernetes SIGs begins with a proposal from a community member for the formation of a new SIG or the addition of new members to an existing SIG. Now this proposal is then reviewed by the Kubernetes Steering Committee, which we have talked about in the beginning, and they're responsible for overseeing the Kubernetes project's overall direction and governance. So the Kubernetes Steering Committee evaluates the proposal and determines whether it aligns with the community's goals and priorities. And if the proposal is approved, the new SIG is formed or the new members are added to the existing SIG. Now the SIG is then responsible for electing its own leaders and defining its own governance structure. The election of SIG leaders typically involves a nomination process, followed by an election in which SIG members vote for their preferred candidates. The specific details of the election process may vary depending on the individual SIG and the specific needs of the community. And once the SIG leaders are elected, they are responsible for overseeing the SIG's work and ensuring that it contributes effectively to the Kubernetes project. 

That's all for this video. I hope you got a good understanding of what SIGs are and how they work. The Kubernetes community is a very open and welcoming community that values community over product or company and values inclusivity better than exclusivity. So everyone is encouraged to get involved and contribute. Now some of the ways that you can get involved are, number one, to join the community by joining the Kubernetes Slack channel and mailing list. Learn the basics of Kubernetes to familiarize yourself with the technology because you need some knowledge to get involved. Find a SIG or working group of your interest and start by attending the SIG meetings as a listener and learning how they're run. Well attend some of the community events such as meetups, webinars, and conferences. Start small by picking up small tasks that require an owner. Review the list of issues and feature requests that are listed in the GitHub page and see if there are small things that you can pick up on. And once you are finally confident, contribute code to the Kubernetes project. Well that's all for now. 

## Open Standards

Let's talk about Open Standards. Now imagine that you have a mobile phone that you want to use while traveling. If you want to travel abroad, you might want to bring a different charger or an adapter for the country that you are visiting due to the variety of plug and socket designs that are used in different regions of the world. In the context of cloud-native technologies, this can be particularly problematic as cloud-native applications often rely on multiple different services and components such as containers, orchestration tools, networking tools, and data storage solutions. Now without a common language and set of guidelines, different technologies may not be able to communicate or work together seamlessly leading to interoperability challenges and vendor lock-in or product lock-ins. 

So Open Standards are specifications, protocols, or formats that are openly available to the public and are developed through a collaborative and consensus-based process. So they are designed to promote interoperability, portability, and vendor neutrality, enabling different technologies and products to work together seamlessly. However, with the adoption of Open Standards for electric plugs and sockets from our first example, many countries have now standardized on a few common plug and socket designs such as the type A, B, C, and D plugs used in different parts of the world. This means that if your phone charger has a type A plug, which is commonly used in the US and Japan, you can use it in countries that use type A plugs without needing any special adapters or converters. Now I wish we had done better than that and just had a single socket everywhere in the entire world, but yeah, this isn't bad either. We're getting there. Now in the same way, the adoption of Open Standards in the CloudNative ecosystem allows different CloudNative technologies to work together seamlessly regardless of which vendor they come from. And this means that developers can build CloudNative applications using a variety of different technologies and services, confident that they will work together without requiring significant modifications or customizations. 

Open Standards also give users the flexibility to switch between different CloudNative technologies and services without being locked in to a particular vendor or product. And this promotes competition and innovation as vendors are incentivized to offer the best products and services and users are free to choose the ones that best meet their needs. Imagine you have developed a containerized application using a specific container format and runtime provided by Vendor X and later you decide to migrate your application to a different cloud provider that uses a different container format and runtime from, let's say, Vendor Y. Now without Open Standards, you would likely need to rewrite and reconfigure your application to work with the new format and runtime, which could be time-consuming and complex. Now the need for a common or open standard for container technology arises from the lack of standardization and fragmentation in the container ecosystem. So this is where the Open Container Initiative, or OCI, plays a crucial role. 

The Open Container Initiative, or OCI, is a group that focuses on creating open standards for container images, runtimes, and distributions. So one important standard created by the OCI is the image spec, which outlines how a filesystem bundle should be packaged into an image. So this standard has enabled a variety of build tools like to create OCI images, including BuildKit, Podman, and Buildah, in addition to Docker. Now in addition to the image spec, the OCI also governs the container runtime specification, which outlines how to run the filesystem bundle. So the runtime specification includes details on downloading, unpacking, and running the filesystem bundle using an OCI-compliant runtime. 

Now this means that using the Docker and docker run command is no longer the only option for running containers. Other available runtimes include ContainerD, CRI, Kata Containers, gVisor, and Firecracker. So the distribution spec is another important standard created by the OCI, and it defines the specification on the Open Standards and API protocols that should be used to standardize the distribution of container images. While Docker Hub was the initial distribution platform for container images, now other platforms such as Amazon ECR and Azure also comply with the OCI distribution standard. Now moving towards Kubernetes open standards. So the open standards promoted by the OCI have been successful and have influenced other areas such as Kubernetes. So Kubernetes has enabled pluggable layers for runtime, networking, service mesh, and storage, allowing for a highly flexible and modular architecture that avoids vendor and product lock-in. By decoupling these layers, Kubernetes provides users with the ability to mix and match components from different vendors and products and ultimately enabling a best-of-breed approach to CloudNative infrastructure. 

So let's dive into a higher-level perspective of how Kubernetes has enabled pluggable layers for runtime, networking, service meshes, and storage. So CRI, so as you can see in the illustration, the Container Runtime Interface, or CRI, is an open standard adopted by Kubernetes which allows for a pluggable container runtime layer. So this flexibility empowers users to select the optimal container runtime that suits their specific needs with the added advantage of enabling different worker nodes within a Kubernetes cluster to operate using distinct container runtimes. Now while Docker was the initial container runtime employed by Kubernetes, it has been gradually supplanted by ContainerD as the default choice for most new Kubernetes clusters. So ContainerD is kind of a part of Docker that is CRI-compatible and Docker directly isn't CRI-compatible. 

Now Container Network Interface, or CNI. So Kubernetes CNI provides a standard interface for Kubernetes network plugins to configure networking for containers. With CNI, Kubernetes can work with a variety of networking technologies enabling network policies, service discovery, and load balancing. So CNI plugins can also be used to connect containers to virtual networks or third-party networking solutions. Now Container Storage Interface, or CSI. CSI is a standard interface that enables Kubernetes to work with different storage solutions such as Cloud Storage, Network Attached Storage, NAS, and Storage Area Networks, or SAN. The CSI architecture separates the Kubernetes core from the storage implementation allowing third-party storage providers to develop plugins that can be easily integrated into Kubernetes. So with CSI, Kubernetes users can dynamically provision and manage storage volumes for containers. 

Now SMI, or Service Mesh Interface, is a specification that standardizes the way service mesh components interact with each other. It provides a set of APIs for Service Mesh control planes and data planes to communicate enabling interoperability between different Service Mesh implementations. And SMI enables users to use different service mesh components for traffic management, security, and observability providing a more flexible and vendor-agnostic approach to service mesh. Well, to learn more about CloudNative open standards and how to implement them in your organization I recommend exploring resources such as the CloudNative Community Foundation, CNCF and the Open Container Initiative, OCI. So go to opencontainers.org for more information. Thank you so much for watching. I'll see you in the next video. 
