---
layout: post
title: CentOS7 KVM Web管理工具WebVirtMgr部署
date: 2017-04-16 00:00:30 +0800
categories: 虚拟化
---

公司有个服务器跑着KVM的虚拟机，但是老是用命令行管理很不方便，发现webvirtmgr挺不错的，功能也比较齐全，这里就记录一下在Cent OS7上部署webvirtmgr的过程。




本文从webvirtmgr的项目[wiki](https://github.com/retspen/webvirtmgr/wiki)翻译而来，如有错误之处，感谢指出。

## 安装WebVirtMgr控制面板

1. 安装依赖：

    ```bash
    $ sudo yum -y install http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-9.noarch.rpm
    $ sudo yum -y install git python-pip libvirt-python libxml2-python python-websockify supervisor nginx
    $ sudo yum -y install gcc python-devel
    $ sudo pip install numpy
    ```

2. 安装Python依赖和Django环境

    ```bash
    $ git clone git://github.com/retspen/webvirtmgr.git
    $ cd webvirtmgr
    $ sudo pip install -r requirements.txt 
    $ ./manage.py syncdb
    $ ./manage.py collectstatic
    ```
    这里需要填写Web管理员的信息，最后用来登录Web的：
    
    ```bash
    You just installed Django's auth system, which means you don't have any superusers defined.
    Would you like to create one now? (yes/no): yes (Put: yes)
    Username (Leave blank to use 'admin'): admin (Put: your username or login)
    E-mail address: username@domain.local (Put: your email)
    Password: xxxxxx (Put: your password)
    Password (again): xxxxxx (Put: confirm password)
    Superuser created successfully.
    ```
    也可以添加额外的用户：
    
    ```bash
    $ ./manage.py createsuperuser
    ```

3. 设置Nginx

    WebVirtMgr默认开放的端口是8000,可以通过Nginx做反向代理通过访问80端口达到访问8000端口的目的。
    
    ```bash
    $ cd ..
    $ mkdir -p /var/www 
    $ sudo mv webvirtmgr /var/www/
    ```
    添加`webvirtmgr.conf`到`/etc/nginx/conf.d`：
    
    ```
    server {
        listen 80 default_server;
    
        server_name $hostname;
        #access_log /var/log/nginx/webvirtmgr_access_log; 
        
        location /static/ {
            root /var/www/webvirtmgr/webvirtmgr; # or /srv instead of /var
            expires max;
        }
        
        location / {
            proxy_pass http://127.0.0.1:8000;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-for $proxy_add_x_forwarded_for;
            proxy_set_header Host $host:$server_port;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 600;
            proxy_read_timeout 600;
            proxy_send_timeout 600;
            client_max_body_size 1024M; # Set higher depending on your needs 
        }
    }
    ```
    打开Nginx默认配置文件`/etc/nginx/nginx.conf`，注释掉默认的Server:
    
    ```bash
    #    server {
    #        listen       80 default_server;
    #        server_name  localhost;
    #        root         /usr/share/nginx/html;
    #
    #        #charset koi8-r;
    #
    #        #access_log  /var/log/nginx/host.access.log  main;
    #
    #        # Load configuration files for the default server block.
    #        include /etc/nginx/default.d/*.conf;
    #
    #        location / {
    #        }
    #
    #        # redirect server error pages to the static page /40x.html
    #        #
    #        error_page  404              /404.html;
    #        location = /40x.html {
    #        }
    #
    #        # redirect server error pages to the static page /50x.html
    #        #
    #        error_page   500 502 503 504  /50x.html;
    #        location = /50x.html {
    #        }
    #    }
    ```
    重启Nginx：
    
    ```bash
    $ sudo systemctl restart nginx
    ```
    更新SELinux策略：
    
    ```bash
    # -P：永久启用
    /usr/sbin/setsebool -P httpd_can_network_connect true 
    ```
    设置supervisord开机启动：
    
    ```bash
    $ sudo systemctl enable supervisord
    ```

4. 设置Supervisord

    运行：
    
    ```bash
    $ sudo chown -R nginx:nginx /var/www/webvirtmgr
    ```
    创建webvirtmgr的supervisrod配置文件`/etc/supervisord.d/webvirtmgr.ini`：
    
    ```bash
    [program:webvirtmgr]
    command=/usr/bin/python /var/www/webvirtmgr/manage.py run_gunicorn -c /var/www/webvirtmgr/conf/gunicorn.conf.py
    directory=/var/www/webvirtmgr
    autostart=true
    autorestart=true
    logfile=/var/log/supervisor/webvirtmgr.log
    log_stderr=true
    user=nginx
    
    [program:webvirtmgr-console]
    command=/usr/bin/python /var/www/webvirtmgr/console/webvirtmgr-console
    directory=/var/www/webvirtmgr
    autostart=true
    autorestart=true
    stdout_logfile=/var/log/supervisor/webvirtmgr-console.log
    redirect_stderr=true
    user=nginx
    ```
    重启supervisord守护进程：
    
    ```bash
    $ sudo systemctl stop supervisord
    $ sudo systemctl start supervisord
    ```

5. 检查服务

    检查Nginx是否已经运行:

    ```bash
    ps aux | grep nginx
    ```

## 设置主机服务

1. 设置libvirt和KVM：

    ```bash
    $ curl http://retspen.github.io/libvirt-bootstrap.sh | sudo sh 
    ```

    或者使用wget:
    ```bash
    $ wget -O - http://retspen.github.io/libvirt-bootstrap.sh | sudo sh
    ```

2. 配置防火墙

    ```bash
    $ sudo firewall-cmd --zone=public --add-port 16509/tcp --permanent
    $ sudo firewall-cmd --reload
    ```

## 设置KVM TCP授权

1. 创建用户访问libvirt

    使用`saslpasswd2`命令创建用户用来访问`libvirt`，这里创建一个`fred`的用户作为例子：
    ```bash
    $ sudo saslpasswd2 -a libvirt fred
    Password: xxxxxx
    Again (for verification): xxxxxx
    ```

    创建的用户存放在`/etc/libvirt/passwd.db`文件中，可以通过`sasldblistusers2`查看：
    ```bash
    $ sudo sasldblistusers2 -f /etc/libvirt/passwd.db
    fred@webvirtmgr.net: userPassword
    ```

    关闭一个用户的权限，使用`saslpasswd2`命令配合`-d`选项：
    ```bash
    $ sudo saslpasswd2 -a libvirt -d fred
    ```

2. 确认设置

    IP_address是上边添加用户的KVM节点
    ```bash
    $ virsh -c qemu+tcp://IP_address/system nodeinfo
    Please enter your authentication name: fred
    Please enter your password: xxxxxx
    CPU model:           x86_64
    CPU(s):              2
    CPU frequency:       2611 MHz
    CPU socket(s):       1
    Core(s) per socket:  2
    Thread(s) per core:  1
    NUMA cell(s):        1
    Memory size:         2019260 kB
    ```

    如果有以下错误：
    ```bash
    $ virsh -c qemu+tcp://IP_address/system nodeinfo
    Please enter your authentication name: fred
    Please enter your password:
    error: authentication failed: authentication failed
    error: failed to connect to the hypervisor
    ```

    检查输入的密码是否正确还有libvirtd的端口是否已经开放


## 设置noVNC

要在管理页面中使用虚拟机的控制台，还需要在防火墙中开放noVNC使用的端口：

```bash
$ sudo firewall-cmd --zone=public --add-port=6080/tcp --permanent
$ sudo firewall-cmd --reload
```

## 测试

最后，浏览器访问管理页面，登录系统，在控制中心添加一个节点，就可以通过Web来控制这个节点的虚拟机了。
