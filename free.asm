; *******************************************************************
; *** This software is copyright 2004 by Michael H Riley          ***
; *** You have permission to use, modify, copy, and distribute    ***
; *** this software so long as this copyright notice is retained. ***
; *** This software may not be used in commercial applications    ***
; *** without express written permission from the author.         ***
; *******************************************************************

include    bios.inc
include    kernel.inc

           org     8000h
           lbr     0ff00h
           db      'free',0
           dw      9000h
           dw      endrom+7000h
           dw      2000h
           dw      endrom-2000h
           dw      2000h
           db      0

buffer:    equ     2100h

           org     02000h
           br      mainlp

include    date.inc
include    build.inc
           db      'Written by Michael H. Riley',0

mainlp:    ldi     high buffer         ; get address of prompt
           phi     rf
           ldi     low buffer
           plo     rf
           ldi     0e0h
           phi     r8
           ldi     0                   ; need to read sector 0
           plo     r8
           phi     r7
           plo     r7
           sep     scall               ; call bios to read sector
           dw      f_ideread
           ldi     high numaus         ; get message
           phi     rf
           ldi     low numaus
           plo     rf
           sep     scall               ; display it
           dw      o_msg
           ldi     low buffer          ; point to read total aus
           adi     11
           plo     r9
           ldi     high buffer
           adci    1
           phi     r9
           lda     r9                  ; get total aus
           phi     rd
           lda     r9
           plo     rd
           ldi     high cbuffer        ; point to cbuffer
           phi     rf
           ldi     low cbuffer
           plo     rf
           sep     scall               ; convert number to ascii
           dw      f_uintout
           ldi     0                   ; place a terminator
           str     rf
           ldi     high cbuffer        ; point to cbuffer
           phi     rf
           ldi     low cbuffer
           plo     rf
           sep     scall               ; display number
           dw      o_msg
           sep     scall               ; do a cr/lf
           dw      docrlf
           ldi     high freeaus        ; get message
           phi     rf
           ldi     low freeaus
           plo     rf
           sep     scall               ; display it
           dw      o_msg

           ldi     low buffer          ; point to directory sector
           adi     5
           plo     r9
           ldi     high buffer
           adci    1
           phi     r9
           lda     r9                  ; get directory sector
           phi     ra
           lda     r9
           plo     ra
           ldi     0                   ; setup count
           phi     rd
           plo     rd
           ldi     0e0h                ; setup directory
           phi     r8
           ldi     0
           plo     r7
           phi     r7
           ldi     17
           plo     r7
secloop:   ldi     high buffer         ; point to buffer
           phi     rf
           ldi     low buffer
           plo     rf
           sep     scall               ; read the sector
           dw      f_ideread
           ldi     high buffer         ; point to buffer
           phi     rf
           ldi     low buffer
           plo     rf
           ldi     1                   ; 256 entries to check
           phi     rb
           ldi     0
           plo     rb
entloop:   lda     rf                  ; get byte from table
           bnz     used                ; jump if it is used
           ldn     rf                  ; next byte
           bnz     used
           inc     rd
used:      dec     rb                  ; decrement entry count
           inc     rf                  ; move to next entry
           glo     rb                  ; check if done with sector
           bnz     entloop             ; jump if more to go
           ghi     rb                  ; check high byte as well
           bnz     entloop
           inc     r7                  ; increment sector
           glo     ra                  ; compare to dir sector
           str     r2
           glo     r7
           sm
           bnz     secloop             ; jump if more sectors to count
           ghi     ra
           str     r2
           ghi     r7
           sm
           bnz     secloop
           ldi     high cbuffer        ; point to cbuffer
           phi     rf
           ldi     low cbuffer
           plo     rf
           sep     scall               ; convert number to ascii
           dw      f_uintout
           ldi     0                   ; place a terminator
           str     rf
           ldi     high cbuffer        ; point to cbuffer
           phi     rf
           ldi     low cbuffer
           plo     rf
           sep     scall               ; display number
           dw      o_msg
           sep     scall               ; do a cr/lf
           dw      docrlf


           sep     sret                ; return to os

docrlf:    ldi     high crlf
           phi     rf
           ldi     low crlf
           plo     rf
           sep     scall
           dw      o_msg
           sep     sret

numaus:    db      'Total AUs: ',0
freeaus:   db      'Free AUs : ',0
prompt:    db      '>',0
crlf:      db      10,13,0

endrom:    equ     $

cbuffer:   ds      40

