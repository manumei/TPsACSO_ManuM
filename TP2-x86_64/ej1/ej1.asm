; /** defines bool y puntero **/
%define NULL 0
%define TRUE 1
%define FALSE 0

section .data

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
    ; Save type (in DIL) and hash (in RSI)
    push rsi            ; save hash on stack
    mov rdi, 32         ; size of string_proc_node
    call malloc         ; malloc(32), result in RAX
    test rax, rax
    je .return_null

    ; Set next = NULL
    mov qword [rax], 0

    ; Set previous = NULL
    mov qword [rax + 8], 0

    ; Set type = DIL
    mov byte [rax + 16], dil

    ; Set hash = value saved on stack
    pop rsi
    mov qword [rax + 24], rsi

.return_null:
    ret

string_proc_list_add_node_asm:
    ; Save list (RDI), type (SIL), hash (RDX)
    push rdi            ; save list
    push rdx            ; save hash

    ; Prepare call to string_proc_node_create_asm(type, hash)
    mov rdi, rsi        ; type → RDI
    pop rsi             ; restore hash into RSI
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

