---
layout: post
title: Kubernetes Traefik+Ingress实践
date: 2018-01-28 09:53:48 +0800
categories: kubernetes
---

* content
{:toc}

如果想从外部访问kubernetes中运行的服务，可以通过以下几种方式：

- NodePort: 从NodePort范围段（默认：30000-32767）随机选取没有被占用的端口进行使用，如果不指定端口号，重建服务之后端口号会发生变化
- LoadBalancer: 使用云服务商的负载均衡服务对外开放
- External IPs: 通过外部可访问的ip和端口，然后路由到集群的节点

除了这些访问方式外，我们还可以通过配置Kubernets的`Ingress`来访问服务




## Ingress

```
internet
   |
[Ingress]
--|---|--
[Services]
```

两个概念：

- Ingress Resource：定义服务访问的规则以及其他内容
- Ingress Controller：与Kubernetes API通信，监控Ingress Resource的规则变化，并修改相对应的Controller配置（比如：Nginx配置）

目前接触过的`Ingress Controller`包括

- [Nginx Ingress Controller](https://github.com/kubernetes/ingress-nginx/blob/master/README.md)
- [Traefik](https://docs.traefik.io/)

如果配置了`Ingress Resource`，但是没有安装`Ingress Controller`，`Ingress`是不会起作用的

## Traefik

`Traefik`作为交通管理员，可以用于`Kubernetes`集群的`Ingress Controller`

安装`Traefik`

1. 配置`RoleBinding`和`ClusterRoleBinding`
    ```bash
    kubectl apply -f https://raw.githubusercontent.com/containous/traefik/master/examples/k8s/traefik-rbac.yaml
    ```
1. 以`Deployment`或者`DaemonSet`的方式安装Traefik

    - Deployment
    ```bash
    kubectl apply -f https://raw.githubusercontent.com/containous/traefik/master/examples/k8s/traefik-deployment.yaml
    ```

    - DaemonSet
    ```bash
    kubectl apply -f https://raw.githubusercontent.com/containous/traefik/master/examples/k8s/traefik-ds.yaml
    ```

1. 检查Pods

    ```bash
    kubectl --namespace=kube-system get pods
    ```

`Traefik`会使用2个端口，一个用来接收访问服务的流量，另一个端口可以访问到`Traefik`的Web UI，可以查看当前的`Ingress`规则

以`Deployment`方式部署时，通过`kubectl get svc -n kube-system`查看对应的端口

**Note:** 以`DaemonSet`方式部署时，默认会使用节点的80端口

## Ingress例子

1. 通过域名转发

    ```yaml
    apiVersion: extensions/v1beta1
    kind: Ingress
    metadata:
      name: cheese
      annotations:
        kubernetes.io/ingress.class: traefik
    spec:
      rules:
      - host: stilton.minikube
        http:
          paths:
          - path: /
            backend:
              serviceName: stilton
              servicePort: http
      - host: cheddar.minikube
        http:
          paths:
          - path: /
            backend:
              serviceName: cheddar
              servicePort: http
    ```

1. 根据路径转发

    ```yaml
    apiVersion: extensions/v1beta1
    kind: Ingress
    metadata:
      name: cheeses
      annotations:
        kubernetes.io/ingress.class: traefik
        traefik.frontend.rule.type: PathPrefixStrip
    spec:
      rules:
      - host: cheeses.minikube
        http:
          paths:
          - path: /stilton
            backend:
              serviceName: stilton
              servicePort: http
          - path: /cheddar
            backend:
              serviceName: cheddar
              servicePort: http
          - path: /wensleydale
            backend:
              serviceName: wensleydale
              servicePort: http
    ```

注意`Ingress`中定义的注解，还有很多其他的注解没有使用到，包括定义优先级，定义负载类型，定义入口类型（http或https）等注解，更加详细的说明参考[官方说明](https://docs.traefik.io/configuration/backends/kubernetes/#annotations)
    
更多使用案例参考[Traefik官方文档](https://docs.traefik.io/user-guide/kubernetes/)

## 参考

- [Kubernetes Ingress doc](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Kubernetes Service doc](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Kubernetes Nginx Ingress 教程](https://mritd.me/2017/03/04/how-to-use-nginx-ingress/)（文章中关于ingress的解释特别好）
- [Traefik Kubernetes Guides](https://docs.traefik.io/user-guide/kubernetes/)