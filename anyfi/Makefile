#
# Copyright (C) 2015 Anyfi Networks AB
#
# This packaging and the accompanying configuration scripts are licensed under the
# MIT License. See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME    := anyfi
PKG_VERSION := 1.0
PKG_RELEASE := 1
PKG_LICENSE := MIT

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)-$(PKG_RELEASE)

include $(INCLUDE_DIR)/package.mk

define Package/anyfi
  SECTION    := net
  CATEGORY   := Network
  TITLE      := Anyfi.net - Carrier Wi-Fi on any AP or CPE
  URL        := http://anyfi.net
  DEPENDS    := +anyfi-mac
  MAINTAINER := Anyfi Networks AB <eng@anyfinetworks.com>
endef

define Package/anyfi/description
  Anyfi.net is a software extension that adds carrier Wi-Fi functionality to any
  access point or CPE. This package configures the software for a specific use-case.
endef

define Package/anyfi/config
	source "$(SOURCE)/Config.in"
endef

define Build/Configure
	cp templates/99_config_anyfi.in $(PKG_BUILD_DIR)/99_config_anyfi
	sed -i -e 's/@ANYFI_CONTROLLER@/$(CONFIG_ANYFI_CONTROLLER)/' \
	       -e 's/@ANYFI_CONTROLLER_KEY@/$(CONFIG_ANYFI_CONTROLLER_KEY)/' \
	       -e 's/@ANYFI_OPTIMIZER_KEY@/$(CONFIG_ANYFI_OPTIMIZER_KEY)/' \
	       -e 's/@ANYFI_ENABLE_RADIO@/$(CONFIG_ANYFI_ENABLE_RADIO)/' \
	       -e 's/@ANYFI_ENABLE_SERVICE@/$(CONFIG_ANYFI_ENABLE_SERVICE)/' \
	    $(PKG_BUILD_DIR)/99_config_anyfi
endef

define Build/Compile
endef

define Package/anyfi/conffiles
	/etc/config/anyfi
endef

define Package/anyfi/postinst
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
    /etc/uci-defaults/99_config_anyfi && rm /etc/uci-defaults/99_config_anyfi
    echo "Please run /sbin/wifi to apply the configuration."
fi
endef

define Package/anyfi/prerm
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
    echo "Stopping Anyfi.net daemons."
    /sbin/anyfi stop
    . /lib/functions.sh
    config_load wireless
    for IFACE in $$CONFIG_SECTIONS; do
        IFNAME=$$(uci -q get wireless.$$IFACE.ifname)
        if [ "$$(uci -q get wireless.$$IFACE.mode)" = monitor ] && \
           [ "$$(uci -q get anyfi.$$IFNAME)" = radio ]
        then
            echo "Removing monitor interface $$IFNAME."
            uci delete wireless.$$IFACE
        fi
    done
    uci commit wireless
    rm -f /etc/config/anyfi
fi
endef

define Package/anyfi/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/99_config_anyfi $(1)/etc/uci-defaults
endef

$(eval $(call BuildPackage,anyfi))
