INPUT_WIZARD_VERSION = 1.0.0
INPUT_WIZARD_SITE = $(TOPDIR)/../../os/board/rootddr/external/input-wizard
INPUT_WIZARD_SITE_METHOD = local

INPUT_WIZARD_DEPENDENCIES = sdl3

INPUT_WIZARD_CARGO_ENV = \
	CARGO_HOME=$(HOST_DIR)/usr/share/cargo \
	RUST_TARGET_PATH=$(HOST_DIR)/usr/share/rustc \
	PKG_CONFIG_PATH=$(STAGING_DIR)/usr/lib/pkgconfig:$(STAGING_DIR)/usr/share/pkgconfig \
	SDL3_LIB=$(STAGING_DIR)/usr/lib \
	SDL3_INCLUDE=$(STAGING_DIR)/usr/include/SDL3

define INPUT_WIZARD_BUILD_CMDS
	cd $(@D) && \
	$(INPUT_WIZARD_CARGO_ENV) \
	cargo build --release --target x86_64-unknown-linux-musl
endef

define INPUT_WIZARD_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/target/x86_64-unknown-linux-musl/release/input-wizard $(TARGET_DIR)/usr/local/bin/input-wizard
endef

$(eval $(cargo-package))
