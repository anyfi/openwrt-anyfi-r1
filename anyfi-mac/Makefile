#
# Copyright (C) 2015 Anyfi Networks AB
#
# This packaging and the accompanying configuration scripts are licensed under the
# MIT License. See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

# Use the smaller and faster mips32/mips32el binary if possible
ARCH-y = $(ARCH)
ARCH-$(CONFIG_TARGET_ar71xx) = mips32
ARCH-$(CONFIG_TARGET_ramips) = mips32el
ANYFI_ARCH := $(ARCH-y)

ANYFI_TARGET := $(ANYFI_ARCH)-linux-$(subst C,c,$(LIBC))-$(LIBCV)

PKG_NAME    := anyfi-mac
PKG_VERSION := 1.9.20
PKG_RELEASE := 1

PKG_LICENSE := ANYFIv1
PKG_LICENSE_FILES := LICENSE

PKG_SOURCE     := anyfimac-$(PKG_VERSION)-$(ANYFI_TARGET).tar.bz2
PKG_SOURCE_URL := http://anyfi.net/download
PKG_BUILD_DIR  := $(BUILD_DIR)/anyfimac-$(PKG_VERSION)-$(ANYFI_TARGET)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION    := net
  CATEGORY   := Network
  TITLE      := Anyfi.net Software
  URL        := http://anyfi.net
  DEPENDS    := +kmod-tun +librt
  MENU       := 1
  MAINTAINER := Anyfi Networks AB <eng@anyfinetworks.com>
endef

define Package/$(PKG_NAME)/description
  Anyfi.net is an IEEE 802.11 Media Access Control (MAC) software extension that
  adds carrier Wi-Fi functionality to any access point or CPE. This package
  contains the radio software (anyfid) that manages a small pool of "extra
  SSIDs" for guest access, as well as the tunnel termination software (myfid)
  needed to provide remote access to the local Wi-Fi network.
endef

define Build/Compile
	@echo "Nothing to do - Anyfi.net software comes pre-built."
endef

define Package/$(PKG_NAME)/install
	$(CP) ./files/* $(1)/
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/anyfimac $(1)/usr/sbin
	$(LN) anyfimac $(1)/usr/sbin/anyfid
	$(LN) anyfimac $(1)/usr/sbin/myfid
	$(LN) anyfimac $(1)/usr/sbin/anyfidctl
	$(LN) anyfimac $(1)/usr/sbin/myfidctl
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
