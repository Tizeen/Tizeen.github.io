---
layout: post
title: OpenStack CLI
date: 2017-05-22 23:04:28 +0800
categories: 读书笔记
---

* content
{:toc}

虽然OpenStack有Web管理界面，但是有时使用CLI会更加方便和直观。




## 使用之前

在使用CLI之前需要设置一些环境变量才能使用，这些变量包括用户名、密码、Project等。

```bash
OS_PROJECT_NAME=demo
OS_USERNAME=demo
OS_PASSWORD=secret
HOST_IP=127.0.0.1
SERVICE_HOST=$HOST_IP
OS_AUTH_URL=http://$SERVICE_HOST:5000/v2.0
```

## 使用

- OpenStack每个组件都有自己的CLI，**命令的名字就是组件的名字**，但是KeyStone使用openstack命令来管理，而不是keystone命令
- 各个服务都有增，删，改，查的操作
- 每个对象都有id，像删除就可以通过id来删除
- 不知道命令如何使用时，通过`help`选项查看可用的命令

命令格式：

```bash
CMD <obj>-action [parm1] [parm2]...
```

一些命令案例:

Keystone:
```bash
## 列出所有用户
openstack user list
## 列出所有Ｒole
openstack role list
## 查看所有的Endpoint(对外开放的API)
openstack catalog list
```

Glance:
```bash
glance image-list
glance image-show
glance image-delete obj-id
glance image-update
```

Neutron:
```bash
## 网络相关
neutron net-create
neutron net -delete
neutron net -list

## 子网相关
neutron subnet-create
neutron net -delete
neutron net -list
```

Nova:
```bash
nova list
nova show
```
