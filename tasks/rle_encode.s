# rle_encode.s — run-length encode this chunk's input slice, same codec
# as rle_encode.epl (and the inverse of the cluster's video decoder).
# Emits (count, value) pairs: run = (count >> 1) + 1, max run 128.
# regs: r0=i r1=v r2=run r3..r5=temps r6=128 r7=256  r14=255-mask? none needed
#       r13=hi r12=2 (run-1)*2 needs shl by 1: use r8=1, shl r5, r5, r8

  loadi r6, 128            # run cap
  loadi r8, 1              # ONE (shl amount / &1)
  loadi r9, 2              # <<1 count encoding uses *2 = shl 1
  lds   r0, 0              # i = lo
  lds   r13, 1             # hi (invariant)

outer:
  cmp   r4, r0, r13        # i < hi? r4=-1 while more
  jz    r4, done
  ldv   r1, r0             # v = input[i]
  loadi r2, 1              # run = 1
  addi  r0, r0, 1          # i++
scan:
  cmp   r4, r0, r13        # i < hi?
  jz    r4, flush          # no more input: flush this run
  ldv   r3, r0             # r3 = input[i]
  cmp   r4, r3, r1         # input[i] == v?
  jnz   r4, flush          # r4 != 0 means != (cmp yields -1 when <)
  cmp   r4, r2, r6         # run < 128?
  jz    r4, flush          # run hit the cap: flush
  addi  r2, r2, 1          # run++
  addi  r0, r0, 1          # i++
  jmp   scan

flush:
  sub   r5, r2, r8         # r5 = run - 1
  shl   r5, r5, r8         # r5 = (run-1) << 1
  emit  r5
  emit  r1
  jmp   outer

done:
  halt
