include $(TOPDIR)/rules.mk

PKG_NAME:=lime-mesh-config
GIT_COMMIT_DATE:=$(shell git log -n 1 --pretty=%ad --date=short . )
GIT_COMMIT_TSTAMP:=$(shell git log -n 1 --pretty=%at . )
PKG_VERSION=$(GIT_COMMIT_DATE)-$(GIT_COMMIT_TSTAMP)
PKG_VERSION:=$(subst -,.,$(PKG_VERSION))

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  CATEGORY:=LibreMesh
  MAINTAINER:=Asociación Civil Altermundi <info@altermundi.net>
  TITLE:=Lime config mesh distribution
  DEPENDS:= +lua +libubus-lua +safe-reboot \
  +shared-state-mesh_config

  PKGARCH:=all
endef

define Package/$(PKG_NAME)/description
	Mesh wide config distribution and testing with safe-reboot
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
