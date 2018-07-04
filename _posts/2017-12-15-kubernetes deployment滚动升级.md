---
layout: post
title: kubernetes deployment升级和回滚
date: 2017-12-15 23:28:57 +0800
categories: kubernetes
---

* content
{:toc}

**Note**：本文实践环境是**kubernetes 1.8.2**版本

在`kubernetes`中使用`deployment`管理`rs`时，可以利用`deployment`滚动升级的特性，达到服务零停止升级的目的



## 升级

- **set image**

直接使用`kubectl set image`的方式升级 deployment

```bash
$ kubectl set image deployment/nginx-deployment nginx=nginx:1.13.7 --record
deployment "nginx-deployment" image updated
```

- **edit**

通过修改 deployment 的配置中的 image 信息达到升级的目的。这种升级方式和在 dashboard 界面中编辑 deployment 配置的方式是一致的

```bash
$ kubectl edit deployment nginx-deployment
```

执行该命令后，会调用`vim`来修改 deployment 的配置，修改完之后保存就会生效

- **replace**

修改原 deployment 配置文件，然后通过`kubectl replace`进行升级

```bash
$ kubectl replace -f <file> --record
```

## 升级策略

deployment 有 2 种策略，分别是`Recreate`和`RollingUpdate`，`RollingUpdate`是默认的策略

`RollingUpdate`也有相对应的升级策略，如果策略设置的不合理，那么升级的过程就有可能导致服务中断

- **Max Unavailable**

最多有几个 pod 处于无法工作的状态，默认值是**25%**

- **Max Surge**

升级过程中可以比预设的 pod 的数量多出的个数，默认值是**25%**

- **minReadySeconds**

等待容器启动的时间，默认值是 **0**，单位是：秒，容器运行成功之后直接执行下一步

根据应用启动时间，设定相应的**minReadySeconds**，保证应用不中断

**Deployment Example**

```yml
apiVersion: apps/v1beta2
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  strategy: 
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 2
  minReadySeconds: 5
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.12-alpine
        ports:
        - containerPort: 80
```

## 回滚

在更新出问题之后，可能就需要对应用进行回滚

将应用更新到旧版本的镜像可以做到应用的回滚，除此之外，可以使用 deployment 的历史版本进行回滚

查看 deployment 升级历史：

```bash
$ kubectl rollout history deployment/nginx-deployment
deployments "nginx-deployment"
REVISION  CHANGE-CAUSE
1         kubectl apply --filename=nginx-test.yml --record=true
2         kubectl replace --filename=nginx-test.yml --record=true
```

**Note:** 如果 CHANGE-CAUSE 为空，那是因为在创建 deployment 时没有使用`--record`选项

如果想要查看历史版本更加详细的升级信息，还可以这样

```bash
$ kubectl rollout history deployment/nginx-deployment --revision=2
```

**Note:** `rollout history`命令输出的历史版本和`deployment`对应的`replicas`对应，如果手动删除了`deployment`某个`replica`，那么相应的`rollout history`也会消失，这样便无法回滚到那个历史版本了。

- 回滚到上一个版本

```bash
$ kubectl rollout undo deployment/nginx-deployment
```

- 回滚到指定版本

```bash
$ kubectl rollout undo deployment/nginx-deployment --to-revision=2
```

## 参考

- [kubernetes dployment官方文档](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#rolling-update-deployment)
- [KUBERNETES DEPLOYMENT 實現滾動升級](https://tachingchen.com/tw/blog/Kubernetes-Rolling-Update-with-Deployment/)