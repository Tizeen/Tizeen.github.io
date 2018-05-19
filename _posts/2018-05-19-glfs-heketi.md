---
layout: post
title: Kubernetes Use GlusterFS Storageclass
date: 2018-05-19 12:16:16 +0800
categories: kubernetes
---

* content
{:toc}

- GlusterFS: 可扩展的分布式文件系统，可将来自多个服务器的磁盘资源整合到一个命名空间中
- Heketi: 基于RESTful风格的GlusterFS卷管理框架

通过`Heketi`提供的API来管理`GlusterFS`集群，`kubernetes`的`GlusterFS Storageclass`通过`Heketi`的地址连接。



## 环境

- glfs节点数：3（节点命名方式`glfs-nodeN`，每个节点必须有一块裸磁盘）
- 系统：CentOS7.4
- glfs版本：3.12
- heketi版本：5.0.1

## GlusterFS安装

在所有节点上安装`glusterfs-server`

```bash
yum install -y centos-release-gluster
yum install -y glusterfs-server
systemctl enable glusterd
systemctl start glusterd
```

## Heketi安装和配置

1. 在`glfs-node1`安装`heketi`

    ```bash
    yum install -y heketi heketi-client
    systemctl enable heketi
    systemctl start heketi
    ```

1. 生成key，打通heketi与glfs节点间ssh无密码登录

    ```bash
    ssh-keygen -f /etc/heketi/heketi_key -t rsa -N ''
    ssh-copy-id -i /etc/heketi/heketi_key.pub root@glfs-node1
    ssh-copy-id -i /etc/heketi/heketi_key.pub root@glfs-node2
    ssh-copy-id -i /etc/heketi/heketi_key.pub root@glfs-node3
    ```

1. 修改heketi配置

    ```json
    {
       "_port_comment":"Heketi Server Port Number",
       "port":"8080",
       "_use_auth":"Enable JWT authorization. Please enable for deployment",
       "use_auth":true,
       "_jwt":"Private keys for access",
       "jwt":{
          "_admin":"Admin has access to all APIs",
          "admin":{
             "key":"adminpass"
          },
          "_user":"User only has access to /volumes endpoint",
          "user":{
             "key":"userpass"
          }
       },
       "_glusterfs_comment":"GlusterFS Configuration",
       "glusterfs":{
          "_executor_comment":[
             "Execute plugin. Possible choices: mock, ssh",
             "mock: This setting is used for testing and development.",
             "      It will not send commands to any node.",
             "ssh:  This setting will notify Heketi to ssh to the nodes.",
             "      It will need the values in sshexec to be configured.",
             "kubernetes: Communicate with GlusterFS containers over",
             "            Kubernetes exec api."
          ],
          "executor":"ssh",
          "_sshexec_comment":"SSH username and private key file information",
          "sshexec":{
             "keyfile":"/etc/heketi/heketi_key",
             "user":"root",
             "port":"22",
             "fstab":"/etc/fstab"
          },
          "_kubeexec_comment":"Kubernetes configuration",
          "kubeexec":{
             "host":"https://kubernetes.host:8443",
             "cert":"/path/to/crt.file",
             "insecure":false,
             "user":"kubernetes username",
             "password":"password for kubernetes user",
             "namespace":"OpenShift project or Kubernetes namespace",
             "fstab":"Optional: Specify fstab file on node.  Default is     /etc/fstab"
          },
          "_db_comment":"Database file name",
          "db":"/var/lib/heketi/heketi.db",
          "_loglevel_comment":[
             "Set log level. Choices are:",
             "  none, critical, error, warning, info, debug",
             "Default is warning"
          ],
          "loglevel":"debug"
       }
    }
    ```

    - `jwt`设置认证的用户名和密码
    - `executor`设置操作方式，`sshexec`中修改对应ssh连接信息

    修改配置文件之后重启`heketi`

1. 测试heketi

    `heketi`默认使用了`8080`端口，可以在配置文件中修改

    ```bash
    curl http://localhost:8080/hello
    ```

1. 创建拓扑

    `heketi`可以根据`json`文件中定义好的内容创建拓扑

    这里定义了3个节点，每个节点的`/dev/vdb`磁盘来做存储

    **topology-sample.json**
    
    ```json
    {
       "clusters":[
          {
             "nodes":[
                {
                   "node":{
                      "hostnames":{
                         "manage":[
                            "10.244.4.148"
                         ],
                         "storage":[
                            "10.244.4.148"
                         ]
                      },
                      "zone":1
                   },
                   "devices":[
                      "/dev/vdb"
                   ]
                },
                {
                   "node":{
                      "hostnames":{
                         "manage":[
                            "10.244.4.136"
                         ],
                         "storage":[
                            "10.244.4.136"
                         ]
                      },
                      "zone":1
                   },
                   "devices":[
                      "/dev/vdb"
                   ]
                },
                {
                   "node":{
                      "hostnames":{
                         "manage":[
                            "10.244.4.143"
                         ],
                         "storage":[
                            "10.244.4.143"
                         ]
                      },
                      "zone":1
                   },
                   "devices":[
                      "/dev/vdb"
                   ]
                }
             ]
          }
       ]
    }
    ```

    执行：

    ```bash
    export HEKETI_CLI_SERVER=http://localhost:8080
    heketi-cli --user admin --secret adminpass topology load --json=topology-sample.json
    # 查看拓扑
    heketi-cli --user admin --secret adminpass topology info
    ```

    这时如果使用`gluster`自己的命令查看`peer`的状态，就能看到其他节点

    ```bash
    gluster peer status
    ```

1. 创建数据卷

    可以直接使用`heketi-cli`直接在glfs中创建数据卷

    ```bash
    # 创建大小30G的数据卷
    heketi-cli --user admin --secret adminpass volume create --size=30
    ```

    数据卷的`brick`在`glfs`集群中表现形式是一个`lvm`的逻辑卷，通过`lvdisply`可以查看

    更多的管理命令可以通过`heketi-cli -h`查看

## kubernetes GlusterFS storageclass

在配置好`heketi`之后，`storageclass`就可以直接用了

**glfs-storageclass.yml**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: glfs-storageclass
provisioner: kubernetes.io/glusterfs
parameters:
  resturl: "http://10.244.4.148:8080"
  clusterid: "1c9971e6170ded3c7adf3546a6186827"
  restauthenabled: "true"
  restuser: "admin"
  secretNamespace: "default"
  secretName: "heketi-secret"
  gidMin: "40000"
  gidMax: "50000"
  volumetype: "replicate:3"
```

关于各个字段的意义，参考[kubernetes文档](https://kubernetes.io/docs/concepts/storage/storage-classes/#glusterfs)

**heketi-secret.yml**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: heketi-secret
type: kubernetes.io/glusterfs
data:
  key: YWRtaW5wYXNz
```

key的值是使用`base64`加密之后的

**glfs-test-pvc.yaml**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  storageClassName: glfs-storageclass
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 30Gi
```

使用`kubectl`查看创建的pvc是否是`bound`的状态

```bash
kubectl get pvc
```

## 参考

- [Gluser Docs](https://docs.gluster.org/en/latest/Quick-Start-Guide/Quickstart/)
- [heketi Docs](https://github.com/heketi/heketi/tree/master/docs/)
- [kubernetes storageclass](https://kubernetes.io/docs/concepts/storage/storage-classes/)