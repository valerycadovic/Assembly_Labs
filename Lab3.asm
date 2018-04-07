.model small
.stack 200h
.data
    buffer db 9 dup('$')
    array dw 30 dup($)
    repeats dw 30 dup(0)
    numbers dw 30 dup($)
    
    msgCount db 0Ah, 0Dh, "Enter count of elements: ", "$"
    msgEnter db  0Ah, 0Dh, "Press enter to input number: ", 0Ah, 0Dh, "$"
    msgInputException db 0ah, 0dh, "INPUT ERROR!", "$"
    msgResultException db 0ah, 0dh, "BYTE TYPE OWERFLOW!", "$"
    msgElement db 0ah, 0dh, "Element: $"
    slash_n db 0ah, 0dh, "$"
    
    c10 dw 10
    countNum dw 1
    symbolNum dw ?
    max dw 1
.code
    puts macro str
        mov ah, 9
        lea dx, str
        int 21h
    endm
    
    main proc
        mov ax, @data
        mov ds, ax
         
        COUNT:  
            puts msgCount
            call ScanNumber
            cmp ax, 0
            js COUNT
            mov symbolNum, ax
            cmp symbolNum, 1
            jle COUNT
            cmp symbolNum, 30
            ja COUNT     
        puts msgEnter
        mov cx, symbolNum
        xor di, di
        
        INPUT_LOOP:
            puts msgElement    
            call ScanNumber
            mov array[di], ax
            jnc CONTINUE
            INPUT:
                puts msgInputException
                call ScanNumber
                mov array[di], ax
                jnc CONTINUE
            jmp INPUT
            CONTINUE:
                add di, 2
        loop INPUT_LOOP
        
        puts slash_n
        call SearchRepeats
        
        
        mov ah, 4ch
        int 21h
    main endp
    
    SearchRepeats proc
        pusha          
        mov ax, countNum
        mov repeats[0], ax
        mov ax, array[0]
        mov numbers[0], ax
        
        xor di, di
        add di, 2
        mov cx, symbolNum
        dec cx
        ARRAY_LOOP:
            push cx
            mov cx, countNum
            xor si, si
            SEARCH_LOOP:
                mov ax, array[di] 
                cmp ax, numbers[si]
                jne NOT_EQUAL
                mov ax, repeats[si]
                inc ax
                mov repeats[si], ax
                cmp ax, max
                jle NOT_MAX
                mov max, ax
                NOT_MAX:
                jmp BREAK
                NOT_EQUAL:
                add si, 2   
            loop SEARCH_LOOP
            mov bx, array[di]
            mov ax, countNum
            mov dx, 2
            mul dx
            mov si, ax
            mov numbers[si], bx
            mov dx, repeats[si]
            inc dx
            mov repeats[si], dx
            mov dx, countNum
            inc dx
            mov countNum, dx
            BREAK:
            add di, 2
            pop cx    
        loop ARRAY_LOOP
        
        mov cx, countNum
        xor si, si
        OUTPUT_LOOP:
            mov ax, repeats[si]
            cmp ax, max
            jne NEQ
            mov ax, numbers[si]
            call PrintNumber
            puts slash_n
            NEQ:
            add si, 2
        loop OUTPUT_LOOP
        
        popa
        ret
    SearchRepeats endp
    
    OutArr proc
        xor si, si
        mov cx, symbolNum
        ZA_LOOP:
            mov ax, array[si]
            call PrintNumber
            puts slash_n
            add si, 2    
        loop ZA_LOOP 
        ret
    OutArr endp
        
    ScanNumber proc near
        push dx
        mov al, 7
        
        call ScanString
        call StringToNumber
        
        pop dx
        ret    
    ScanNumber endp
    
    ScanString proc near
        push cx
        push bx
        
        mov cx, ax
        mov buffer[0], al
        mov buffer[1], 0
        
        lea dx, buffer
        mov ah, 0Ah
        int 21h
        
        mov al, buffer[1]
        
        add dx, 2
        mov ah, ch
        
        pop bx
        pop cx
        ret    
    ScanString endp
    
    ;input: al - strlen
    ;       dx - adress of the string
    ;output:ax - word (if error - ax == 0)
    ;       if cf == 1 - error  
    
    StringToNumber proc near
        push bx
        push dx
    
        test al, al
        jz STR_TO_NUM_ERROR  
    
        mov bx, dx
        mov bl, [bx]
        cmp bl, '-'
        jne STR_TO_NUM_NO_SIGN   
        inc dx
        dec al    
    
    STR_TO_NUM_NO_SIGN:
        call StringToUnsigned
        jc STR_TO_NUM_ERROR   ;   if CF == 1 
    
        cmp bl, '-'
        jne STR_TO_NUM_PLUS   
    
        cmp ax, 32768   
        ja STR_TO_NUM_ERROR
        neg ax          ; convert to additional code                                                                                                                                                                        ; слава лох
        jmp STR_TO_NUM_OK 
    
    STR_TO_NUM_PLUS:
        cmp ax, 32767
        ja STR_TO_NUM_ERROR
    
    STR_TO_NUM_OK:   
        clc              ;CF=0
        jmp STR_TO_NUM_EXIT
    
    STR_TO_NUM_ERROR:
        xor ax, ax
        stc              ;CF=1
    
    STR_TO_NUM_EXIT:
        pop dx
        pop bx   
    
        ret   
    StringToNumber endp            
    
    StringToUnsigned proc near
        push cx                 
        push dx
        push bx
        push si
        push di
 
        mov si,dx               
        mov di,10  
        xor cx, cx             
        mov cl,al             
        jcxz STR_TO_UNS_ERROR      ;if cx == 0
         
        xor ax,ax              
        xor bx,bx 
 
    STR_TO_UNS_LOOP:
        mov bl,[si]             
        inc si         
     
        cmp bl,' '              
        jne STR_TO_UNS_NOT_SPACE   
    
        dec cx
        jmp STR_TO_UNS_LOOP 
    
    STR_TO_UNS_NOT_SPACE: 
        cmp bl, 9              
        jne STR_TO_UNS_NOT_TAB
    
        dec cx
        jmp STR_TO_UNS_LOOP 
    
    STR_TO_UNS_NOT_TAB:               
        cmp bl,'0'              
        jl STR_TO_UNS_ERROR  
            
        cmp bl,'9'              
        jg STR_TO_UNS_ERROR
            
        sub bl,'0'             
        mul di                   
        jc STR_TO_UNS_ERROR         
        add ax,bx      
              
        jc STR_TO_UNS_ERROR ;if CF == 1
             
    loop STR_TO_UNS_LOOP 
             
        jmp STR_TO_UNS_EXIT         
 
    STR_TO_UNS_ERROR:
        xor ax,ax               
        stc           ;CF = 1 
 
    STR_TO_UNS_EXIT:
        pop di                  
        pop si
        pop bx
        pop dx
        pop cx   
    
        ret
    StringToUnsigned endp
    
    PrintNumber proc
        push cx
        xor cx, cx
        
        cmp ax, 0
        jns ATOI
        
    NEGATIVE:
        push ax
        mov dl, '-'
        mov ah, 2
        int 21h
        pop ax
        neg ax
        
    ATOI:
        xor dx, dx
        div c10
        add dx, 30h
        push dx
        inc cx
        cmp ax, 0
        je PRINT_LOOP
        jmp ATOI:
        
    PRINT_LOOP:
        pop dx
        mov ah, 2
        int 21h
    loop PRINT_LOOP
    
        pop cx
        ret
    PrintNumber endp