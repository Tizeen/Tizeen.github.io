---
layout: post
title: CentOS7安装指定版本docker-ce
date: 2017-08-28 23:16:57 +0800
categories: Docker
---

* content
{:toc}

在使用[官方文档](https://docs.docker.com/engine/installation/linux/docker-ce/centos/#install-using-the-repository)安装`docker-ce`时，需要安装指定的版本，指定了版本但是安装的还是最新版本




## 解决

可以设置yum的参数来限定版本

```bash
$ yum search docker-ce

# list all available docker version
$ yum list docker-ce --showduplicates | sort -r

$ sudo yum install -y docker-ce-17.03.1.ce-1.el7.centos
```

or

```bash
$ sudo yum install --setopt=obsoletes=0 \
  docker-ce-17.03.1.ce-1.el7.centos \
```