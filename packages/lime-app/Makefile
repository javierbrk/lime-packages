#
# Copyright (C) Libremesh 2017
#
# This is free software, licensed under the GNU General Public License v3.

include $(TOPDIR)/rules.mk

PKG_NAME:=lime-app
PKG_VERSION:=0.2.29
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-v$(PKG_VERSION).tar.gz
PKG_HASH:=59c6d27dc88459588141306e27526473f2ea794d02e21d27c9271c441bcbcb0c
PKG_SOURCE_URL:=https://github.com/Pablomonte/lime-app/releases/download/v$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	CATEGORY:=LibreMesh
	TITLE:=LimeApp
	MAINTAINER:=German Ferrero <germanferrero@altermundi.net>
	URL:=http://github.com/libremesh/lime-app
	DEPENDS:=+rpcd +uhttpd +uhttpd-mod-ubus +uhttpd-mod-lua \
		+ubus-lime-location +ubus-lime-metrics +ubus-lime-utils \
		+rpcd-mod-iwinfo +ubus-lime-groundrouting
	PKGARCH:=all
endef

define Package/$(PKG_NAME)/description
	Light webApp for LibreMesh over uhttpd
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/
	$(CP) ./files/* $(1)/
	$(INSTALL_DIR) $(1)/www/app/
	$(CP) $(BUILD_DIR)/build/* $(1)/www/app/
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] ||	( /etc/init.d/rpcd restart && /etc/init.d/uhttpd restart ) || true
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
