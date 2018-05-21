.model small
.stack 100h
.data
    cmd_length db ?
    cmd_capacity equ 127
    cmd_text db cmd_capacity + 2 dup(0)
    folder_path db cmd_capacity + 2 dup(0)
    disk_transfer_area_size equ 2ch
    disk_transfer_area_block db disk_transfer_area_size dup(0)
    word_capacity equ 50
    buffer db word_capacity + 2 dup(0)
    exe_path db cmd_capacity + 15 dup(0)
    new_program_cmd db 0
    msg_bad_args db "Wrong cmd arguments! 1 required", 0Ah, 0Dh , '$'
    err_bad_init db "bad init error: $"
    err_run_prog db "error while running invoked program: $"
    err_folder db "wrong folder path", 0Ah, 0Dh , '$'
    
    epb_struct  dw 0
                dw offset line, 0
                dw 005Ch, 0, 006Ch, 0
    
    line db 125
         db " /?"
    
    line_text db 122 dup(?)
    
    epb_length dw $ - epb_struct
    suffix db "*.exe", 0
    data_size = $ - cmd_length

.code
 
;------procedures-----------



;------macros---------------                            
 
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

print_error_code macro
    add al, '0'
    mov dl, al
    mov ah, 06h
    int 21h
endm
                            
;------main----------------- 
 
start:
    mov ah, 4Ah
    mov bx, ((code_size/16)+1)+((data_size/16)+1)+32
    int 21h
    
    jnc init
    puts err_run_prog
    print_error_code
    
    mov ax, 1
    
    jmp end_start
    
init:
    mov ax, @data
    mov es, ax
    xor ch, ch
    mov cl, ds:[80h]
    mov cmd_length, cl
    mov si, 81h
    lea di, cmd_text
    rep movsb
    mov ds, ax
    
    call parse_cmd
    
    test ax, ax
    jne end_start
    
    mov ah, 3Bh
    lea dx, folder_path
    int 21h
    
    jc bad_folder_path
    
    call find_first_file
    test ax, ax
    jne end_start
    
    call run_exe
    test ax, ax
    jne end_start
    
run_file:
    call find_next_file
    test ax, ax
    jne end_start
    
    call run_exe
    test ax, ax
    jne end_start
    
    jmp run_file
    
bad_folder_path:
    puts err_folder
    
end_start:
    
    mov ax, 4C00h
    int 21h
    
    
parse_cmd proc
    push bx
    push cx
    push dx
    
    mov cl, cmd_length
    xor ch, ch
    lea si, cmd_text
    lea di, buffer
    
    call to_asciiz
    
    lea di, folder_path
    call to_asciiz
    is_empty folder_path, bad_cmd_args
    
    lea di, buffer
    call to_asciiz
    is_empty buffer, good_cmd_args
    
bad_cmd_args:
    puts msg_bad_args
    mov ax, 1
    jmp end_parse_cmd
    
good_cmd_args:
    xor ax, ax
    
end_parse_cmd:
    pop dx
    pop cx
    pop bx
    ret
parse_cmd endp

;ds:si - source
;es:di - result in ASCIIZ
;cx - maximum size
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

run_exe proc
    push bx
    push dx
    mov ax, 4B00h
    mov bx, offset epb_struct
    mov dx, offset disk_transfer_area_block + 1Eh
    int 21h
    
    jnc good_run_exe
    
    puts err_run_prog
    print_error_code
    
    mov ax, 1
    jmp exit_run_exe
    
good_run_exe:
    xor ax, ax
    
exit_run_exe:
    pop dx
    pop bx
    ret     
run_exe endp

install_dta proc
    mov ah, 1Ah
    mov dx, offset disk_transfer_area_block
    int 21h
    ret
install_dta endp
    
find_first_file proc
    call install_dta
    mov ah, 4Eh
    xor cx, cx
    lea dx, suffix
    int 21h
    
    jnc good_find
    
    mov ax, 1
    
    jmp end_find
    
good_find:
    xor ax, ax

end_find:
    ret 
find_first_file endp

find_next_file proc
    call install_dta
    mov ah, 4Fh
    lea dx, disk_transfer_area_block
    int 21h
    jnc good_next
    
    mov ax, 1
    jmp end_next
    
good_next:
    xor ax, ax
end_next:
    ret
find_next_file endp
    
    code_size = $ - start
    
end start