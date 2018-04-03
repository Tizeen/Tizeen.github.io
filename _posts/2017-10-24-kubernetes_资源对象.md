---
layout: post
title: kubernetes资源对象
date: 2017-10-24 23:08:00 +0800
categories: kubernetes
---

* content
{:toc}

Kubernetes有很多资源对象，比如Pod，Deployment，Service，Daemonset等等，这里简单介绍其中一些。



## Pod

`pod`是kubernetes集群创建和管理的最小计算单元

一个`pod`中可以包含**一个或多个**容器（豆荚），容器之间共享网络、存储卷等资源

pod如何共享网络：

1. 先运行一个`pause`容器（也可以是其他容器，可以在kubelet中配置），这个容器什么都不做

1. 运行其他容器，然后指定这些容器的网络为正在运行的`pause`容器（`--net=container:name_or_id` ），这样容器之间就能共享网络

**Example**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-example
spec:
  containers:
  - image: ubuntu:trusty
    command: ["echo"]
    args: ["Hello World"]
```

**Note**: 不推荐直接使用pod来进行部署，可以采用rc或者rs管理pod

## Replication Controller and Replication Set

决定一个pod有多少个同时运行的副本，并保证这些副本的期望状态和当前状态一致。

典型场景

- 重（chong）调度。一旦发现pod运行终止，kubernetes进行相应的重调度

- 弹性伸缩。修改副本数量，实现pod数量的弹性伸缩

- 滚动更新。通过逐个替换pod的方式进行副本的增删操作

  1. 创建1个新的replication controller，设置副本数为1，这个replication controller负责新版本容器的数量

  1. 逐步将新的副本replication controller的副本数+1，将旧的replication controller-1，直到旧的replication controller副本数为0，然后删除旧的replication controller

**Example**

```yaml
apiVersion: v1
kind: ReplicationController
metadata:
  name: nginx-controller
spec:
  # 设定副本数量
  replicas: 2
  # 管理含有name=nginx这个标签的pod
  selector:
    name: nginx
  template:
    metadata:
      labels:
        # 被创建pod的labels，需要与selector中的一致
        name: nginx
      spec:
        containers:
        - name: nginx
          image: nginx:1.13
          ports:
          - containerPort: 80
```

`rs`与`rc`不同的地方在于：`rs`支持基于子集的selector查询条件，而`rc`只支持基于值相等的selector查询

**Example**

```console
# 基于值相等的查询
kubectl get pods -l app=nginx

# 基于集合的查询
kubectl get pods -l 'app in (nginx, tomcat-web)'
```

更多的查询参考[这里](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)

**Note**

- 在许多情况下，建议使用`Deployment`替代`rc`或者`rs`

- `kubectl rolling-update`不支持`rs`，具体用法可以通过`kubectl rolling-update -h`查看

  > Most kubectl commands that support Replication Controllers also support ReplicaSets. One exception is the rolling-update command. 

## Deployment

`Deployment`多用于为pod和replica set提供更新，并且方便跟踪pod数量和状态的变化。`Deployment`是为了应用的更新而设计的。

**创建`Deploymet`**

```yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: tomcat
  labels:
    app: tomcat-web
spec:
  replicas: 2
  template:
    metadata: 
      labels: 
        app: tomcat-web
        tier: backend
    spec:
      containers:
      - name: tomcat
        image: tomcat:8.0
        ports:
        - containerPort: 8080
```

```console
kubectl create -f tomcat-deployment.yml --record
# or
kubectl apply -f tomcat-deployment.yml --record

# get deployment status
kubectl get deployments
```

**更新`Deployment`的方法**

- 使用`Dashboard`管理界面直接修改更新配置

- 修改资源文件，然后`kubectl apply -f update-deployment.yml`

- 使用`kubectl edit deployment deployment_name`命令修改配置，然后保存

`Deployment`更新和`kubectl rolling-update`的区别：

`kubectl rollingupdate`是由命令行工具实现更新逻辑（类似前端），而`Deployment`的更新操作转移到了服务端，有专门的`controller manager`负责

## Service

`pod`在`kubernetes`中重新调度之后IP地址会改变，需要一个代理来确保使用`pod`的应用不需要知道`pod`的真实IP地址。对于多个`pod`副本的`rc`、`rs`，需要一个代理为这些pod做负载均衡。`Service`主要就是实现这些而设计的

**一些要点**

- `Service`一个唯一的集群`IP`和`label selector`组成，这个IP会一直伴随`Service`的整个生命周期。因为集群IP是唯一的，不需要担心`Service`之间端口冲突的问题

- `Service`创建时，会同时一个相对应的`Endpoint`，里边保存了所有匹配`label selector`后端`pod`的IP地址和端口

- `kube-proxy`是实现`Service`的主要组件（流量转发模式：`userspace`模式和`iptables`模式）

**定义一个`Service`**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: tomcat
  labels:
    app: tomcat-web
spec:
  ports:
    - port: 8080
      targetPort: 8080
  selector: 
    app: tomcat-web
    tier: backend
```

**Note:** 如果要代理外部已存在的系统（比如数据库），定义`Service`不添加`selector`，然后自己定义对应的`Endpoint`，具体参考[例子](mysvc.my-namespace.svc.cluster.local)

**`Service`发现机制**

- 环境变量的方式

- DNS方式([kube-dns](https://github.com/kubernetes/kubernetes/tree/master/cluster/addons/dns))

  DNS完整记录: `mysvc.my-namespace.svc.cluster.local`

  - 相同`namespace`的服务，直接通过服务名字连接

  - 不同`namespace`的服务，采用`service_name.namespace`方式连接

**`Service`对外**

默认`Service`只能通过集群内部访问，有3种方式可以从外部访问

- NodePort: 在工作节点开启一个端口，直接访问该端口就可以访问对应的服务

- LoadBalancer: 配合云服务提供商（GCE，AWS...）的负载均衡控制器使用

- external ip: 指定一个额外的IP和端口，访问该`IP:Port`会直接访问到相应的`Service`

## DaemonSet

`DaemonSet`保证在每个Node上都运行一个容器副本，常用来部署一些集群的日志、监控或者其他系统管理应用。

- 可以通过`nodeSelector`设置pod运行在特定的节点，使`DaemonSet`的pod不运行在所有工作节点

- `DaemonSet`由于在创建的时候controller已经指定了nodeName，scheduler会忽略这些pod的调度

- `DaemonSet`支持滚动更新（1.7报本之后）

## 参考

- Docker容器与容器云

- [Kubernetes指南](https://www.gitbook.com/book/feisky/kubernetes)

- [官方文档](https://kubernetes.io/docs/concepts/)