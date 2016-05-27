#
# Copyright (C) 2016 Anyfi Networks AB
#
# This packaging and the accompanying configuration scripts are licensed under the
# MIT License. See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME    := easycwmp-anyfi
PKG_VERSION := 1.0
PKG_RELEASE := 1
PKG_LICENSE := MIT

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)-$(PKG_RELEASE)

include $(INCLUDE_DIR)/package.mk

define Package/easycwmp-anyfi
  SECTION    := net
  CATEGORY   := Network
  TITLE      := Anyfi.net TR-069 data model for EasyCwmp
  DEPENDS    := +anyfi +easycwmp
  PKGARCH    := all
  MAINTAINER := Anyfi Networks AB <eng@anyfinetworks.com>
endef

define Package/easycwmp-anyfi/description
  This package provides the Anyfi.net TR-069 data model for EasyCwmp.
  The TR-98 data model is extended with vendor objects prefixed X_ANYFI_NET. 
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/easycwmp-anyfi/install
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,easycwmp-anyfi))
