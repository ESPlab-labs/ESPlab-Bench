# crc32.s — standard CRC-32 (IEEE reflected, poly 0xEDB88320) over this
# chunk's input slice, bitwise (no table).  Emits 4 digest bytes
# big-endian.  Hand-tuned companion to tasks/crc32.epl.
# regs: r0=crc r1=i r2=k r3=byte r4,r5=temps r6=poly r7=all-ones
#       r8=24 r9=16 r10=8 r11=1 r12=255 r13=hi r14=16(shl amount)

  loadi r11, 1             # ONE
  loadi r14, 16            # shift-16 amount

  loadi r6, 0xEDB8         # poly high half
  shl   r6, r6, r14        # << 16
  loadi r7, 0x8320         # poly low half (r7 free until all-ones)
  or    r6, r6, r7         # r6 = 0xEDB88320

  loadi r7, 0xFFFF         # all-ones low
  loadi r8, 0xFFFF         # scratch for high half
  shl   r8, r8, r14        # << 16
  or    r7, r7, r8         # r7 = 0xFFFFFFFF

  loadi r12, 255
  loadi r8, 24
  loadi r9, 16
  loadi r10, 8

  mov   r0, r7             # crc = 0xFFFFFFFF
  lds   r1, 0              # i = lo
  lds   r13, 1             # hi (loop-invariant: hoisted)

loop_i:
  cmp   r4, r1, r13        # r4 = (i < hi) ? -1 : (i > hi ? 1 : 0)
  jz    r4, done           # i >= hi when r4 == 0
  ldv   r3, r1             # byte = input[i]
  xor   r0, r0, r3         # crc ^= byte
  loadi r2, 0              # k = 0
loop_k:
  and   r4, r0, r11        # r4 = crc & 1
  shru  r5, r0, r11        # r5 = crc >>> 1
  jz    r4, even           # bit clear: r5 already right
  xor   r5, r5, r6         # bit set: r5 ^= poly
even:
  mov   r0, r5             # crc = r5
  addi  r2, r2, 1          # k++
  cmp   r4, r2, r10
  jnz   r4, loop_k         # k < 8 (r4 == -1) -> next round
  addi  r1, r1, 1          # i++
  jmp   loop_i

done:
  xor   r0, r0, r7         # crc ^= 0xFFFFFFFF
  shru  r4, r0, r8         # >> 24
  and   r4, r4, r12
  emit  r4
  shru  r4, r0, r9         # >> 16
  and   r4, r4, r12
  emit  r4
  shru  r4, r0, r10        # >> 8
  and   r4, r4, r12
  emit  r4
  and   r4, r0, r12        # & 255
  emit  r4
  halt
