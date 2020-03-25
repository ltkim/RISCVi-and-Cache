factorial.S:
.align 4
.section .text
.globl _start

_start:
  # initialize registers
loop:
  la x1, argument
  #sh x2, 0(x3)
  #sh x2, 1(x3)
  #sh x2, 2(x3)
  #sh x2, 3(x3)

  lw x2, 0(x1)
  lw x2, 4(x1)
  lw x2, 8(x1)

  lw x2, 256(x1)
  lw x2, 260(x1)
  lw x2, 264(x1)

  lw x2, 512(x1)
  lw x2, 548(x1)
  lw x2, 520(x1)

halt:
  beq x2, x2, halt

argument:
  .asciz "ABCDEFGHIJKLMNOPQRSTUVWXYZ123jsoijfoijfojadndakfhfueowhe978w78wfhw98yhfukasuhflkkjdknhfuewuhfuehtusffnkalilhuiaeuhuwaefuiwailawgelaygABCDEFGHIJKLMNOPQRSTUVWXYZ123jsoijfoijfojadndakfhfueowhe978w78wfhw98yhfukasuhflkkjdknhfuewuhfuehtusffnkalilhuiaeuhuwaefuiwailawgelaygABCDEFGHIJKLMNOPQRSTUVWXYZ123jsoijfoijfojadndakfhfueowhe978w78wfhw98yhfukasuhflkkjdknhfuewuhfuehtusffnkalilhuiaeuhuwaefuiwailawgelaygijfoijfojadndakfhfueowhe978w78wfhw98yhfukasuhflkkjdknhfuewuhfuehtusffnkalilhuiaeuhuwaefuiwailawgelaygijfoijfojadndakfhfueowhe978w78wfhw98yhfukasuhflkkjdknhfuewuhfuehtusffnkalilhuiaeuhuwaefuiwaillkkjdknhfuewuhfuehtusffnkalilhuiaeuhuwaefuiwailawgelaygABCDEFGHIJKLMNOPawgelayg"





.section .rodata
argument0:        .word  0x12345678
argument00:        .word  0x12345678
argument01:        .word  0x12345678
argument02:        .word  0x12345678
argument03:        .word  0x12345678
argument04:        .word  0x12345678
argument05:        .word  0x12345678
argument06:        .word  0x12345678
argument07:        .word  0x12345678
argument08:        .word  0x12345678
argument09:        .word  0x12345678
argument1:        .word  0x87654321
argument2:        .word  0x02040608
argument3:        .word  0x10245674
argument4:        .word  0x12d43a78
argument5:        .word  0xaa3cc56e
loop1_check:      .word 0x00000000
loop2_check:      .word 0x00000001
