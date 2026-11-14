# bytebeat.s — formula music, the classic t*(42 & t>>10) melody.
# One output byte per t in this chunk's slice [lo, hi).
# regs: r0=t r1=tmp r2=42 r3=255 r4=10 r5=hi

  loadi r2, 42
  loadi r3, 255
  loadi r4, 10
  lds   r0, 0              # t = lo
  lds   r5, 1              # hi (invariant)
loop:
  cmp   r1, r0, r5
  jz    r1, done
  shr   r1, r0, r4         # t >> 10 (arith; t >= 0 makes it logical)
  and   r1, r1, r2         # & 42
  mul   r1, r0, r1         # t * (…)
  and   r1, r1, r3         # & 255
  emit  r1
  addi  r0, r0, 1
  jmp   loop
done:
  halt
