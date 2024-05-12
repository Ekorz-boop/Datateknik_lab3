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

.text
.global main
main:
# --------- Inmatning ---------

# --- What we use registers for ---

# rbx = output buffer
# rcx = output buffer pos
# rdi = input buffer pos
# rsi = input buffer





# Rutinen ska läsa in en ny textrad från tangentbordet till er inmatningsbuffert för indata
# och nollställa den aktuella positionen i den. De andra inläsningsrutinerna kommer sedan att
# jobba mot den här bufferten. Om inmatningsbufferten är tom eller den aktuella positionen
# är vid buffertens slut när någon av de andra inläsningsrutinerna nedan anropas ska inImage
# anropas av den rutinen, så att det alltid finns ny data att arbeta med.
inImage:
    pushq $0

    movq $0, %rax # add call number of sys_read 
    movq $0, %rdi # load file descriptor for standard input
    leaq input_buffer, %rsi # Pointer to our input buffer
    movq $64, %rdx # The size of our input buffer
    syscall # Returns syscall in input buffer
    
    movq $0, input_buffer_length # Reset input position

    # Terminate
    popq %rax
    ret
