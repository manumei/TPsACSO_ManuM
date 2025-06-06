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
 mov  QWORD [rax+8], NULL
 
 ; node->type = type 
 mov  [rax+16], dil ; (dil = los 8 lower bits de rdi, porque el struct decia que es uint8_t)
 
 ; node->hash = hash
 mov  [rax+24], rsi
 
 ; Saco del stack y devuelvo el pointer a la lista
 pop  rbp
 ret
 
.error:
 ; vacio el stack y devuelvo directamente NULL
 pop  rsi
 pop  rdi
 xor  rax, rax ; con esto aseguro que rax sea NULL


string_proc_list_add_node_asm:
  ; rdi = string_proc_list* list
  ; rsi = uint8_t type (only lower 8 bits used)
  ; rdx = char* hash
  ; si lista esta vacia, el nodo se vuelve primero y ultimo, otherwise, ultimo
  
  ; creo el stack
  push  rbp
  mov   rbp, rsp
  
  ; guardo los inputs en el stack
  push  rdi
  push  rsi
  push  rdx
  
  ; paso los parametros type & hash a donde los toma node_create
  mov   rdi, rsi
  mov   rsi, rdx
  call  string_proc_node_create_asm
  
  cmp rax, NULL ; veo si el nodo es NULL
  je  .null_node
  
  ; guardo el nodo y restoreo los valores que guarde en el stack
  mov   r8, rax ; nodo
  pop   rdx
  pop   rsi
  pop   rdi
  
  cmp   QWORD [rdi], NULL ; if list->first == NUL, entonces la lista esta vacia (qword por 8 bytes del primer puntero)
  je   .list_empty

  ; aca pongo el nuevo nodo
  mov   rax, [rdi+8] ; a rax le cargo el current last node (para ser el previous del nuevo)  
  mov   [r8+8], rax  ; previous es offset=8, asi que r8+8 es el previous del nuevo nodo
  mov   [rax], r8    ; hago que current_last->next sea el nuevo nodo (offset=0 asi que accedo a [rax])
  
  mov   [rdi+8], r8 ; list->last el nuevo nodo (el next ya es NULL por como hice node_create)
  jmp   .finalizar

.list_empty:
  ; el nodo (r8) va primero y ultimo
  mov   [rdi], r8 ; list->first
  mov   [rdi+8], r8 ; list->last
  jmp   .finalizar
  
.null_node:
  ; vacio el stack y nada mas (se va a devolver NULL)
  pop rdx
  pop rsi  
  pop rdi
  jmp .finalizar
  
.finalizar:
  ; vacio el stack y devuelvo
  pop   rbp
  ret


string_proc_list_concat_asm:
    ; rdi = list pointer
    ; sil = type (como es uint8_t guardo solo los 8 lower bits, sil hace eso para rsi)
    ; rdx = hash pointer

    ; creo el stack
    push  rbp
    mov   rbp, rsp

    ; voy a estar guardando los parametros en estos registers
    ; asi que los guardo en el stack para no perderlos y devolverselos al que llamo la funcion
    push  rbx
    push  r12
    push  r13

    ; Store parameters in callee-saved registers for safety
    mov   rbx, rdi ; list
    mov   r12b, sil ; r12b es los 8 lower bits de r12, porque again, type es uint8_t y le hago sil para agarrar los 8 lowers de rsi
    mov   r13, rdx ; hash
    
    ; preparo para alocar memoria
    mov   rdi, r13
    call  strlen ; devuelve en rax
    add   rax, 1 ; para el null terminator
    mov   rdi, rax ; rdi = tamaño final para el malloc, ya que malloc usa rdi por default

    ; aloco memoria para el result
    call  malloc ; aloca a rax
    cmp   rax, NULL ; si falla el malloc, error
    je    error_malloc
    
    ; Copy initial hash to result buffer
    mov   rdi, rax                ; rdi = result buffer
    mov   rsi, r13                ; rsi = initial hash
    push  rax                     ; save result pointer on stack
    call  strcpy                  ; copy initial hash to result
    pop   rax                     ; restore result pointer to rax
    
    ; Initialize loop - get first node from list
    mov   rcx, QWORD [rbx]        ; rcx = list->first (current node pointer)
    test  rcx, rcx                ; check if list is empty
    jz    concatenation_done      ; if empty, we're done
    
traverse_list:
    ; Check if current node's type matches the target type
    mov   dl, BYTE [rcx + 16]     ; dl = current_node->type
    cmp   dl, r12b                ; compare with target type
    jne   next_node               ; if not equal, skip this node
    
    ; Types match - concatenate this node's hash
    push  rax                     ; save current result pointer
    push  rcx                     ; save current node pointer
    
    ; Call str_concat(current_result, current_node->hash)
    mov   rdi, rax                ; rdi = current result
    mov   rsi, QWORD [rcx + 24]   ; rsi = current_node->hash
    call  str_concat              ; rax = new concatenated string
    
    pop   rcx                     ; restore current node pointer
    pop   rdi                     ; restore old result pointer to rdi
    
    ; Free old result and update to new result
    push  rax                     ; save new result pointer
    push  rcx                     ; save current node pointer
    call  free                    ; free old result
    pop   rcx                     ; restore current node pointer
    pop   rax                     ; restore new result pointer
    
next_node:
    ; Move to next node in the list
    mov   rcx, QWORD [rcx]        ; rcx = current_node->next
    test  rcx, rcx                ; check if we've reached the end
    jnz   traverse_list           ; if not null, continue traversing
    
concatenation_done:
    ; Restore callee-saved registers and return
    pop   r13
    pop   r12
    pop   rbx
    pop   rbp
    ret

error_malloc:
    ; Return NULL if initial malloc failed
    xor   rax, rax ; rax = NULL
    pop   r13
    pop   r12
    pop   rbx
    pop   rbp
    ret
