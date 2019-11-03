	.data			; switch to data segment
	.origin	0x0000
	.word	221
        .word   180
        .word   41

        .text

	l16	$r0, 0x0000   ; This is an address that points to 221
	l16	$r1, 0x0003
	llo	$r2, 0x02
        llo     $r3, 0x00

        l16	$r5, 0x0025   ; 37
        llo     $r7, 0x01     ; Points to 180


        ; r8-11 Shouldnt change until branches
        l16     $r8,  -0x0013   ; 19
        l16     $r9,  0x0002
        l16     $r10, 0x0002   ; Points to 41
        l16     $r11, error


main:   
        add     $r1, $r2     ; r1 should have 3 at the start
        xor     $r1, 5       ; Turns the 5 in r1 into 0
        jnz     $r1, $r11    ; r11 should contain the address of error

	add	$r2, 6       ; r2 should have 2 at the start
        sub     $r2, 5
        llo     $r1, 0x03
        xor     $r2, $r1     ; Turns the 3 in r2 into 0
        jnz     $r2, $r11    ; r11 should contain the address of 'error'

        llo     $r1, 41      ; verify memory
        xor     $r1, @$r10   ; @$r10 contains 41
        jnz     $r1, $r11

	add	$r3, @$r0    ; @$r0 contains 221, r3 contains 0
	sub	$r3, @$r7    ; @$r7 contains 180
        xor     $r3, @$r10   ; @$r10 contains 41
        jnz     $r3, $r11


        or      $r0, $r5     ; r5 should = 37 at the start, r1 = 0
        xor     $r0, $r5
        jnz     $r0, $r11

	or	$r2, 3       ; r2 should still = 0
        jz      $r2, $r11


        and     $r6, $r5     ; r5 = 37, r6 = 24
        jnz     $r6, $r11

	and     $r5, 4
        jz      $r5, $r11    ; r5 = 4


        l16     $r1, 0x8001   ; 1000 0000 0000 0001
        rol	$r1, 2        ; 0000 0000 0000 0110
        xor     $r1, 6
        jnz     $r1, $r11

        l16     $r1, 0x2800   ; 0010 1000 0000 0000
        l16     $r2, 0x0005
	rol	$r1, $r2      ; r1 rotated by 5 = 5 (0101)
        xor     $r1, $r2
        jnz     $r1, $r11

        l16     $r3, 0xC841   ; 1100 1000 0100 0001
        l16     $r4, 0x0642   ; 0000 0110 0100 0010   just r3 >> 5

        shr     $r3, $r2      ; r2 = 5
        xor     $r3, $r4
        jnz     $r3, $r11

        l16     $r5, 0x00C8   ; 0000 0000 1100 1000   just r4 >> 3
        shr     $r4, 3
        xor     $r4, $r5
        jnz     $r4, $r11

        dup     $r4, $r5
        xor     $r4, $r5
        jnz     $r4, $r11

        dup     $r4, 5
        xor     $r4, 5
        jnz     $r4, $r11

        l16     $r1, 0x0000
        l16     $r2, 0x8416
        lhi     $r1, 0x84
        xlo     $r1, 0x16
        xor     $r1, $r2     ; r1 = r2
        jnz     $r1, $r11

	l16     $r1, 99
	l16     $r2, 41
	l16     $r3, 2 ; pointer to 41
	ex      $r1, @$r3
	xor     $r1, $r2
	jnz     $r1, $r11
	l16     $r1, 99
	xor     $r1, @$r3
	jnz     $r1, $r11

        


        bn	$r8,  2      ; r8  should be negative, branch should skip to
        fail    0            ; bnn
        

	bnn     $r9,  2      ; r9  should be positive, branch should skip to       
        fail    0            ; bnz

	bnz     $r10, 2      ; r10 should be positive, branch should skip to 
        fail    0            ; bz

	bz 	$r0, 3      ; r0 should be zero, branch should skip to com
        fail    0
    

error:  fail    0            ; If you get here, it means something went wrong

        com                  ; Only get here by the bz right above this label
                             ; If you get here, everything worked
        land
        jerr    $r1, 0       ; These are NOPs
        sys
