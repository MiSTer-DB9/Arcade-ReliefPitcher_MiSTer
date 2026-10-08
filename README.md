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
- **Analog alignment** moves and resizes the picture on CRTs and analogue
  VGA outputs.
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

## License

GPL-3.0-or-later; see LICENSE. NOTICE.md lists the cores and libraries this
one builds on. Keep LICENSE, NOTICE.md and the bundled third-party licences
when redistributing.
