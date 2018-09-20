---
layout: post
title: Kubespray部署高可用Kubernetes
date: 2017-12-04 22:00:40 +0800
categories: kubernetes
---

* content
{:toc}

官方的[kubeadm](https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/)部署工具，默认部署的是单master节点的集群，在生产环境使用会有一定的风险（如果工作节点不是很多，可以考虑采用单master节点）



对于部署，想到了`Ansible`。于是，相对应的找到了[kubespray](https://github.com/kubernetes-incubator/kubespray)

本篇大多来自`kubespray`项目的README，附加一些部署时需要注意的东西。

## 准备

- 安装 [pip](https://pip.pypa.io/en/stable/installing/)
- 安装`python-netaddr`和`git`
- 安装 **Ansible 2.4以上**和`Jinjia`的版本
    ```console
    pip install ansible
    pip install jinja
    ```
- 集群节点需要开启**IPv4 forwarding**
    ```console
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    # 重新加载配置
    sysctl -p /etc/sysctl.conf
    ```
- 部署节点与集群节点之间无密码登录

## 步骤

1. 克隆项目

    ```bash
    git clone https://github.com/kubernetes-incubator/kubespray.git
    ```

1. 修改配置

    复制配置样本文件

    ```bash
    cp -rfq inventory/sample inventory/mycluster
    ```

    编辑`./inventory/mycluster/hosts.ini`

    内容如下：
    
    ```
    [kube-master]
    k8s-test-master1
    k8s-test-master2

    [all]
    k8s-test-master1    ansible_user=root ansible_host=10.244.4.155
    k8s-test-master2    ansible_user=root ansible_host=10.244.4.152
    k8s-test-node1      ansible_user=root ansible_host=10.244.4.135

    [k8s-cluster:children]
    kube-node		
    kube-master		

    [kube-node]
    k8s-test-master1
    k8s-test-master2
    k8s-test-node1

    [etcd]
    k8s-test-master1
    k8s-test-master2
    k8s-test-node1
    ```

    由于国内网络的原因，很多**gcr.io**和**quay.io**的镜像都会`pull`失败，这里提供一些解决方法：

    - 配置节点的docker代理（节点数量多时不推荐）
    - 将需要的镜像拉取下来，上传到本地`docker registry`，然后修改`Ansible role`中的链接。
    
    
    规则中定义下载链接的地方主要在以下2个文件：
    
    - ./roles/download/defaults/main.yml
    - ./roles/kubernetes-apps/ansible/defaults/main.yml

    将文件中的镜像地址修改为私有仓库的地址即可

    其他关于集群的配置位于`./inventory/mycluster/groups`文件夹内

1. 开始部署

    在配置修改完之后，可以开始部署了

    ```bash
    ansible-playbook -i ./inventory/mycluster/hosts.ini -K -n flannel cluster.yml
    ```

    - `-n`可以指定网络插件，目前支持：`flannel`、`calico`（默认）、`canal`、`weave`
    - `-K`：输入`ansible_user`的密码，该用户需要支持`sudo`

## 添加Worker节点

1. 在`./inventory/mycluster/hosts.init`中修改

1. 执行

    ```bash
    ansible-playbook -i ./inventory/mycluster/hosts.ini -K -n flannel scale.yml
    ```

添加节点后，`API Server`所在机器的`hosts`不会自动添加新节点的host记录，会导致`kubectl logs|exec`操作新节点的pod会提示dns解析失败，解决方法是手动在`API Server`机器上修改`/etc/hosts`，添加新节点信息

**Note**: 使用kubespray部署的集群，`API Server`默认是采用`static pod`方式运行，所以添加hosts记录需要进入到`API Server`所在的pod中添加


## 注意点

- 执行失败后，检查失败的原因，改正之后重新执行即可
- 采用`calico`网络插件时，集群节点的容器无法访问外网，需要添加相应的**nat转发**规则才可以

    ```bash
    # 10.233.64.0/18为集群网络（cluster network）
    # 10.244.4.128/27为集群节点网络（eth0 address）  
    /usr/sbin/iptables -t nat -A POSTROUTING -s 10.233.64.0/18 ! -d 10.244.4.128/27 -j MASQUERADE

    # 172.17.0.1/16 为docker0网络
    /usr/sbin/iptables -t nat -A POSTROUTING -s 172.17.0.1/16 ! -d 10.244.4.128/27 -j MASQUERADE
    ```
- `kubespray`部署的集群，会在每个工作节点运行一个`nginx`，这个`nginx`是`apiserver`的入口，负责将请求转发到`apiserver`并且实现负载均衡，以实现**master节点**的高可用