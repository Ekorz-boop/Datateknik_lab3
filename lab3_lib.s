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

# OBS! Lägg till en extra pushq $0 / popq %rax i de funktioner som anropar externa funktioner.
# Checked functions: setInPos, setOutPos, getOutPos, outImage
# Unchecked functions: inImage, getInt, getText, getChar, putInt, putText, putChar

.text
# --- What we use registers for ---
# rbx = output buffer
# rcx = output buffer pos
# rdi = input buffer pos
# rsi = input buffer

# --- Egna funktioner ---

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


# --------- Inmatning ---------

.global inImage
inImage:
    # Rutinen ska läsa in en ny textrad från tangentbordet till er inmatningsbuffert för indata
    # och nollställa den aktuella positionen i den. De andra inläsningsrutinerna kommer sedan att
    # jobba mot den här bufferten. Om inmatningsbufferten är tom eller den aktuella positionen
    # är vid buffertens slut när någon av de andra inläsningsrutinerna nedan anropas ska inImage
    # anropas av den rutinen, så att det alltid finns ny data att arbeta med.
    pushq $0 # Uses external function call
    movq $input_buffer, %rdi # arg1 for fgets
    movq $MAXPOS, %rsi # arg2 for fgets
    movq stdin, %rdx # arg3 for fgets
    call fgets
    
    movq $0, input_buffer_pos # Reset input buffer position

    # Terminate inImage
    popq %rax
    ret


.global getInt
getInt:
    # Rutinen ska tolka en sträng som börjar på aktuell buffertposition i inbufferten och fortsätta
    # tills ett tecken som inte kan ingå i ett heltal påträffas. Den lästa substrängen översätts till
    # heltalsformat och returneras. Positionen i bufferten ska vara det första tecken som inte
    # ingick i det lästa talet när rutinen lämnas. Inledande blanktecken i talet ska vara tillåtna.
    # Ett plustecken eller ett minustecken ska kunna inleda talet och vara direkt följt av en eller
    # flera heltalssiffror. Ett tal utan inledande plus eller minus ska alltid tolkas som positivt.
    # Om inmatningsbufferten är tom eller om den aktuella positionen i inmatningsbufferten
    # är vid dess slut vid anrop av getInt ska getInt kalla på inImage, så att getInt alltid
    # returnerar värdet av ett inmatat tal.
    # Returvärde: inläst heltal
    # Load input buffer and get the position
    movq input_buffer_pos, %rdi # Get the current position of the input buffer
    leaq input_buffer, %rsi # Get the input buffer memory address

    xorq %rax, %rax  # Clear %rax to store the result
    movq $1, %r8  # Set %r8 to 1, it will be used to handle negative numbers

    # Check if empty input_buffer
    cmpq $0, %rdi
    je getInt_call_inImage
    # Check if at last place in input_buffer
    cmpq $MAXPOS, %rdi
    je getInt_call_inImage

    getInt_loop:
        movb (%rsi), %al # Move first char from input buffer into al

        # Check for whitespace
        cmpb $' ', %al
        je next_character

        # Check for minus sign
        cmpb $'-', %al
        je handle_minus

        # Check for plus sign
        cmpb $'+', %al
        je next_character

        # Check if the character is a digit
        cmpb $'0', %al
        jl not_integer
        cmpb $'9', %al
        jg not_integer


        # Kommer skriva över sig själv
        # Convert the ASCII character to a digit and add it to the result
        subb $'0', %al
        imulq $10, %rax
        addq %rax, %rax
        jmp next_character

    handle_minus:
        movq $-1, %r8
        jmp next_character

    not_integer:
        imulq %r8, %rax  # Apply the sign to the result
        jmp exit_getInt_loop

    next_character:
        incq %rdi
        incq %rsi
        jmp getInt_loop

    end_of_buffer:
        call inImage
        jmp getInt_loop

    exit_getInt_loop:
        movq %rdi, input_buffer_pos # Update input buffer position
        ret

    getInt_call_inImage:
        call inImage
        jmp getInt_loop


.global getText
getText:
    # Rutinen ska överföra maximalt n tecken från aktuell position i inbufferten och framåt till
    # minnesplats med början vid buf. När rutinen lämnas ska aktuell position i inbufferten vara
    # första tecknet efter den överförda strängen. Om det inte finns n st. tecken kvar i inbufferten
    # avbryts överföringen vid slutet av bufferten. Returnera antalet verkligt överförda tecken.
    # Om inmatningsbufferten är tom eller aktuell position i den är vid buffertens slut vid anrop
    # av getText ska getText kalla på inImage, så att getText alltid läser över någon sträng
    # till minnesutrymmet sombuf pekar till. Kom ihåg att en sträng per definition är NULLterminerad.
    # Parameter 1: adress till minnesutrymme att kopiera sträng till från inmatningsbufferten
    # (buf i texten)
    # Parameter 2: maximalt antal tecken att läsa från inmatningsbufferten (n i texten)
    # Returvärde: antal överförda tecken
    # Input: rsi = n, %rdi = buffert to move to
    # Save the inputs to r9 and r10
    movq %rdi, %r9  # Save the destination buffer address
    movq %rsi, %r10  # Save the maximum number of characters to read

    # Load input buffer and get the position
    movq input_buffer_pos, %rdi # Get the current position of the input buffer
    leaq input_buffer, %rsi # Get the input buffer memory adress
    
    xorq %rax, %rax  # Set counter to 0

    # Check if the input buffer is at the end. If it is we need to refill input buffer
    cmpq $MAXPOS, %rdi
    jge getText_call_inImage

    getText_loop:
        # Check if we have read the maximum number of characters
        cmpq %r10, %rax
        je exit_getText_loop  # If we have, we are done
        # Read first character from the input buffer into al
        movb (%rsi), %al
        # Check if the character is null
        cmpb $0, %al
        je exit_getText_loop  # If it is, we are done
        incq %rdi  # Increment the input buffer position
        incq %rsi  # Increment the input buffer memory adress
        # Write the character to the destination buffer
        movb %al, (%r9)
        incq %r9  # Increment the destination buffer position
        incq %rax  # Increment the counter
        # Check if we have reached the end of the input buffer
        cmpq $MAXPOS, %rdi
        je getText_call_inImage  # If we have call inImage
        
        jmp getText_loop

    getText_call_inImage:
        call inImage
        jmp getText_loop

    exit_getText_loop:
        # Null-terminate the string
        movb $0, (%r9)
        # Update input buffer position
        movq %rdi, input_buffer_pos
        # Calculate and return the num of chars read
        ret


.global getChar
getChar:
    # Rutinen ska returnera ett tecken från inmatningsbuffertens aktuella position och flytta
    # fram aktuell position ett steg i inmatningsbufferten ett steg. Om inmatningsbufferten är
    # tom eller aktuell position i den är vid buffertens slut vid anrop av getChar ska getChar
    # kalla på inImage, så att getChar alltid returnerar ett tecken ur inmatningsbufferten.
    # Returvärde: inläst tecken
    # output: rax = inläst tecken
    movq input_buffer_pos, %rdi # Get the current position of the input buffer
    leaq input_buffer, %rsi # Get the input buffer memory adress

    cmpq $MAXPOS, %rdi # Check if we are at max pos
    je getChar_call_inImage # If we reached the end of buffer, call inImage to get new characters

    cmpq $0, %rdi  # If pos is zero its empty
    je getChar_call_inImage # If we have an empty buffer, call inImage to get new characters

    getChar_part2: # Just to find back after calling inimage

    addq %rdi, %rsi # Add pos onto adress to get current adress
    movb (%rsi), %al # Get that char

    cmpq $0, %rdi  # Check if input pos is zero, since this means we did inImage and thus shouldnt increment
    jne increment_pos # If its not at the first pos we should increment
    jmp exit_getChar

    getChar_call_inImage:
        call inImage
        jmp getChar_part2

    increment_pos: 
        incq %rdi # Increment the position

    exit_getChar:
        # Terminate getChar
        movq %rdi, input_buffer_pos # Update input buffer position
        ret


.global setInPos
setInPos:
    # Rutinen ska sätta aktuell buffertposition för inbufferten till n. n måste dock ligga i intervallet
    # [0,MAXPOS], där MAXPOS beror av buffertens faktiska storlek. Om n<0, sätt positionen
    # till 0, om n>MAXPOS, sätt den till MAXPOS.
    # Parameter: önskad aktuell buffertposition (index), n i texten.
    # input: rdi = n
    cmpb $0, %dil
    je setInPos_zero
    cmpb MAXPOS, %dil
    je setInPos_max
    movb %dil, input_buffer_pos
    jmp exit_setInPos

    setInPos_zero:
        movq $0, input_buffer_pos
        jmp exit_setOutPos

    setInPos_max:
        movq $MAXPOS, input_buffer_pos
        jmp exit_setOutPos

    exit_setInPos:
        ret


# --------- Utmatning ---------

.global outImage
outImage:
    # Rutinen ska skriva ut strängen som ligger i utbufferten i terminalen. Om någon av de
    # övriga utdatarutinerna når buffertens slut, så ska ett anrop till outImage göras i dem, så
    # att man får en tömd utbuffert att jobba mot.
    push $0 # Uses external function call
    # Move value fo outbuffer to rbx
    movq $output_buffer, %rdi
    call puts
    # Reset position
    movq $0, output_buffer_pos
    # Terminate outImage
    popq %rax
    ret


.global putInt
putInt:
    # Rutinen ska lägga ut talet n som sträng i utbufferten från och med buffertens aktuella
    # position. Glöm inte att uppdatera aktuell position innan rutinen lämnas.
    # Parameter: tal som ska läggas in i bufferten (n i texten)
    # input: rdi = int
    pushq %rbx # Caller owned register, save it
    movq output_buffer_pos, %rcx  # Move the current outoput position into rcx
    leaq output_buffer, %rbx # Load output buffer into rbx
    
    # Initialize reverse_buffer stuff
    leaq reverse_int_buffer, %r8
    movq reverse_int_buffer_pos, %r9
    movq $0, %r9 # Reset reverse buffer pos

    convert_int_loop:
        # Check if the number is 0, if it is we are done
        cmpq $0, %rdi
        je copy_reverse_loop
        
        # Get the least significant digit of the number
        # Remainder in rdx
        # Quotient in rax
        # Put rdi in rax
        movq %rdi, %rax
        movq $10, %r10
        xorq %rdx, %rdx
        divq %r10

        # Convert the digit to ASCII and put it into correct pos in reverse_buffer
        addb $48, %dl
        movb %dl, (%r8, %r9, 1)

        # Increment the reverse buffer position
        incq %r9

        # Update %rdi with the quotient of the division
        movq %rax, %rdi

        # Continue loop with the next digit
        jmp convert_int_loop

    copy_reverse_loop:
        # Check if reverse buffer is empty
        cmpq $0, %r9
        je exit_putInt

        # Copy the character from reverse_buffer to output_buffer
        movb reverse_int_buffer(%rcx), %bl
        movb %bl, %al
        call put_into_output_buffer

        # Decrement reverse_buffer_pos
        decq %r9
        # Increment output_buffer_pos
        incq %rcx

        # Continue with the next character
        jmp copy_reverse_loop

    exit_putInt:
        movq %rcx, output_buffer_pos # Update output buffer position
        popq %rbx
        ret


.global putText
putText:
    # Rutinen ska lägga textsträngen som finns i buf från och med den aktuella positionen i
    # utbufferten. Glöm inte att uppdatera utbuffertens aktuella position innan rutinen lämnas.
    # Om bufferten blir full så ska ett anrop till outImage göras, så att man får en tömd utbuffert
    # att jobba vidare mot.
    # Parameter: adress som strängen ska hämtas till utbufferten ifrån (buf i texten)
    # Input: rdi = buf
    leaq output_buffer, %rbx
    movq output_buffer_pos, %rcx

    # Check if the output buffer is full

    putText_loop:
        # Get first 8 bits of the string
        movb (%rdi), %al
        # Check if it's 0, if it is we are done
        cmpb $0, %al
        je exit_putText_loop
        # Move the first 8 bits of n into the output buffer at the current position
        # rbx = output buffer memory adress, rcx = output buffer pos, al = value to put into output buffer
        call put_into_output_buffer
        # Increment position (check so we don't go out of bounds first)
        cmpq $64, %rcx
        je putText_outImage
        part2:
        inc %rdi
        inc %rcx
        jmp putText_loop

    exit_putText_loop:
        movq %rcx, output_buffer_pos
        ret

    putText_outImage:
        call outImage
        jmp part2


.global putChar
putChar:
    # Rutinen ska lägga tecknet c i utbufferten och flytta fram aktuell position i den ett steg.
    # Om bufferten blir full när getChar anropas ska ett anrop till outImage göras, så att man
    # får en tömd utbuffert att jobba vidare mot.
    # Parameter: tecknet som ska läggas i utbufferten (c i texten)
    # input: rdi = c
    pushq %rbx # Caller owned register, save it
    call getChar # Get character c from input buffer
    # Check if the output buffer is full
    leaq output_buffer, %rbx
    movq output_buffer_pos, %rcx
    cmpq $MAXPOS, %rcx
    je putChar_outImage # If the output buffer is full, call outImage to empty it
    # Move the character to the output buffer
    call put_into_output_buffer
    # Increment the output buffer position
    inc %rcx

    putChar_outImage:
        call outImage
        # Move the character to the output buffer
        call put_into_output_buffer
        # Increment the output buffer position
        inc %rcx

    # Terminate putChar
    movq %rcx, output_buffer_pos # Update output buffer position
    popq %rbx
    ret


.global getOutPos
getOutPos:
    # Rutinen ska returnera aktuell buffertposition för utbufferten.
    # Returvärde: aktuell buffertposition (index)
    movq output_buffer_pos, %rax
    ret


.global setOutPos
setOutPos:
    # Rutinen ska sätta aktuell buffertposition för utbufferten till n. n måste dock ligga i intervallet
    # [0,MAXPOS], där MAXPOS beror av utbuffertens storlek. Om n<0 sätt den till 0, om
    # n>MAXPOS sätt den till MAXPOS.
    # Parameter: önskad aktuell buffertposition (index), n i texten 
    # Input: rdi = n
    cmpb $0, %dil
    je setOutPos_zero
    cmpb $MAXPOS, %dil
    je setOutPos_max
    movb %dil, output_buffer_pos
    jmp exit_setOutPos

    setOutPos_zero:
        movq $0, output_buffer_pos
        jmp exit_setOutPos

    setOutPos_max:
        movq $MAXPOS, output_buffer_pos
        jmp exit_setOutPos

    exit_setOutPos:
        ret
