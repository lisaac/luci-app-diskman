# DiskMan for LuCI (WIP)
A Simple Disk Manager for LuCI, support disk partition and format, support raid/btrfs-raid(WIP)
### Depends
- [parted](https://github.com/lisaac/luci-app-diskman/blob/master/Parted.Makefile)
- blkid
- smartmontools
- e2fsprogs
- btrfs-progs (Optional)
- mdadm (Optional)
    - kmod-md-raid456 (Optional)
    - kmod-md-linear (Optional)

### Compile
``` bash
git clone https://github.com/lisaac/luci-app-diskman package/luci-app-diskman
mkdir -p package/parted && cp -i package/luci-app-diskman/Parted.Makefile package/parted/Makefile

#compile package only
make package/luci-app-diskman/compile V=99

#compile
make menuconfig
#choose LuCI ---> 3. Applications  ---> <*> luci-app-diskman..... Disk Manager interface for LuCI ----> save
make V=99

```

### Screenshot
- Disk Info
![](https://raw.githubusercontent.com/lisaac/luci-app-diskman/master/doc/disk_info.png)
- Partitions Info
![](https://raw.githubusercontent.com/lisaac/luci-app-diskman/master/doc/partitions_info.png)

### Thanks To
- [luci-app-diskmanager](http://eko.one.pl/forum/viewtopic.php?id=18669)
- [luci-app-smartinfo](https://github.com/animefansxj/luci-app-smartinfo)
- Chinese translation by [锤子](https://www.right.com.cn/forum/space-uid-311750.html)

### TODO
- btrfs support
- mergerfs & snapraid support