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
extern str_concat
extern strlen
extern strcpy


string_proc_list_create_asm:
 ; creo el stack
 push rbp
 mov rbp, rsp

 ; 2 punteros de 8 bytes cada uno = 16 bytes de memoria inicial
 mov rdi, 16 ; rdi primero (standard practice)
 call malloc ; a rax

 ; Veo si fallo el malloc (rax == NULL)
 cmp rax, NULL
 je .error ; error de memoria a puntero nulo

 ; inicializo los punteros a NULL (first, y despues last en +8 porque el primero mide 8 segun docstring de la consigna)
 mov qword [rax], NULL
 mov qword [rax + 8], NULL

 ; Saco del stack y devuelvo el pointer a la lista
 pop rbp
 ret

.error:
 ; no inicializo nada, vacio el stack y devuelvo directamente NULL (rax es NULL porque no se le hizo nada)
 pop rbp
 xor rax, rax ; con esto aseguro que rax sea NULL
 ret


string_proc_node_create_asm:
 ; rdi = uint8_t type
 ; rsi = char* hash
 
 ; creo el stack
 push rbp
 mov  rbp, rsp
 
 ; guardo los parametros
 push rdi ; guardo type
 push rsi ; guardo hash
 
 ; asigno 32 de memoria | 8 (next) + 8 (previous) + 8 (type) + 8 (hash)
 mov  rdi, 32
 call malloc ; manda al rax
 
 ; Veo si fallo el malloc (rax == NULL)
 cmp rax, NULL
 je .error ; error de memoria a puntero nulo
 
 ; los agarro del stack como los habia dejado jic
 pop  rsi
 pop  rdi
 
 ; node->next = NULL
 mov  QWORD [rax], NULL
 
 ; node->previous = NULL
 mov  QWORD [rax+8], 0
 
 ; node->type = type 
 mov  [rax+16], dil ; (dil = los 8 lower bits de rdi, porque el struct decia que es uint8_t)
 
 ; node->hash = hash
 mov  [rax+24], rsi
 
 ; Saco del stack y devuelvo el pointer a la lista
 pop  rbp ; Restore caller's base pointer
 ret   ; Return to caller (return value in rax)
 
.error:
 ; vacio el stack y devuelvo directamente NULL
 pop  rsi
 pop  rdi
 xor  rax, rax ; con esto aseguro que rax sea NULL



string_proc_list_add_node_asm:
  push rbp
  mov  rbp, rsp
  sub  rsp, 48
  mov  QWORD [rbp-24], rdi
  mov  eax, esi
  mov  QWORD [rbp-40], rdx
  mov  BYTE [rbp-28], al
  movzx   eax, BYTE [rbp-28]
  mov  rdx, QWORD [rbp-40]
  mov  rsi, rdx
  mov  edi, eax
  call string_proc_node_create_asm
  mov  QWORD [rbp-8], rax
  cmp  QWORD [rbp-8], 0
  je   .L11
  mov  rax, QWORD [rbp-24]
  mov  rax, QWORD [rax]
  test rax, rax
  jne  .L10
  mov  rax, QWORD [rbp-24]
  mov  rdx, QWORD [rbp-8]
  mov  QWORD [rax], rdx
  mov  rax, QWORD [rbp-24]
  mov  rdx, QWORD [rbp-8]
  mov  QWORD [rax+8], rdx
  jmp  .L7
.L10:
  mov  rax, QWORD [rbp-24]
  mov  rdx, QWORD [rax+8]
  mov  rax, QWORD [rbp-8]
  mov  QWORD [rax+8], rdx
  mov  rax, QWORD [rbp-24]
  mov  rax, QWORD [rax+8]
  mov  rdx, QWORD [rbp-8]
  mov  QWORD [rax], rdx
  mov  rax, QWORD [rbp-24]
  mov  rdx, QWORD [rbp-8]
  mov  QWORD [rax+8], rdx
  jmp  .L7
.L11:
  nop
.L7:
  leave
  ret

string_proc_list_concat_asm:
  push rbp
  mov  rbp, rsp
  sub  rsp, 64
  mov  QWORD [rbp-40], rdi
  mov  eax, esi
  mov  QWORD [rbp-56], rdx
  mov  BYTE [rbp-44], al
  mov  rax, QWORD [rbp-56]
  mov  rdi, rax
  call strlen
  add  rax, 1
  mov  rdi, rax
  call malloc
  mov  QWORD [rbp-8], rax
  cmp  QWORD [rbp-8], 0
  jne  .L13
  mov  eax, 0
  jmp  .L14
.L13:
  mov  rdx, QWORD [rbp-56]
  mov  rax, QWORD [rbp-8]
  mov  rsi, rdx
  mov  rdi, rax
  call strcpy
  mov  rax, QWORD [rbp-40]
  mov  rax, QWORD [rax]
  mov  QWORD [rbp-16], rax
  jmp  .L15
.L17:
  mov  rax, QWORD [rbp-16]
  movzx   eax, BYTE [rax+16]
  cmp  BYTE [rbp-44], al
  jne  .L16
  mov  rax, QWORD [rbp-16]
  mov  rdx, QWORD [rax+24]
  mov  rax, QWORD [rbp-8]
  mov  rsi, rdx
  mov  rdi, rax
  call str_concat
  mov  QWORD [rbp-24], rax
  mov  rax, QWORD [rbp-8]
  mov  rdi, rax
  call free
  mov  rax, QWORD [rbp-24]
  mov  QWORD [rbp-8], rax
.L16:
  mov  rax, QWORD [rbp-16]
  mov  rax, QWORD [rax]
  mov  QWORD [rbp-16], rax
.L15:
  cmp  QWORD [rbp-16], 0
  jne  .L17
  mov  rax, QWORD [rbp-8]
.L14:
  leave
  ret