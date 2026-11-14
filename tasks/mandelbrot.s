# mandelbrot.s — fixed-point Mandelbrot membership test for this chunk's
# slice of a 64x64 grid, Q12, byte per pixel = iterations to escape
# (0 when in the set).  Companion to tasks/mandelbrot.epl.
# regs: r0=p r1=x r2=y r3=it r4=cx r5=cy r6=x2 r7=y2 r8/r9=temps
#       r10=4096 r11=2048 r12=25 r13=64 r14=192 r15=16384

  loadi r10, 4096
  loadi r11, 2048
  loadi r12, 25
  loadi r13, 64
  loadi r14, 192
  loadi r15, 16384
  lds   r0, 0              # p = lo

outer:
  lds   r8, 1              # hi
  cmp   r9, r0, r8         # p < hi?
  jz    r9, done           # r9==0 -> p >= hi
  mod   r8, r0, r13        # col = p % 64
  mul   r8, r8, r14        # col * 192
  loadi r9, 6144
  sub   r4, r8, r9         # cx = col*192 - 6144
  div   r8, r0, r13        # row = p / 64
  mul   r8, r8, r14        # row * 192
  loadi r9, 4608
  sub   r5, r8, r9         # cy = row*192 - 4608
  loadi r1, 0              # x = 0
  loadi r2, 0              # y = 0
  loadi r3, 0              # it = 0

inner:
  mul   r6, r1, r1
  div   r6, r6, r10        # x2 = x*x/4096
  mul   r7, r2, r2
  div   r7, r7, r10        # y2 = y*y/4096
  add   r8, r6, r7        # mag
  cmp   r9, r8, r15       # mag vs 16384: -1 <, 0 ==, +1 >
  addi  r9, r9, -1        # 0 only when mag > 16384
  jz    r9, escaped       # -> escape path
  mul   r9, r1, r2
  div   r9, r9, r11       # xy = x*y/2048
  sub   r8, r6, r7
  add   r8, r8, r4        # xn = x2 - y2 + cx
  add   r9, r9, r5        # yn = xy + cy
  mov   r1, r8
  mov   r2, r9
  addi  r3, r3, 1         # it++
  cmp   r8, r3, r12       # it < 25? (only -1 here)
  jnz   r8, inner
  jmp   emit_path         # it == 25: in the set

escaped:
  addi  r3, r3, 26        # it += 26 (mark escape)

emit_path:
  cmp   r8, r3, r12       # it vs 25
  jz    r8, in_set        # == 25 -> in set, emit 25-it = 0
  addi  r3, r3, -26       # escaped: it - 26
  jmp   do_emit
in_set:
  sub   r3, r12, r3       # 25 - it (== 0)

do_emit:
  emit  r3
  addi  r0, r0, 1         # p++
  jmp   outer

done:
  halt
