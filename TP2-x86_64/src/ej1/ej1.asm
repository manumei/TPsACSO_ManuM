; /** defines bool y puntero **/
%define NULL 0
%define TRUE 1
%define FALSE 0

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

    ; llamo strcpy 
    mov   rdi, rax  ; memoria para el result
    mov   rsi, r13  ; el hash (para pasarle al strcpy)
    push  rax       ; guardo el puntero (por si acaso si strcpy lo modifica, aunque no deberia por lo que lei en google)
    call  strcpy
    pop   rax       ; again, por si las moscas
    
    ; Initialize loop - get first node from list
    mov   rcx, QWORD [rbx] ; lee el primer nodo (8 bytes)
    cmp   rcx, NULL
    je    termine_de_concatenar ; si la lista esta vacia (first is NULL)
    
  iterar_lista:
    ; dl son los 8 lower bits de rdx, asi guardo el type
    mov   dl, BYTE [rcx + 16] ; BYTE lee 1 byte (8 bits), meaning el tamaño del type, que estaba en el offset=16
    cmp   dl, r12b
    jne   siguiente_nodo ; salteo si no son del mismo type
    
    ; si matchean los guardo antes del str_concat
    push  rax ; result
    push  rcx ; node
    
    ; concateneo los hashes
    mov   rdi, rax                ;
    mov   rsi, QWORD [rcx + 24]   ; el hash en el offset=24, de tamaño 8 bytes
    call  str_concat              ; con rdi=result, rsi=hash, guarda en rax

    pop   rcx ; node
    pop   rdi ; result
    
    ; Free (rdi), por si acaso pusheo y popeo mis rax & rcx por si free los llegase a cambiar
    push  rax ; el nuevo result (la string concatenada)
    push  rcx
    call  free
    pop   rcx
    pop   rax
    
siguiente_nodo:
    ; sigo el loop
    mov   rcx, QWORD [rcx]  ; next node
    cmp   rcx, NULL
    jne    iterar_lista ; si es NULL, terminamos (pasa al codigo de aba)
    
termine_de_concatenar:
    ; restoro los registers & return
    pop   r13
    pop   r12
    pop   rbx
    pop   rbp
    ret

error_malloc:
    ; Return NULL if initial malloc failed
    xor   rax, rax ; con esto aseguro que rax sea NULL
    pop   r13
    pop   r12
    pop   rbx
    pop   rbp
    ret
