---
layout: post
title: Vagrant Multi-Machine
date: 2017-08-05 10:52:05 +0800
categories: Linux Tools
---

使用`vagrant init`默认只有一台虚拟机，如果需要在一个`Vagrantfile`里边定义多个虚拟机，可以这样做。




## Vagrant Multi-Machine

可以通过`config.vm.define`定义不同的虚拟机

*Vagrantfile Example*

```ruby
# -*- mode: ruby -*-

Vagrant.configure("2") do |config|

    config.vm.define "master" do |master|
        master.vm.box = "centos/7"
        master.vm.hostname = "k8s-master"
        master.vm.network "private_network", ip: "192.168.10.10"
        master.vm.provider "virtualbox" do |vb|
            vb.name = "k8s-master"
            vb.memory = "2048"
            vb.cpus = 1
        end
    end

    config.vm.define "node1" do |node1|
        node1.vm.box = "centos/7"
        node1.vm.hostname = "k8s-node1"
        node1.vm.network "private_network", ip: "192.168.10.20"
        node1.vm.provider "virtualbox" do |vb|
            vb.name = "k8s-node1"
            vb.memory = "2048"
            vb.cpus = 1
        end
    end

    config.vm.define "node2" do |node2|
        node2.vm.box = "centos/7"
        node2.vm.hostname = "k8s-node2"
        node2.vm.network "private_network", ip: "192.168.10.30"
        node2.vm.provider "virtualbox" do |vb|
            vb.name = "k8s-node2"
            vb.memory = "2048"
            vb.cpus = 1
        end
    end
end

```

最后，执行`vagrant up`就可以启动3台虚拟机

## 参考

- [Vagrant document](https://www.vagrantup.com/docs/multi-machine/)