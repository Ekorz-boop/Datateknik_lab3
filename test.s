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
    input_buffer_length: .space 8
    output_buffer_length: .space 8

.text
.global main
main:
# --------- Inmatning ---------

# --- What we use registers for ---

# rcx = output buffer stuff
# 
# rdi = input buffer length
# rsi = input buffer
# 
#
#
#
#
#

put_in_buffer:
    # Function will put a value (8 bits) in the buffer at position.
    # rdi = buffer length/pos, rsi = buffer, rdx = value
    
    # Calculate the correct position (8 times length/pos)
    movq $8, %rcx
    imulq %rdi, %rcx
    # Move dl into buffer position (len * 8)
    addq %rsi, %rcx # Add the buffer position on top of the buffer adress
    movb %dl, (%rcx) # Move our 8 bits into the correct position
    


# Rutinen ska läsa in en ny textrad från tangentbordet till er inmatningsbuffert för indata
# och nollställa den aktuella positionen i den. De andra inläsningsrutinerna kommer sedan att
# jobba mot den här bufferten. Om inmatningsbufferten är tom eller den aktuella positionen
# är vid buffertens slut när någon av de andra inläsningsrutinerna nedan anropas ska inImage
# anropas av den rutinen, så att det alltid finns ny data att arbeta med.
inImage:
    pushq $0
    movq $0, %rdi # Reset input position

    movq $0, %rax # add call number of sys_read 
    movq $0, %rdi # load file descriptor for standard input
    movq input_buffer, %rsi # Pointer to our input buffer
    movq $64, %rdx # The size of our input buffer
    syscall # Returns syscall in rax

    # Save the number of bytes read by syscall
    movq %rax, %rbx

    leaq input_buffer, %rsi # Load input buffer in rsi
    movq input_buffer_length, %rdi # Load the length in rdi
    call put_in_input_buffer # Call the loop

    # Exit function
    popq %rax 
    ret

    put_in_input_buffer:
        # Read first 8 bits of the syscall return
        movb (%rax), %bl
        cmpq %bl, $0 # Check if zero (read all bytes)
        je exit_put_in_input_buffer
        # Calculate the correct position (8 times length/pos)
        movq $8, %rcx
        imulq %rdi, %rcx
        # Move bl into buffer position (len * 8)
        addq %rsi, %rcx # Add the buffer position on top of the buffer adress
        movb %bl, (%rcx) # Move our 8 bits into the correct position
        # Increment the length
        incq %rdi
        # Use bitwise shift to get rid of the first 8 bits so we read the next 8 bits
        # in the next iteration.
        shr $8, %rax
        # Do another loop
        jmp put_in_input_buffer

    exit_put_in_input_buffer:
        # Reset position/length of input buffer
        movq $0, %rdi
        ret # Return
