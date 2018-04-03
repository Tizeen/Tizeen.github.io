---
layout: post
title: OpenWrt x86 FTP服务器
date: 2017-03-11 19:15:02 +0800
categories: 折腾
---

* content
{:toc}

OpenWrt在x86的板子上已经安装并正常的运行了，但是硬盘还有很大的空间没有用到，感觉有点浪费，于是便想搭建一个简单的FTP服务器，在局域网内共享一些常用的资源。




这里使用vsftpd实现匿名用户只能下载资源，无法上传和修改。

## 配置步骤

1. 安装vsftpd

    使用opkg包管理工具直接安装。

    ```bash
    opkg install vsftpd
    ```

1. 修改配置文件

    在基础配置上对`/etc/vsftpd.conf`配置文件做一些修改，其他的配置无需修改。

    ```
    # 采用standalone方式运行
    background=YES
    # 启用匿名用户
    anonymous_enable=YES
    # 匿名用户不用输入密码
    no_anon_password=YES
    # 指定chroot的目录
    anon_root=/data/anonymous
    ```

1. 管理vsftpd

    ```bash
    # 启动vsftpd
    /etc/init.d/vsftpd start
    # 关闭vsftpd
    /etc/init.d/vsftpd stop
    ```

## 测试

- 局域网内浏览器直接访问`ftp://ip`，可以看到存放在/data/anonymous目录的文件，可以下载;

- 使用FileZilla连接，输入anonymous，不输入密码直接登录，能成功登录，并且无法切换到/data/anonymous目录之外的其他目录，说明chroot有效;

