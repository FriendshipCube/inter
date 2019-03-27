# Targets:
#   all               Build everything
#   test              Build and test everyything (implies all_check)
#   install           Build and install all OTF files. (currently Mac-only)
#   zip               Build a complete release-grade ZIP archive of all fonts.
#   dist              Create a new release distribution. Does everything.
#
#   all_const         Build all non-variable files
#   all_const_hinted  Build all non-variable files with hints
#   all_var           Build all variable files
#   all_var_hinted    Build all variable files with hints (disabled)
#
#   all_otf					  Build all OTF files into FONTDIR/const
#   all_ttf					  Build all TTF files into FONTDIR/const
#   all_ttf_hinted	  Build all TTF files with hints into FONTDIR/const-hinted
#   all_web					  Build all WOFF files into FONTDIR/const
#   all_web_hinted	  Build all WOFF files with hints into FONTDIR/const-hinted
#   all_var           Build all variable font files into FONTDIR/var
#   all_var_hinted    Build all variable font files with hints into
#                     FONTDIR/var-hinted
#
#   designspace       Build src/Inter.designspace from src/Inter.glyphs
#
# Style-specific targets:
#   STYLE_otf         Build OTF file for STYLE into FONTDIR/const
#   STYLE_ttf         Build TTF file for STYLE into FONTDIR/const
#   STYLE_ttf_hinted  Build TTF file for STYLE with hints into
#                     FONTDIR/const-hinted
#   STYLE_web         Build WOFF files for STYLE into FONTDIR/const
#   STYLE_web_hinted  Build WOFF files for STYLE with hints into
#                     FONTDIR/const-hinted
#   STYLE_check       Build & check OTF and TTF files for STYLE
#
# "build" directory output structure:
# 	fonts
# 		const
# 		const-hinted
# 		var
# 		var-hinted  (disabled)
#
FONTDIR = build/fonts

all: all_const  all_const_hinted  all_var

all_const: all_otf  all_ttf  all_web
all_const_hinted: all_ttf_hinted  all_web_hinted
var: \
	$(FONTDIR)/var/Inter.var.woff2 \
	$(FONTDIR)/var/Inter.var.ttf
all_var: \
	$(FONTDIR)/var/Inter.var.woff2 \
	$(FONTDIR)/var/Inter.var.ttf \
	$(FONTDIR)/var/Inter-upright.var.woff2 \
	$(FONTDIR)/var/Inter-italic.var.woff2 \
	$(FONTDIR)/var/Inter-upright.var.ttf \
	$(FONTDIR)/var/Inter-italic.var.ttf

all_ufo_masters = $(Thin_ufo_d) \
                  $(ThinItalic_ufo_d) \
                  $(Regular_ufo_d) \
                  $(Italic_ufo_d) \
                  $(Black_ufo_d) \
                  $(BlackItalic_ufo_d)

# Hinted variable font disabled. See https://github.com/rsms/inter/issues/75
# all_var_hinted: $(FONTDIR)/var-hinted/Inter.var.ttf $(FONTDIR)/var-hinted/Inter.var.woff2
# .PHONY: all_var_hinted

.PHONY: all_const  all_const_hinted  var  all_var

export PATH := $(PWD)/build/venv/bin:$(PATH)

# generated.make is automatically generated by init.sh and defines depenencies for
# all styles and alias targets
include build/etc/generated.make


# TTF -> WOFF2
build/%.woff2: build/%.ttf
	woff2_compress "$<"

# TTF -> WOFF
build/%.woff: build/%.ttf
	ttf2woff -O -t woff "$<" "$@"

# make sure intermediate TTFs are not gc'd by make
.PRECIOUS: build/%.ttf



# Master UFOs -> variable TTF
$(FONTDIR)/var/%.var.ttf: src/%.designspace $(all_ufo_masters)
	misc/fontbuild compile-var -o $@ $<

# Instance UFO -> OTF, TTF (note: masters' rules in generated.make)
$(FONTDIR)/const/Inter-%.otf: build/ufo/Inter-%.ufo
	misc/fontbuild compile -o $@ $<

$(FONTDIR)/const/Inter-%.ttf: build/ufo/Inter-%.ufo
	misc/fontbuild compile -o $@ $<


# designspace <- glyphs file
src/Inter-*.designspace: src/Inter.designspace
src/Inter.designspace: src/Inter.glyphs
	misc/fontbuild glyphsync $<

# make sure intermediate files are not gc'd by make
.PRECIOUS: src/Inter-*.designspace

designspace: src/Inter.designspace
.PHONY: designspace

# short-circuit Make for performance
src/Inter.glyphs:
	@true

# instance UFOs <- master UFOs
build/ufo/Inter-%.ufo: src/Inter.designspace $(all_ufo_masters)
	misc/fontbuild instancegen src/Inter.designspace $*

# make sure intermediate UFOs are not gc'd by make
.PRECIOUS: build/ufo/Inter-%.ufo

# Note: The seemingly convoluted dependency graph above is required to
# make sure that glyphsync and instancegen are not run in parallel.


# hinted TTF files via autohint
$(FONTDIR)/const-hinted/%.ttf: $(FONTDIR)/const/%.ttf
	mkdir -p "$(dir $@)"
	ttfautohint --fallback-stem-width=256 --no-info "$<" "$@"

# python -m ttfautohint --fallback-stem-width=256 --no-info "$<" "$@"

# $(FONTDIR)/var-hinted/%.ttf: $(FONTDIR)/var/%.ttf
# 	mkdir -p "$(dir $@)"
# 	ttfautohint --fallback-stem-width=256 --no-info "$<" "$@"

# make sure intermediate TTFs are not gc'd by make
.PRECIOUS: $(FONTDIR)/const/%.ttf $(FONTDIR)/const-hinted/%.ttf $(FONTDIR)/var/%.var.ttf




# check var
all_check_var: $(FONTDIR)/var/Inter.var.ttf
	misc/fontbuild checkfont $(FONTDIR)/var/*.*

# test runs all tests
# Note: all_check_const is generated by init.sh and runs "fontbuild checkfont"
# on all otf and ttf files.
test: all_check_const  all_check_var
	@echo "test: all ok"

# check does the same thing as test, but without any dependency checks, meaning
# it will check whatever font files are already built.
check:
	misc/fontbuild checkfont \
		$(FONTDIR)/const/*.ttf \
		$(FONTDIR)/const/*.otf \
		$(FONTDIR)/const/*.woff2 \
		$(FONTDIR)/var/*.ttf \
		$(FONTDIR)/var/*.woff2
	@echo "check: all ok"

.PHONY: test check




# samples renders PDF and PNG samples
samples: $(FONTDIR)/samples all_samples_pdf all_samples_png

$(FONTDIR)/samples/%.pdf: $(FONTDIR)/const/%.otf
	misc/tools/fontsample/fontsample -o "$@" "$<"

$(FONTDIR)/samples/%.png: $(FONTDIR)/const/%.otf
	misc/tools/fontsample/fontsample -o "$@" "$<"

$(FONTDIR)/samples:
	mkdir -p $@


ZD = build/tmp/zip
# intermediate zip target that creates a zip file at build/tmp/a.zip
build/tmp/a.zip:
	@rm -rf "$(ZD)"
	@rm -f  build/tmp/a.zip
	@mkdir -p \
	  "$(ZD)/Inter (web)" \
	  "$(ZD)/Inter (web hinted)" \
	  "$(ZD)/Inter (TTF)" \
	  "$(ZD)/Inter (TTF hinted)" \
	  "$(ZD)/Inter (TTF variable)" \
	  "$(ZD)/Inter (OTF)"
	@#
	@# copy font files
	cp -a $(FONTDIR)/const/*.woff \
	      $(FONTDIR)/const/*.woff2 \
	      $(FONTDIR)/var/*.woff2        "$(ZD)/Inter (web)/"
	cp -a $(FONTDIR)/const-hinted/*.woff \
	      $(FONTDIR)/const-hinted/*.woff2 \
	                                    "$(ZD)/Inter (web hinted)/"
	cp -a $(FONTDIR)/const/*.ttf        "$(ZD)/Inter (TTF)/"
	cp -a $(FONTDIR)/const-hinted/*.ttf "$(ZD)/Inter (TTF hinted)/"
	cp -a $(FONTDIR)/var/*.ttf          "$(ZD)/Inter (TTF variable)/"
	cp -a $(FONTDIR)/const/*.otf        "$(ZD)/Inter (OTF)/"
	@#
	@# copy misc stuff
	cp -a misc/dist/inter.css           "$(ZD)/Inter (web)/"
	cp -a misc/dist/inter.css           "$(ZD)/Inter (web hinted)/"
	cp -a misc/dist/*.txt               "$(ZD)/"
	cp -a LICENSE.txt                   "$(ZD)/"
	@#
	@# Fix VF metadata
	misc/tools/fix-vf-meta.py \
	  "$(ZD)/Inter (web)/Inter-upright.var.woff2" \
	  "$(ZD)/Inter (web)/Inter-italic.var.woff2"
	misc/tools/fix-vf-meta.py \
	  "$(ZD)/Inter (TTF variable)/Inter-upright.var.ttf" \
	  "$(ZD)/Inter (TTF variable)/Inter-italic.var.ttf"
	@#
	@# Add "beta" to Light and Thin filenames.
	@# Requires "rename" tool in PATH (`brew install rename` on macOS)
	rename 's/(Light.*|Thin.*)\./$$1-BETA./' "$(ZD)/Inter"*/*.*
	@#
	@# zip
	cd "$(ZD)" && zip -q -X -r "../../../$@" * && cd ../..
	@rm -rf "$(ZD)"

# load version, used by zip and dist
VERSION := $(shell cat version.txt)

# distribution zip files
ZIP_FILE_DIST := build/release/Inter-${VERSION}.zip

# zip
build/release/Inter-%.zip: build/tmp/a.zip
	@mkdir -p "$(shell dirname "$@")"
	@mv -f "$<" "$@"
	@echo write "$@"
	@sh -c "if [ -f /usr/bin/open ]; then /usr/bin/open --reveal '$@'; fi"

zip: all
	$(MAKE) check
	$(MAKE) build/release/Inter-${VERSION}-$(shell git rev-parse --short=10 HEAD).zip

zip_dist: pre_dist
	$(MAKE) check
	$(MAKE) ${ZIP_FILE_DIST}

.PHONY: zip zip_dist

# distribution
pre_dist: all
	@echo "Creating distribution for version ${VERSION}"
	@if [ -f "${ZIP_FILE_DIST}" ]; \
		then echo "${ZIP_FILE_DIST} already exists. Bump version or remove the zip file to continue." >&2; \
		exit 1; \
  fi

dist: zip_dist
	$(MAKE) -j docs
	misc/tools/versionize.py
	@echo "——————————————————————————————————————————————————————————————————"
	@echo ""
	@echo "Next steps:"
	@echo ""
	@echo "1) Commit & push changes"
	@echo ""
	@echo "2) Create new release with ${ZIP_FILE_DIST} at"
	@echo "   https://github.com/rsms/inter/releases/new?tag=v${VERSION}"
	@echo ""
	@echo "3) Bump version in version.txt (to the next future version)"
	@echo ""
	@echo "——————————————————————————————————————————————————————————————————"

docs: docs_fonts
	$(MAKE) -j docs_info

docs_info: docs/_data/fontinfo.json docs/lab/glyphinfo.json docs/glyphs/metrics.json

docs_fonts:
	rm -rf docs/font-files
	mkdir docs/font-files
	cp -a $(FONTDIR)/const/*.woff \
	      $(FONTDIR)/const/*.woff2 \
	      $(FONTDIR)/const/*.otf \
	      $(FONTDIR)/var/*.* \
	      docs/font-files/

.PHONY: docs docs_info docs_fonts

docs/_data/fontinfo.json: docs/font-files/Inter-Regular.otf misc/tools/fontinfo.py
	misc/tools/fontinfo.py -pretty $< > docs/_data/fontinfo.json

docs/lab/glyphinfo.json: build/UnicodeData.txt misc/tools/gen-glyphinfo.py $(all_ufo_masters)
	misc/tools/gen-glyphinfo.py -ucd $< src/Inter-*.ufo > $@

docs/glyphs/metrics.json: $(Regular_ufo_d) misc/tools/gen-metrics-and-svgs.py
	misc/tools/gen-metrics-and-svgs.py src/Inter-Regular.ufo

# Download latest Unicode data
build/UnicodeData.txt:
	@echo fetch http://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt
	@curl '-#' -o "$@" http://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt

# install targets
install_ttf: all_ttf_const
	@echo "Installing TTF files locally at ~/Library/Fonts/Inter"
	rm -rf ~/'Library/Fonts/Inter'
	mkdir -p ~/'Library/Fonts/Inter'
	cp -va $(FONTDIR)/const/*.ttf ~/'Library/Fonts/Inter'

install_ttf_hinted: all_ttf_hinted
	@echo "Installing autohinted TTF files locally at ~/Library/Fonts/Inter"
	rm -rf ~/'Library/Fonts/Inter'
	mkdir -p ~/'Library/Fonts/Inter'
	cp -va $(FONTDIR)/const-hinted/*.ttf ~/'Library/Fonts/Inter'

install_otf: all_otf
	@echo "Installing OTF files locally at ~/Library/Fonts/Inter"
	rm -rf ~/'Library/Fonts/Inter'
	mkdir -p ~/'Library/Fonts/Inter'
	cp -va $(FONTDIR)/const/*.otf ~/'Library/Fonts/Inter'

install: install_otf

# clean removes generated and built fonts in the build directory
clean:
	rm -rvf build/tmp build/fonts

.PHONY: all web clean install install_otf install_ttf deploy pre_dist dist geninfo glyphsync
