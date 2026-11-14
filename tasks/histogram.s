# histogram.s — byte histogram of this chunk's slice, 64 buckets
# (value mod 64), companion to histogram.epl.  Emits 64 bytes.
# The array workload: both versions use LDX/STX scratch words.
# regs: r0=i r1=v r2=tmp r3=hi r4=1 r6=64 r7=255 r8=b

  lds   r0, 0              # i = lo
  lds   r3, 1              # hi
  loadi r4, 1
  loadi r6, 64
  loadi r7, 255

scan:
  cmp   r2, r0, r3
  jz    r2, report
  ldv   r1, r0             # v = input[i]
  mod   r1, r1, r6         # v % 64
  ldx   r2, r1, 0          # r2 = h[v]
  add   r2, r2, r4
  stx   r2, r1, 0          # h[v]++
  addi  r0, r0, 1
  jmp   scan

report:
  loadi r8, 0              # b = 0
emit_b:
  ldx   r2, r8, 0
  and   r2, r2, r7
  emit  r2
  addi  r8, r8, 1          # b++
  cmp   r2, r8, r6         # b == 64?
  jz    r2, done
  jmp   emit_b

done:
  halt
