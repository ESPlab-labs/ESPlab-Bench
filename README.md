# ESPlab-Bench

A benchmark pack for [ESPlab](https://github.com/ESPlab-labs/ESPlab) clusters:
six real workloads, each written **twice** — once in [espc](https://github.com/ESPlab-labs/ESPlab/blob/main/tools/espc.py),
once in hand-tuned VM assembly — same algorithm, same input, same slice.

Both versions run on the same VM interpreter that ships on the boards, and the
runner checks every output byte-exact against an independent Python reference
before recording anything. Speed findings are recorded, whatever direction
they point.

## The scorecard (v0.4.0 VM, commit-pinned inputs)

| task | stresses | espc insns | asm insns | winner | espc/asm code size |
|---|---|---|---|---|---|
| crc32 | xor/shift inner loop, branchy | 51,283 | 34,358 | asm (−33%) | 57 / 45 |
| rle_encode | run scan with early exit | 23,392 | 12,299 | asm (−47%) | 41 / 26 |
| mandelbrot | nested loops, fixed-point multiply | 84,793 | 66,310 | asm (−22%) | 63 / 50 |
| bytebeat | straight-line integer formula | 7,686 | 4,615 | asm (−40%) | 20 / 15 |
| greplite | pattern scan with state | 3,880 | 3,482 | asm (−10%) | 38 / 33 |
| histogram | table-driven counting | 4,615 | 3,155 | asm (−32%) | 30 / 23 |

Totals: **espc 175,649 vs asm 124,219 executed instructions — hand assembly
is 29% fewer on these tasks.**

The fair counterpoint: on the production streaming decoder that ships in
ESP On Demand, espc *beats* the hand-tuned assembly (891 vs 945 instructions
on a representative band), and the ESPlab test suite enforces that contract
on every commit. Read both numbers: **espc wins straight-line stream
processing, hand assembly wins branchy state machines.** That is what this
benchmark exists to make measurable instead of debatable.

## Quick start

```sh
git clone https://github.com/ESPlab-labs/ESPlab-Bench.git
cd ESPlab-Bench
git clone https://github.com/ESPlab-labs/ESPlab.git esplab
make -C esplab        # builds vbasm + espc_vmtest (the VM core)
./bench.py             # or: ESPLAB_DIR=/path/to/ESPlab ./bench.py
```

CI does exactly this against the tagged ESPlab release, so every scorecard
number is reproducible from a clean checkout.

## How measurement works

- **Instruction counts come from the VM itself** (`execute`d counter), the
  same interpreter binary the boards run — identical on host and ESP32.
- **Correctness gates the run.** Each task's output is checked against an
  independent reference implementation (zlib for CRC-32, a straightforward
  Python model for the rest). A benchmark binary may not quietly become a
  wrong-answer binary.
- **Inputs are seeded** (`random.Random(42)` etc.), so numbers are
  deterministic and comparable across runs and across users.
- **Code size is reported** in instructions (4 bytes each), against the
  VM's 64-instruction task cap.

## The tasks

- **crc32** — standard IEEE CRC-32, bitwise, 512 bytes. The classic
  optimizer stress.
- **rle_encode** — run-length encode 1,200 bytes with the same codec ESP
  On Demand uses for video. The mirror of the production decoder.
- **mandelbrot** — 320 pixels of the 64×64 set, Q12 fixed point, 25 max
  iterations per pixel.
- **bytebeat** — the classic `t*(42 & t>>10)` melody, 512 samples.
- **greplite** — 4-byte needle count over 400 bytes, overlaps allowed.
- **histogram** — 64-bucket byte histogram over 300 bytes; the workload
  arrays (`var h[64]`) were added to espc for.

## Why espc loses here (and when to care)

Every espc `while`/`if` compiles to a `cmp` + branch pair with join-label
traffic, and small constants rebuild through the r15 cache; a hand writer
chains compare and jump directly and hoists everything by hand. In tight
branchy loops that overhead is per-iteration, which is exactly what these
tasks measure. When the loop body is straight-line emit/discard work —
the decoder shape — the compiler's register discipline wins instead.

If instruction count on state-machine tasks matters to you, write
assembly; the VM's assembler is one command away either way. If
development speed and decoder-shaped work matter, espc compiles it for
you.

## Reading the numbers on real boards

Instruction counts transfer 1:1 to real hardware (same interpreter). For
wall-clock, run the bench jobs through the cluster's job submission and
time them — the community-standard "how fast is my ESPlab" number will be
wall-clock across boards, which this repo deliberately does not claim
from an emulator.

## License

MIT, same as ESPlab.
