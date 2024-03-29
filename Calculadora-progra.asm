;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; this maro is copied from emu8086.inc ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; this macro prints a char in AL and advances
; the current cursor position:
PUTC MACRO char
    PUSH AX
    MOV AL, char
    MOV AH, 0Eh
    INT 10h
    POP AX
ENDM    

org 100h

JMP start 

;declare variables
msg0 db "Inserte operando 1: $"
msg1 db "Inserte operando 2: $"
msg2 db "Inserte operador: $", 0Dh, 0Ah 
msg3 db "El resultado es: $"
msg4 db "Desea hacer otra operacion: Si $ o No$" 

;variable to store op1 input
number1 dw ? 
number2 dw ? 
operator db '?'
result db ?

unit db ?

;used as multiplier/divider by SCAN_NUM & PRINT_NUM_UNS.
ten DW 10
 
start:
;print message requesting op1
MOV DX, offset msg0
CALL PRINT_TEXT

;get op1 input
CALL SCAN_NUM
MOV number1, CX
       
;print new line       
PUTC 0Dh
PUTC 0Ah

;print message requesting op2
MOV DX, offset msg1
CALL PRINT_TEXT

;get op2 input
CALL SCAN_NUM
MOV number2, CX

get_operator:

;print new line       
PUTC 0Dh
PUTC 0Ah


;print message requesting operator sing
MOV DX, offset msg2
CALL PRINT_TEXT


;get operator sign 
MOV AH, 1
INT 21h 

CMP AL, '+'
JE do_sum

CMP AL, '-'
JE do_res

CMP AL, '*'
JE do_mult

CMP AL, '%'
JE do_div

JMP get_operator

do_sum:
;add number 1 and number2
MOV AX, number1
ADD AX, number2 
MOV result, AX

JMP print_result



do_res:
;substract number 2 to number 1
MOV AX, number1
SUB AX, number2 
MOV result, AX

JMP print_result 


 
do_mult:
;multiply number 1 and number 2
MOV AX, number1
MUL number2
MOV result, AX

JMP print_result 


   
do_div:
;divide number 1 for number 2
MOV DX, 0
MOV AX, number1
DIV number2
MOV result, AX

JMP print_result
 


;print the result
MOV DX, OFFSET msg3
CALL PRINT_TEXT

ret

;print message requesting make another operator
MOV DX, offset msg4
CALL PRINT_TEXT



print_result:

PUTC 0Dh
PUTC 0Ah
              
MOV DX, offset msg3
CALL PRINT_TEXT              
              
CMP result, 9
ja print_big

ADD result, 30h
mov dx, result
mov ah, 02h
int 21h

PUTC 0Dh
PUTC 0Ah
JMP start



print_big:
MOV DX, 0
MOV AX, result
IDIV ten
MOV result, AX
MOV unit, DX

ADD result, 30h
mov dx, result
CALL PRINT_NUMBER

ADD unit, 30h
mov dx, unit
CALL PRINT_NUMBER

PUTC 0Dh
PUTC 0Ah
JMP start

RET
      
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; these functions are copied from emu8086.inc ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


; gets the multi-digit SIGNED number from the keyboard,
; and stores the result in CX register:
SCAN_NUM        PROC    NEAR
        PUSH    DX
        PUSH    AX
        PUSH    SI
        
        MOV     CX, 0

        ; reset flag:
        MOV     CS:make_minus, 0

next_digit:

        ; get char from keyboard
        ; into AL:
        MOV     AH, 00h
        INT     16h
        ; and print it:
        MOV     AH, 0Eh
        INT     10h

        ; check for MINUS:
        CMP     AL, '-'
        JE      set_minus

        ; check for ENTER key:
        CMP     AL, 0Dh  ; carriage return?
        JNE     not_cr
        JMP     stop_input
not_cr:


        CMP     AL, 8                   ; 'BACKSPACE' pressed?
        JNE     backspace_checked
        MOV     DX, 0                   ; remove last digit by
        MOV     AX, CX                  ; division:
        DIV     CS:ten                  ; AX = DX:AX / 10 (DX-rem).
        MOV     CX, AX
        PUTC    ' '                     ; clear position.
        PUTC    8                       ; backspace again.
        JMP     next_digit
backspace_checked:


        ; allow only digits:
        CMP     AL, '0'
        JAE     ok_AE_0
        JMP     remove_not_digit
ok_AE_0:        
        CMP     AL, '9'
        JBE     ok_digit
remove_not_digit:       
        PUTC    8       ; backspace.
        PUTC    ' '     ; clear last entered not digit.
        PUTC    8       ; backspace again.        
        JMP     next_digit ; wait for next input.       
ok_digit:


        ; multiply CX by 10 (first time the result is zero)
        PUSH    AX
        MOV     AX, CX
        MUL     CS:ten                  ; DX:AX = AX*10
        MOV     CX, AX
        POP     AX

        ; check if the number is too big
        ; (result should be 16 bits)
        CMP     DX, 0
        JNE     too_big

        ; convert from ASCII code:
        SUB     AL, 30h

        ; add AL to CX:
        MOV     AH, 0
        MOV     DX, CX      ; backup, in case the result will be too big.
        ADD     CX, AX
        JC      too_big2    ; jump if the number is too big.

        JMP     next_digit

set_minus:
        MOV     CS:make_minus, 1
        JMP     next_digit

too_big2:
        MOV     CX, DX      ; restore the backuped value before add.
        MOV     DX, 0       ; DX was zero before backup!
too_big:
        MOV     AX, CX
        DIV     CS:ten  ; reverse last DX:AX = AX*10, make AX = DX:AX / 10
        MOV     CX, AX
        PUTC    8       ; backspace.
        PUTC    ' '     ; clear last entered digit.
        PUTC    8       ; backspace again.        
        JMP     next_digit ; wait for Enter/Backspace.
        
        
stop_input:
        ; check flag:
        CMP     CS:make_minus, 0
        JE      not_minus
        NEG     CX
not_minus:

        POP     SI
        POP     AX
        POP     DX
        RET
make_minus      DB      ?       ; used as a flag.
SCAN_NUM        ENDP        


;Custom Procs

;  this procedure print what is in register DX
PRINT_TEXT PROC NEAR
    MOV AH, 9
    INT 21h
    ret
PRINT_TEXT ENDP

PRINT_NUMBER PROC NEAR
    MOV AH, 02h
    INT 21h
    ret
PRINT_NUMBER ENDP