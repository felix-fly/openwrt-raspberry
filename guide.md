下文为在树莓派4b独立部署爬网服务的具体实施方案，想了解前情的[请看这里](./README.md)

# 主路由

笔者主路由使用k2p，刷的padavan自编译系统，没有集成各种复杂组件，只保留了基本的路由功能，固件大小不足5mb。刚开始刷的lede自编译，但是最近编译出来的固件似乎不是很稳定，有时候会挂掉，还有一个重要的问题是在openwrt系统下性能不是很好，同样跑到140mbps的带宽时cpu占用比padavan高，所以后来采用了padavan固件。

由于要把流量转发到另外一台设备，开始尝试iptables直接DNAT，始终不成功，于是放弃。现在采用iptables先REDIRECT到本地的ipt2socks，然后再走socks5到树莓派的trojan。对于DNS部分由dnsmasq直接指定server到树莓派的trojan开的forward端口。tproxy的方式在openwrt下没有问题，但是padavan下没有成功。

## dnsmasq

下载dnsmasq文件夹，修改gw.hosts文件里192.168.1.10:1053的ip为树莓派的ip

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
conf-dir=/etc/storage/dnsmasq/,*.hosts
```

## ipt2socks

下载ipt2socks文件夹，修改ipt2socks.service和check.sh文件里192.168.1.10的ip为树莓派的ip

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

## iptables

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

# 树莓派4b

可以自行从lede编译固件，也可以从 [release](https://github.com/felix-fly/openwrt-raspberry/releases) 处下载。

解压 openwrt-bcm27xx-bcm2711-rpi-4-squashfs-sysupgrade.img.gz 得到 openwrt-bcm27xx-bcm2711-rpi-4-squashfs-sysupgrade.img

使用 Win32DiskImager 或者其它工具将镜像写入tf卡

插卡启动树莓派4b，网线连接，浏览器访问 http://192.168.1.1 修改 接口-LAN，ip根据自己需要调整

```bash
# ip设为 192。168.1.10
# 网关及DNS设为 192.168.1.1
# 忽略 DHCP
```

trojan和v2ray选择其一即可，trojan性能上有优势，v2ray可能更稳定。跑到140mbps时trojan的cpu接近30%，而v2ray的cpu接近40%，一般情况下使用二者均可。

笔者编译的固件里只包含了trojan而没有v2ray，要用的看后面

## trojan

下载trojan文件夹，修改config.json和config-dns.json文件里的remote_addr和password，其它如有需求自行调整

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

## v2ray

下载v2ray文件夹，修改config.json文件里的address、id、path等

然后整个上传至树莓派 /etc/config/v2ray

```bash
chmod +x /etc/config/v2ray/v2ray
chmod +x /etc/config/v2ray/v2ray.service
ln -s /etc/config/v2ray/v2ray.service /etc/init.d/v2ray
/etc/init.d/v2ray enable
/etc/init.d/v2ray start
```

一切顺利的话就可以愉悦的享受啦，期待你们的speedtest报告
