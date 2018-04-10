---
layout: post
title: 记一次kubernetes网络问题分析
date: 2018-04-10 22:42:48 +0800
categories: kubernetes
---

* content
{:toc}


最近kubernetes集群碰到一个很奇怪的问题，虽然最后莫名其妙的解决了，但是觉得还是很多必要记录一下排查过程，以供以后学习。



## 集群情况


- Kubernetes版本: 1.9.0
- 网络插件: cni flannel v0.9.1
- etcd版本: 3.2.4
- kube-dns: 1.14.7

集群总共3个节点

- master1(同时也是workder node)
- master2(同时也是workder node)
- node1

## 问题详情

当pod被调度到node1时，pod内的应用通过服务名去连接其他命名空间的服务时，超时连不上，但是调度到master1或者master2时，又能连接成功。

## 问题分析

从问题现象来看，应该是node1节点的网络存在问题，但也有可能是`kube-dns`有问题。

可能性

- 当从node1节点发出解析请求时，`kube-dns`解析失败
- node1节点发出解析流量被拦截，没有到达`kube-dns`

## 问题排查

### 排查flannel网络

![](https://ws1.sinaimg.cn/large/9bbe7ebdgy1fq7y3q2otzj20ve0lnwga.jpg)

pod内部流量出来经过cni0网卡，转发给flannel.1网卡，flanneld对流量进行udp封装，再根据路由转发到目的节点，目的节点flanneld对udp包进行解封装，转发到对应的pod。

物理网卡和flannel.1网卡地址段不一致，flannel使用iptables进行`SNAT`和`DNAT`。

1. 检查flannel网卡

    节点的`flannel.1`和`cni0`位于同一网络，正常

1. 检查node1节点的pod是否互通

    配置pod的`nodeSelector`，在node1上运行一个`busybox pod`，在pod内ping node1节点上的其他pod，网络相通

1. 检查跨节点的pod是否互通

    在`busybox pod`中ping其他节点的pod地址，网络也是连通的
    
至此，集群内的`flannel`网络应该是没问题的。

### 排查kube-dns

在排查前先了解下`kube-dns`的工作原理

`kube-dns`的pod包含3个容器，每个容器各司其职，实现dns服务的功能。

- kubedns: kubedns容器与API Server通信，监视Service和Endpoint的变化，并维护内存查找结构来服务DNS请求
- dnsmasq: dnsmasq容器添加DNS缓存提高性能
- sidecar: sidecar容器执行健康检查(针对kubedns和dnsmasq)

通过将pod调度到每个节点，然后测试对同一命名空间和不同命名空间的服务进行解析，查看解析情况。

|busybox pod位置|解析相同命名空间的服务|解析不同命名空间的服务|
|---|---|---|
|master1|秒解析|秒解析|
|master2|秒解析|秒解析|
|node1|有时能解析，有时不能|不能解析|

`kube-dns`并不会针对某个节点的解析请求解析失败，基本能确定`kube-dns`没有问题。再通过使用服务的`ClusterIP`访问服务来测试一下。

当`busybox`位于node1上时，访问同一命名空间和其他命名空间的服务（不论服务位于那个节点）都失败。

这时基本能确认问题出现在node1节点的网络出去规则存在问题，kubernetes会在每个节点为每个服务建立很多`iptables`规则，需要排查。

### 路由

```bash
ip route list
```

对比node1和另外2个节点的路由表，发现并没有不同寻常之处

**Note:** 静态路由没有优先级顺序

### iptables

1. 首先检查`FORWARD`链是否被设置为`DROP`

    ```bash
    iptables -S
    ```

    确认没有

1. 检查节点内核`net.ipv4.ip_forward`参数

    是设置为`1`

1. 查看`nat`表的规则

    ```bash
    iptables -t nat -S
    ```

    输出有点多（＞﹏＜）

规则看得很迷糊，最后查资料得知`kube-proxy`控制iptables的规则，尝试重启`kube-proxy`重新刷新iptables规则，结果还是不行

此时已经手足无措，在确定数据不会丢失的情况下，重启节点。

重启之后，等待节点恢复，再次测试，节点正常了....（╯＾╰〉

## 总结

这次问题排查虽然失败了，最终都没能定位是什么导致这个节点的pod访问其他服务会失败，但也算一次不错的经历（感觉只能这样安慰自己了::>_<::）。期间还尝试了`tcpdump`抓数据包分析，但是也没分析出什么来，倒使自己对`flannel`这个网络了解多一点。

最后，还需多实践，对问题不能退却，直面难题才能学习更多。

## 参考

- [配置Kubernetes DNS服务kube-dns
](https://jimmysong.io/posts/configuring-kubernetes-kube-dns/)
- [Debug Services](https://kubernetes.io/docs/tasks/debug-application-cluster/debug-service/#is-kube-proxy-running)