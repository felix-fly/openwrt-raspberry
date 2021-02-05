# 目录

* [开场白](#开场白)
* [主路由](#主路由)
  * [dnsmasq](#dnsmasq)
  * [流量转发](#流量转发)
      * [路由表方式（推荐）](#路由表方式推荐)
      * [ipt2socks（旧方法）](#ipt2socks旧方法)
* [树莓派4b或(友善)NanoPi R2S](#树莓派4b或友善nanopi-r2s)
  * [xray（推荐）](#xray推荐)
  * [v2ray](#v2ray)
  * [trojan](#trojan)
  * [iptables配置](#iptables配置)
* [IPv6降级](#IPv6降级)
* [更新记录](#更新记录)

# 开场白

下文为在树莓派4b或(友善)NanoPi R2S独立部署爬网服务的具体实施方案，为描述方便，以下仅以树莓派为例，(友善)NanoPi R2S类同。想了解前情的 [**请看这里**](./README.md)

# 主路由

笔者主路由使用k2p，刷的padavan自编译系统，没有集成各种复杂组件，只保留了基本的路由功能，固件大小不足5mb。刚开始刷的lede自编译，但是最近编译出来的固件似乎不是很稳定，有时候会挂掉，还有一个重要的问题是在openwrt系统下性能比padavan略差，所以后来采用了padavan固件。

由于要把流量转发到另外一台设备，开始尝试iptables直接DNAT，始终不成功，于是放弃。之前采用iptables先REDIRECT到本地的ipt2socks，然后再走socks5到树莓派的v2ray/xray/trojan方式。对于DNS部分由dnsmasq直接指定server到树莓派的trojan开的forward端口或者v2ray的dns转发端口。tproxy的方式在openwrt下没有问题，但是padavan下没有成功。

**目前推荐使用路由表方式，不再依赖ipt2socks的转发，性能更优。**

**另外，xray现在从v2ray独立出来，使用xtls配合xtls-rprx-splice性能很强大，目前看来trojan性能已经落后。**

## dnsmasq

下载dnsmasq文件夹，修改gw.hosts文件里192.168.1.10#1053的ip为树莓派的ip

然后整个上传到主路由，路径依固件不同

```bash
# openwrt
/etc/config/dnsmasq

# padavan
/etc/storage/dnsmasq
```

修改dnsmasq配置

```bash
# openwrt
vi /etc/dnsmasq.conf
# 加入下面的配置项
conf-dir=/etc/config/dnsmasq, *.hosts
# 重启dnsmasq
/etc/init.d/dnsmasq restart

# padavan
# 内部网络(LAN) -> DHCP服务器 -> 自定义配置文件 "dnsmasq.conf"
conf-dir=/etc/storage/dnsmasq, *.hosts
```

## 流量转发

这里有两种选择，推荐使用路由表方式，喜欢ipt2socks的可以继续使用。

### 路由表方式（推荐）

此处树莓派的ip为192.168.1.10，不同记得修改

```bash
# openwrt
# 在 luci-网络-防火墙-自定义规则 下添加
ipset -R < /etc/config/dnsmasq/ad.ips
ipset -R < /etc/config/dnsmasq/gw.ips
ip rule add fwmark 1 table 100
ip route add default via 192.168.1.10 table 100
iptables -t filter -A INPUT -m set --match-set ad dst -j REJECT
iptables -t mangle -A PREROUTING -p tcp -m set --match-set gw dst -j MARK --set-mark 1

# padavan
# 新建文件 /etc/storage/iptables.sh 内容如下：
#!/bin/sh
ipset -R < /etc/storage/dnsmasq/ad.ips
ipset -R < /etc/storage/dnsmasq/gw.ips
ip rule add fwmark 1 table 100
ip route add default via 192.168.1.10 table 100
iptables -t filter -A INPUT -m set --match-set ad dst -j REJECT
iptables -t mangle -A PREROUTING -p tcp -m set --match-set gw dst -j MARK --set-mark 1

# 高级设置 -> 自定义设置 -> 脚本 -> 在防火墙规则启动后执行:
/etc/storage/iptables.sh
# 如果配置没生效，可手动关闭防火墙再打开
```

### ipt2socks（旧方法）

采用路由表方式请忽略此部分。下载ipt2socks文件夹，修改ipt2socks.service和check.sh文件里192.168.1.10的ip为树莓派的ip

```bash
# openwrt
# 上传 ipt2socks.service 文件到 /etc/config
chmod +x /etc/config/ipt2socks.service
ln -s /etc/config/ipt2socks.service /etc/init.d/ipt2socks
/etc/init.d/ipt2socks enable
/etc/init.d/ipt2socks start

# padavan
# 在 /etc/storage 下新建目录 ipt2socks
# 上传 ipt2socks check.sh 到 /etc/storage/ipt2socks
chmod +x /etc/storage/ipt2socks/ipt2socks
chmod +x /etc/storage/ipt2socks/check.sh
# 高级设置 -> 自定义设置 -> 脚本 -> 在路由器启动后执行:
/etc/storage/ipt2socks/check.sh &
# 此项在重启时才有效，此时可以手动执行此命令
/etc/storage/ipt2socks/check.sh &
```

iptables for ipt2socks

```bash
# openwrt
# 在 luci-网络-防火墙-自定义规则 下添加
ipset -R < /etc/config/dnsmasq/ad.ips
ipset -R < /etc/config/dnsmasq/gw.ips
iptables -t filter -A INPUT -m set --match-set ad dst -j REJECT
iptables -t nat -A PREROUTING -p tcp -m set --match-set gw dst -j REDIRECT --to-port 12345

# padavan
# 上传 iptables.sh 到 /etc/storage/ipt2socks
chmod +x /etc/storage/ipt2socks/iptables.sh
# 高级设置 -> 自定义设置 -> 脚本 -> 在防火墙规则启动后执行:
/etc/storage/ipt2socks/iptables.sh
# 如果配置没生效，可手动关闭防火墙再打开
```

# 树莓派4b或(友善)NanoPi R2S

可以自行从lede编译固件，也可以从 [release](https://github.com/felix-fly/openwrt-raspberry/releases) 处下载。

解压 openwrt-bcm27xx-bcm2711-rpi-4-squashfs-sysupgrade.img.gz 得到 openwrt-bcm27xx-bcm2711-rpi-4-squashfs-sysupgrade.img

使用 Win32DiskImager 或者其它工具将镜像写入tf卡

插卡启动树莓派4b，网线连接，浏览器访问 http://192.168.1.1 修改 接口-LAN，ip根据自己需要调整

```bash
# ip设为 192.168.1.10
# 网关及DNS设为 192.168.1.1
# 忽略 DHCP
```

v2ray、xray和trojan选择其一即可，目前更推荐xray，新协议提升了性能，而且后期还有优化提升的空间。

笔者编译的固件里只包含了trojan而没有v2ray。由于v2ray更新比较快，且后期安装很容易，而trojan独立编译并不容易，暂时保留。

## xray（推荐）

**[点此获取最新版本的xray](https://github.com/felix-fly/xray-openwrt/releases)**

安装方式同 v2ray

## v2ray

下载v2ray文件夹，修改config.json文件里的address、id、port等

**[点此获取最新版本的v2ray](https://github.com/felix-fly/v2ray-openwrt/releases)**

使用ipt2socks方式需要修改protocol为socks

然后整个上传至树莓派 /etc/config/v2ray

```bash
chmod +x /etc/config/v2ray/v2ray
chmod +x /etc/config/v2ray/v2ray.service
ln -s /etc/config/v2ray/v2ray.service /etc/init.d/v2ray
/etc/init.d/v2ray enable
/etc/init.d/v2ray start
```

## trojan

下载trojan文件夹，修改config.json和config-dns.json文件里的remote_addr和password，其它如有需求自行调整

使用ipt2socks方式需要修改run_type为client

上传至树莓派 /etc/config/trojan

```bash
chmod +x /etc/config/trojan/trojan.service
ln -s /etc/config/trojan/trojan.service /etc/init.d/trojan
/etc/init.d/trojan enable
/etc/init.d/trojan start

chmod +x /etc/config/trojan/trojan-dns.service
ln -s /etc/config/trojan/trojan-dns.service /etc/init.d/trojan-dns
/etc/init.d/trojan-dns enable
/etc/init.d/trojan-dns start
```

## iptables配置

修改网段及YOUR_SERVER_IP地址

```bash
# 在 luci-网络-防火墙-自定义规则 下添加
iptables -t nat -N PROXY
iptables -t nat -A PROXY -d 0.0.0.0 -j RETURN
iptables -t nat -A PROXY -d 127.0.0.1 -j RETURN
iptables -t nat -A PROXY -d 192.168.1.0/24 -j RETURN
iptables -t nat -A PROXY -d YOUR_SERVER_IP -j RETURN
iptables -t nat -A PROXY -p tcp -j REDIRECT --to-port 12345
iptables -t nat -A PREROUTING -j PROXY
```

一切顺利的话就可以愉悦的享受啦，期待你们的speedtest报告

心动了吗，买它！买它！买它！

* 树莓派4b

  ![raspberry4](images/raspberry4.png)

* 无风扇全被动散热外壳

  ![box](images/box.png)

# IPv6降级

目前国内各大运营商都落实了IPv6,在本地网络开通IPv6的情况下，访问园外网络时可能会被优先到IPv6网络，此时会导致分流失效，因为目前的ipset只适用于IPv4情形。这里采取了对IPv6降级处理，即园外网络解析时屏蔽AAAA记录，确保始终走IPv4网络。实现也比较简单：

## 主路由

修改 gw.hosts 文件，去掉 `#1053`

## 树莓派

修改 resolv 文件，nameserver 指向主路由

```bash
rm /etc/resolv.conf
echo "nameserver 192.168.1.1" > /etc/resolv.conf
```

在 `luci-网络-DHCP/DNS-基本设置` 下，修改 **本地服务器** 为

```bash
127.0.0.1#1053
```

在 `luci-网络-DHCP/DNS-HOSTS 和解析文件` 下，勾选 **忽略解析文件**

# 更新记录
2021-02-4
* IPv6降级

2020-12-23
* 添加目录
* 整理文案

2020-09-30
* 增加路由表转发方式
* 优化文案
