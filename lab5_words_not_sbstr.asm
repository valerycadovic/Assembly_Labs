.model small
.stack 100h
.data
    crlf db 0Dh, 0Ah, '$'
    word db 10, 0, 15 dup('$'), '$'
    buf db 2, 0, 2 dup('$'), '$'
    msg_prompt_to_input db 'Enter the word to search', 0Dh, 0Ah, '$'
    msg_result db 0Dh, 0Ah, 'Count of strings: $'
    msg_bad db 0Dh, 0Ah, 'overflow$'
    msg_bad_args db 'command line parse error', 0Dh, 0Ah, '$'
    msg_empty_args db 'no command line args', 0Dh, 0Ah, '$'
    msg_error db 0Dh, 0Ah, 'error', 0Dh, 0Ah, '$'
    word_capacity equ 50
    word_buffer db word_capacity + 2 dup(0)
    cmd_capacity equ 127
    cmd_length db ?
    cmd_text db cmd_capacity dup('$')
    file_path db cmd_capacity dup('$') 
    is_previous_delimeter db 1  
    is_found db 0
    
.code

;-----macros--------------------

is_empty macro str, is_0
    push si
    lea si, str
    call strlen
    pop si
    
    cmp ax, 0
    je is_0
endm

puts macro str
    push ax
    push dx
    lea dx, str
    mov ah, 9
    int 21h
    pop dx
    pop ax    
endm

gets macro str
    push bx
    push cx
    push dx

again:                      ; check empty word input
    mov ah, 0Ah
    lea dx, str
    int 21h
    
    xor ax, ax
    xor cx, cx
    
    mov cl, [word + 1]
    cmp cl, 0
    je again
    
    pop dx
    pop cx
    pop bx
endm

puti macro
    local put1
    local put2
    local ex
    
    push ax
    push cx
    push -1
    mov cx, 10
    mov dx, 0
put1:
    xor dx, dx
    mov ah, 0
    div cl          ; al - result, ah - reminder
    mov dl, ah
    push dx
    cmp al, 0
    jne put1
    
    mov ah, 2
    
put2:
    pop dx
    cmp dx, -1
    je ex
    add dl, '0'
    int 21h
    jmp put2
ex:
    mov dl, ' '
    int 21h
    pop cx
    pop ax
endm

fopen macro
    lea dx, file_path
    mov ah, 3Dh
    mov al, 00h
    int 21h
    jc exit
    
    mov bx, ax
endm

fclose macro
    mov ah, 3Eh
    int 21h
endm

fread macro
    local continue
    push ax
    push cx
    push dx
    
    mov cx, 1
    lea dx, buf
    
    mov ah, 3Fh
    int 21h
    jc exit
    
    puts [buf]
    
    mov cx, ax
    test cx, cx
    jnz continue
    fclose
    
    jmp good_exit
    
continue:
    pop dx
    pop cx
    pop ax
endm

;------procedures---------------

parse_cmd_text proc
    push bx
    push cx
    push dx
    
    mov cl, cmd_length
    xor ch, ch
    
    lea si, cmd_text
    lea di, file_path
    call to_asciiz
    
    is_empty file_path, bad_cmd_args
    
    lea di, word_buffer
    call to_asciiz
    
    is_empty word_buffer, good_cmd_args
    
bad_cmd_args:
    puts msg_bad_args
    mov ax, 1
    jmp end_parse_cmd_text
    
empty_cmd_args:
    puts msg_empty_args
    mov ax, 1
    jmp end_parse_cmd_text
    
good_cmd_args:
    mov ax, 0
    
end_parse_cmd_text:
    pop bx
    pop cx
    pop bx
    ret    
parse_cmd_text endp
  
  
to_asciiz proc
    push ax
    push cx
    push di
    
    ;---------------------;
    
    parse_to_asciiz:
        mov al, ds:[si]
        cmp al, ' '
        je is_delimeter
        cmp al, 0Dh     
        je is_delimeter
        cmp al, 09h
        je is_delimeter
        cmp al, 0Ah
        je is_delimeter
        cmp al, 00h
        je is_delimeter
        cmp al, '$'
        je is_delimeter
        
        mov es:[di], al
        inc di
        inc si
    loop parse_to_asciiz
    
is_delimeter:
    mov al, 00h
    mov es:[di], al
    mov al, '$'
    inc di
    mov es:[di], al
    inc si
    
    ;---------------------;
    
    pop di
    pop cx
    pop ax 
    ret
to_asciiz endp 

strlen proc
    push bx
    push si
    
    xor ax, ax
start_strlen:
    mov bl, ds:[si]
    cmp bl, 00h
    je end_strlen
    inc si
    inc ax
    jmp start_strlen
end_strlen:
    pop si
    pop bx
    ret
strlen endp

;------main---------------------

proc count
    xor dx, dx  
    mov is_previous_delimeter, 1
    whil:
        fread
        mov al, [word+2]
        mov cl, [buf]
        cmp cl, 13
        jne no_end
        mov is_previous_delimeter, 1
        mov is_found, 0
        no_end:
        mov ch, is_previous_delimeter
        test ch, ch
        jz whil
        is_delim skp nxt
        skp:
        mov is_previous_delimeter, 1
        jmp whil
        nxt:
        mov is_previous_delimeter, 0  
        cmp al, cl
        jne skip_to_delim
        compare:
            lea si, word+2
            mov al, [si]
            mov ah, 1
            cyc:
                inc ah
                inc si
                mov al, [si]
                mov cl, [word+1]
                cmp ah, cl
                jg succ
                fread
                mov cl, [buf]
                cmp al, cl
                mov is_previous_delimeter, 0
                jne skip_to_delim
                je cyc
        
    jmp whil
    
succ:        
    fread
    mov cl, [buf]
    is_delim word_found skip_to_delim
    word_found:
    inc dx
    mov is_found, 1

skip_to_crlf:
    fread    
    mov cl, [buf]
    cmp cl, 13
    jne skip_to_crlf
    mov is_previous_delimeter, 1
    jmp whil

skip_to_delim:
    fread
    mov cl, [buf]
    is_delim sk, skip_to_delim
    sk:
    mov is_previous_delimeter, 1
    jmp whil    
    
    ret
endp count

is_delim macro true_delim false_delim
        cmp cl, ' '
        je true_delim
        cmp cl, 0Dh
        je true_delim
        cmp cl, 09h
        je true_delim
        cmp cl, 0Ah
        je true_delim
        cmp cl, 00h
        je true_delim
        cmp cl, '$'
        je true_delim    
        
        jmp false_delim
is_delim endm

       

start:
    mov ax, @data
    mov es, ax
    xor ch, ch
    mov cl, ds:[80h]
    mov cmd_length, cl
    mov si, 82h
    lea di, cmd_text
    rep movsb               ;text from command line to variable cmd_text
    mov ds, ax
    
    call parse_cmd_text
    test ax, ax
    jne exit
    
    puts msg_prompt_to_input
    gets word
    fopen
    puts msg_result              
    
    puts crlf
    call count
    
exit:
    puts msg_error
    pop dx
    pop cx
    pop ax
    mov ax, 4c00h
    int 21h
good_exit:
    puts crlf
    pop dx
    pop cx
    pop ax
    mov ax, dx
    puti
    mov ax, 4c00h
    int 21h
end start                      