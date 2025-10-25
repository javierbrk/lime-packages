include ../../libremesh.mk

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

$(eval $(call BuildPackage,$(PKG_NAME)))
