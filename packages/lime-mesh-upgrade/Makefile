include ../../libremesh.mk

define Package/$(PKG_NAME)
  CATEGORY:=LibreMesh
  MAINTAINER:=selankon <selankon@selankon.xyz>
  TITLE:=LibreMesh mesh wide firmware upgrade
  DEPENDS:= +lua +libubus-lua +safe-upgrade \
  +shared-state-mesh_wide_upgrade

  PKGARCH:=all
endef

define Package/$(PKG_NAME)/description
  This package provides a mechanism to perform mesh wide firmware upgrades
  in LibreMesh networks.
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
