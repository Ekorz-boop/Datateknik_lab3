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
# Checked functions: setInPos, setOutPos, getOutPos, outImage, inImage, putInt, , putText, putChar
# Unchecked functions: getInt, getText, getChar

.text

# --- Egna funktioner ---

put_into_output_buffer:
    # al = value to put into output buffer
    movq $output_buffer, %r8 # Move the output buffer memory adress to r8
    addq output_buffer_pos, %r8 # Add the output buffer position to r8
    movb %al, (%r8) # Put the value into the output buffer

    # Terminate put_into_output_buffer
    ret


put_into_input_buffer:
    # al = value to put into input buffer
    movq $input_buffer, %r8 # Move the output buffer memory adress to r8
    addq input_buffer_pos, %r8 # Add the output buffer position to r8
    movb %al, (%r8) # Put the value into the input buffer

    # Terminate put_into_input_buffer
    ret


get_current_output_buffer_value:
    # Get the value of the current input buffer position
    movq $output_buffer, %r8 # Move the output buffer memory adress to r8
    addq output_buffer_pos, %r8 # Add the output buffer position to r8
    movb (%r8), %al
    ret


get_current_input_buffer_value:
    # Get the value of the current input buffer position
    movq $input_buffer, %r8 # Move the input buffer memory adress to r8
    addq input_buffer_pos, %r8 # Add the input buffer position to r8
    movb (%r8), %al
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
    movq $input_buffer, %rdi # arg1 for fgets. The buffer where fgets puts the input
    movq $MAXPOS, %rsi # arg2 for fgets. How many bytes it can read
    movq stdin, %rdx # arg3 for fgets. From standard input
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

    # Check if empty input_buffer or at last place in input_buffer
    call get_current_input_buffer_value
    cmpb $0, %al
    je getInt_call_inImage
    cmpb $MAXPOS, %al
    je getInt_call_inImage

    xorq %rax, %rax
    movq $1, %r8

    getInt_loop:
        call get_current_input_buffer_value # Returns in al

        cmpb $' ', %al # If whitespace
        je next_character

        cmpb $'-', %al # If minus sign
        je handle_minus

        cmpb $'+', %al # If plus sign
        je next_character

        cmpb $'\n', %al # If new line
        je next_character

        cmpb $'0', %al
        jl not_integer
        cmpb $'9', %al
        jg not_integer

        subb $'0', %al
        imulq $10, %rax
        addq %rax, %rax
        jmp next_character

    handle_minus:
        movq $-1, %r8
        jmp next_character

    not_integer:
        imulq %r8, %rax
        jmp exit_getInt_loop

    next_character:
        incq %rdi
        incq %rsi
        jmp getInt_loop

    getInt_call_inImage:
        call inImage
        jmp getInt_loop

    exit_getInt_loop:
        movq %rdi, input_buffer_pos
        ret


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
    xorq %rax, %rax  # Will use rax as counter. Set it to 0

    # Check if the input buffer is at the end. If it is we need to refill input buffer
    call get_current_input_buffer_value
    cmpb $MAXPOS, %al
    jge getText_call_inImage
    cmpb $0, %al
    jle getText_call_inImage

    getText_loop:
        # Check if we have read the maximum number of characters
        cmpq %r10, %rax
        je exit_getText_loop  # If we have, we are done
        call get_current_input_buffer_value # Returns in al
        # Check if the character is null
        cmpb $0, %al
        je exit_getText_loop  # If it is, we are done
        incq input_buffer_pos # Increment the input buffer position
        # Write the character to the destination buffer
        movb %al, (%r9)
        incq %r9  # Increment the destination buffer adress
        incq %rax  # Increment the counter
        je getText_call_inImage  # If we have call inImage
        
        jmp getText_loop

    getText_call_inImage:
        call inImage
        jmp getText_loop

    exit_getText_loop:
        # Null-terminate the string
        movb $0, (%r9)
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

    call get_current_output_buffer_value
    cmpb $MAXPOS, %al # Check if the output buffer is full
    je getChar_call_inImage # If we reached the end of buffer, call inImage to get new characters
    cmpb $0, %al # Check if first byte in buffer is zero (empty)
    je getChar_call_inImage  # If the value in al is 0, jump to getChar_call_inImage

    getChar_part2: # Just to find back after calling inimage

    movq $input_buffer, %r8 # Load input buffer adress into r8
    addq input_buffer_pos, %r8 # Add pos onto adress to get current adress
    movb (%r8), %al # Get that char

    incq input_buffer_pos # Increment the input buffer position

    # Terminate getChar
    ret

    getChar_call_inImage:
        call inImage
        jmp getChar_part2


.global setInPos
setInPos:
    # Rutinen ska sätta aktuell buffertposition för inbufferten till n. n måste dock ligga i intervallet
    # [0,MAXPOS], där MAXPOS beror av buffertens faktiska storlek. Om n<0, sätt positionen
    # till 0, om n>MAXPOS, sätt den till MAXPOS.
    # Parameter: önskad aktuell buffertposition (index), n i texten.
    # input: rdi = n
    cmpb $0, %dil
    je setInPos_zero
    cmpb $MAXPOS, %dil
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
    push $0 # Uses external function call so fix stack alignment

    movq $output_buffer, %rdi # Move value of outbuffer to rdi
    call puts # Puts prints buffer in rdi to terminal
    movq $0, output_buffer_pos # Reset output buffer position
    
    # Terminate outImage
    popq %rax
    ret


.global putInt
putInt:
    # Rutinen ska lägga ut talet n som sträng i utbufferten från och med buffertens aktuella
    # position. Glöm inte att uppdatera aktuell position innan rutinen lämnas.
    # Parameter: tal som ska läggas in i bufferten (n i texten)
    # input: rdi = int
    
    movq $0, reverse_int_buffer_pos # Reset reverse buffer pos

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
        movq reverse_int_buffer, %r8
        addq reverse_int_buffer_pos, %r8
        movb %dl, (%r8) # Put the value into the reverse buffer

        # Increment the reverse buffer position
        incq reverse_int_buffer_pos

        # Update %rdi with the quotient of the division
        movq %rax, %rdi

        # Continue loop with the next digit
        jmp convert_int_loop

    copy_reverse_loop:
        # Check if reverse buffer is empty
        cmpq $0, reverse_int_buffer_pos
        jle exit_putInt

        # Copy the character from reverse_buffer to output_buffer
        movq reverse_int_buffer, %r8
        addq reverse_int_buffer_pos, %r8
        movb (%r8), %al
        call put_into_output_buffer

        # Decrement reverse_buffer_pos
        decq reverse_int_buffer_pos
        # Increment output_buffer_pos
        incq output_buffer_pos
        # Continue with the next character
        jmp copy_reverse_loop

    exit_putInt:
        ret


.global putText
putText:
    # Rutinen ska lägga textsträngen som finns i buf från och med den aktuella positionen i
    # utbufferten. Glöm inte att uppdatera utbuffertens aktuella position innan rutinen lämnas.
    # Om bufferten blir full så ska ett anrop till outImage göras, så att man får en tömd utbuffert
    # att jobba vidare mot.
    # Parameter: adress som strängen ska hämtas till utbufferten ifrån (buf i texten)
    # Input: rdi = buf

    # Check if the output buffer is full
    call get_current_output_buffer_value
    cmpb $MAXPOS, %al # Check if the output buffer is full
    jne putText_loop # If it's not full, continue with the loop
    call outImage # If it's full, call outImage to empty the output buffer

    putText_loop:
        movb output_buffer, %al # Get first 8 bits of the string
        cmpb $0, %al # Check if it's 0, if it is we are done
        je exit_putText_loop
        
        # Move the first 8 bits of n into the output buffer at the current position
        # rbx = output buffer memory adress, rcx = output buffer pos, al = value to put into output buffer
        call put_into_output_buffer
        
        call get_current_output_buffer_value
        cmpb $MAXPOS, %al # Check if the output buffer is full
        je putText_outImage 
        continue_after_putText_outImage:
        inc %rdi # Move to the next character in the string
        inc output_buffer_pos # Increment the output buffer position
        jmp putText_loop # Continue with the next character

    exit_putText_loop:
        ret

    putText_outImage:
        call outImage
        jmp continue_after_putText_outImage


.global putChar
putChar:
    # Rutinen ska lägga tecknet c i utbufferten och flytta fram aktuell position i den ett steg.
    # Om bufferten blir full när getChar anropas ska ett anrop till outImage göras, så att man
    # får en tömd utbuffert att jobba vidare mot.
    # Parameter: tecknet som ska läggas i utbufferten (c i texten)
    # input: rdi = c
    call getChar # Get character c from input buffer

    cmpq $MAXPOS, output_buffer # Check if the output buffer is full
    je putChar_outImage # If the output buffer is full, call outImage to empty it
    
    call put_into_output_buffer # Move the character to the output buffer
    inc output_buffer_pos # Increment the output buffer position
    jmp exit_putChar # Done, let's exit

    putChar_outImage:
        call outImage # Call outImage to empty the output buffer
        call put_into_output_buffer # Move the character to the output buffer
        inc output_buffer_pos # Increment the output buffer position

    exit_putChar:
        # Terminate putChar
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
