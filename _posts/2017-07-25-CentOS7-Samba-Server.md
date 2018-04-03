---
layout: post
title: CentOS7 Samba Server
date: 2017-07-25 09:03:06 +0800
categories: Linux Server
---

* content
{:toc}

Samba使得Linux和Windows之间文件共享十分方便。搭建Samba服务器来对文档进行统一的管理，这样文档统一存储在服务器上，但是可以直接通过Windows来编辑。

这里记录一下搭建过程。




## 安装

```shell
yum install -y samba samba-server
```

## 配置匿名共享

1. 修改配置文件如下

    ```bash
    vim /etc/samba/smb.conf
    ```

    ```bash
    [global]
    workgroup = WORKGROUP
    server string = Samba Server %v
    netbios name = centos # not hostname
    security = user
    map to guest = Bad User
    dns proxy = no
    #============================ Share Definitions ============================== 
    [Anonymous]
    path = /samba/anonymous
    browsable =yes
    writable = yes
    guest ok = yes
    read only = no
    ```

1. 创建目录

    ```bash
    mkdir -p /samba/anonymous
    ```

1. 检查配置文件

    可以使用`testparm`命令检验配置是否正确。

1. 配置防火墙

    ```bash
    firewall-cmd --zone=public --add-service=samba --permanent
    firewall-cmd --reload
    ```

1. 配置SELinux和目录权限

    要正确读取共享目录中的文件，SELinux和目录权限配置不可缺少

    ```bash
    chown -R nobody:nobody /samba/anonymous
    chmod -R 0755 /samba/anonymous
    ## 查看Security context
    ls -ldZ /samba/anonymous
    chchon -t samba_share_t  /samba/anonymous
    ```

1. 启动服务

    ```bash
    systemctl start smb
    systemctl start nmb
    ```

这时就可以在Windows访问共享的目录了

## 配置安全共享

1. 添加用户组

    ```bash
    groupadd smbgrp
    ```

1. 添加用户

    ```bash
    useradd user1 -G smbgrp
    ```

1. 为用户设定密码

    ```bash
    smbpasswd -a user1
    ```

1. 配置文件中添加相应共享

    ```bash
    [secured]
        path = /samba/secured
        valid users = @smbgrp
        guest ok = no
        writable = yes
        browsable = yes
    ```

1. 更改权限和SELinux

    ```bash
    mkdir -p /samba/secured
    cd /samba
    chmod -R 0777 secured/
    chown -R user1:smbgrp secured/
    chcon -t samba_share_t secured/
    ```

1. 检查配置文件

    ```bash
    testparm
    ```

1. 重启服务

    ```bash
    systemctl restart smb
    systemctl restart nmb
    ```

## 后记

最后发现[ownCloud](https://owncloud.org/)对文件统一管理更加合适，既可以通过Web端访问，也有同步盘，权限控制更加全面，更易于管理文件和用户，部署也可以通过Docker来运行，推荐使用。