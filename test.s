# Uppgiften går ut på att implementera rutiner för att hantera inmatning och utmatning av
# data. För att klara av det behöver man reservera plats för två olika systembuffertar, en
# för inmatning och en för utmatning. Var och en av dessa buffertar behöver också någon
# variabel som håller reda på aktuell position i respektive buffert. Eftersom ett bibliotek ska
# implementeras måste nedanstående specifikation följas. Biblioteket ska ligga i en separat
# fil som kompileras och länkas tillsammans med testprogrammet Mprov64.s när sluttestet
# sker.
.data
    input_buffer: .space 64 
    output_buffer: .space 64 
    input_buffer_pos: .space 8
    output_buffer_pos: .space 8
    reverse_int_buffer: .space 64
    reverse_int_buffer_pos: .space 8
    .equ MAXPOS, 64

.text
# --- What we use registers for ---
# rbx = output buffer
# rcx = output buffer pos
# rdi = input buffer pos
# rsi = input buffer

# --- Egna funktioner ---
# OBS! Lägg till en extra pushq $0 / popq %rax i de funktioner som anropar externa funktioner.
put_into_output_buffer:
    # rbx = output buffer memory adress, rcx = output buffer pos, al = value to put into output buffer
    pushq %rbx # Caller owned register, save it
    # Calculate the correct position in the output buffer
    addq %rcx, %rbx # Add the position to the buffer to get the correct position
    # Put the value into the output buffer
    movb %al, (%rbx)

    # Terminate put_into_output_buffer
    pop %rbx
    ret


put_into_input_buffer:
    # rsi = input buffer memory adress, rdi = input buffer pos, al = value to put into input buffer
    # Calculate the correct position in the input buffer
    addq %rdi, %rsi # Add the position to the buffer to get the correct position
    # Put the value into the input buffer
    movb %al, (%rsi)

    # Terminate put_into_input_buffer
    ret


