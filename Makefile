# iOS 15.0 floor: the spoti.pw sub repo (Sources/EeveeSpotifyC/SubRepos/spoti.pw) is
# compiled straight into this tweak and uses iOS 15+ UIKit APIs unguarded
# (UITableView.sectionHeaderTopPadding, UIButtonConfiguration, UIListContentConfiguration);
# with a 14.0 target those calls are -Werror availability errors. The Swift side already
# guards its iOS 15/16 APIs with #available.
TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = Spotify
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = EeveeSpotify

REPO_SLUG ?= $(shell git remote get-url origin 2>/dev/null | sed -E 's|.*github\.com[:/]([^/]+/[^/.]+)(\.git)?$$|\1|')
REPO_SLUG_FINAL := $(if $(REPO_SLUG),$(REPO_SLUG),jaydenjcpy/EeveeSpotifyReincarnated)

BRANCH_NAME ?= $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null)
BRANCH_NAME_FINAL := $(if $(BRANCH_NAME),$(BRANCH_NAME),Master)

$(shell mkdir -p Sources/EeveeSpotify/Generated)
$(shell printf 'enum GeneratedConfig {\n    static let repoSlug = "%s"\n    static let branchName = "%s"\n}\n' "$(REPO_SLUG_FINAL)" "$(BRANCH_NAME_FINAL)" > Sources/EeveeSpotify/Generated/RepoSlug.swift)

# spoti.pw is a sub repo at Sources/EeveeSpotifyC/SubRepos/spoti.pw, built straight into this
# same tweak binary rather than as a package of its own. SG_VERSION mirrors what spoti.pw's own
# Makefile bakes in from its control file; it's read as empty (not an error) before the sub repo
# is checked out, so a fresh clone can still `make` — it just won't have spoti.pw's code yet.
SPOTIPW_DIR := Sources/EeveeSpotifyC/SubRepos/spoti.pw/tweak
SPOTIPW_CONTROL := $(SPOTIPW_DIR)/control
SG_VERSION := $(if $(wildcard $(SPOTIPW_CONTROL)),$(shell sed -n 's/^Version: //p' $(SPOTIPW_CONTROL)),0.0.0)

# spoti.pw's flag table (SGFlagList.m) is generated from a decrypted Spotify IPA and
# gitignored upstream, so it's absent from a fresh checkout and FlagsPage.m fails to link
# (undefined SGFlagTable/SGFlagCount). Compile a checked-in empty-table stub in that case:
# the tweak links and the All-flags page just lists nothing. Run the submodule's
# scripts/extract-flags.py on a decrypted IPA to get the real table; this stub then drops out.
SGFLAGLIST := $(SPOTIPW_DIR)/Sources/Features/Flags/SGFlagList.m
EeveeSpotify_FILES = $(shell find Sources/EeveeSpotify -name '*.swift') $(shell find Sources/EeveeSpotifyC -name '*.m' -o -name '*.c' -o -name '*.mm' -o -name '*.cpp' -o -name '*.x')
ifeq ($(wildcard $(SGFLAGLIST)),)
EeveeSpotify_FILES += Tools/SGFlagListStub.m
endif
EeveeSpotify_SWIFTFLAGS = -ISources/EeveeSpotifyC/include -Osize
EeveeSpotify_EXTRA_FRAMEWORKS = EeveeSwiftProtobuf
EeveeSpotify_FRAMEWORKS += QuartzCore
# spoti.pw's own headers use quote-includes relative to its Sources/ dir (e.g. "Core/SGCore.h"),
# same as it does building standalone, so it needs that dir on the search path here too.
#
# The latest SDK (26.x) marks UIKit APIs the sub repo uses as iOS 17/26-only, e.g.
# UIButtonConfiguration.glassButtonConfiguration and UIImageView.addSymbolEffect:. spoti.pw
# guards every such call with respondsToSelector: at runtime (that's how it builds against its
# pinned 16.5 SDK), but the compiler can't see those guards, so with -Werror they'd fail the
# build. Downgrade just this diagnostic group back to a warning — it stays visible in the log,
# and every other -Werror check keeps failing the build as before.
EeveeSpotify_CFLAGS = -fobjc-arc -ISources/EeveeSpotifyC/include -I$(SPOTIPW_DIR)/Sources -DSG_VERSION=\"$(SG_VERSION)\" -Os -Wno-error=unguarded-availability-new
# spoti.pw's .x files use Logos %hook; "internal" swizzles at runtime instead of linking
# CydiaSubstrate, matching how spoti.pw builds on its own (see its Makefile) and keeping this
# combined dylib dependency-free the same way.
EeveeSpotify_LOGOS_DEFAULT_GENERATOR := internal

# RootHide's compatibility implementation of libroot resolves jailbreak paths
# through libroothide at runtime. Rootless builds continue to use libroot.
ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
EeveeSpotify_SWIFTFLAGS += -D ROOTHIDE
EeveeSpotify_LDFLAGS += -lroothide -Xlinker -rpath -Xlinker @loader_path/.jbroot/Library/Frameworks
else
EeveeSpotify_LDFLAGS += -lroot
endif

# Sideload compatibility (keychain redirect, group containers, CloudKit) is
# handled out-of-process by modules/zxPluginsInject — LC-injected via ipapatch
# in build-ipa-local.sh and the GitHub workflow. No flags needed here.

include $(THEOS_MAKE_PATH)/tweak.mk

internal-stage::
	# Bundle EeveeSwiftProtobuf.framework into the package. Renamed from
	# SwiftProtobuf so the @objc class names don't collide with the
	# SwiftProtobuf statically embedded in SpotifyShared.framework.
	mkdir -p $(THEOS_STAGING_DIR)/Library/Frameworks
	cp -r $(THEOS)/lib/iphone/$(or $(THEOS_PACKAGE_SCHEME),rootless)/EeveeSwiftProtobuf.framework $(THEOS_STAGING_DIR)/Library/Frameworks/
	# Compile the karaoke background Metal shader into a .metallib and
	# stage it next to the tweak binary so device.makeLibrary(filepath:)
	# can load it at runtime (Theos's tweak.mk has no built-in Metal
	# shader compilation step the way an Xcode app target's build phases
	# do, so this is done by hand here — UNTESTED, no Theos/Metal
	# toolchain was available to verify this actually produces a working
	# .metallib or that the staged path is correct; if `make package`
	# fails at this step or the shader doesn't load at runtime, check
	# this block first).
	xcrun -sdk iphoneos metal -c Sources/EeveeSpotify/Karaoke/KaraokeBackgroundShader.metal \
		-o $(THEOS_OBJ_DIR)/KaraokeBackgroundShader.air
	xcrun -sdk iphoneos metallib $(THEOS_OBJ_DIR)/KaraokeBackgroundShader.air \
		-o $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/KaraokeBackgroundShader.metallib

# Build EeveeSwiftProtobuf.framework from apple/swift-protobuf source. Run
# this once before `make package`. Re-run if SWIFTPROTOBUF_VERSION changes
# or `swift --version` jumps a major.
build-eeveeswiftprotobuf:
	Tools/SwiftProtobufBuild/build-eeveeswiftprotobuf.sh
