---
layout: post
title: Linux iptables防护
date: 2017-04-07 22:25:11 +0800
categories: 系统
---

* content
{:toc}

最近有个设备刚好要使用iptables进行简单的保护，这里记录下iptables的使用过程。




## 防火墙简介

防火墙隔开了信任区域和非信任区域。

防火墙类型：

- 以TCP/IP堆栈来区分：网络层防火墙、应用层防火墙

- 以软硬件区分：硬件防火墙、软件防火墙、软硬结合防火墙

- 代理防火墙

- 状态检测防火墙

- 统一威胁管理(UTM)防火墙

## Linux流量流程图

![](http://ww1.sinaimg.cn/mw690/9bbe7ebdgy1fdosrs5dhkj20hz0ukwiw)

## iptables组成

iptables由一系列的表**(tables)**组成，每个表中包含一套预定义的链**(chain)**，链中包含了顺序遍历的规则**(rules)**，每条规则都会有一个目标操作**(target)**

iptables会遍历每一条规则，如果没有匹配到就会执行规则所在链的target

### Tables

iptables包含5个表

1. raw

2. filter：默认表，一般的过滤都发生在这张表

3. nat：通常用来做网络地址转换

4. manqle

5. security

比较常用的是filter和nat这两个表。

### Chains

filter表内建的链有：

- INPUT

- OUTPUT

- FORWARD

nat表内建的链有：

- PREROUTING：DNAT的rules放在里边

- POSTROUTING : SNAT的rules放在里边

- OUTPUT

### Rules

每条规则都包含有条件，符合条件的数据包都会执行一个target

使用`-j`或`--jump`选项指定target，常用的target有`ACCEPT`,`DROP`,`RETURN`

### Modules

模块可以扩展iptables的功能，使用`-m`指定使用的模块

常用几个Module如下：

1. conntrack: 根据数据包的状态定义规则

2. limit: 可以限制数据包的速率

3. tcp

4. icmp

其他扩展以及详细功能用法可以通过`man iptables-extensions`查看

## iptables管理

```bash
# 查看规则

## 查看filter表的规则(filter是默认表，可以不写)
iptables -S
iptables -t filter -S
iptables -t filter -nvL --line-numbers

## 查看nat表的规则
iptables -t nat -nvL --line-numbers

# 链操作

# 添加
iptables -N TCP
iptables -N UDP

## 删除
iptables -X TCP
iptables -X UDP

## 更改链的target
iptables -P INPUT DROP

# 规则操作

## 添加规则
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

## 删除规则(也可以通过规则编号来删除 --line-numbers)
iptables -D INPUT -p tcp --dport 22 -j ACCEPT
iptables -D INPUT 3

iptables -A INPUT -i lo -j ACCEPT

iptables -A INPUT -s 192.168.0.23 -j DROP

# 模块使用

## conntrack模块
iptables -A INPUT -p tcp -m conntrack --ctstate RELATE,ESTABLISHED -j ACCEPT
iptables -A INPUT -p tcp -m conntrack --ctstate INVALID -j DROP

## limit模块
iptables -A INPUT -p icmp -m icmp --icmp-type 8 -m limit --limit 1/sec -j ACCEPT

# NAT
## SNAT
iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o ppp0 -j SNAT --to-source 32.12.34.56
### 如果出口地址不是固定的(拨号连接)，可以使用MASQUERADE这个target
iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o ppp0 -j MASQUERADE

## DNAT
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 80 -j DNAT --to-destination 192.168.1.2:80
```

## 导入导出rules

```bash
## 导出规则
iptables-save > iptables.rules

## 导入规则
iptables-restore < iptables.rules

## 保存规则
service iptables save
```

Note: CentOS7以上版本已经采用`firewalld`管理防火墙，如想使用iptables，可以这样

```bash
# stop and disable firewalld
systemctl stop firewalld
systemctl disable firewalld

# Install iptables services
yum install iptables-services
```

## 简单主机防护规则

以下是一个简单的iptables防护规则:

```bash
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [141409:11506175]
## 根据数据包的状态进行过滤
-A INPUT -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j ACCEPT
-A INPUT -m conntrack --ctstate INVALID -j DROP
## 允许ping
-A INPUT -p icmp -m icmp --icmp-type 8 -m conntrack --ctstate NEW -j ACCEPT
## 允许lo网口流量
-A INPUT -i lo -j ACCEPT
-A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
-A INPUT -i eth5 -p tcp -m tcp --dport 3306 -j ACCEPT
## 指定一段端口
-A INPUT -p tcp -m tcp --dport 30600:30604 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 30606 -j ACCEPT
-A INPUT -i eth5 -p udp -m udp -m multiport --dports 5404:5405 -j ACCEPT
COMMIT
```

## 参考

- [防火墙-维基百科](https://zh.wikipedia.org/wiki/%E9%98%B2%E7%81%AB%E5%A2%99)

- [防火墙类型-cisco](http://www.cisco.com/c/zh_cn/products/security/firewalls/what-is-a-firewall.html)

- [iptables-archwiki](https://wiki.archlinux.org/index.php/Iptables)

- [Simple stateful firewall](https://wiki.archlinux.org/index.php/Simple_stateful_firewall)