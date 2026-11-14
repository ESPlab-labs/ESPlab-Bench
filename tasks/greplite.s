# greplite.s — pattern-4 scan with state: count occurrences of needle
# AB AC AD AE in this chunk's slice, emit the count byte.
# Exact match semantics, overlaps allowed (skip 3 on hit).
# regs: r0=s r1=count r2..: temps r6..r9 = pattern bytes r10=hi r11=4

  loadi r6, 171
  loadi r7, 172
  loadi r8, 173
  loadi r9, 174
  loadi r11, 4
  lds   r0, 0              # s = lo
  lds   r10, 1             # hi
  loadi r1, 0              # count = 0
outer:
  add   r2, r0, r11        # r2 = s + 4
  cmp   r3, r2, r10        # (s+4 vs hi): -1 <, 0 ==, +1 >
  addi  r3, r3, -1         # 0 only when s+4 > hi
  jz    r3, done
  ldv   r2, r0             # input[s]
  cmp   r3, r2, r6
  jnz   r3, next           # != pattern byte: skip (cmp != 0 covers < and >)
  addi  r4, r0, 1          # s+1
  ldv   r2, r4
  cmp   r3, r2, r7
  jnz   r3, next
  addi  r4, r0, 2
  ldv   r2, r4
  cmp   r3, r2, r8
  jnz   r3, next
  addi  r4, r0, 3
  ldv   r2, r4
  cmp   r3, r2, r9
  jnz   r3, next
  addi  r1, r1, 1          # count++
  addi  r0, r0, 3          # s += 3 (the 4th byte pair consumed by outer ++)
next:
  addi  r0, r0, 1
  jmp   outer
done:
  emit  r1
  halt
