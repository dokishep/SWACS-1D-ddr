#############################################################
#
# input-wizard
#
#############################################################

INPUT_WIZARD_VERSION = 1.0
INPUT_WIZARD_SITE = $(TOPDIR)/../input-wizard
INPUT_WIZARD_SITE_METHOD = local
INPUT_WIZARD_LICENSE = MIT
INPUT_WIZARD_LICENSE_FILES = LICENSE

INPUT_WIZARD_DEPENDENCIES = sdl3 host-pkgconf host-cargo

define INPUT_WIZARD_BUILD_CMDS
	(cd $(@D); \
		$(TARGET_CONFIGURE_OPTS) \
		CARGO_TARGET_DIR=$(@D)/target \
		$(HOST_DIR)/bin/cargo build --release --locked)
endef

define INPUT_WIZARD_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/target/release/input-wizard $(TARGET_DIR)/usr/bin/input-wizard
endef

$(eval $(generic-package))