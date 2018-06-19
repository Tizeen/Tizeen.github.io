---
layout: post
title: Prometheus+node_exporter+alertmanager监控主机
date: 2018-04-21 12:38:30 +0800
categories: prometheus
---

* content
{:toc}

先前采用`zabbix+grafana`监控主机状态，觉得`zabbix`虽然功能强大，但过于臃肿了。在`Kubernetes`集群的建设中，监控采用`kube-prometheus`，知道了`prometheus`，于是将其他主机也采用`prometheus+node_exporter`监控起来。这里记录一下过程，以供后续查询。



## Prometheus

### 安装

采用`go`语言编写，安装十分简单，在[release](https://github.com/prometheus/prometheus/releases)将文件下载下来，解压，使用`systemd`来管理服务即可。

`prometheus.service`内容：

```
[Unit]
Description=Prometheus Monitoring service
After=network.target auditd.service

[Service]
ExecStart=/opt/prometheus/prometheus \
            --config.file="/opt/prometheus/prometheus.yml"
Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
```

### 配置

配置采用`yml`格式的文件，清晰明了。

```yaml
# my global config
global:
  scrape_interval:     15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.                                          
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
  # scrape_timeout is set to the global default (10s). 

# Alertmanager configuration                                
alerting:    

  alertmanagers:                            
  - static_configs:
    - targets:
      - localhost:9093

# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
rule_files:
  - "rules/high_load.rules"
  # - "second_rules.yml"

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config. 
  - job_name: 'prometheus'

    # metrics_path defaults to '/metrics'
    # scheme defaults to 'http'.
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'linux_server'

    # metrics_path defaults to '/metrics'
    # scheme defaults to 'http'.
    static_configs:
      - targets:
        - '127.0.0.1:9100'
```

`rules`规则示例：

```
groups:
- name: example
  rules:

  # CPU使用率超过85%触发告警
  - alert: NodeCPUUsage
    expr: (100 - (avg by (instance) (irate(node_cpu{job="linux_server",mode="idle"}[5m])) * 100)) > 85
    for: 2s
    labels:
      servity: page
```


- global：定义全局配置，比如抓取数据间隔、超时时间等
- alerting：定义`alert`信息，根据此配置和`alertmanager`通信
- rules：定义`alerting rule`，当规则被触发之后，通知`alertmanager`发送告警消息
- scrape_configs：定义数据源配置，不同的数据源用不同的`job`表示

还有其他的配置项没有用到，比如`remote_write`和`remote_read`，具体请查看[官方文档]。(https://prometheus.io/docs/prometheus/latest/configuration/configuration/)

`scrape_config`使用了`static config`，在小量机器中使用简单快捷，当机器数量很多时，使用`service discovery`方式更好，具体参考[官方文档](https://prometheus.io/blog/2015/06/01/advanced-service-discovery/)。


### 访问

`prometheus`默认采用的`9090`端口，有一个简单的web管理界面，可以用来查看服务信息和数据查询。

## Node exporter

下载[地址](https://github.com/prometheus/node_exporter/releases)，使用`systemd`管理服务。

`node_exporter.sevice`内容：

```
[Unit]
Description=Prometheus Node exporter service
After=network.target auditd.service

[Service]
ExecStart=/opt/node_exporter/node_exporter
Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
```

node exporter默认使用`9100`端口，可以使用`--web.listen-address=":9200"`指定端口号。

默认方式运行包括了很多Collectors（比如：cpu、meminfo、filesystem....），关于Colletors，请查看[官方README](https://github.com/prometheus/node_exporter/blob/master/README.md)

`Node exporter`常用查询语句：

- CPU使用率

    ```
    100 - (avg by (instance) (irate(node_cpu{instace="xxx", mode="idle}[5m])) * 100) 
    ```

- 内存使用率

    ```
    100 - ((node_memory_MemFree{instance="xxx}+node_memory_Cached{instace="xxx"}+node_memory_Buffers{instace="xxx"})/node_memory_MemTotal) * 100
    ```

- 磁盘使用率

    ```
    100 - node_filesystem_free{instance="xxx",fstype!~"rootfs|selinuxfs|autofs|rpc_pipefs|tmpfs|udev|none|devpts|sysfs|debugfs|fuse.*"} / node_filesystem_size{instance="xxx",fstype!~"rootfs|selinuxfs|autofs|rpc_pipefs|tmpfs|udev|none|devpts|sysfs|debugfs|fuse.*"} * 100
    ```

- 网络IO

    ```
    // 下行带宽
    sum by (instance) (irate(node_network_receive_bytes{instance="xxx",device!~"bond.*?|lo"}[5m])/128)

    //上行带宽
    sum by (instance) (irate(node_network_transmit_bytes{instance="xxx",device!~"bond.*?|lo"}[5m])/128)
    ```

## alertmanager

下载[地址](https://github.com/prometheus/alertmanager/releases)，使用`systemd`管理服务。

`alertmanager.service`内容：

```
[Unit]
Description=Prometheus alertmanager service
After=network.target auditd.service

[Service]
ExecStart=/opt/alertmanager/alertmanager \
            --config.file /opt/alertmanager/email.yml
Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
```

配置了使用邮件告警，使用了qq邮箱的smtp服务，`email.yml`内容：

```
global:
  smtp_from: "xxx@qq.com"
  smtp_smarthost: "smtp.qq.com:587"
  smtp_auth_username: "xxx@qq.com"
  smtp_auth_password: "connect_smtp_password"
  # smtp_require_tls: true
  
route:
  receiver: "receiver"

receivers:
- name: "receiver"
  email_configs:
    - to: "xxxx@foxmail.com"
```

`alertmanager`还可以通过很多方式进行告警，比如：`slack`、`hipchat`、`webhook`等，如何配置可以参考[官方文档](https://prometheus.io/docs/alerting/configuration/)

`alertmanager`使用了`9093`端口，同样拥有一个简单的web管理界面。

## 总结

虽然整套监控能正常工作了，但是还是显得很简单，`prometheus`还有很多东西需要深入探索，并且本文没有涉及到`Grafana`进行数据展示部分。这里列出一些自己认为需要深入探索的内容。

- prometheus架构
- 时间序列数据
- 数据查询运算语句
- 监控高可用
- 更加细化的告警规则
- 告警模板
- 使用`client library`监控应用服务

## 参考

- [Prometheus document](https://prometheus.io/docs/)
- [Prometheus实战](https://www.gitbook.com/book/songjiayang/prometheus/details)