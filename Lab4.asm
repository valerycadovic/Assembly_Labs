.model	tiny
.386
.code
org	100h
start:
	call	restart			
exit:	
    mov	ax, 3
	int	10h
	int	20h
	                       

key_catcher	proc       ; отлов нажатия кнопки
	mov	ah, 10h        ; чтение с 101-символьной клавиатуры
	int	16h
                       ; отлов кнопок
	cmp	al, ESC_key	
	je	exit

	cmp	ah, UP
	je	gotcha
	cmp	ah, LEFT
	je	gotcha
	cmp	ah, RGHT
	je	gotcha
	cmp	ah, DOWN
	jne	key_catcher
gotcha:
	mov	keycode, ah         ; запоминаем нажатую кнопку
	call	move_numbers    ; делаем сдвиг    
	cmp	succ_moving, 1
	jne	dont_put_number     ; кладем новое число только в случае успешного сдвига

put_und_update:
	call	put_number              ; получаем новое число
dont_put_number:
	call	update_screen           ; обновление экрана

	cmp	ignr_2048_plate, 1          ; если игра уже выиграна, нет смысла проверять на наличие 2048
	je	do_ignore_2048_plate
	call	check_2048_plate        ; проверка на наличие числа 2048
	test	al, al
	jz	do_ignore_2048_plate
	call	show_winnerscreen       ; победка

	cmp	al, 'r'
	je	restart                     
	mov	ignr_2048_plate, 1		    ; играем дальше после победы

do_ignore_2048_plate:

	call	can_move                ; проверяем, есть ли возможные ходы
	test	al, al
	jz	wasted         ; проигрыш
	jmp	key_catcher		            
wasted:
	call	show_loserscreen

restart:
	call	print_main		; отрисовка границ и текста                               

	xor	ax, ax			
	mov	score, ax		    ; обнуляем счёт
	mov	ignr_2048_plate, al	; указываем, что игра еще не выиграна
	jmp	put_und_update

	ret			           
key_catcher endp		


fill_zero	proc            ; начальная инициализация матрицы нулями
	mov	ax, offset matrix-1	; адрес слова перед началом матрицы	
	mov	cx, 16				; потому что заполнение с помощью loop и сх
	xor	bx, bx
fill_zero_loop:
	mov	[eax+ecx], bl	    ; зануляем
	loop	fill_zero_loop

	mov	score, bx           ; обнуляем игровой счёт
	ret
fill_zero	endp


; процедура получения рандомного числа из книги Зубкова
get_random	proc
	push	dx
	mov	ax, seed		    ; считать последнее случайное число
	test	ax, ax			; проверить его, если это -1,
	js	fetch_seed		    ; функция еще ни разу не вызывалась
					        ; и надо создать начальное значение
randomize:
	mul	word ptr rand_a		; умножить на число а,
	div	word ptr rand_m		; взять остаток от деления на 231-1
	mov	ax, dx
	mov	seed, ax		    ; сохранить для следующих вызовов
	pop	dx
	ret

fetch_seed:
	push	ds
	push	0040h
	pop	ds
	mov	ax, ds:006Ch		; считать двойное слово из области
	pop	ds			        ; данных BIOS по адресу 0040:0060 -
	jmp	short randomize		; текущее число тактов таймера

rand_a	dw	271
rand_m	dw	7FFFh
seed	dw	-1
get_random	endp            ; на выходе регистр ах содержит рандомное число

put_number	proc                    ; получить число                                                                                          
	call	count_zeros             ; проверяем, остались ли пустые ячейки
	test	ax, ax                  ; если нет, выходим
	jz	put_number_exit
	push	ax
	call	get_random		        ; AH - 2 или 4
					                ; AL - индекс свободной ячейки
	mov	cl, 1                       ; CL == 1 - двойка
	cmp ah, 22			            ; 10% на появление четвёрки
					
	jg	dont_put_four_in_cell       
	inc	cl			                ; CL == 2 - четверка 
dont_put_four_in_cell:

	pop	bx			; восстановить количество пустых ячеек
	xor	ah, ah	    ; обнуляем, чтобы положить туда остаток
	div	bl			; AL division with remainder in AH
	shr	ax, 8	    ; ah -> al
	inc	ax			; теперь в al - позиция
	mov	ah, cl	    ; а в ah - 2 или 4
	call put_number_sub  ; занесение нового числа в пустую клетку
put_number_exit:
	ret
put_number	endp


count_zeros	proc    ; считаем пустые ячейки
	xor	ax, ax               ; обнуляем ах, чтобы хранить здесь количество пустых ячеек
	mov	bx, offset matrix-1	 ; адрес матрицы
	mov	cx, 16			     ; размер матрицы - в цикл
count_zeros_loop1:
	mov	dl, [ebx+ecx]        ; элемент по индексу
	test	dl, dl           ; проверка на ноль
	jnz	count_zeros_continue
	inc	ax                   ; если ноль, увеличиваем ах
count_zeros_continue:        
	loop	count_zeros_loop1
	ret
count_zeros	endp             ; на выходе в ах получаем колическто пустых ячеек


put_number_sub	proc                ; запись нового числа в свободную ячейку. Число находится в ah
	mov	bx, offset matrix-1         ; адрес слова перед matrix[0,0]
	mov	cx, 16                                                                                                                     
put_number_sub_loop:
	cmp	byte ptr [ebx+ecx], 0       ; сравниваем значение элемента с нулём
	jne	put_number_sub_continue     ; если не ноль, то пропускаем
	dec	al				            ; 
	jnz	put_number_sub_continue		; 
	mov	byte ptr [ebx+ecx], ah		; кладём число
	jmp	put_number_sub_exit
put_number_sub_continue:
	loop	put_number_sub_loop
put_number_sub_exit:
	ret
put_number_sub	endp

                                ; подвинуть
compress_ax_bx	proc				
	test	al, al				; если al == 0
	jnz	c_ax_bx_end			    ; выход
	test	bl, bl              ; если bl == 0
	jz	c_ax_bx_end             ; выход
	xchg	ax, bx              ; иначе меняем местами
	mov	succ_moving, 1			; указываем, что перемещение было выполнено
c_ax_bx_end:
	ret
compress_ax_bx	endp

merge_ax_bx	proc				; слияние
	test	al, al				; если al == 0
	jz	m_ax_bx_end			    ; выход
	cmp	al, bl				    ; если не al == bl
	jne	m_ax_bx_end             ; выход
	inc	ax                      ; увеличиваем ах
	xor	bl, bl                  ; обнуляем
	add	score, ax               ; увеличиваем счет на полученную степень двойки
	mov	succ_moving, 1			; двигали!
m_ax_bx_end:
	ret
merge_ax_bx	endp

compress_registers	proc        
	mov	si, 3                   ; instead of cx, because it stores third element
    c_registers_loop:               ; ax, bx, cx, dx
	    call	compress_ax_bx      ; compress ax, bx 
	    xchg	ax, cx              ; cx, bx, ax, dx
	    xchg	ax, bx              ; bx, cx, ax, dx
	    call	compress_ax_bx      ; compress bx, cx
	    xchg	ax, dx              ; dx, cx, ax, bx
	    xchg	ax, bx              ; cx, dx, ax, bx
	    call	compress_ax_bx      ; compress cx, dx
	    xchg	ax, cx              ; ax, dx, cx, bx
	    xchg	bx, dx              ; ax, bx, cx, dx
        dec	    si				
	jnz	c_registers_loop		; repeat it three times
	ret
compress_registers	endp

merge_registers	proc                
	call	merge_ax_bx             ; merge ax, bx
	xchg	ax, bx                  ; bx, ax, cx, dx
	xchg	bx, cx                  ; bx, cx, ax, dx
	call	merge_ax_bx             ; merge bx, cx
	xchg	ax, bx                  ; cx, bx, ax, dx
	xchg	bx, dx                  ; cx, dx, ax, bx
	call	merge_ax_bx             ; merge cx, dx
	xchg	ax, cx                  ; ax, dx, cx, bx
	xchg	bx, dx                  ; ax, dx, cx, dx
	ret
merge_registers	endp

prepare_registers_to_loading proc
	mov	ax, 3	; default directions - right or down
	mov	bx, 2
	mov	cx, 1	
	xor	dx, dx	

	cmp	keycode, DOWN
	je	move_load_end
	cmp	keycode, RGHT
	je	move_load_end
	
	; inversion
	xor	al, al	
	dec	bx	
	inc	cx	
	mov	dl, 3
move_load_end:             

	cmp	keycode, LEFT
	je	not_vertical
	cmp	keycode, RGHT
	je	not_vertical
	; define as vertical via left shift
	shl	al, 2
	shl	bl, 2
	shl	cl, 2
	shl	dl, 2
not_vertical:
	ret
prepare_registers_to_loading endp

move_numbers	proc                 ; движение чисел
	lea	di, matrix                   ; адрес первого элемента
	mov	cx, 4                        
	mov	succ_moving, 0               
loop1:                               
	push	cx                       
	
	call	prepare_registers_to_loading       
	mov	al, [edi+eax]                ; заносим строку матрицы
	mov	bl, [edi+ebx]                ; в регистры общего назначения
	mov	cl, [edi+ecx]
	mov	dl, [edi+edx]

	call	compress_registers             
	call	merge_registers
	call	compress_registers

	mov	regstore._al, al
	mov	regstore._bl, bl
	mov	regstore._cl, cl
	mov	regstore._dl, dl

	call	prepare_registers_to_loading
	call	store_registers

	cmp	keycode, UP
	je	goto_next_cell
	cmp	keycode, DOWN
	je	goto_next_cell
	add	di, 3
goto_next_cell:
	inc	di
	pop	cx
	loop	loop1
	ret
move_numbers	endp         

store_registers	proc
	push	bx
	mov	bl, regstore._al
	mov	[edi+eax], bl
	pop	bx
	mov	al, regstore._bl
	mov	[edi+ebx], al
	mov	al, regstore._cl
	mov	[edi+ecx], al
	mov	al, regstore._dl
	mov	[edi+edx], al
	ret
store_registers	endp


can_move	proc
	mov	ax, 1			    ;
	lea	dx, matrix	; адрес первого элемента матрицы
	mov	cx, 4               ;
	 
    can_move_loop_glob:
	    mov	bh, cl         ; используем bh как счетчик внешнего цикла
	    mov	cl, 4

        can_move_loop:
	        mov	bl, [edx]   ; получаем значение клетки
	        cmp	bl, ah		; сравниваем с нулем. Если ноль, то можем двигаться
	        jz	we_can_move

	        cmp	cl, al      ; сравниваем cl с единицей	
	        je	can_move_loop_next	; если равно, значит мы на крайнем столбце справа
	        cmp	bl, [edx+1] ; иначе сравниваем со следующей ячейкой в строке
	        je	we_can_move ; если равно, можем двигаться далее

            can_move_loop_next: ; здесь идет сравнение в столбце
	            cmp	bh, al	; в bh - номер строки
	            jle	can_move_loop_continue	
	            cmp	bl, [edx+4]  ; сравнение с ячейкой на 1 ниже
	            je	we_can_move

            can_move_loop_continue:
	            inc	dx              ; переход к следующей ячейке
	    loop	can_move_loop
	    mov	cl, bh
	loop	can_move_loop_glob

	xor	ax, ax           ; return false
we_can_move:
	ret
can_move	endp


check_2048_plate	proc
	xor	ax, ax
	lea	bx, matrix-1
	mov	cx, 16
check_2048_plate_loop:
	cmp	byte ptr [ebx+ecx], 11      ; 11 == log2(2048)
	je	plate_2048_exists
	loop	check_2048_plate_loop
	jmp	check_2048_plate_end

plate_2048_exists:
	inc	ax
check_2048_plate_end:
	ret
check_2048_plate	endp                                                              
                                 
      ; GRAPHICS
      
print_text macro text, length, position
	mov	ax, 1300h
	mov	cx, length
	mov	dx, position
	lea	bp, text
	int	10h
endm

print_main proc
	mov	ax, 0003h
	int	10h				    ; go to color 80x25 mode
	xor	dx, dx
	mov	bx, 05h				; colour, purple
	call	print_header
	mov	bx, 0111b			; colour, lightblue
	call	print_inner

	mov	ah, 02h
	mov	dx, 26*100h		; move cursor to 26th line
	int	10h				; out of teh screen

	call fill_zero		; put first number on field

	mov	bx, 0111b				; colour, white
	print_text	score_text, score_text_l, 6*100h+40-score_text_l
	print_text	copy_text,  copy_text_l, 23*100h+78-copy_text_l
	ret
print_main endp

print_header	proc
	print_text header_text header_text_l, 3*100h+38
	ret
print_header	endp

show_loserscreen	proc
	mov	bx, 000Ch
	print_text waste, waste_l, 3*100h+37
	mov	ax, 10h		    ;
	int	16h
	cmp	al, ESC_key
	je	exit
	ret
show_loserscreen	endp

show_winnerscreen	proc
	mov	bx, 000Ah
	print_text victory, victory_l, 3*100h+20

choice_loop:
	mov	ah, 10h
	int	16h
	cmp	al, 'r'
	je	choice_done
	cmp	al, 'c'
	je	choice_done
	cmp	al, ESC_key
	je	exit
	jmp	choice_loop
choice_done:

	push	ax				; here we store pressed key
	call	print_header	; 
	pop	ax		            ; which will be rewritten when new game starts
	ret
show_winnerscreen	endp

print_inner proc
	mov	ah, 02h
	mov	dh, 9
	int	10h
	mov	cx, 3
    print_inner_loop:
	    push	' |'
	    call	print_inner_sub
	    push	'--'
	    call	print_inner_sub
	loop	print_inner_loop
	push	' |'
	call	print_inner_sub
	ret
print_inner endp

print_inner_sub proc
	push	cx
	mov	ah, 02h
	mov	dl, 30
	int	10h
	mov	cx, 3
print_inner_sub_loop:
	push 	cx                                 
	mov	al, [esp+7]
	mov	cx, 4
	call	print_symb		; 1st sumbol x 4 times
	mov	al, [esp+6]
	mov	cx, 1
	call	print_symb		; 2nd sumbol x 1 time

	pop	cx
	loop	print_inner_sub_loop

	mov	al, [esp+5]
	mov	cx, 4
	call	print_symb		; 1st sumbol x 4 times

	inc	dh
	pop	cx

	pop	ax		; temporary store returning address
	add	sp, 2		; remove one prameter from stack
	push	ax		; restore returning address

	ret			; return using restored address
print_inner_sub endp


print_symb proc
	mov	ah, 02h			
	int	10h				
	mov	ah, 09h
	int	10h				
	add	dl, cl	
	ret
print_symb endp


update_screen	proc
	call	display_numbers
	call	display_score
	ret
update_screen	endp


display_numbers	proc
	mov	bp, offset matrix+15	; changing, have to be stored
	mov	dh, 15			; position, line
	mov	cx, 4			; 4 lines
    display_numbers_loop1:
	    push	cx
	    mov	dl, 45			; 4th number, position of 1st symbol
	    mov	cl, 4			; 4 columns
        display_numbers_loop2:
	        push	cx
	        push	bp
	
	        movzx	bp, ds:byte ptr [bp]	; BP usually addreses as SS:BP

	        mov	ax, bp			; color generation. Range:
	        mov	bl, 6			; 0Ah..0Fh  which means
	        div	bl			    ; black BG colour
	        mov	bx, 0Ah			; and bright FG colour in 3 low bits
	        add	bl, ah			; BL = 0Ah + remainder

	        shl	bp, 2			
	        add	bp, offset powers	; because our substrings occupy 4 bytes
	        mov	ax, 1300h		; each
	        mov	cl, 4			; 4 symbols to grab from [offset power]
	        int	10h			    ; print
	
	        sub	dl, 5h			; next (in fact previous) position
					            ; as our string - 4 and border - 1
	        pop	bp
	        dec	bp
	        pop	cx
	    loop	display_numbers_loop2
	    sub	dh, 2			; move up two lines
	    pop	cx
	loop	display_numbers_loop1
	ret
display_numbers	endp


display_score	proc
	mov	ax, score
	mov	bx, 10
	mov	do_print_spaces, bh	; BH=0
	mov	cx, scorebuf_l
	mov	di, offset scorebuf
	add	di, cx
display_score_loop:
	xor	dx, dx
	div	bx

	cmp	do_print_spaces, 1
	jge	another_space
	add	dl, '0'
another_space:

	dec	di
	mov	[di], dl
	
	test	ax, ax
	jnz	dddont
	inc	do_print_spaces	; we may move "1", but it costs 1 byte. So, no.
				; And as we may maximum increase it 5 times,
				; there is no owerflow in future
dddont:
	
	loop	display_score_loop

	dec	bx		; 'l be 9 - 1001 -  bright green
	print_text scorebuf, scorebuf_l, 6*100h+41
	ret
display_score	endp

;.data		; places all data with alignment. May eat some bytes
victory	db 'You got 2048! Press R to '
victory_l	equ $ - victory
copy_text	db 'Valery Chadovich. 650502'
copy_text_l	equ $ - copy_text
score_text	db 'Score:'
score_text_l	equ $ - score_text
waste		db 'GAME OVER'
waste_l	equ $ - waste
header_text	db '2048'
header_text_l	equ $ - header_text

; store this megastring more effective than generate values dynamicaly
; try to compile POWERS.ASM in "Side products" for comparsion
powers		db '    ','  2 ','  4 ','  8 ',' 16 ',' 32 ',' 64 ',' 128'
	 db ' 256',' 512','1024','2048','4096','8192','2^14','2^15','2^16'

regstore_s struc
	_al db ?
	_bl db ?
	_cl db ?
	_dl db ?
regstore_s ends
regstore regstore_s <>			; temporary storage for registers

keycode		db ?
succ_moving	db ?
do_print_spaces	db ?
ignr_2048_plate	db ?
score		dw ?
scorebuf	db 5 dup(?)
scorebuf_l	equ $-scorebuf
matrix		db 16 dup(?)

UP      equ 48h
LEFT    equ 4Bh
RGHT    equ 4Dh
DOWN    equ 50h
ESC_key equ 1Bh

end start