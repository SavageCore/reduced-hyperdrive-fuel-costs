# Reduced Hyperdrive Fuel Costs

Scale down **hyperdrive** fuel consumption in No Man's Sky - the Warp Cells you
burn per jump, refilled from the ship's hyperdrive tank. Pick a jumps-per-cell
multiplier at install time. Built natively on Linux with the
[AMUMSS Linux port](https://github.com/SavageCore/AMUMSS/tree/feat/linux-support).

The approach is ported from Cykron0271's
[Reduced Ship Launch Fuel Costs (Or Increased)](https://www.nexusmods.com/nomanssky/mods/3490)
(original mod by Lexman6 and Lo2k), retargeted from launch cost to hyperdrive
fuel.

## How it works

Hyperdrive is a **charge** mechanic, not a burn-per-jump one. The hyperdrive
technology fills a tank of `ChargeAmount` **120** units, a Warp Cell (`HYPERFUEL1`)
adds `ChargeValue` **24**, and each jump spends one cell's worth of charge.
120 / 24 = 5 cells fills the tank, which is where the vanilla "pre-charged with
up to 5 warp cells" figure comes from.

The lever is `Ship_Hyperdrive_JumpsPerCell`: how many warps the hyperdrive gets
out of one Warp Cell. Vanilla is `1.0` for the Standard and Alien drives and
`2.0` for the Royal and Robo drives, which is exactly why the Royal Hyperdrive
is the better drive. **Higher is cheaper here** - the inverse of a
fuel-spending multiplier - so this mod scales the value *up*.

## Usage

During installation, pick how many warps you want per Warp Cell.

| Variant | Factor | `HYPERDRIVE` | `WARP_ALIEN` | `HYPERDRIVE_SPEC` (Royal) | `HYPERDRIVE_ROBO` (Robo) |
| --- | --- | --- | --- | --- | --- |
| *unmodified* | 1.00 | 1.0 | 1.0 | 2.0 | 2.0 |
| `Double` | x2 | 2.0 | 2.0 | 4.0 | 4.0 |
| `Quadruple` | x4 | 4.0 | 4.0 | 8.0 | 8.0 |
| `Tenfold` | x10 | 10.0 | 10.0 | 20.0 | 20.0 |

Each column is that drive's final `Ship_Hyperdrive_JumpsPerCell` value. The
italic row is the unmodified baseline, shown for reference only.

The factor is the reciprocal of the fuel cost per jump, so `Tenfold` is a tenth
of the Warp Cells per jump that vanilla uses. The numbers sit far outside the
vanilla range on purpose; do not "tidy" them back toward 1.0.

## Compatibility

Modifies
`METADATA/REALITY/TABLES/NMS_REALITY_GCTECHNOLOGYTABLE.MBIN` only. It may
conflict with any other mod editing that file, which is a lot of mods. The
generated patch is minimal: four `Bonus` values and nothing else, so
load-order conflicts with unrelated tech mods should be rare, but a mod that
rewrites the whole technology table will conflict outright.

**The charge side is not modified.** `ChargeAmount` (120), `ChargeType` and
`ChargeBy` on the four hyperdrive technologies, and the Warp Cell `HYPERFUEL1`
`ChargeValue` (24), are all deliberately left alone. Those decide how fast the
hyperdrive fills, so your tank still charges up at the vanilla rate and each
Warp Cell still refills the same amount. Only the number of jumps it buys
changes.

**Not affected:** the colour-drive upgrades (`HDRIVEBOOST1`-`HDRIVEBOOST4`)
grant only `Ship_Hyperdrive`, and the freighter drive (`F_HYPERDRIVE`) uses the
separate `Freighter_Hyperdrive_JumpsPerCell`, so neither is touched.

## Build (on Linux)

Requires a full AMUMSS install at `~/AMUMSS` (override with
`AMUMSS_HOME=...`) with `MBINCompiler-linux` fetched
(`linux/scripts/fetch_mbincompiler.sh` in the AMUMSS repo).

```sh
make release      # clean rebuild + verify + pack dist/ zip (default)
make verify       # sanity-check the built outputs
make clean        # remove build/ and dist/
make assets       # regenerate Nexus page images (needs assets/src/hyperdrive-fuel.jpg)

make release VERSION=0.1.0   # override the version in the zip name
```

`VERSION` in the `Makefile` is currently **0.0.0**. It is a development build:
the generated patch is verified against the v7.04 technology table, but the
shipped variants have not been played in game yet (see
[Not yet confirmed in game](#not-yet-confirmed-in-game)). It becomes 0.1.0 in
its own commit once they have.

`make build` temporarily stages the variant scripts into
`$(AMUMSS_HOME)/ModScript` (existing content moved aside and restored),
runs one `buildmod.sh --run-pipeline`, and collects the outputs.

`make verify` is the load-bearing step, not a formality. It asserts, per
variant, that the EXML was produced by *this* run, that each of the four techs
got the requested value in the correct `StatBonuses` slot, and that **exactly
four** `Bonus` values were patched in total.

The count check exists because of how AMUMSS fails: a `SPECIAL_KEY_WORDS` path
that stops matching does not error, it silently applies the change to every
`StatBonuses` in the table (501 of them in v7.04) and ships that. See the
comment on `SPECIAL_KEY_WORDS` in `src/hyperfuel.lua.in`.

The freshness check covers the failure the count check cannot see. Each variant
is copied out of `$(AMUMSS_HOME)/CreatedMODS`, a persistent directory this
project does not own. When a script changes nothing - a drifted keyword path, a
typo, a bad stat name - AMUMSS logs `0 action(s) made`, creates no output, and
leaves the *previous* build's file sitting there. The copy then succeeds and the
value checks happily validate last week's output. Since the rendered script is
always written before the pipeline runs, an EXML older than its script came
from somewhere else, and verify fails rather than shipping it.

## Release

`make release` creates `dist/Reduced Hyperdrive Fuel Costs <VERSION>.zip`,
which is the zip to import into
[Amethyst](https://github.com/ChrisDKN/Amethyst-Mod-Manager)/[Vortex](https://github.com/Nexus-Mods/Vortex)
or upload to Nexus. `fomod/` sits at the zip root, which is how mod managers
detect an installer.

## Game updates / versioning

The mod version is `VERSION` in the `Makefile`. The game version the scripts
target is `GameVersion` in `src/hyperfuel.lua.in`.

When No Man's Sky updates:

1. Fetch the new matching compiler from the AMUMSS repo (use
   `MBINCOMPILER_TAG=vX` to pin):
   `AMUMSS_HOME=~/AMUMSS linux/scripts/fetch_mbincompiler.sh`
   If the AMUMSS core itself changed, re-run the pipeline once so the
   linux patches re-verify (`apply_linux_patches.sh --verify`).
2. Bump `GameVersion` in `src/hyperfuel.lua.in`.
3. Bump `VERSION` in the `Makefile`.
4. Re-check the assumptions in the source table below (see below).
5. `make release`, import, deploy, test.

### Re-checking the source values after a game update

The four drive values and the `_index` they live at are game data, not
constants this mod owns. To re-derive them:

```sh
PAK=~/.local/share/Steam/steamapps/common/"No Man's Sky"/GAMEDATA/PCBANKS/NMSARC.Precache.pak
hgpaktool -O /tmp/probe -f "*NMS_REALITY_GCTECHNOLOGYTABLE.MBIN" "$PAK"
cd /tmp/probe/metadata/reality/tables
~/AMUMSS/MODBUILDER/MBINCompiler-linux -q -y -f -iMBIN nms_reality_gctechnologytable.mbin
```

Then find every tech carrying `Ship_Hyperdrive_JumpsPerCell`:

```sh
python3 - <<'EOF'
import xml.etree.ElementTree as ET
t = ET.parse('nms_reality_gctechnologytable.MXML')
STAT = 'Ship_Hyperdrive_JumpsPerCell'
for tech in t.getroot().find('Property').findall('Property'):
    p = {x.get('name'): x for x in tech.findall('Property')}
    tid = p.get('ID')
    sb = p.get('StatBonuses')
    if sb is None: continue
    for b in sb.findall('Property'):
        bp = {x.get('name'): x for x in b.findall('Property')}
        st = bp.get('Stat')
        if st is None: continue
        leaf = st.find('Property')
        if leaf is None or leaf.get('value') != STAT: continue
        print(f"{tid.get('value'):18s} Bonus={bp['Bonus'].get('value'):10s} _index={b.get('_index')}")
EOF
```

Expected as of v7.04: exactly the four `HYPERDRIVE*` / `WARP_ALIEN` drives at
`_index=2`, with vanilla values `1.0`, `1.0`, `2.0`, `2.0`. If the four drives
move off `_index=2`, update `HYPER_BONUS_INDEX` in the `Makefile` or
`make verify` will fail loudly rather than quietly patching the wrong stat. If
the vanilla values change, update the value table and `HD_*` / `HD_*_*` in the
`Makefile` to keep the factors honest.

### Not yet confirmed in game

The patch is verified against the v7.04 technology table, and the mechanic is
derivable from the data (`120 / 24 = 5` cells, matching the documented 5),
but the shipped variants have not been played. In particular it is unverified
how the fuel UI handles **fractional** charge at high multipliers: at `Tenfold`
each jump costs `24 / 10 = 2.4` units, and a "warps remaining" readout could
round oddly. Test each variant in game before shipping. If the display
misbehaves, the fix is to drop the top variant or move to an integer-safe scale
rather than to clamp the values back toward vanilla.
