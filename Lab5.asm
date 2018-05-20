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

                                ; string output macro
puts macro str
    push ax
    push dx
    lea dx, str
    mov ah, 9
    int 21h
    pop dx
    pop ax    
endm

                                ; string input marco
gets macro str
    push bx
    push cx
    push dx

again:                          ; check empty word input
    mov ah, 0Ah
    lea dx, str
    int 21h
    
    xor ax, ax
    xor cx, cx
    
    mov cl, [word + 1]
    cmp cl, 0                   ; if str is empty
    je again
    
    pop dx
    pop cx
    pop bx
endm

puti macro                      ; integer number output
    local put1
    local put2
    local ex
    
    push ax
    push cx
    push -1                     ; break condition
    mov cx, 10
put1:
    xor dx, dx
    xor ah, ah
    div cl                      ; al - result, ah - remainder
    mov dl, ah
    push dx
    cmp al, 0
    jne put1
    
    mov ah, 2
    
put2:
    pop dx
    cmp dx, -1          ; if -1 break
    je ex
    add dl, '0'         ; to char
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
    mov ah, 3Eh     ; close file function
    int 21h
endm

fread macro
    local continue
    push ax
    push cx
    push dx
    
    mov cx, 1
    lea dx, buf
    
    mov ah, 3Fh         ; read from file
    int 21h             ; bx - file id
    jc exit             ; cx - bytes count for reading
                        ; cf == 1 -> error
    mov cx, ax          ; returns bytes have been read to ax
    test cx, cx         ; if eof
    jnz continue
    fclose
    
    jmp good_exit
    
continue:
    pop dx
    pop cx
    pop ax
endm

;------procedures---------------

;   returns 0 if an error has occured else 1 to ax
parse_cmd_text proc
    push bx
    push cx
    push dx
    
    mov cl, cmd_length                         
    xor ch, ch
    
    lea si, cmd_text                           ; cmd text offset to source
    lea di, file_path                          ; parsing result offset to data
    call to_asciiz                             ; convert to asciiz
    
    is_empty file_path, bad_cmd_args           
    
    lea di, word_buffer
    call to_asciiz
    
    is_empty word_buffer, good_cmd_args

;-----errors handle
    
bad_cmd_args:
    puts msg_bad_args
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
  
;   
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
        
        mov es:[di], al        ; write symbol
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

;------main---------------------------------

count_raws:
    xor dx, dx
    
    search:
        fread
        mov al, [word+2]
        mov cl, [buf]
        cmp cl, al
        je check_word
    jmp search
    
check_word:
    lea si, word+2
    mov al, [si]
    mov ah, 1
    
    while:
        inc ah
        inc si
        mov al, [si]
        mov cl, [word+1]
        cmp ah, cl
        jg success
        fread
        mov cl, [buf]
        cmp al, cl
        jne search
    je while
    
success:
    inc dx
    
skip:
    fread
    mov al, 13             ;    \n
    mov cl, [buf]
    cmp al, cl
    jne skip
    fread
    jmp search
    
    jmp count_raws_end       

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
    jmp count_raws
    
count_raws_end:

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