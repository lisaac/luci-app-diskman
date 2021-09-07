include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-diskman
PKG_VERSION:=v0.2.11
PKG_RELEASE:=beta

PKG_LICENSE:=AGPL-3.0
PKG_MAINTAINER:=lisaac <https://github.com/lisaac/luci-app-diskman>

PKG_CONFIG_DEPENDS:= \
	CONFIG_PACKAGE_$(PKG_NAME)_INCLUDE_btrfs_progs \
	CONFIG_PACKAGE_$(PKG_NAME)_INCLUDE_lsblk \
	CONFIG_PACKAGE_$(PKG_NAME)_INCLUDE_mdadm \
	CONFIG_PACKAGE_$(PKG_NAME)_INCLUDE_kmod_md_raid456 \
	CONFIG_PACKAGE_$(PKG_NAME)_INCLUDE_kmod_md_linears
	
LUCI_TITLE:=Disk Manager interface for LuCI
LUCI_PKGARCH:=all
LUCI_DEPENDS:=+e2fsprogs +parted +smartmontools +blkid \
	+PACKAGE_$(PKG_NAME)_INCLUDE_btrfs_progs:btrfs-progs \
	+PACKAGE_$(PKG_NAME)_INCLUDE_lsblk:lsblk \
	+PACKAGE_$(PKG_NAME)_INCLUDE_mdadm:mdadm \
	+PACKAGE_$(PKG_NAME)_INCLUDE_kmod_md_raid456:mdadm \
	+PACKAGE_$(PKG_NAME)_INCLUDE_kmod_md_raid456:kmod-md-raid456 \
	+PACKAGE_$(PKG_NAME)_INCLUDE_kmod_md_linears:mdadm \
	+PACKAGE_$(PKG_NAME)_INCLUDE_kmod_md_linears:kmod-md-linear

define Package/$(PKG_NAME)/config
config PACKAGE_$(PKG_NAME)_INCLUDE_btrfs_progs
	bool "Include btrfs-progs"
	default y
config PACKAGE_$(PKG_NAME)_INCLUDE_lsblk
	bool "Include lsblk"
	default y
config PACKAGE_$(PKG_NAME)_INCLUDE_mdadm
	bool "Include mdadm"
	default n
config PACKAGE_$(PKG_NAME)_INCLUDE_kmod_md_raid456
	depends on PACKAGE_$(PKG_NAME)_INCLUDE_mdadm
	bool "Include kmod-md-raid456"
	default n
config PACKAGE_$(PKG_NAME)_INCLUDE_kmod_md_linear
	depends on PACKAGE_$(PKG_NAME)_INCLUDE_mdadm
	bool "Include kmod-md-linear"
	default n
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
