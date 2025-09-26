/* Simple linker script for flat binary */
OUTPUT_ARCH( "riscv" )
ENTRY( _start )

SECTIONS
{
  . = 0x00000000;
  .text : { *(.text) }
  . = ALIGN(4);
  .data : { *(.data) }
  .bss : { *(.bss) }
}
