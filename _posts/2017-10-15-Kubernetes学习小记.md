---
layout: post
title: kubernetes学习小记
date: 2017-10-15 16:10:30 +0800
categories: kubernetes
---

* content
{:toc}

最近一段时间都在折腾`kubernetes`，这里记录一些知识点




## Kubernetes是什么

Kubernetes始于Google内部的大规模集群管理工具Borg，它是一个管理跨主机容器化应用的系统，实现了包括部署、高可用管理和弹性伸缩在内的一系列基础功能并封装成一套完整、简单易用的的`RESTful API`对外提供服务。

Kubernetes的设计哲学之一就是维护应用容器集群一直处于用户期望的状态。

## Kubernetes特点

- 健壮的集群恢复机制，包括容器的自动重启、自动重调度以及自动备份；
- 引入专门对容器进行分组管理的`pod`，`pod`是Kubernetes的最小管理单元

## Kubernetes资源对象

- Pod：Pod是Kubernetes中被创建、调度和管理的最小单元，而非单个容器。一个Pod是由若干容器构成的容器组
- Replication Controller：副本控制器，决定一个Pod有多少同时运行的副本，并保证这些副本的期望状态与当前状态一致
- Replication Set：Replication Set的升级版，引入了对基于子集的Selector查询条件，Replication Controller仅支持基于值相等的selector查询
- Deployment：多用户Pod和Replica Set提供更新，为了应用的更新而设计的
- Service：Pod在Kubernetes中的IP地址是不固定的，重新调度之后IP会变化。Service就是用来解决这些问题的，它将Pod进行逻辑分组，并提供访问Pod的策略
- DaemonSet：DaemonSet可以让所有工作节点都运行某个相同的Pod副本

一般来说，都是采用`Deployment`来控制`rs`或者`rc`，rs与rc再管理`Pod`，如果需要对外提供服务，再使用`Service`管理`Deployment`

## Kubernetes架构

Kubernetes由两种节点组成：

- master节点：管理节点
- 工作节点：容器运行的节点

Kubernetes结构图如下所示：

![](https://ws1.sinaimg.cn/large/9bbe7ebdgy1fjjjl26y8ej20ru0ku76t.jpg)

master节点有3个重要的组件：

- APIServer：负责响应用户请求，进行指挥协调等工作
- scheduler：将pod调度绑定到合适的工作节点
- controller manager：一组控制器的合集，负责控制管理对应的资源，比如副本（replication）和工作节点（node）

工作节点的2个重要组件：

- kubelet：管理维护pod的运行
- kube-proxy：负责将`Service`的流量转发给`Endpoint`中指定的`Pod`

其他基础组件：

- etcd：一个键值存储仓库，用户配置共享和服务发现
- 网络组件：使容器跨节点进行网络通信，有`Flannel`,`Weave`,`Calico`等

## Kubernetes组件解释

以下内容大概解释一下各个组件在集群中扮演的角色和作用

### kube-apiserver

`kube-apiserver`提供以下功能

- 对外提供基于RESTful的管理接口，譬如：pod、service、deployment、工作节点等资源的增、删、改、查和监听操作
- 配置kubernetes资源对象，并将资源对象的期望状态和实际状态存储在etcd中供其他组件读取和分析（只有API Server与etcd进行连接，其他组件不直接与etcd连接）
- 日志收集
- 提供可定制的功能性插件，完善对集群的管理

`kube-apiserver`会监听两个端口，一个安全端口`6443`,一个非安全端口`8080`

### kube-scheduler

`kube-scheduler`是调度器，根据特定的调度算法将`pod`调度到指定的工作节点上（绑定）

因为kubernetes中没有消息系统在组件之间进行通知，所以`kube-scheduler`会定时想`API Server`请求数据，为了减缓`API Server`的压力，`kube-scheduler`设置了本地缓存机制

调度阶段

1. Predicates: 能否调度到某个节点
1. Priorities: 在能调度的节点，选一个最优的节点

这里对调度算法不多做说明，感兴趣的可以自行去查阅资料

### kube-controller-manager

管理集群中的各种控制器，比如：`replication controller`，`node controller`...

- `API Server`负责集群内资源的“增删改”，`controller manager`负责管控这些资源，定期检查资源状态，确保它们保持在用户期望的状态

### kubelet

负责管理和维护这台主机上运行着的所有容器。

- `kubelet`会定期向`API Server`请求，发现有跟本节点的相关变化后，进行相应的操作（比如：有新的pod要运行）

- `kubelet`中包含了`cAdvisor`，可以获取容器的相关数据

### kube-proxy

`kube-proxy`运行在所有的工作节点上，监听`API Server`和`Endpoint`的变化，可以将进入的集群的TCP，UDP数据流进行转发，也可以以轮询的形式将流量转发到一组相同的服务（负载均衡）

`kube-proxy`有两种代理模式：

- userspace模式

    这种模式下，kube-proxy监听master节点`Service`和`Endpoint`资源添加和删除的变化，为每一个服务在工作节点上开放一个随机的端口，任何连接到这个端口的流量都会被转发到相应服务的`Pod`（根据`Endpoint`可以知道`Pod`）

- iptables模式

    这种模式下，kube-proxy监听master节点`Service`和`Endpoint`资源添加和删除的变化，为每一个服务添加`iptables`规则，捕获**服务集群ip**和**端口**的流量，然后转发给**后端Service集合**中的Service，最后根据`Endpoint`转发到相对应的`Pod`

## 核心组件协作流程

以下是**创建pod**的流程的示意图和说明

![](https://ws1.sinaimg.cn/large/9bbe7ebdgy1fki80kzjl6j20kv0abjs7.jpg)

1. 当客户端发起一个创建pod请求后，kubectl向APIServer的/pods端点发送一个HTTP POST请求，请求的内容即客户端提供的pod资源配置文件

1. APIServer收到该REST API请求后会进行一系列的验证操作，包括用户认证、授权和资源配额控制等。验证通过后，APIServer调用etcd的存储借口在后台数据库中创建一个pod对象

1. scheduler使用API Server的API，顶起从etcd获取/监测系统中可用的工作节点列表和待调度pod，并使用调度策略为pod选择一个运行的工作节点，这个过程也就是绑定（bind）

1. 绑定成功后，scheduler会调用APIServer的API在etcd中创建一个binding对象，描述在一个工作节点上绑定运行的所有pod信息。同时kubelet会监听APIServer上pod的更新，如果发现有pod更新信息，则会自动在podWorker的同步周期中更新对应的pod

## 集群部署

- kops (aws采用)
- kubeadm （官方工具，目前还处于beta版本...）
- kubespray (利用ansible部署)
- 手动部署 (苦力活...)

## 陷阱

- 高版本的Docker会将iptables中`FORWARD`链设置为DROP，导致跨节点的pod无法通信（采用flannel网络），需要修改

## 参考

- Docker容器与容器云-第二版
- [Kubernetes指南](https://feisky.gitbooks.io/kubernetes/)