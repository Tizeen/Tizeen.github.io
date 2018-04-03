---
layout: post
title: kubespray部署高可用kubernetes
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
- 安装 **Ansible 2.4以上**的版本
    ```console
    pip install ansible
    ```
- 集群节点需要开启**IPv4 forwarding**
    ```console
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    # 重新加载配置
    sysctl -p /etc/sysctl.conf
    ```
- 部署节点与集群节点之间无密码登录

## kubespray-cli

使用`kubespray-cli`可以很方便进行部署

1. 安装`kubespray`

    ```console
    pip2 install kubespray
    ```
    安装完之后，查看Home目录下是否存在`.kubespray.yml`配置文件，如果不存在，则手动添加，文件内容可以在[官方README](https://github.com/kubespray/kubespray-cli)中找到

1. 准备配置

    ```console
    kubespray prepare --nodes 3
    ```

    这里简单写`--nodes 3`，是因为后续会手动的更改集群节点配置。更加详细的`prepare`细节，可以参考[官方README](https://github.com/kubespray/kubespray-cli)

1. 修改配置

    上一步执行成功之后，会在当前用户的Home目录下生成`.kubespray`文件夹

    `.kubespray`目录中则保存在部署所需的`Ansible playbook`，需要修改相应的`inventory`和`docker`镜像地址

    编辑`.kubespray/inventory/inventory.cfg`

    ```ini
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
    
    - .kubespray/roles/download/default/main.yml
    - .kubespray/roles/kubernetes-apps/ansible/defaults/main.yml

    将文件中的镜像地址修改为私有仓库的地址即可

1. 开始部署

    在配置修改完之后，可以开始部署了

    ```console
    kubespray deploy -i ./kubespray/inventory/inventory.cfg -K -n flannel
    ```

    - `-n`可以指定网络插件，目前支持：flannel、calico（默认）、canal、weave
    - `-K`：输入`ansible_user`的密码，该用户需要支持`sudo`

    可以看出`kubespray deploy`其实是调用了`ansible-playbook`，更多的参数说明通过`kubespray deploy -h`查看

## Note

- `kubespray deploy`执行失败后，检查失败的原因，改正之后重新执行即可
- 采用`calico`网络插件时，集群节点的容器无法访问外网，需要添加相应的**nat转发**规则才可以

    ```console
    # 10.233.64.0/18为集群网络（cluster network）
    # 10.244.4.128/27为集群节点网络（eth0 address）  
    /usr/sbin/iptables -t nat -A POSTROUTING -s 10.233.64.0/18 ! -d 10.244.4.128/27 -j MASQUERADE

    # 172.17.0.1/16 为docker0网络
    /usr/sbin/iptables -t nat -A POSTROUTING -s 172.17.0.1/16 ! -d 10.244.4.128/27 -j MASQUERADE
    ```
- `kubespray`部署的集群，会在每个工作节点运行一个`nginx`，这个`nginx`是`apiserver`的入口，负责将请求转发到`apiserver`并且实现负载均衡，以实现**master节点**的高可用