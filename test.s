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

inImage:
    pushq $0
    movq $input_buffer, %rdi # arg1
    movq $64, %rsi # arg2
    movq stdin, %rdx # arg3
    call fgets
    
    movq $0, input_buffer_pos # Reset input buffer position

    leaq input_buffer(%rip), %rdi
    call puts

    # Terminate inImage
    ret
