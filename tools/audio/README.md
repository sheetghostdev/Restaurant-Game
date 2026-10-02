# Procedural placeholder audio

All sound effects in `audio/sfx/` and music in `audio/music/` come from
`generate_audio.py`. The script synthesizes every sound from scratch with
numpy/scipy DSP: oscillators, filtered noise, modal "struck object" resonators,
FM bells, simple formant voices, envelopes, and convolution reverb. It uses no
samples or third-party recordings.

**License / ownership:** these are original, procedurally generated
placeholders owned by the project and dedicated to the public domain (CC0).
They are meant to be **replaced later by real recordings or composed music
with the same file names**. Game code should only rely on the names and the
loop / layering conventions below.

## Regenerating

Requirements: Python 3.9+, `numpy`, `scipy`, and `ffmpeg` built with
`libvorbis` (needed only for the music).

```bash
pip install numpy scipy
python3 tools/audio/generate_audio.py            # everything, then verification (~25 s)
python3 tools/audio/generate_audio.py --sfx      # only sound effects
python3 tools/audio/generate_audio.py --music    # only music
python3 tools/audio/generate_audio.py --only ding,coin,stem_base
python3 tools/audio/generate_audio.py --verify   # check existing files only
python3 tools/audio/generate_audio.py --list     # asset names
```

Output is deterministic because every asset uses a fixed seed. Each sound is
a small function, and the `SFX` dict maps file names to those functions.
To tweak a sound, edit its function and run with `--only <name>`.

The generator verifies its output automatically. It checks:

- WAV format (mono, 16-bit, 44.1 kHz).
- Peak level below 0 dBFS, and no DC offset.
- One-shots start and end at silence.
- Every `_loop` has no step or kink at the loop point.
- Music decodes to stereo, and the three stems have exactly the same length.
- The three stems together (base + groove + rush) don't clip.

## Formats and conventions

| | Format | Notes |
|---|---|---|
| `audio/sfx/*.wav` | 16-bit PCM, mono, 44.1 kHz | Peak −1 dBFS. Some are quieter on purpose: footsteps −5, `ui_hover` −12, `ui_click` −4, steady tones such as `truck_beep` −7, `alarm_loop` −6 and `dishwasher_done` −5. |
| `audio/music/*.ogg` | Ogg Vorbis q5, stereo, 44.1 kHz | Every track is exactly 16 bars and loops seamlessly. |

- **Loops:** files ending in `_loop` are built circularly. Events wrap
  around the loop end, noise beds are filtered in the frequency domain, and
  tones use whole periods. In Godot, set **Loop Mode = Forward** in the WAV
  import settings, with loop begin 0 and loop end at the end of the file. For
  the `.ogg` music, enable **Loop**.
- **Music reverb:** note tails and the reverb are wrapped around to the start
  of each music file, so the loop point needs no crossfade.

## Music

The music is a cozy diner jazz theme in F major, with swung 8ths, jazzy 7th
and 9th chords, light humanization and stereo placement.

| File | Tempo | Length | Use |
|---|---|---|---|
| `stem_base.ogg` | 112 BPM | 16 bars = 1,512,000 samples (34.286 s) | Calm prep layer: tine e-piano chords, vibraphone answers, soft bass, light shaker. Works on its own. |
| `stem_groove.ogg` | 112 BPM | identical | Add during service: brushed kit (kick, brush snare, swing hats, brush swirl), walking bass, muted-guitar chord stabs. |
| `stem_rush.ogg` | 112 BPM | identical | Add during rush hour: 16th hats and shaker, whistle lead melody (with ping-pong delay), brass stabs, tom fills. |
| `music_closing.ogg` | 84 BPM | 16 bars (45.714 s) | After service / evening planning: mellow lo-fi version with dusty drums, vinyl crackle and tape wobble. |
| `music_menu.ogg` | 108 BPM | 16 bars (35.556 s) | Title / menu theme: bright e-piano, vibraphone melody with glockenspiel lift, brushes. |

Stem progression (one chord per bar): Fmaj9 | Dm9 | Gm9 | C13 | Fmaj9 | Am7 |
Bbmaj9 | C9 | Dm9 | G13 | Gm9 | C13 | Fmaj9 | D9 | Gm9 C13 | Fmaj9 C9sus4.
The last bar turns around into bar 1.

**Layering:** start all three stems on the same audio frame and keep them
playing. Bring layers in and out with volume fades (for example, −80 dB to
0 dB over 1–2 bars) rather than starting them later. That keeps them sample
locked.

The stems share one gain stage. The loudest stem peaks at about −6 dBFS, and
the full layered mix peaks at about −3 dBFS. `music_menu` is normalized to
−3 dBFS peak and `music_closing` to −5 dBFS peak, so all of them play at
about the same loudness as the full stem mix.

## Sound effects

| File(s) | Intended use |
|---|---|
| `footstep_1..3` | Player footsteps (soft muffled taps, slightly different pitches; randomize between them) |
| `pickup` / `putdown` | Grabbing an item / placing it on a counter |
| `drop_heavy` | Box or crate landing (deliveries) |
| `crate_take` | Taking a vegetable from a crate |
| `chop_1..3` | Knife chops on a cutting board (randomize) |
| `sizzle_loop` | Grill / pan sizzling |
| `fryer_loop` | Deep fryer bubbling |
| `ding` | Cooking done |
| `burn_warning` | Food about to burn (crackle, hiss and a soft "uh-oh") |
| `coffee_brew_loop` / `coffee_done` | Espresso machine running / finished |
| `fridge_open` / `fridge_close` | Fridge door |
| `door_bell` | Customer enters (shop bell) |
| `dish_clink` / `dish_stack` | Single plate / stacking plates |
| `wash_loop` | Sink: running water and scrubbing |
| `dishwasher_loop` / `dishwasher_done` | Dishwasher running / finished beeps |
| `cash_register` / `coin` / `money_spend` | Payment received / small money gain / spending money |
| `crowd_loop` | Dining-room murmur ambience (unintelligible synthetic babble, 4 s) |
| `customer_happy` / `customer_angry` | Customer reactions ("mm-HM!" chirp / grumble) |
| `order_ready` | Customer raising their hand (two rising notes) |
| `serve` | Plate served, with sparkle |
| `truck_engine_loop` / `truck_beep` / `truck_horn` | Delivery truck idling / reversing beep (repeat it from code) / horn |
| `alarm_loop` | Fire / smoke alarm |
| `fire_loop` / `extinguisher_loop` | Kitchen fire / extinguisher spray |
| `breakdown` / `repair_loop` / `repair_done` | Machine breaks / being repaired / fixed |
| `mop_loop` / `splash` | Mopping / liquid spill |
| `glass_break` | Dropped glass or plate |
| `ui_click`, `ui_hover`, `ui_confirm`, `ui_back` | Menu UI |
| `open_sign` | "We're open!" sting at the start of service |
| `day_end` | Closing chime at the end of the day |
| `level_up` | Reputation up fanfare |
| `build_place` / `build_lift` / `construct` | Build mode: place furniture / pick it up / construction |
| `ping` | Player marks something (attention ping) |
| `trash` | Throwing something in the bin |
| `conveyor_loop` / `grabber` | Automation: conveyor belt / pneumatic arm |
| `timer_ring` | Mechanical kitchen timer |
| `whoosh` | Sprint / dash |
| `error` | Invalid action (soft "bonk-bonk") |
| `spoil` | Food spoiled ("blorp") |

## Limitations

- These are stylized synthetic sounds. Organic sources such as water, crowd,
  fire and voices are convincing as cartoon placeholders but not as
  realistic recordings.
- The crowd babble and customer voices are formant-synthesized vowels. They
  contain no real speech.
- Vorbis is lossy, so the decoded music is not bit-exact at the loop point.
  The verifier measures the codec error there. It is about 15–25 dB below the
  codec's normal error elsewhere in the file, and well under −40 dBFS.
- Loudness is balanced by ear-free heuristics (peak and RMS targets). Expect
  to set per-sound `volume_db` in game.
