; /** defines bool y puntero **/
%define NULL 0
%define TRUE 1
%define FALSE 0

extern printf

section .data
msg_concat_start db "Entering concat_asm", 10, 0
msg_concat_node db "Visiting node", 10, 0
msg_type db "TYPE RECEIVED in create: %d", 10, 0

section .text

global string_proc_list_create_asm
global string_proc_node_create_asm
global string_proc_list_add_node_asm
global string_proc_list_concat_asm

; FUNCIONES auxiliares que pueden llegar a necesitar:
extern malloc
extern free
extern strlen
extern strcpy
extern str_concat

section .text

string_proc_list_create_asm:
    ; Allocate 16 bytes
    mov rdi, 16             ; size of string_proc_list (2 pointers)
    call malloc             ; malloc(16), return in RAX

    ; If malloc fails, return NULL
    test rax, rax
    je .return_null

    ; Set first = NULL
    mov qword [rax], 0

    ; Set last = NULL
    mov qword [rax + 8], 0

.return_null:
    ret



string_proc_node_create_asm:
    ; Save incoming type (in DIL) and hash (in RSI)
    push rsi             ; save hash
    movzx rcx, dil       ; save type into RCX before trashing RDI

    mov rdi, 32
    call malloc
    test rax, rax
    je .return_null

    ; Set next = NULL
    mov qword [rax], 0

    ; Set previous = NULL
    mov qword [rax + 8], 0

    ; Set type from RCX (was in DIL)
    mov byte [rax + 16], cl

    ; Set hash
    pop rsi
    mov qword [rax + 24], rsi

.return_null:
    ret

string_proc_list_add_node_asm:
    ; Save list (RDI), type (SIL), hash (RDX)
    push rdi            ; save list
    push rdx            ; save hash

    ; Prepare call to string_proc_node_create_asm(type, hash)
    movzx rdi, sil    ; zero-extend the 8-bit type to 64-bit RDI
    pop rsi             ; restore hash
    call string_proc_node_create_asm
    mov rbx, rax        ; new_node in RBX

    pop rdi             ; restore list into RDI

    ; if (list->first == NULL)
    mov rax, [rdi]      ; rax = list->first
    test rax, rax
    jnz .not_empty_list

    ; list->first = new_node
    mov [rdi], rbx

    ; list->last = new_node
    mov [rdi + 8], rbx
    ret

.not_empty_list:
    ; new_node->previous = list->last
    mov rcx, [rdi + 8]       ; rcx = list->last
    mov [rbx + 8], rcx       ; new_node->previous = rcx

    ; list->last->next = new_node
    mov [rcx], rbx           ; rcx->next = new_node

    ; list->last = new_node
    mov [rdi + 8], rbx

    ret

string_proc_list_concat_asm:
    push rbx
    push r12
    push r13

    ; Save input args
    mov rbx, rdi        ; list
    movzx r12, sil      ; type to compare (zero-extended)
    mov r13, rdx        ; initial hash

    ; Now safe to call printf
    mov rdi, msg_concat_start
    call printf

    ; malloc(strlen(hash) + 1)
    mov rdi, r13
    call strlen
    add rax, 1
    mov rdi, rax
    call malloc
    mov r14, rax        ; result string

    ; strcpy(result, hash)
    mov rdi, r14
    mov rsi, r13
    call strcpy

    ; Traverse list
    mov r15, [rbx]      ; current_node = list->first
.loop:
    test r15, r15
    je .done

    ; Compare node->type with input type
    movzx eax, byte [r15 + 16]
    cmp eax, r12d

    ; Debug: visiting node
    ; mov rdi, msg_concat_node
    ; call printf

    jne .next_node

    ; Call str_concat(result, current_node->hash)
    mov rdi, r14
    mov rsi, [r15 + 24]
    call str_concat

    ; Free old result
    mov rdi, r14
    call free

    ; Update result with new pointer
    mov r14, rax

.next_node:
    mov r15, [r15]      ; current_node = current_node->next
    jmp .loop

.done:
    mov rax, r14        ; return final result

    pop r13
    pop r12
    pop rbx
    ret

