# Relief Pitcher for MiSTer

An FPGA core for Atari Games' baseball game **Relief Pitcher** (1992). It
recreates the game board and its audio daughterboard: a 68000 CPU at
7.16 MHz, Atari's VAD and MOB video chips, a YM2413 for music and an
MSM6295 for sampled sounds. There is no sound CPU; the 68000
drives both sound chips directly.

The core was built from the schematic sheets in Atari's TM-376 manual and
the logic read from the board's GAL chips, with MAME 0.289 as a reference
where those are silent.

<img src="https://img.shields.io/badge/Quartus-17.0.2-blue" alt="Quartus 17.0.2"> <img src="https://img.shields.io/badge/license-GPL--3.0--or--later-blue" alt="GPL-3.0-or-later">

## Supported games

| MRA | MAME set | Revision |
| --- | --- | --- |
| `Relief Pitcher.mra` | `relief` | Rev D |
| `_alternatives/_Relief Pitcher/Relief Pitcher (rev C).mra` | `relief2` | Rev C |
| `_alternatives/_Relief Pitcher/Relief Pitcher (rev B).mra` | `relief3` | Rev B |

All three revisions run on the same bitstream; only the program ROMs differ.

## Requirements

- A DE10-Nano with a MiSTer SDRAM module of 32 MB or larger. Game data is
  read from SDRAM while the game runs, so the module is not optional.
- The MAME 0.289 ROM sets `relief`, `relief2` and `relief3`. No ROM data is
  included in this repository.

## Installing

1. Copy `releases/ReliefPitcher_<date>.rbf` to `_Arcade/cores/`. Keep only
   one `ReliefPitcher_*.rbf` there; the MRAs match any of them.
2. Copy `releases/Relief Pitcher.mra` to `_Arcade/`. For the older
   revisions, copy the `releases/_alternatives` folder to
   `_Arcade/_alternatives`.
3. Put `relief.zip` in `games/mame/`. The rev C and rev B MRAs also need
   `relief2.zip` or `relief3.zip` next to it, because a clone zip holds only
   the ROMs that differ from the parent.

## Controls

The cabinet has two joysticks, each with a three-colour button. The left set
pitches and fields; the right set bats and runs the bases.

| Button | Colour | Left (pitching) | Right (batting) |
| --- | --- | --- | --- |
| 1 | Yellow | Fast Ball | Swing |
| 2 | Red | Curve Ball | Power Swing |
| 3 | Green | Special Pitch | Bunt |

The OSD **Controls** option chooses how controllers reach the two sets:

- **One Set** (default): one controller plays both roles. It drives the
  left set while you are in the field and the right set while you are at
  bat, following the game.
- **Original**: controller 1 is the left set and controller 2 the right.
  Use this for two-player games.

| Function | Controller | Keyboard (player 1) | Keyboard (player 2) |
| --- | --- | --- | --- |
| Joystick | D-pad or stick | Arrow keys | R F D G |
| Buttons 1, 2, 3 | A, B, X | Left Ctrl, Left Alt, Space | A, S, Q |
| Start | Start | 1 | 2 |
| Coin | Select | 5 | 6 |
| Service credit | L | F1 | F1 |
| Self-test | OSD Service | hold F2 | hold F2 |

All controller buttons can be remapped in the MiSTer menu.

## OSD options

- **Aspect ratio**, **Orientation** (Flip) and **Scale** set the picture.
- **CRT Adjust** moves and resizes the picture on CRTs and analogue VGA
  outputs: H-Size, H-Position and V-Shift. Off leaves the picture untouched.
  It is unavailable while the scandoubler is forced on.
- **Service** is the cabinet's self-test switch. Turn it on to enter the
  game's test menu and off to leave it.

## Volume, settings and high scores

The game has no volume buttons. Set the volume in the self-test menu under
Adjust Volume. Game settings, the volume and high scores are kept in the
board's EEPROM, which the core saves to a file in `config/nvram/` on the SD
card. A save is ready about a second after the game last changes the
EEPROM, and MiSTer writes the file the next time the OSD is opened. A
damaged or wrong-sized file is not loaded; the user LED stays lit to show
it.

## Known limits

The colour mixer wiring was worked out from the mixer GAL logic, not read
from a board. Sound levels use typical chip output figures, not a board
measurement.

## Building

Open `ReliefPitcher.qpf` in Quartus Prime Lite 17.0.2 and compile, or run
`quartus_sh --flow compile ReliefPitcher` in this folder. The bitstream is
written to `output_files/ReliefPitcher.rbf`. Add new source files to
`files.qip` rather than through the Quartus GUI. The build date is written
into the bitstream, so a build made on another day is not byte-identical to
the release.

## Credits

- **Atari Games**: the original hardware and game.
- **The [MAME](https://github.com/mamedev/mame) team**: `relief.cpp`
  (Aaron Giles), `atarivad`, `atarimo`, `okim6295` and `ymfm`, the
  reference for everything the schematics and GALs do not settle.
- **Jorge Cwik (ijor)**: the [fx68k](https://github.com/ijor/fx68k) 68000
  core.
- **Sehyeon Kim (Raki)**: the [IKAOPLL](https://github.com/ika-musume/IKAOPLL)
  YM2413 core.
- **Nuke.YKT**: [Nuked-OPLL](https://github.com/nukeykt/Nuked-OPLL), a
  second YM2413 reference used while testing.
- **Alexey Melnikov (Sorgelig)** and the MiSTer-devel community: the
  [MiSTer framework](https://github.com/MiSTer-devel/Template_MiSTer).
- **Umberto Parisi (rmonic79)**: `crt_adjust.sv`, from
  [MiSTer-CRT-Adjust](https://github.com/rmonic79/MiSTer-CRT-Adjust).
- **RetroShrimp**: this core, and the YM2413 bus adapter from the
  [Rampart](https://github.com/MiSTer-devel/Arcade-Rampart_MiSTer) MiSTer
  core.
- The authors of the MiSTer cores whose CPU wrapper, SDRAM controller and
  loader, VAD and MOB video models, MSM6295 model and MiSTer glue this core
  builds on:
  [Batman](https://github.com/MiSTer-devel/Arcade-Batman_MiSTer),
  [Skull & Crossbones](https://github.com/MiSTer-devel/Arcade-SkullXBones_MiSTer),
  [Klax](https://github.com/MiSTer-devel/Arcade-Klax_MiSTer),
  [Bad Lands](https://github.com/MiSTer-devel/Arcade-Badlands_MiSTer),
  [Vindicators](https://github.com/MiSTer-devel/Arcade-Vindicators_MiSTer),
  [Blasteroids](https://github.com/MiSTer-devel/Arcade-Blasteroids_MiSTer),
  [Xybots](https://github.com/MiSTer-devel/Arcade-Xybots_MiSTer) and
  [Toobin'](https://github.com/MiSTer-devel/Arcade-Toobin_MiSTer).

## Licence

The combined work is GPL-3.0-or-later; see `LICENSE`. Bundled components
keep their own licences and notices:

| Component | Author | Licence |
| --- | --- | --- |
| `rtl/lib/fx68k/` | Jorge Cwik | GPL-3.0 |
| `rtl/lib/ikaopll/` | Sehyeon Kim (Raki) | BSD-2-Clause |
| `rtl/lib/oki/` | Klax MiSTer core authors | GPL-2.0-or-later |
| `rtl/video/crt_adjust.sv` | Umberto Parisi | GPL-3.0-or-later |
| `sys/` | Alexey Melnikov and contributors | GPL-2.0-or-later / GPL-3.0-or-later |

`NOTICE.md` lists the cores this one builds on. Keep `LICENSE`, `NOTICE.md`
and the bundled licences when redistributing.

*Relief Pitcher* is a trademark of its respective owner. This is an
unaffiliated preservation project and contains no ROM data. Use it only
with ROMs you are legally entitled to.
