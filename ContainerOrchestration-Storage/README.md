## Storage

Hello, and welcome to this section on storage in Kubernetes. This is Mumshad Mannambeth. In this section, we look at the various storage-related concepts such as persistent volumes, persistent volume claims, access modes and how to configure applications with persistent storage. There are so many different storage options out there. And depending on your environment, the options may vary. However, looking at all of those options is out of scope for this course. In this course, our focus is on the Kubernetes side of storage. Once you get that you should be able to relate that knowledge to implement any third-party storage solutions out there. So let's get started. 

## Introduction to Docker Storage

Let us now look at storage in Kubernetes. To understand storage in container orchestration tools like Kubernetes, it is important to first understand how storage works with containers. Understanding how storage works with Docker first and getting all the basics right, will later make it so much easier to understand how it works in Kubernetes. When it comes to storage in Docker, there are two concepts, you must know about **storage drivers**, and **volume driver plugins**. In the upcoming video, we will discuss storage drivers. It's something that we've discussed in the Docker course. So if you have gone through that already, feel free to skip this video, or you may choose to stay and refresh your memory. Once done, we will talk about volume drivers.

## Storage in Docker

Hello, and welcome to this lecture. And we are learning advanced Docker concepts. In this lecture, we're going to talk about Docker storage drivers and file systems. We're going to see where and how Docker stores data, and how it manages file systems of the containers. Let us start with how Docker stores data on the local file system. When you install Docker on a system, it creates this folder structure at **/var/lib/docker**. You have multiple folders under it called overlay2, containers, images, volumes, etc. This is where Docker stores all its data by default. When I say data, I mean files related to images and containers running on the Docker host. For example, all files related to containers are stored under the containers folder. And the files related to images are stored under the images folder. Any volumes created by the Docker containers are created under the volumes folder. Well, don't worry about that. For now, we will come back to that in a bit. For now, let's just understand where Docker stores its files, and in what format. 

So how exactly does Docker store the files of an image and a container? To understand that we need to understand Docker's layered architecture. Let's quickly recap something we learned when Docker builds images, it builds these in a layered architecture. Each line of instruction in the Dockerfile creates a new layer in the Docker image with just the changes from the previous layer. For example, the first layer is a base Ubuntu operating system, followed by the second instruction that creates a second layer, which installs all the APT packages. And then the third instruction creates a third layer, which includes the Python packages, followed by the fourth layer that copies the source code over and then finally the fifth layer that updates the entry point of the image. Since each layer only stores the changes from the previous layer, it is reflected in the size as well. If you look at the base Ubuntu image, it is around 120 megabytes in size, the APT packages that are installed are around 300 MB, and then the remaining layers are small. 

To understand the advantages of this layered architecture, let's consider a second application. This application has a different Dockerfile, but is very similar to our first application, as it uses the same base image as Ubuntu and uses the same Python and Flask dependencies, but uses a different source code to create a different application. And so a different entry point as well. When I run the Docker build command to build a new image for this application, since the first three layers of both the applications are the same, Docker is not going to build the first three layers. Instead, it reuses the same three layers it built for the first application from the cache and only creates the last two layers with the new sources and the new entry point. This way, Docker builds images faster and efficiently saves disk space. This is also applicable if you were to update your application code. Whenever you update your application code, such as the app.py. In this case, Docker simply reuses all the previous layers from cache and quickly rebuilds the application image by updating the latest source code, thus saving us a lot of time during rebuilds and updates. 

Let's rearrange the layers bottom up so we can understand it better. At the bottom, we have the base Ubuntu layer, then the packages, then the dependencies, and then the source code of the application. And then the entry point. All of these layers are created when we run the Docker build command to form the final Docker image. So all of these are the Docker image layers. Once the build is complete, you cannot modify the contents of these layers. And so they are read-only and you can only modify them by initiating a new build. When you run a container based off of this image using the Docker run command, Docker creates a container based off of these layers, and creates a new writable layer on top of the image layer. The writable layer is used to store data created by the container, such as log files written by the applications, any temporary files generated by the container, or just any file modified by the user on that container. The life of this layer is only as long as the container is alive. When the container is destroyed, this layer and all of the changes stored in it are also destroyed. Remember that the same image layer is shared by all containers created using this image. If I were to log into the newly created container and say, create a new file called temp.txt, it will create that file in the container layer, which is read and write. We just said that the files in the image layer are read-only meaning you cannot edit anything in those layers. Let's take an example of our application code. Since we bake our code into the image, the code is part of the image layer and as such is read-only. After running a container, what if I wish to modify the source code to say test a change. Remember, the same image layer may be shared between multiple containers created from this image. So does it mean that I cannot modify this file inside the container? No, I can still modify this file. But before I save the modified file, Docker automatically creates a copy of the file in the read-write layer. And I will then be modifying a different version of the file in the read-write layer. All future modifications will be done on this copy of the file in the read-write layer. This is called copy-on-write mechanism. The image layer being read-only just means that the files in these layers will not be modified in the image itself. So the image will remain the same all the time until you rebuild the image using the Docker build command. What happens when we get rid of the container, all of the data that was stored in the container layer also gets deleted. The change we made to the app.py, and the new temp file we created will also get removed. 

So what if we wish to persist this data? For example, if we were working with a database, and we would like to preserve the data created by the container, we could add a persistent volume to the container. To do this, first create a volume using the Docker volume create command. So when I run the Docker volume create data_volume command, it creates a folder called data_volume under the var/lib/Docker/volumes directory. Then when I run the Docker container using the Docker run command, I could mount this volume inside the Docker container's rewrite layer using the -v option like this. So I would do a Docker run -v, then specify my newly created volume name followed by a colon and the location inside my container, which is the default location where MySQL stores data. And that is where var/lib/MySQL and then the image name MySQL. This will create a new container and mount the data volume we created into var/lib/MySQL folder inside the container. So all data written by the database is in fact stored on the volume created on the Docker host. Even if the container is destroyed, the data is still active. 

```bash
docker volume create data_volume
docker run -v data_volume:/var/lib/mysql mysql
```

Now what if you didn't run the Docker volume create command to create the volume before the Docker run command. For example, if I run the Docker run command to create a new instance of MySQL container with the volume data_volume_two, which I have not created yet, Docker will automatically create a volume named data_volume_two, and mount it to the container. You should be able to see all these volumes if you list the contents of the var/lib/docker/volumes folder. This is called **volume mounting**, as we are mounting a volume created by Docker under the var/lib/docker/volumes folder. 

```bash
docker run -v data_volume2:/var/lib/mysql mysql
```

But what if we had our data already at another location? For example, let's say we have some external storage on the Docker host at /data. And we would like to store database data on that volume and not in the default var/lib/docker/volumes folder. In that case, we would run a container using the command Docker run -v. But in this case, we will provide the complete path to the folder we would like to mount that is /data/MySQL. And so it will create a container and mount the folder to the container. This is called **bind mounting**. 

```bash
docker run -v /data/mysql:/var/lib/mysql mysql
```

So there are two types of mounts: a volume mount and a bind mount. Volume mount mounts a volume from the volumes directory and bind mount mounts a directory from any location on the Docker host. One final point to note before I let you go: using the -v is an old style. The new way is to use the --mount option. The --mount is the preferred way as it is more verbose. So you have to specify each parameter in a key equals value format. For example, the previous command can be written with the --mount option as this using the type, source, and target options. The type in this case is bind. The source is the location on my host and target is the location on my container. 

```bash
docker run --mount type=bind,source=/data/mysql,target=/var/lib/mysql mysql
```

So who is responsible for doing all of these operations, maintaining the layered architecture, creating a writable layer, moving files across layers to enable copy-on-write etc. It's the storage drivers. So Docker uses storage drivers to enable layered architecture. Some of the common storage drivers are AUFS, VTRFS, VFS, device mapper, overlay and overlay2. The selection of the storage driver depends on the underlying OS being used. For example, with Ubuntu, the default storage driver is AUFS, whereas this storage driver is not available on other operating systems like Fedora or CentOS. In that case, device mapper may be a better option. Docker will choose the best storage driver available automatically based on the operating system. The different storage drivers also provide different performance and stability characteristics. So you may want to choose one that fits the needs of your application and your organization. If you would like to read more on any of these storage drivers, please refer to the links in the attached documentation. For now, that is all from the Docker architecture concepts. 

## Volume Driver Plugins in Docker

Okay, so in the previous lecture, we discussed storage drivers. Storage drivers help manage storage on images and containers. We also briefly touched upon volumes. In the previous lecture, we learned that if you want to persist storage, you must create volumes. Remember that volumes are not handled by storage drivers. Volumes are handled by volume driver plugins. The default volume driver plugin is **local**. The local volume plugin helps create a volume on the Docker host and store its data under the var/lib/docker/volumes directory. There are many other volume driver plugins that allow you to create a volume on third-party solutions like Azure File Storage, Convoy, DigitalOcean Block Storage, Flocker, Google Compute Persistent Disks, Cluster FS, NetApp, Rex Ray, Portworx, and VMware vSphere Storage. These are just a few of the many. Some of these volume drivers support different storage providers. For instance, Rex Ray storage driver can be used to provision storage on AWS EBS, S3, EMC storage arrays like Isilon and ScaleIO or Google Persistent Disk or OpenStack Cinder. 

When you run a Docker container, you can choose to use a specific volume driver such as the Rex Ray EBS to provision a volume from Amazon EBS. This will create a container and attach a volume from the AWS cloud. When the container exits, your data is safe in the cloud. 

```bash
docker run -it --name mysql --volume-driver rexray/ebs --mount src=ebs-vol, target=/var/lib/mysql mysql
```

## Container Storage Interface

Let us now look at Container Storage Interface. In the past, Kubernetes used Docker alone as the container runtime engine, and all the code to work with Docker was embedded within the Kubernetes source code. With other container runtimes coming in, such as Rocket and CRI, it was important to open up and extend support to work with different container runtimes, and not be dependent on the Kubernetes source code. And that's how Container Runtime Interface came to be. The Container Runtime Interface is a standard that defines how an orchestration solution like Kubernetes would communicate with container runtimes like Docker. So in the future, if any new Container Runtime Interface is developed, they can simply follow the CRI standards. And that new container runtime would work with Kubernetes without really having to work with a Kubernetes team of developers or touch the Kubernetes source code. 

Similarly, as we saw in the networking lectures, to extend support for different networking solutions, the Container Networking Interface was introduced. Now, any new networking vendors could simply develop their plugin based on the CNI standards and make their solution work with Kubernetes. And as you can guess, the Container Storage Interface was developed to support multiple storage solutions. With CSI, you can now write your own drivers for your own storage to work with Kubernetes. Portworx, Amazon EBS, Azure Disk, Dell EMC, Isilon, PowerMax, Unity, XtremIO, NetApp, Nutanix, HPE, Hitachi, Pure Storage, everyone's got their own CSI drivers. 

Note that CSI is not a Kubernetes specific standard. It is meant to be a universal standard. And if implemented allows any container orchestration tool to work with any storage vendor with a supported plugin. Currently, Kubernetes, Cloud Foundry, and Mesos are on board with CSI. So here's what the CSI kind of looks like. It defines a set of RPCs or Remote Procedure Calls that will be called by the container orchestrator. And these must be implemented by the storage drivers. For example, CSI says that when a pod is created and requires a volume, the container orchestrator, in this case, Kubernetes should call the Create Volume RPC and pass a set of details such as the volume name. The storage driver should implement this RPC and handle that request and provision a new volume on the storage array and return the results of the operation. Similarly, the container orchestrator should call the Delete Volume RPC when a volume is to be deleted. And the storage driver should implement the code to decommission the volume from the array when that call is made. And the specification details exactly what parameters should be sent by the caller, what should be received by the solution, and what error codes should be exchanged. If you're interested, you can view all these details in the CSI specification on GitHub at this URL. So that's about it for now about Container Storage Interface.

## Volumes

Hello, and welcome to this lecture on persistent volumes in Kubernetes. Before we head into persistent volumes, let us start with volumes in Kubernetes. Let us look at volumes in Docker. First, Docker containers are meant to be transient in nature, which means they are meant to last only for a short period of time. They're called upon when required to process data and destroyed once finished. The same is true for the data that is within the container, the data is destroyed along with the container. To persist data processed by the containers, we attach a volume to the containers when they are created. The data processed by the container is now placed in this volume, thereby retaining it permanently. Even if the container is deleted, the data generated or processed by it remains. 

So how does that work in the Kubernetes world? Just as in Docker, the pods created in Kubernetes are transient in nature. When a pod is created to process data, and then deleted, the data processed by it gets deleted as well. For this, we attach a volume to the pod. The data generated by the pod is now stored in the volume. And even after the pod is deleted, the data remains. Let's look at a simple implementation of volumes. We have a single node Kubernetes cluster, we create a simple pod that generates a random number between one and 100, and writes that to a file at /opt/number.out, it then gets deleted along with the random number. To retain the number generated by the pod, we create a volume. And a volume needs a storage. When you create a volume, you can choose to configure its storage in different ways. We will look at the various options in a bit. But for now, we will simply configure it to use a directory on the host. In this case, I specify a path /data on the host. This way, any files created in the volume would be stored in the directory data on my node. Once the volume is created to access it from a container, we mount the volume to a directory inside the container, we use the volume mounts field in each container to mount the data volume to the directory /opt within the container. The random number will now be written to /opt/mount inside the container, which happens to be on the data volume, which is in fact the data directory on the host. 

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: random-number-generator
spec:
  containers:
  - image: alpine
    name: alpine
    command: ["/bin/sh","-c"]
    args: ["shuf -i 0-100 -n 1 >> /opt/number.out;"]
    volumeMounts:
    - mountPath: /opt
      name: data-volume

  volumes:
  - name: data-volume
    hostPath:
      path: /data
      type: Directory
```

When the pod gets deleted, the file with a random number still lives on the host. Let's take a step back and look at the volume storage options. We just used the hostPath option to configure a directory on the host as storage space for the volume. Now that works fine on a single node. However, it is not recommended for use in a multi-node cluster. This is because the pods would use the /data directory on all the nodes and expect all of them to be the same and have the same data. Since they are on different servers, they're in fact not the same. Unless you configure some kind of external replicated cluster storage solution. Kubernetes supports several types of different storage solutions, such as NFS, GlusterFS, Flocker, Fibre Channel, CephFS, ScaleIO, or public cloud solutions like AWS EBS, Azure Disk, or File, or Google's Persistent Disk. For example, to configure an AWS Elastic Block Store volume as the storage option for the volume, we replace the hostPath field of the volume with the AWS Elastic Block Store field along with the volume ID and file system type. The volume storage will now be on AWS EBS. 

```yaml
volumes:
  awsElasticBlockStore:
    volumeID: <volume-id>
    fsType: ext4
```

## Persistent Volume

Hello, and welcome to this lecture on persistent volumes. In the last lecture, we learned about volumes. Now we will discuss persistent volumes in Kubernetes. When we created volumes in the previous section, we configured volumes within the pod definition file. So every configuration information required to configure storage for the volume goes within the pod definition file. Now when you have a large environment with a lot of users deploying a lot of pods, the users would have to configure storage every time for each pod. Whatever storage solution is used, the users who deploy the pods would have to configure that on all pod definition files in their environment. Every time changes need to be made, the user would have to make them on all of their pods. 

Instead, you would like to manage storage more centrally, you would like it to be configured in a way that an administrator can create a large pool of storage, and then have users carve out pieces from it as required. That is where persistent volumes can help us. A persistent volume is a cluster-wide pool of storage volumes configured by an administrator to be used by users deploying applications on the cluster. The users can now select storage from this pool using persistent volume claims. 

Let us now create a persistent volume. We start with the base template and update the API version, set the kind to persistent volume, and name it PV-01. Under the spec section, specify the access modes. Access mode defines how a volume should be mounted on the hosts, whether in read-only mode, or read-write mode, etc. The supported values are read only, many read-write once, and read-write many mode. Next is the capacity, specify the amount of storage to be reserved for this persistent volume, which is set to one GB here. Next comes the volume type. We will start with the host path option that uses storage from the node's local directory. Remember, this option is not to be used in a production environment. 

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-vol1
spec:
  accessModes:
    - ReadWriteOnce
  capacity:
    storage: 1Gi
  hostPath:
    path: /tmp/data
```

To create the volume, run kubectl create command and to list the created volume from the kubectl get persistent volume command. Replace the host path option with one of the supported storage solutions as we saw in the previous lecture, like AWS Elastic Block Store, etc.

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-vol1
spec:
  accessModes:
    - ReadWriteOnce
  capacity:
    storage: 1Gi
  awsElasticBlockStore:
    volumeID: <volume-id>
    fsType: ext4
```

```bash
kubectl get persistentvolume
```

## Persistent Volume Claim

Hello, and welcome to this lecture on persistent volume claims in Kubernetes. Now we will try to create a persistent volume claim to make the storage available to a node. Persistent volumes and persistent volume claims are two separate objects in the Kubernetes namespace. An administrator creates a set of persistent volumes, and a user creates persistent volume claims to use the storage. Once the persistent volume claims are created, Kubernetes binds the persistent volumes to claims based on the request and properties set on the volume. Every persistent volume claim is bound to a single persistent volume. During the binding process, Kubernetes tries to find a persistent volume that has sufficient capacity as requested by the claim and any other request properties such as access modes, volume modes, storage class, etc. However, if there are multiple possible matches for a single claim, and you would like to specifically use a particular volume, you could still use labels and selectors to bind to the right volumes. Finally, note that a smaller claim may get bound to a larger volume if all the other criteria match, and there are no better options. There is a one-to-one relationship between claims and volumes. So no other claims can utilize the remaining capacity in the volume. If there are no volumes available, the persistent volume claim will remain in a pending state until newer volumes are made available to the cluster. Once newer volumes are available, the claim would automatically be bound to the newly available volume. 

Let us now create a persistent volume claim. We start with a blank template, set the API version to v1 and kind to persistent volume claim. We will name it my claim under specification set the access modes to ReadWriteOnce and set resources to request a storage of 500 megabytes. Create the claim using kubectl create command. To view the created claim, run the kubectl get persistent volume claim command. We see the claim in a pending state. When the claim is created, Kubernetes looks at the volume created previously, the access modes match the capacity requested is megabytes, but the volume is configured with one GB of storage. Since there are no other volumes available, the persistent volume claim is bound to the persistent volume. When we run the get volumes command again, we see the claim is bound to the persistent volume we created. Perfect. 

```yaml
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-vol1
spec:
  accessModes:
    - ReadWriteOnce
  capacity:
    storage: 1Gi
  awsElasticBlockStore:
    volumeID: <volume-id>
    fsType: ext4
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myclaim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
```

To delete a PVC run the kubectl delete persistent volume claim command. But what happens to the underlying persistent volume when the claim is deleted? You can choose what is to happen to the volume. By default, it is set to **retain** meaning the persistent volume will remain until it is manually deleted by the administrator. It is not available for reuse by any other claims, or it can be **deleted** automatically. This way as soon as the claim is deleted, the volume will be deleted as well. Thus freeing up storage on the end storage device. Or a third option is to **recycle**. In this case, the data in the data volume will be scrubbed before making it available to other claims. Well, that's it for this lecture. 

```bash
kubectl delete persistentvolumeclaim myclaim
```

```yaml
persistentVolumeReclaimPolicy: Retain
---
persistentVolumeReclaimPolicy: Delete
---
persistentVolumeReclaimPolicy: Recycle
```

## Storage Class

In this lecture, we will look at storage classes. In the previous lectures, we discussed how to create PVs and then create PVCs to claim that storage and then use the PVCs in the pod definition files as volumes. In this case, we create a PVC from a Google Cloud persistent disk. The problem here is that before this PV is created, you must have created the disk on Google Cloud. Every time an application requires storage, you have to first manually provision the disk on Google Cloud, and then manually create a persistent volume definition file using the same name as that of the disk that you created. That's called **static provisioning volumes**; it would have been nice if the volume gets provisioned automatically when the application requires it. And that's where storage classes come in. 

With storage classes, you can define a provisioner such as Google Storage that can automatically provision storage on Google Cloud and attach that to pods when a claim is made. That's called **dynamic provisioning of volumes**. You do that by creating a storage class object with the API version set to storage.k8s.io/v1, specify a name and use provisioner as kubernetes.io/gce-pd. 

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: google-storage
provisioner: kubernetes.io/gce-pd
```

So going back to our original state where we have a pod using a PVC for its storage, and the PVC is bound to a PV, we now have a storage class. So we no longer need the PV definition because the PV and any associated storage is going to be created automatically when the storage class is created. For the PVC to use the storage class we defined, we specify the storage class name in the PVC definition. That's how the PVC knows which storage class to use. 

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myclaim
spec:
  storageClassName: google-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
```

Next time a PVC is created, the storage class associated with it uses the defined provisioner to provision a new disk with the required size on GCP, and then creates a persistent volume and then binds the PVC to that volume. So remember that it still creates a PV, it's just that you don't have to manually create PV anymore. It's created automatically by the storage class. We used the GCE provisioner to create a volume on GCP. There are many other provisioners as well, such as for AWS EBS, Azure File, Azure Disk, Ceph FS, Portworx, ScaleIO, and so on. 

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: google-storage
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-standard
  replication-type: none
```

With each of these provisioners, you can pass in additional parameters such as the type of disk to provision, the replication type, etc. These parameters are very specific to the provisioner that you're using. For Google persistent disk, you can specify the type, which could be standard or SSD, you can specify the replication mode, which could be none, or regional PD. So you see, you can create different storage classes, each using different types of disks. For example, a silver storage class with the standard disks, a gold class with SSD drives, and a platinum class with SSD drives and replication. And that's why it's called storage class, you can create different classes of service. Next time you create a PVC, you can simply specify the class of storage you need for your volumes. 
