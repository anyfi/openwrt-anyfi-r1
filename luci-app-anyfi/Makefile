#
# Copyright (C) 2015 Anyfi Networks AB
#
# This packaging and the accompanying files are licensed under the
# MIT License. See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME    := luci-app-anyfi
PKG_VERSION := 1.0
PKG_RELEASE := 1
PKG_INSTALL := 1
PKG_LICENSE := MIT

PKG_SRC_DIR := $(shell pwd)
PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)-$(PKG_RELEASE)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION    := luci
  CATEGORY   := LuCI
  SUBMENU    := 3. Applications
  TITLE      := Anyfi.net configuration interface
  URL        := http://anyfi.net
  MAINTAINER := Anyfi Networks AB <eng@anyfinetworks.com>
  DEPENDS    := luci anyfi
  PKGARCH    := all
endef

define Package/$(PKG_NAME)/description
  Anyfi.net is a software extension that adds carrier Wi-Fi functionality to
  any access point or CPE. This package provides configuration support for
  the LuCI web interface.
endef

# NOTE: We need to modify a few of LuCI's files to be able to integrate
# tighly with the Wi-Fi interface configuration. The modified files are
# included in this package and will replace the original versions when
# the package is installed, either in the firmware image or on target.
# The files are reverted when the package is uninstalled.

# Patch files from the LuCI package and put them in our build dir.
# Add symlinks to unify the LuCI directory structure so our patches apply.
define Build/Compile
	cd $(BUILD_DIR); \
	[ -e luci-base ] || ln -s luci/modules/base luci-base; \
	[ -e luci-mod-admin-full ] || \
	    ln -s luci/modules/admin-full luci-mod-admin-full; \
	for f in $(PKG_SRC_DIR)/luci-patches/*.patch; do \
	    patch -p1 -o $(PKG_BUILD_DIR)/$$$$(basename $$$$f .patch) < $$$$f \
	    || exit 1; \
	done
endef

define Build/Install
endef

LUCI_WIFI_DIR=/usr/lib/lua/luci/model/cbi/admin_network/
LUCI_CBI_DIR=/usr/lib/lua/luci/cbi/
LUCI_JS_DIR=/www/luci-static/resources/

# Pre-install hook: save the original LuCI files
define Package/$(PKG_NAME)/preinst
#!/bin/sh -e
cd $${IPKG_INSTROOT}/$(LUCI_WIFI_DIR) && mv wifi.lua wifi.lua.orig
cd $${IPKG_INSTROOT}/$(LUCI_CBI_DIR) && mv datatypes.lua datatypes.lua.orig
cd $${IPKG_INSTROOT}/$(LUCI_JS_DIR) && mv cbi.js cbi.js.orig
rm -f /tmp/luci-indexcache
endef

# Post-remove hook: restore the original LuCI files
define Package/$(PKG_NAME)/postrm
#!/bin/sh -e
cd $${IPKG_INSTROOT}/$(LUCI_JS_DIR) && mv cbi.js.orig cbi.js
cd $${IPKG_INSTROOT}/$(LUCI_CBI_DIR) && mv datatypes.lua.orig datatypes.lua
cd $${IPKG_INSTROOT}/$(LUCI_WIFI_DIR) && mv wifi.lua.orig wifi.lua
rm -f /tmp/luci-indexcache
endef

# Install all our files, including our LuCI replacement files
define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci
	$(CP) ./luasrc/* $(1)/usr/lib/lua/luci
	$(INSTALL_DIR) $(1)/$(LUCI_WIFI_DIR)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/wifi.lua $(1)/$(LUCI_WIFI_DIR)
	$(INSTALL_DIR) $(1)/$(LUCI_CBI_DIR)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/datatypes.lua $(1)/$(LUCI_CBI_DIR)
	$(INSTALL_DIR) $(1)/$(LUCI_JS_DIR)
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/cbi.js $(1)/$(LUCI_JS_DIR)
endef

$(eval $(call BuildPackage,$(PKG_NAME)))