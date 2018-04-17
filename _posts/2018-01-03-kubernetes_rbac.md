---
layout: post
title: kubernetes RBAC
date: 2018-01-03 23:06:53 +0800
categories: kubernetes
---

* content
{:toc}

最近在使用`kube-prometheus`时，需要自定义监控，然后遇到了跟`RBAC`相关的错误，导致监控失败，虽然通过搜索解决了，但还是需要对`RBAC`进行一个深入学习才行。




RBAC：全称`Role-Based Access Control`，基于角色的权限控制，通过使用`rbac.authorization.k8s.io`API组执行授权决定，允许管理员通过`Kubernetes API`动态配置权限


## API概览

RBAC API包含了4个顶级类型的资源对象，用户可以像创建其他资源一样来创建RBAC资源，例如：`kubectl create -f (resource).yml`

### Role和ClusterRole

`Role`里边包含有规则，这些规则代表一组权限。权限只能纯粹的增加（这里没有禁止相关的规则）。`Role`可以定义在一个`namespace`中，对应集群的是`ClusterRole`

一个`Role`只能授予给一个`namespace`资源访问权限，下边是一个例子

```yml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: default
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
```

`ClusterRole`可以像`Role`一样授予同样的权限，但因为是集群级的，所以对应的资源也不一样，`ClusterRole`可以用于：

- 集群资源（比如：nodes）
- 非资源型endpoints（比如：/healethz）
- 所有命名空间资源（比如：pods）

下述是一个`ClusterRole`的相关例子：

```yml
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "watch", "list"]
```

**Note: ClusterRole因为是集群级的，不需要定义namespace**

### RoleBinding和ClusterRoleBinding

规则定义好之后，还需要将这些规则绑定给一个用户或是一组用户。这些用户对象在kubernetes中有：users, groups, service accounts

`RoleBinding`会引用同一个命名空间下的`Role`。下述的`RoleBinding`是在 "default" 命名空间内将 "pod-reader" 的role赋予给 "jane" 用户

```yml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: read-pods
  namespace: default
subject:
- kind: User
  name: jane
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

`RoleBinding`同样可以引用`ClusterRole`对当前命名空间内的用户、用户组或Service Account授予权限。这样就允许管理员定义一系列相同的规则，然后在不同的命名空间内使用

```yml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: read-secrets
  namespace: development
subject:
- kind: User
  name: dave
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: secert-reader
  apiGroup: rbac.authorization.k8s.io
```

例子中`RoleBinding`应用`secret-reader`的`ClusterRole`，但是 dave 还是只能读取 development 命名空间下的 secret，因为`RoleBinding`应用在 development 这个命名空间下

`ClusterRoleBinding`对整个集群的命名空间授权

```yml
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: read-secrets-global
subject:
- kind: Group
  name: manager
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: secert-reader
  apiGroup: rbac.authorization.k8s.io
```

## 一个例子

配置一个名字为`test-sa`的`ServiceAccount`，限定在`test`命名空间内，但是能操作`test`命令空间的所有资源

1. 配置`ServiceAccount`

  ```yaml
  apiVersion: v1
  kind: ServiceAccount
  metadata:
    name: test-sa
    namespace: test
  ```

1. 定义`role`

  ```yaml
  apiVersion: rbac.authorization.k8s.io/v1
  kind: Role
  metadata:
    namespace: test
    name: all-priviledges-roles
  rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
  ```

  `*`表示所有

1. 定义`RoleBinding`

  ```yaml
  apiVersion: rbac.authorization.k8s.io/v1
  kind: RoleBinding
  metadata:
    name: all-priviledges-rolebinding
    namespace: test
  roleRef:
    kind: Role
    name: all-priviledges-roles
    apiGroup: rbac.authorization.k8s.io
  subjects:
  - kind: ServiceAccount
    name: test-sa
    namespace: test
  ```

没创建一个`ServiceAccount`时，都会创建一个对应的`secret`，保存有`token`，可以使用这个`token`值登录`kubernetes dashboard`，所有的操作被限制在`test`这个命名空间下。

查看`token`命令：

```sh
kubectl describe serviceaccount <serviceaccount name>
kubectl describe secret <secret name>
```


## 简单总结

`Role`和`ClusterRole`是角色，这些角色拥有不同的权限，我们可以控制这些角色的权限

`RoleBinding`和`ClusterRoleBinding`将角色赋予给用户，使用户拥有这个角色的权限，从而可以对集群的资源进行操作

## 参考

- [官方文档](https://kubernetes.io/docs/admin/authorization/rbac/)
- [Kubernetes RBAC](https://mritd.me/2017/07/17/kubernetes-rbac-chinese-translation/)