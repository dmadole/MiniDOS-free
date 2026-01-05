
;  Copyright 2024, David S. Madole <david@madole.net>
;
;  This program is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
;
;  This program is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License
;  along with this program.  If not, see <https://www.gnu.org/licenses/>.


#include    include/bios.inc
#include    include/kernel.inc


          ; Unpublished kernel vectors for raw disk I/O

d_idewrite: equ   044ah
d_ideread:  equ   0447h


          ; Executable header

            org   2000h-6
            dw    start                 ; load address
            dw    end-start             ; memory size
            dw    initial               ; start address

start:      br    initial

            db    1+80h                 ; month
            db    5                     ; date
            dw    2026                  ; year
            dw    2                     ; build

            db    'See github.com/dmadole/MiniDOS-free for info',0


          ; One argument is accepted which is a volume specifier. If one is
          ; not provided, we will use the one from the current directory.

initial:    ldi   rootdir.1             ; default to current drive
            phi   rf
            ldi   rootdir.0
            plo   rf

skipspc:    lda   ra                    ; skip spaces, use default if empty
            lbz   gotname
            sdi   ' '
            lbdf  skipspc

            ghi   ra                    ; save pointer to volume specifier
            phi   rf
            glo   ra
            plo   rf

            dec   rf                    ; back it up to previous character

skipvol:    lda   ra                    ; skip spaces, use default if empty
            lbz   gotname
            sdi   ' '
            lbnf  skipvol

            dec   ra                    ; zero terminate the name
            ldi   0
            str   ra
            inc   ra

skipend:    lda   ra                    ; skip any trailing spaces
            lbz   gotname
            sdi   ' '
            lbdf  skipend


          ; If more than one argument supplied, then fail with error.

dousage:    sep   scall
            dw    o_inmsg
            db    "USAGE: free [path]",13,10,0

            ldi   1                     ; return failure status
            sep   sret


          ; We got the volume specifier, use O_OPENDIR to open it as a
          ; directory to find the drive number as this allows names to be
          ; mapped. It has the side-effect of allowing a directory or file
          ; to be specified, but that's okay, the result still makes sense.

gotname:    ldi   fildes.1              ; pointer to fildes for later os
            phi   rd
            ldi   fildes.0
            plo   rd

            sep   scall                 ; open the directory
            dw    o_opendir
            lbnf  havedir

            sep   scall
            dw    o_inmsg
            db    'ERROR: unable to open directory',13,10,0

            ldi   1
            sep   sret


          ; Now that we have opened the directory, we can get the drive number
          ; from the sector loaded field of the file descriptor. Remember it
          ; into R8.1 for D_IDEREAD and display it.

havedir:    glo   rd                    ; pointer to drive of loaded sector
            adi   15
            plo   rf
            ghi   rd
            adci  0
            phi   rf

            ldn   rf                    ; get drive that directory is on
            plo   rd
            ori   %11100000
            phi   r8

            ldi   0                     ; clear high byte for f_uintout
            phi   rd

            ldi   string.1              ; pointer to disk number field
            phi   rf
            ldi   string.0
            plo   rf

            sep   scall                 ; convert disk number to decimal
            dw    f_uintout

            ldi   0                     ; terminate the string
            str   rf

            sep   scall                 ; convert disk number to decimal
            dw    o_inmsg
            db    'Disk: //',0

            ldi   string.1              ; pointer to start of string
            phi   rf
            ldi   string.0
            plo   rf

            sep   scall                 ; output the disk number message
            dw    o_msg

            sep   scall                 ; output return and newline
            dw    o_inmsg
            db    13,10,0


          ; We don't need the file descriptor any more, so close it, and 
          ; read the system sector from the specified drive.

            sep   scall                 ; close directory
            dw    o_close

            ldi   sector.1              ; get address of buffer
            phi   rf
            ldi   sector.0
            plo   rf

            ldi   0                     ; system info sector is zero
            plo   r7
            phi   r7
            plo   r8

            sep   scall                 ; read sector into buffer
            dw    d_ideread


          ; Check that this is a type-1 filesystem before proceeding.

            ldi   (sector+104h).1       ; pointer to filesystem type
            phi   rf
            ldi   (sector+104h).0
            plo   rf

            ldn   rf                    ; continue if type is 1
            smi   1
            lbz   typeone

            sep   scall                 ; else output error message
            dw    o_inmsg
            db    'ERROR: can only read LAT-16 filessytems',13,10,0

            ldi   1                     ; and return failure status
            sep   sret


          ; See if there is a volume label set, and if so, display it.

typeone:    ldi   (sector+138h).1       ; pointer to volume label
            phi   rf
            ldi   (sector+138h).0
            plo   rf

            ldn   rf                    ; if empty, don't display field
            lbz   nolabel

            sep   scall                 ; output prefixed text
            dw    o_inmsg
            db    'Name: ',0

            sep   scall                 ; output volume label
            dw    o_msg
 
            sep   scall                 ; output return and line feed
            dw    o_inmsg
            db    13,10,0

            
          ; Display the filesystem type. Since we only work with one type,
          ; this is just hard-coded for now.

nolabel:    sep   scall
            dw    o_inmsg
            db    'Type: Elf/OS, LAT-16',13,10,0


          ; Display the size of the volume in allocation units and megabytes.

            ldi   (sector+10bh).1       ; pointer to volume size in au
            phi   rf
            ldi   (sector+10bh).0
            plo   rf

            lda   rf                    ; get the volume size
            phi   ra
            phi   rd
            lda   rf
            plo   ra
            plo   rd




            sep   scall
            dw    o_inmsg
            db    'Size: ',0

            sep   scall
            dw    sizeout

            lbr   getfree


sizeout:    ghi   rd
            phi   rb
            glo   rd
            plo   rb

            ldi   string.1              ; pointer to au space field
            phi   rf
            ldi   string.0
            plo   rf

            sep   scall                 ; convert au count to decimal
            dw    f_uintout

            ldi   0                     ; zero terminate
            str   rf

            ldi   string.1              ; get pointer to au space message
            phi   rf
            ldi   string.0
            plo   rf

            sep   scall                 ; display au space message
            dw    o_msg

            sep   scall
            dw    o_inmsg
            db    ' AU, ',0

            ghi   rb
            ani   %11000000
            bnz   sizembs

            glo   rb
            shl
            plo   rd
            ghi   rb
            shlc
            phi   rd

            glo   rd
            shl
            plo   rd
            ghi   rd
            shlc
            phi   rd

            ldi   string.1              ; pointer to au space field
            phi   rf
            ldi   string.0
            plo   rf

            sep   scall                 ; convert au count to decimal
            dw    f_uintout

            ldi   0                     ; zero terminate
            str   rf

            ldi   string.1              ; get pointer to au space message
            phi   rf
            ldi   string.0
            plo   rf

            sep   scall                 ; display au stace message
            dw    o_msg

            sep   scall
            dw    o_inmsg
            db    ' KB',13,10,0

            sep   sret


sizembs:    glo   rb                    ; divide by 256 and round for mb
            adi   128
            ghi   rb
            adci  0
            plo   rd                    ; save 9-bit mb free in rb

            ldi   0
            shlc
            phi   rd

            ldi   string.1              ; pointer to mb size template
            phi   rf
            ldi   string.0
            plo   rf

            sep   scall                 ; convert to decimal string
            dw    f_uintout

            ldi   0                     ; zero terminate string
            str   rf

            ldi   string.1              ; pointer to beginning of mb free
            phi   rf
            ldi   string.0
            plo   rf

            sep   scall                 ; output mb free space string
            dw    o_msg

            sep   scall
            dw    o_inmsg
            db    ' MB',13,10,0

            sep   sret


          ; Count the number of used allocation units on the disk. This
          ; could be done with READLUMP but it would be very slow, so we
          ; will read the table on disk directly instead.

getfree:    ghi   ra                    ; start with free count set to size
            phi   rd
            glo   ra
            plo   rd

            ldi   17                    ; starting lat sector address
            plo   r7

            glo   ra                    ; move fractional lat count to rb
            plo   rb
 
            ldi   0                     ; truncate fractional lat sector
            plo   ra

            phi   r7                    ; clear high bytes of sector address
            plo   r8

            ldi   sector.0              ; only need to set the low part once
            plo   rf

            lbr   readsec               ; read the first sector to start


          ; This loop is for counting whole sectors of LAT entries. It always
          ; counts 256 entries per invocation since we set RA.0 to zero.

skipsec:    inc   rf                     ; skip lsb of entry
usedsec:    dec   rd                     ; decrement free entry count

            dec   ra                     ; decrement total, get next if zero
            glo   ra
            lbz   nextsec

loopsec:    lda   rf                     ; check if entry is non-zero
            lbnz  skipsec
            lda   rf
            lbnz  usedsec

            dec   ra                     ; decrement total, continue if more
            glo   ra
            lbnz  loopsec

nextsec:    inc   r7                     ; advance to next sector


          ; Load the next sector from the LAT table from disk into the buffer.

readsec:    ldi   sector.1               ; point to start of sector buffer
            phi   rf

            sep   scall                  ; read the sector from disk
            dw    d_ideread

            ldi   sector.1               ; point to start of buffer again
            phi   rf


         ; This has a two-part strategy for counting LAT entries. There is
         ; one loop for counting entire sectores, and another loop for any
         ; partial sector left at the end. Decide here which one.

            ghi   ra                     ; read whole page if there is one
            lbnz  loopsec

            lbr   partone                ; else read any partial sector left


          ; This counts the last partial sector if there is one. It counts
          ; the fractional part that we moved to RB.0 before the start.

skipone:    inc   rf                     ; skip lsb of lat entry
usedone:    dec   rd                     ; decrement count of free entries

            dec   rb                     ; decrement entries, end if last
            glo   rb
            lbz   doneone

loopone:    lda   rf                     ; check if entry is non-zero
            lbnz  skipone
            lda   rf
            lbnz  usedone

            dec   rb                     ; decrement entries, loop not last
partone:    glo   rb
            lbnz  loopone


          ; Display the free space in allocation units and megabytes.

doneone:    sep   scall
            dw    o_inmsg
            db    'Free: ',0

            sep   scall
            dw    sizeout

            ldi   0                     ; return with success status
            sep   sret


          ; String with root path used when no command-line argument given.

rootdir:    db    '/',0


          ; File descriptor and buffer for DTA and sector operations.

fildes:     ds    4                     ; file offset
            dw    sector                ; pointer to dta
            ds    1                     ; flags byte
            ds    4                     ; date and time
            ds    1                     ; aux flags
            ds    20                    ; file name

sector:     ds    512                   ; sector buffer

string:     ds    10

end:        end   start
