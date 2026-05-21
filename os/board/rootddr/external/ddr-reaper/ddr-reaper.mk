# ddr-reaper - Watchdog daemon for RootDDR
DDRREAPER_VERSION = 1.0.0
DDRREAPER_SITE = $(TOPDIR)/../../os/board/rootddr/external/ddr-reaper
DDRREAPER_SITE_METHOD = local
DDRREAPER_LICENSE = MIT
DDRREAPER_LICENSE_FILES = LICENSE

# Source files
DDRREAPER_SRC = ddr-reaper.c

# Build commands
define DDRREAPER_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) $(TARGET_CONFIGURE_OPTS) -C $(@D) $(TARGET_CFLAGS) $(TARGET_LDFLAGS)
endef

# Install commands
define DDRREAPER_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/ddr-reaper $(TARGET_DIR)/usr/bin/ddr-reaper
	$(INSTALL) -D -m 0644 $(@D)/ddr-reaper.service $(TARGET_DIR)/usr/lib/systemd/system/ddr-reaper.service
endef

# Post-install commands to enable the service
define DDRREAPER_POST_INSTALL_TARGET_HOOKS
	mkdir -p $(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/
	ln -sf ../../../../usr/lib/systemd/system/ddr-reaper.service $(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/ddr-reaper.service
endef

$(eval $(generic-package))