---
layout: post
title: Dockerfile经验之谈
date: 2018-04-18 23:35:14 +0800
categories: Docker
---

* content
{:toc}

最近由于工作需要，编写了不少Dockerfile，其中也踩了不少坑，这里对此进行总结一下。




## 镜像层划分

虽说镜像层的数量越少越好，但也不能无脑的将所有东西都放在一个层里。做好划分，利用好缓存，编译镜像时也会更快。

从下往上看，我一般是这样划分的：

- 基础层
- 中间件层
- 不变数据层（静态文件）
- 变化数据层

将会发生变化的层放在最顶上，这样在它以下的层都可以使用缓存，这样在编译镜像时就能提高不少速度。

## 时区

如果镜像没有指定时区，那么默认的是`UTC`时区。对应要使用本地时间的应用，就有可能导致问题；另一方面，容器日志也显示的`UTC`时区的时间，看起来就会觉得很恍惚。

可以在Dockerfile中通过`ENV`来设定本地时区

```dockerfile
ENV TZ Asia/Shanghai
```

## ADD或者COPY

`ADD`和`COPY`在功能上很类似，但通常优先选择使用`COPY`，因为`COPY`比`ADD`更透明。

`COPY`仅有复制的功能，而`ADD`除了复制的功能外，还有其他的特性

- ADD后边可以加一个url，下载这个url对应的文件
- ADD后边如果加的一个压缩文件，那么在编译的时候它会将这个压缩文件解压放到镜像中

## 复制目录到容器

- 复制单个目录

    ```dockerfile
    ADD go /usr/local/go
    # or
    COPY go /usr/local/go
    ```

    **Note:** 不需要在容器中先创建`go`这个目录

- 复制多个目录

    失败的做法：

    ```dockerfile
    # 会将dir1和dir2目录中的文件复制到容器中，但是dir1和dir2本身不会被复制
    COPY dir1 dir2 /usr/local/dir
    ```

    + 可以将复制的多个目录放到一个目录内，通过复制单个目录的方式实现；
    
    + 编写多个`COPY`或者`ADD`



## ENTRYPOINT和CMD

`ENTRYPOINT`和`CMD`指令都定义了容器运行时执行的命令，两者既可单独使用，也可结合使用。

`ENTRYPOINT`和`CMD`都有`shell`和`exec`两种编写格式

- ENTRYPOINT/CMD ["executable", "param1", "param2"]
- ENTRYPOINT/CMD command param1 param2

`CMD`除了上述两种方式外，还有一种方式可以为`ENTRYPOINT`提供默认参数

- CMD ["param1","param2"]

**Example**

```dockerfile
FROM ubuntu:16.04
ENTRYPOINT ["top", "-b"]
CMD ["-c"]
```

上述Dockerfile是CMD为ENTRYPOINT提供参数的例子，这时两者都需要采用**exec**的形式

更加详细的说明参考[官方文档](https://docs.docker.com/engine/reference/builder/#entrypoint)