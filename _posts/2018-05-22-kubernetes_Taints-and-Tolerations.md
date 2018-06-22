---
layout: post
title: Kubernetes Taints and Tolerations 
date: 2018-06-22 09:30:34 +0800
categories: kubernetes
---

Taints：污点，应用于`node`

Tolerations：容忍，应用于`pod`

`Taints`和`Tolerations`配合使用可以使特定的`pod`调度到特定的`node`，这对于某些场景来说非常有用。



## 概念

通过`kubectl taint`添加`taint`到节点：

```bash
kubectl taint node node1 key=value:NoSchedule
```

删除`taint`：

```bash
kubectl taint nodes node1 key:NoSchedule-
```

`Tolerations`配置：

```yaml
tolerations:
- key: "key"
  operator: "Equal"
  value: "value"
  effect: "NoSchedule"
```

```yaml
tolerations:
- key: "key"
  operator: "Exists"
  effect: "NoSchedule"
```

- 当`operator`是`Exists`时，`value`可以为空

- 当`operator`是`Equal`时，`value`是必须的

在没有指定的情况下，`operator`默认值是`Equal`

`effect`除了`NoSchedule`之外，还有`PreferNoSchedule`和`NoExecute`

- PreferNoSchedule：轻量版本的`NoSchedule`，对于没有设置`toleration`的`pod`，集群尽量避免调度到`PreferNoSchedule`的节点，但它不是必需的，还是有可能调度到`PreferNoSchedule`的节点；
- NoExecute：设置`NoExecute`之后，在节点上已经运行的但是没有设置`toleration`的`pod`都会被驱逐出该节点，新的`pod`，如果没有设置`toleration`也不会调度到该节点；

## 例子

需要设置两个专用的`node`来运行`es`

1. 设置`taint`

   ```bash
   kubectl taint nodes lognode1 dedicated=es:NoSchedule
   kubectl taint nodes lognode2 dedicated=es:NoSchedule
   kubectl labels nodes lognode1 role=es
   kubectl labels nodes lognode2 role=es
   ```

2. `pod template`配置

   ```yaml
   spec:
     contains:
     ...
     tolerations:
     - key: "dedicated"
       value: "es"
       effect: NoSchedule
     nodeSelector:
       role: es
   ```

   