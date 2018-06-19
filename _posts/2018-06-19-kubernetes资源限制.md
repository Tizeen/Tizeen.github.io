---
layout: post
title: Kubernetes资源限制
date: 2018-06-19 19:32:26 +0800
categories: kubernetes
---

* content
{:toc}

Kubernetes资源限制小记。




## 介绍

资源类型包括
- CPU
- 内存

CPU资源单位是`core`，使用小数也是允许的，比如0.5表示1core的一半，0.5同样等同于500m

```
# 1core
1000m

# 100 / 1000 core
0.1
```

内存资源单位是`byte`，可以使用E、P、T、G、M、K等单位，同样可以使用Ei、Pi、Ti、Gi、Mi、Ki，例如：

```
2G

4096Mi
```

## 配置 

通过在配置中写明即可，相对应的项有

- `spec.containers[].resources.limit.cpu`
- `spec.containers[].resources.limit.memory`
- `spec.containers[].resources.request.cpu`
- `spec.containers[].resources.request.memory`

**Example**

```yml
spec:
  containers:
  - name: rabbitmq
    image: rabbitmq
    ports: 
    - name: db
      containerPort: 5672
    - name: manager
      containerPort: 15672
    resources:
      limit:
        cpu: 2
        memory: 8G
      request:
        cpu: 0.5
        memory: 2G
```

通过`describe pod`可以看到限制的值是多少，`kubectl top`可以查看当前pod使用的资源

## 设定namespace中容器的默认限制值

通过使用`LimitRange`，可以在namespace设置一个默认值，而不必要在每个容器的配置中设定

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: mem-limit-range
spec:
  limits:
  - default: 
      memory: 512Mi
    defaultRequest:
      memory: 256Mi
    type: Container
```

- 如果容器中没有设置限定，那么limit值是512Mi，request值是256Mi
- 如果容器中限定的limit值大于512Mi，那么会使用容器中限定的limit值，而不是512Mi
- 如果容器中限定的request值小于256Mi，那么会使用容器中限定的request值，而不是256Mi

## 其他

1. 当pod请求的资源超出当前集群节点能满足的资源，pod会调度失败，直至有满足资源条件的节点出现；
2. 当容器的内存资源不足（限制值需要合理设置）时，容器会被杀死，然后pod重启；
3. `kubectl describe node`可以看到节点上所有pod的资源请求和限制比例；

## 一点小结

1. 每个容器都应该设置内存的`request`和`limit`值，这样能够避免应用内存泄露导致将节点资源耗尽的问题；
1. 明确的资源使用配置有利于集群合理调度pod；
1. 如果容器负载过高，可以设置`HPA`自动扩展pod数量；