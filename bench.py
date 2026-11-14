#!/usr/bin/env python3
"""ESPlab-Bench — espc vs hand assembly, measured on the real VM.

Each task in tasks/ exists twice: once in espc (*.epl), once in hand
assembly (*.s) — same algorithm, same input, same slice.  This runner

  1. compiles the .epl, assembles the .s
  2. runs BOTH on the ESPlab VM (the same interpreter that ships on
     the boards) via espc_vmtest
  3. checks the output byte-exact against an independent Python
     reference (a wrong answer fails the run — a benchmark binary may
     not quietly become a wrong-answer binary)
  4. counts executed instructions (deterministic: identical on
     emulator and real chips) and code size

Numbers are facts, not contracts: CI enforces correctness only.
Speed findings are recorded, whatever direction they point.
"""
import json
import os
import random
import subprocess
import sys
import tempfile
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))


# ---------------- locate the ESPlab checkout ----------------
def find_esplab():
    cand = []
    if os.environ.get("ESPLAB_DIR"):
        cand.append(os.environ["ESPLAB_DIR"])
    cand += [os.path.join(HERE, "esplab"),
             os.path.join(HERE, "..", "ESPlab"),
             os.path.join(HERE, "..", "esp32-cluster")]
    for c in cand:
        if all(os.path.exists(os.path.join(c, p)) for p in
               ("tools/espc.py", "build/vbasm", "build/espc_vmtest")):
            return os.path.abspath(c)
    sys.stderr.write(
        "ESPlab checkout not found (needs tools/espc.py, build/vbasm,\n"
        "build/espc_vmtest). Set ESPLAB_DIR or run its `make` first.\n"
        f"Tried: {cand}\n")
    sys.exit(1)


ESPLAB = find_esplab()
sys.path.insert(0, os.path.join(ESPLAB, "tools"))
import espc  # noqa: E402

VASM = os.path.join(ESPLAB, "build", "vbasm")
VMT = os.path.join(ESPLAB, "build", "espc_vmtest")


def run_on_vm(binary, data, lo, hi):
    """Run one task image; return (out_bytes, executed)."""
    with tempfile.NamedTemporaryFile(suffix=".bin", delete=False) as tf:
        tf.write(binary)
        bp = tf.name
    ip = bp + ".in"
    with open(ip, "wb") as f:
        f.write(data)
    try:
        r = subprocess.run([VMT, bp, ip, str(lo), str(hi)],
                           capture_output=True, text=True, timeout=120)
        if r.returncode != 0 or not r.stdout.startswith("status="):
            raise RuntimeError(f"espc_vmtest failed: {r.returncode} "
                               f"{r.stderr.strip()} {r.stdout.strip()}")
        head, outhex = r.stdout.strip().split("out=")
        status = int(head.split("status=")[1].split()[0])
        executed = int(head.split("executed=")[1].split()[0])
        if status != 0:
            raise RuntimeError(f"VM fault status={status} for task")
        return bytes.fromhex(outhex), executed
    finally:
        os.unlink(bp)
        os.unlink(ip)


def compile_epl(path):
    blob, _ = espc.compile_src(open(path).read())
    return blob


def assemble_s(path):
    with tempfile.NamedTemporaryFile(suffix=".bin", delete=False) as tf:
        out = tf.name
    try:
        r = subprocess.run([VASM, path, "-o", out],
                           capture_output=True, text=True)
        if r.returncode != 0:
            raise RuntimeError(f"vbasm failed on {path}: {r.stderr.strip()}")
        with open(out, "rb") as f:
            return f.read()
    finally:
        os.unlink(out)


# ---------------- task inputs + independent references ----------------
def gen_crc32():
    rng = random.Random(42)
    return bytes(rng.randrange(256) for _ in range(512))


def ref_crc32(data, lo, hi):
    return zlib.crc32(data[lo:hi]).to_bytes(4, "big")


def gen_rle():
    rng = random.Random(42)
    runs, total = [], 0
    while total < 1200:
        v, L = rng.randrange(32), rng.randint(1, 40)
        runs.append(bytes([v] * L))
        total += L
    return b"".join(runs)


def ref_rle(data, lo, hi):
    out, i = bytearray(), lo
    d = data
    while i < hi:
        v, run = d[i], 1
        i += 1
        while i < hi and d[i] == v and run < 128:
            run += 1
            i += 1
        out += bytes([(run - 1) << 1, v])
    return bytes(out)


def gen_greplite():
    rng = random.Random(7)
    data = bytearray(rng.randrange(256) for _ in range(400))
    needle = bytes([171, 172, 173, 174])
    for _ in range(6):
        i = rng.randrange(len(data) - 8)
        data[i:i + 4] = needle
    data[100:108] = needle + needle   # one overlapping pair
    return bytes(data)


def ref_greplite(data, lo, hi):
    needle, count, s = bytes([171, 172, 173, 174]), 0, lo
    while s + 4 <= hi:
        if data[s:s + 4] == needle:
            count += 1
            s += 3
        s += 1
    return bytes([count & 0xFF])


def gen_histogram():
    rng = random.Random(3)
    return bytes(rng.randrange(256) for _ in range(300))


def ref_histogram(data, lo, hi):
    buckets = [0] * 64
    for b in data[lo:hi]:
        buckets[b % 64] += 1
    return bytes(v & 0xFF for v in buckets)


def ref_mandelbrot(data, lo, hi):
    out = bytearray()
    for p in range(lo, hi):
        cx = (p % 64) * 192 - 6144
        cy = (p // 64) * 192 - 4608
        x, y, it = 0, 0, 0
        while it < 25:
            x2 = x * x // 4096
            y2 = y * y // 4096
            if x2 + y2 > 16384:
                it += 26
            else:
                xy = x * y // 2048
                x = x2 - y2 + cx
                y = xy + cy
                it += 1
        it = it - 26 if it > 25 else 25 - it
        out.append(it)
    return bytes(out)


def ref_bytebeat(data, lo, hi):
    out = bytearray()
    for t in range(lo, hi):
        out.append((t * (42 & (t >> 10))) & 0xFF)
    return bytes(out)


# name -> (lo, hi, generator, reference, what it stresses)
TASKS = {
    "crc32":       (0, 512,  gen_crc32, ref_crc32,
                    "xor/shift inner loop, branchy"),
    "rle_encode":  (0, 1200, gen_rle, ref_rle,
                    "run scan with early exit (video codec mirror)"),
    "mandelbrot":  (640, 960, lambda: b"", ref_mandelbrot,
                    "nested escape loops, fixed-point multiply"),
    "bytebeat":    (8000, 8512, lambda: b"", ref_bytebeat,
                    "straight-line integer formula per sample"),
    "greplite":    (0, 400, gen_greplite, ref_greplite,
                    "pattern scan with state"),
    "histogram":   (0, 300, gen_histogram, ref_histogram,
                    "table-driven counting (arrays)"),
}


def main():
    build = os.path.join(HERE, "build")
    os.makedirs(build, exist_ok=True)
    rows, fails = [], 0

    for name, (lo, hi, gen, ref, note) in TASKS.items():
        data = gen()
        want = ref(data, lo, hi)

        epl_bin = compile_epl(os.path.join(HERE, "tasks", name + ".epl"))
        asm_bin = assemble_s(os.path.join(HERE, "tasks", name + ".s"))
        epl_out, epl_exec = run_on_vm(epl_bin, data, lo, hi)
        asm_out, asm_exec = run_on_vm(asm_bin, data, lo, hi)

        good = True
        if epl_out != want:
            fails += 1
            print(f"FAIL {name}: espc output != reference")
            good = False
        if asm_out != want:
            fails += 1
            print(f"FAIL {name}: asm output != reference")
            good = False
        if good and epl_out != asm_out:
            fails += 1
            print(f"FAIL {name}: espc and asm outputs differ")
            good = False
        if good:
            epl_n, asm_n = len(epl_bin) // 4, len(asm_bin) // 4
            rows.append(dict(task=name, stress=note,
                             espc_insns=epl_exec, asm_insns=asm_exec,
                             espc_code=epl_n, asm_code=asm_n))
            print(f"ok   {name:11s} espc {epl_exec:6d}  asm {asm_exec:6d}"
                  f"   code {epl_n:2d} vs {asm_n:2d} insns")

    if fails:
        print(f"\n{fails} correctness failure(s) — benchmark NOT recorded")
        return 1

    # scorecard
    print("\n| task | stress | espc insns | asm insns | asm advantage |"
          " espc code | asm code |")
    print("|---|---|---|---|---|---|---|")
    for r in rows:
        adv = (1 - r["asm_insns"] / r["espc_insns"]) * 100
        print(f"| {r['task']} | {r['stress']} | {r['espc_insns']} |"
              f" {r['asm_insns']} | {adv:.0f}% fewer |"
              f" {r['espc_code']} | {r['asm_code']} |")

    tot_e = sum(r["espc_insns"] for r in rows)
    tot_a = sum(r["asm_insns"] for r in rows)
    print(f"\ntotal: espc {tot_e} vs asm {tot_a} executed instructions "
          f"(asm {100 * (1 - tot_a / tot_e):.0f}% fewer overall)")

    with open(os.path.join(build, "results.json"), "w") as f:
        json.dump(dict(tasks=rows, totals=dict(espc=tot_e, asm=tot_a)), f, indent=2)
    print(f"\nwrote build/results.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
