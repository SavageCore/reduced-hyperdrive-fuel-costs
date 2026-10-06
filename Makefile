# Reduced Hyperdrive Fuel Costs
# Builds the FOMOD installer (Double / Quadruple / Tenfold) with the
# AMUMSS Linux port.
#
# What it does: scales up Ship_Hyperdrive_JumpsPerCell on the four ship
# hyperdrive technologies (HYPERDRIVE, WARP_ALIEN, HYPERDRIVE_SPEC,
# HYPERDRIVE_ROBO) in NMS_REALITY_GCTECHNOLOGYTABLE. That is the number of
# warps the hyperdrive gets out of one Warp Cell, i.e. how much fuel a single
# jump burns. HIGHER is cheaper here, the inverse of a fuel-spending
# multiplier, because the hyperdrive is a charge mechanic rather than a
# burn-per-jump one. Deliberately left alone: the hyperdrive ChargeAmount
# (120), ChargeType and ChargeBy, and the Warp Cell HYPERFUEL1 ChargeValue
# (24). Those set how fast the hyperdrive fills, so the tank still charges at
# the vanilla rate.
#
# Usage:
#   make release      clean rebuild + verify + pack dist/ zip (default)
#   make verify       sanity-check the built outputs
#   make assets       regenerate the Nexus page images (needs a screenshot)
#   make clean        remove build/ and dist/
#
# Override the AMUMSS install location if needed:
#   make AMUMSS_HOME=/path/to/AMUMSS release
#
# Game-update playbook (see README.md):
#   1. fetch latest MBINCompiler into AMUMSS_HOME
#   2. bump GameVersion in src/hyperfuel.lua.in to the new game version
#   3. make release VERSION=x.y.z   (bump the mod version too)
#   4. import + deploy + test in game

AMUMSS_HOME ?= $(HOME)/AMUMSS
AMUMSS_LINUX ?= $(HOME)/Git/AMUMSS/linux

# Mod version
VERSION      := 0.1.0

MOD_SET      := Reduced Hyperdrive Fuel Costs

SRC_TEMPLATE := src/hyperfuel.lua.in

BUILD := build
DIST  := dist
STAMP := $(BUILD)/.built

# Technology table this mod patches, relative to a built variant folder.
EXML_RELPATH := METADATA/REALITY/TABLES/NMS_REALITY_GCTECHNOLOGYTABLE.EXML

# Index of the Ship_Hyperdrive_JumpsPerCell entry inside a hyperdrive's
# StatBonuses list, as of v7.04. All four hyperdrives carry it at index 2;
# Ship_Hyperdrive sits at 0 and Ship_Hyperdrive_JumpDistance at 1. verify
# asserts the patch landed here, so a game update that reorders the list fails
# loudly instead of quietly editing the wrong stat.
HYPER_BONUS_INDEX := 2

# Installer variants. Each variant label names the rendered script, the
# CreatedMODS folder, the fomod source folder and the in-game MOD_FILENAME
# suffix, so it must match ModuleConfig.xml exactly. Ordered least to most
# fuel reduction. The labels name the mechanic rather than the percentage
# because Ship_Hyperdrive_JumpsPerCell counts warps per Warp Cell, and that is
# what this mod changes. There is deliberately no "vanilla" option: a variant
# that rewrote the values to the unmodified ones would still install a patch on
# the technology table, gaining nothing while adding conflict surface with every
# other mod that touches that file. To play unmodified, do not install it.
VARIANT   := Double Quadruple Tenfold
RENDERED  := $(addprefix $(BUILD)/,$(addsuffix .lua,$(VARIANT)))

# Per-tech final value of Ship_Hyperdrive_JumpsPerCell to write: warps per Warp
# Cell. These are the vanilla values scaled by the variant factor, not one flat
# absolute number, so the Royal and Robo drives keep their built-in 2x advantage
# over the Standard and Alien drives.
#
#              factor  HYPERDRIVE  WARP_ALIEN  HYPERDRIVE_SPEC  HYPERDRIVE_ROBO
#   (vanilla)   1.00      1.0         1.0            2.0               2.0
#   Double      2.00      2.0         2.0            4.0               4.0
#   Quadruple   4.00      4.0         4.0            8.0               8.0
#   Tenfold    10.00     10.0        10.0           20.0              20.0
#
# The factor is the reciprocal of the fuel cost per jump: Tenfold is ten warps
# per cell, i.e. a tenth of the fuel vanilla burns per jump. These numbers are
# deliberately far outside the vanilla range (which tops out at 2.0) - that is
# the whole point of the mod, not a mistake. Do not "tidy" them back toward 1.0.
HD_Double    := 2.0
HD_Quadruple := 4.0
HD_Tenfold   := 10.0

HD_ALIEN_Double    := 2.0
HD_ALIEN_Quadruple := 4.0
HD_ALIEN_Tenfold   := 10.0

HD_SPEC_Double    := 4.0
HD_SPEC_Quadruple := 8.0
HD_SPEC_Tenfold   := 20.0

HD_ROBO_Double    := 4.0
HD_ROBO_Quadruple := 8.0
HD_ROBO_Tenfold   := 20.0

# Descriptions shown in the FOMOD menu and in the in-game mod list. The variant
# name says the mechanic, the description translates it into the fuel saving
# the player actually cares about. No "%" problem: these go through sed and zip.
DESC_Double    := 2x warps per cell - half the fuel per jump
DESC_Quadruple := 4x warps per cell - a quarter of the fuel per jump
DESC_Tenfold   := 10x warps per cell - a tenth of the fuel per jump

# Base hyperdrive value per variant, for the verify summary line.
BASEVALS := $(foreach v,$(VARIANT),$(v)=$(HD_$(v)))

# The four ship hyperdrive technologies this mod patches. Keep in sync with
# HyperTechs in src/hyperfuel.lua.in (build checks this).
HYPER_TECHS := HYPERDRIVE WARP_ALIEN HYPERDRIVE_SPEC HYPERDRIVE_ROBO

# Which per-tech value variable holds each tech's value.
JUMPVAR_HYPERDRIVE      := HD
JUMPVAR_WARP_ALIEN      := HD_ALIEN
JUMPVAR_HYPERDRIVE_SPEC := HD_SPEC
JUMPVAR_HYPERDRIVE_ROBO := HD_ROBO

# Value for one tech in one variant, e.g. jumptval Double HYPERDRIVE_SPEC -> 4.0
jumptval = $($(JUMPVAR_$(2))_$(1))

# "TECH=value" pairs for one variant, for the awk value check.
jumpwant = $(foreach t,$(HYPER_TECHS),$(t)=$(call jumptval,$(1),$(t)))

# clean runs before build runs before verify, so release must not be parallel.
.NOTPARALLEL:

.PHONY: all release build verify assets clean

all: release

release: clean build verify
	@rm -rf "$(BUILD)/fomodz" && mkdir -p "$(BUILD)/fomodz/fomod" $(addprefix "$(BUILD)/fomodz/",$(VARIANT))
	@set -e; for v in $(VARIANT); do cp -a "$(BUILD)/$(MOD_SET) - $$v/METADATA" "$(BUILD)/fomodz/$$v/"; done
	@cp ModuleConfig.xml "$(BUILD)/fomodz/fomod/"
	@mkdir -p "$(DIST)" && rm -f "$(FOMOD_ZIP)" && cd "$(BUILD)/fomodz" && zip -qr "$(shell pwd)/$(FOMOD_ZIP)" fomod $(VARIANT)
	@echo "packed: $(FOMOD_ZIP)"
	@python3 -c "import xml.dom.minidom; xml.dom.minidom.parse('$(BUILD)/fomodz/fomod/ModuleConfig.xml'); print('ModuleConfig.xml: well-formed XML')"

# Render the variant scripts from the single template. One pattern rule for
# every variant: the file stem is the variant label, so $* drives the
# substitutions. The guard turns a typo in VARIANT into a loud failure rather
# than a script with a blank multiplier.
$(BUILD)/%.lua: $(SRC_TEMPLATE)
	@mkdir -p "$(BUILD)"
	@test -n "$(HD_$*)" -a -n "$(HD_ALIEN_$*)" -a -n "$(HD_SPEC_$*)" -a -n "$(HD_ROBO_$*)" -a -n "$(DESC_$*)" || { echo "ERROR: unknown variant '$*' - add HD_$*, HD_ALIEN_$*, HD_SPEC_$*, HD_ROBO_$* and DESC_$* to the Makefile" >&2; exit 1; }
	@sed -e "s/@VARIANT_LABEL@/$*/" -e "s/@HD@/$(HD_$*)/" -e "s/@HD_ALIEN@/$(HD_ALIEN_$*)/" -e "s/@HD_SPEC@/$(HD_SPEC_$*)/" -e "s/@HD_ROBO@/$(HD_ROBO_$*)/" -e "s/@DESC@/$(DESC_$*)/" "$(SRC_TEMPLATE)" > "$@"

# One pipeline run builds every variant as an individual mod.
build: $(RENDERED)
	@test -d "$(AMUMSS_HOME)/MODBUILDER" || (echo "ERROR: no AMUMSS install at $(AMUMSS_HOME) (set AMUMSS_HOME=...)" >&2; exit 1)
	@test -x "$(AMUMSS_HOME)/MODBUILDER/MBINCompiler-linux" || (echo "ERROR: run $(AMUMSS_LINUX)/scripts/fetch_mbincompiler.sh with AMUMSS_HOME=$(AMUMSS_HOME) first" >&2; exit 1)
	@mkdir -p "$(BUILD)"
	@set -e; \
	if [ -d "$(AMUMSS_HOME)/ModScript" ]; then mv "$(AMUMSS_HOME)/ModScript" "$(AMUMSS_HOME)/ModScript.makebak"; trap 'rm -rf "$(AMUMSS_HOME)/ModScript"; mv "$(AMUMSS_HOME)/ModScript.makebak" "$(AMUMSS_HOME)/ModScript"' EXIT; fi; \
	mkdir -p "$(AMUMSS_HOME)/ModScript"; \
	cp $(RENDERED) "$(AMUMSS_HOME)/ModScript/"; \
	AMUMSS_HOME="$(AMUMSS_HOME)" "$(AMUMSS_LINUX)/buildmod.sh" --run-pipeline; \
	rm -rf "$(AMUMSS_HOME)/ModScript"; \
	if [ -d "$(AMUMSS_HOME)/ModScript.makebak" ]; then mv "$(AMUMSS_HOME)/ModScript.makebak" "$(AMUMSS_HOME)/ModScript"; fi; \
	trap - EXIT
	@set -e; for v in $(VARIANT); do \
		rm -rf "$(BUILD)/$(MOD_SET) - $$v"; \
		mkdir -p "$(BUILD)/$(MOD_SET) - $$v"; \
		cp -a "$(AMUMSS_HOME)/CreatedMODS/$(MOD_SET) - $$v/METADATA" "$(BUILD)/$(MOD_SET) - $$v/"; \
	done
	@touch "$(STAMP)"
	@echo "built: $(foreach v,$(VARIANT),$(BUILD)/$(MOD_SET) - $(v) )"

# Single zip with a FOMOD installer menu (choose a jumps-per-cell multiplier).
# fomod/ lives at the zip root (that is how managers detect installers).
# Version travels in the zip filename (Nexus convention).
FOMOD_ZIP := $(DIST)/$(MOD_SET) $(VERSION).zip

# Path to a variant's generated EXML.
exml = $(BUILD)/$(MOD_SET) - $(1)/$(EXML_RELPATH)

# One check chain per variant, expanded at make time so each value is baked in.
# The generated EXML is a minimal patch, keyed by _id rather than name="ID",
# and carries no StatsType leaf, so verify has three jobs:
#   1. the EXML was produced by THIS run, not carried over from a previous one
#   2. each of the four techs got the value we asked for, in the right
#      StatBonuses slot
#   3. nothing ELSE got touched - the total Bonus count must be exactly 4.
#      This is the load-bearing check. If a SPECIAL_KEY_WORDS path ever stops
#      matching, AMUMSS silently applies the change to every StatBonuses in
#      the table (501 of them in v7.04) and ships that as the patch.
#
# Job 1 covers the failure mode the other two cannot see. The build copies each
# variant out of $(AMUMSS_HOME)/CreatedMODS, which is a persistent directory
# that this Makefile does not own. When a script changes nothing (a drifted
# keyword path, a typo, a bad stat name) AMUMSS logs "0 action(s) made",
# creates nothing, and leaves the PREVIOUS build's file sitting there. The copy
# then succeeds, and jobs 2 and 3 happily validate last week's output. The
# rendered script is always written before the pipeline runs, so anything
# older than it came from somewhere else.
define VERIFY_VARIANT
test -f "$(call exml,$(1))" || { echo "MISSING $(1) EXML" >&2; exit 1; }; \
if [ "$(call exml,$(1))" -ot "$(BUILD)/$(1).lua" ]; then \
	echo "STALE $(1) EXML - older than the script that should have produced it." >&2; \
	echo "       AMUMSS most likely made no changes this run, so this is output from a" >&2; \
	echo "       previous build being picked out of $(AMUMSS_HOME)/CreatedMODS." >&2; \
	echo "       Clear $(AMUMSS_HOME)/CreatedMODS and rebuild; if it persists the script" >&2; \
	echo "       is not matching anything." >&2; \
	exit 1; \
fi; \
awk -v tag="$(1)" -v ntech="$(words $(HYPER_TECHS))" -v wantidx="$(HYPER_BONUS_INDEX)" -v want="$(call jumpwant,$(1))" \
 'BEGIN{n=split(want,W," ");for(i=1;i<=n;i++){split(W[i],kv,"=");want_v[kv[1]]=kv[2]+0}} \
  /name="Table" value="GcTechnology"/{if(match($$0,/_id="[^"]*"/)){x=substr($$0,RSTART+5,RLENGTH-6);if(x in want_v){t=x;ix=-1}}} \
  /name="StatBonuses" value="GcStatsBonus"/{if(match($$0,/_index="[^"]*"/)){ix=substr($$0,RSTART+8,RLENGTH-9)+0}} \
  /name="Bonus" value=/{total++;if(t!=""){if(match($$0,/value="[^"]*"/)){got[t]=substr($$0,RSTART+7,RLENGTH-8)+0};gotix[t]=ix}} \
  END{rc=0;for(k in want_v){if(!(k in got)){printf "MISSING %s bonus in %s\n",k,tag> "/dev/stderr";rc=1}else if(got[k]!=want_v[k]){printf "BAD %s bonus in %s: got %s want %s\n",k,tag,got[k],want_v[k]> "/dev/stderr";rc=1}else if(gotix[k]!=wantidx){printf "BAD %s StatBonuses index in %s: got %s want %s - the keyword path may have drifted onto another stat\n",k,tag,gotix[k],wantidx> "/dev/stderr";rc=1}};if(total!=ntech){printf "LEAK in %s: %s Bonus values patched, want %s - the keyword path is not matching and AMUMSS is rewriting the whole table\n",tag,total,ntech> "/dev/stderr";rc=1};exit rc}' \
 "$(call exml,$(1))" || { echo "VERIFY FAILED: $(1)" >&2; exit 1; }; \
if grep -q '!#' "$(call exml,$(1))"; then echo "marker tags present in $(1)" >&2; exit 1; fi
endef

verify: build
	@set -e; for v in $(VARIANT); do \
		for t in $(HYPER_TECHS); do \
			grep -qF "\"$$t\"," "$(BUILD)/$$v.lua" \
				|| { echo "ERROR: $$t is missing from HyperTechs in $(SRC_TEMPLATE) - HYPER_TECHS in the Makefile and the template have drifted apart" >&2; exit 1; }; \
		done; \
		kw=$$(grep -o '\["SPECIAL_KEY_WORDS"\][^}]*}' "$(BUILD)/$$v.lua" | head -1); \
		n=$$(printf '%s' "$$kw" | tr -cd ',' | wc -c); \
		n=$$((n + 1)); \
		if [ $$((n % 2)) -ne 0 ]; then \
			echo "ERROR: SPECIAL_KEY_WORDS in $(SRC_TEMPLATE) has $$n entries (odd)." >&2; \
			echo "       AMUMSS silently discards the last entry, the path stops matching, and" >&2; \
			echo "       the Bonus change is applied to EVERY StatBonuses in the table." >&2; \
			exit 1; \
		fi; \
	done
	@set -e; $(foreach v,$(VARIANT),$(call VERIFY_VARIANT,$(v));)
	@echo "verify: OK ($(BASEVALS) hyperdrive warps per cell, $(words $(HYPER_TECHS)) techs each, fresh this run, no marker tags)"

# Nexus page images from assets/src (Pillow required). Outputs are
# generated artifacts (gitignored) - reproducible via this target.
assets: assets/src/hyperdrive-fuel.jpg assets/generate.py
	python3 assets/generate.py

clean:
	rm -rf "$(BUILD)" "$(DIST)"
