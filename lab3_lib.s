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
    input_buffer_pos: .quad 0
    output_buffer_pos: .quad 0
    MAXPOS: .quad 64

# OBS! Lägg till en extra pushq $0 / popq %rax i de funktioner som anropar externa funktioner.
# Checked functions: setInPos, setOutPos, getOutPos, outImage, inImage, putInt, , putText, putChar
# Unchecked functions: getInt, getText, getChar

.text


# --------- Inmatning ---------

.global inImage
inImage:
    # Rutinen ska läsa in en ny textrad från tangentbordet till er inmatningsbuffert för indata
    # och nollställa den aktuella positionen i den. De andra inläsningsrutinerna kommer sedan att
    # jobba mot den här bufferten. Om inmatningsbufferten är tom eller den aktuella positionen
    # är vid buffertens slut när någon av de andra inläsningsrutinerna nedan anropas ska inImage
    # anropas av den rutinen, så att det alltid finns ny data att arbeta med.
    pushq $0
    movq $input_buffer, %rdi # arg1 for fgets. The buffer where fgets puts the input
    movq MAXPOS, %rsi # arg2 for fgets. How many bytes it can read
    movq stdin, %rdx # arg3 for fgets. From standard input
    call fgets
    
    # Reset input buffer position
    movq $0, input_buffer_pos

    # Terminate inImage
    pop %rax
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
    
    # Check if input buffer is full
    cmpq $input_buffer_pos, MAXPOS
    jl getInt_not_full_or_empty

    # Check if input buffer is empty
    movq    $input_buffer,%rax # Put buffer adress in rax
    addq    input_buffer_pos,%rax # Add on current position
    movb    (%rax), %al # Take first char
    cmpb    $0, %al # Is it zero
    jne getChar_not_full_or_empty # If its not zero we can proceed without calling inImage
    call inImage # Call inimage to refill

    getInt_not_full_or_empty:
        movq $input_buffer, %rdi # Input buffer start adress to rdi
        addq input_buffer_pos, %rdi # Add on current position
        call atoi # Returns in rax. Atoi gets first interger in string. If no int it returns zero
        movq %rax, %rdi # Save atoi output in rdi

        xorq %rax, %rax # Reset rax
        xorq %rcx, %rcx # Zero rcx (will use for length)

        movq $input_buffer, %r8 # Move the input buffer memory address to r8
        addq input_buffer_pos, %r8 # Add the input buffer position to r8
        movb (%r8), %al # Load the current character into al
        xorq %r8, %r8 # Reset r8

        cmpb $'-', %al 
        je handle_extra_sign # If we find a minus sign

        cmpb $'+', %al
        je handle_extra_sign # If we find a plus sign

        cmpb $' ', %al
        je handle_whitespace # If we find a whitespace

        cmpb $'\n', %al
        je redo_but_call_inImage # If we find a newline

        cmpb $'0', %al
        jle handle_true_zero # If we find a zero

        # If no numbers are found, return the value in rdi. It should be 0 since atoi didn't find any numbers
        cmpb $'0', %al
        jl handle_not_integer
        cmpb $'9', %al
        jg handle_not_integer

        # If we didn't find any prefixes, the int has same length as the buffer space it took
        jmp getInt_calc_pos_loop
        
    handle_not_integer:
        movq %rdi, %rax # Return the value in rax
        ret

    handle_true_zero:
        movq $0, %rax # Return 0 if we find a zero
        incq input_buffer_pos # Increment the input buffer position
        ret

    handle_whitespace:
        incq %rcx # Increment the length of the string
        incq input_buffer_pos # Increment the input buffer position
        jmp getInt_calc_pos_loop

    handle_extra_sign:
        addq $1, %rcx # Add one length since any whitespace/sign takes on place in buffer but not as an int

    getInt_calc_pos_loop:
        movq $input_buffer, %r8 # Get the start of the input buffer
        addq input_buffer_pos, %r8 # Add the current pos to the start of the input buffer
        addq %rcx, %r8 # Add the current length of the string to the current pos
        movb (%r8), %al # Get the character 

        # Exit loop if we find a non-integer character
        cmpb $'0', %al 
        jl exit_getInt_calc_pos_loop
        cmpb $'9', %al
        jg exit_getInt_calc_pos_loop

        incq %rcx # Increment the length of the string

        jmp getInt_calc_pos_loop

    exit_getInt_calc_pos_loop:
        movq input_buffer_pos, %r9 # Get current pos of input buffer
        addq %r9, %rcx # Add the true pos of the reverse buffer to the current pos
        movq %rcx, input_buffer_pos # Update the input buffer pos to this new pos
        movq %rdi, %rax # Return the value in rdi (put in rax)
        ret

    redo_but_call_inImage:
        incq input_buffer_pos # Increment the input buffer position
        call inImage # Call inImage to refill
        jmp getInt # Restart the getInt function


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
    movq %rsi, %r9 # n in r9
    movq %rdi, %r10 # buffert in r10

    getText_loop:
        call getChar # Get current char. getChar handles empty/full buffer
        cmpb $0, %al # Is char 0? Then we are done
        je exit_getText_loop # If so, exit

        cmpq $0, %r9 # Have we succeeded max number of chars to read?
        je exit_getText_loop # If so, exit

        movb %al, (%r10) # Move char to destination buf
        incq %r10 # Increase position 
        decq %r9 # Decrease counter

        jmp getText_loop # Loop

    exit_getText_loop:
        subq %rsi, %r9 # Calculate how many chars we read
        movq %r9, %rax # Return the value in rax
        ret 


.global getChar
getChar:
    # Rutinen ska returnera ett tecken från inmatningsbuffertens aktuella position och flytta
    # fram aktuell position ett steg i inmatningsbufferten ett steg. Om inmatningsbufferten är
    # tom eller aktuell position i den är vid buffertens slut vid anrop av getChar ska getChar
    # kalla på inImage, så att getChar alltid returnerar ett tecken ur inmatningsbufferten.
    # Returvärde: inläst tecken
    # output: rax = inläst tecken

    # Check if input buffer is empty
    movq    $input_buffer, %rax # Get buffer adress
    addq    input_buffer_pos, %rax # Add current pos
    movb    (%rax), %al # Get frist char
    cmpb    $0, %al # Is it zero?
    jne getChar_not_full_or_empty # If not zero we can skip the inImage call

    # Check if input buffer is full
    cmpq $input_buffer_pos, MAXPOS
    jl getChar_not_full_or_empty # If not full we can skip inImage call

    call inImage

    getChar_not_full_or_empty:
        movq $input_buffer, %rax # Load input buffer adress into r8
        addq input_buffer_pos, %rax # Add pos onto adress to get current adress
        movb (%rax), %al # Get that char

        incq input_buffer_pos # Increment the input buffer position

    # Terminate getChar
    ret


.global getInPos
getInPos:
    # Rutinen ska returnera aktuell buffertposition för inbufferten.
    # Returvärde: aktuell buffertposition (index)
    movq input_buffer_pos, %rax # Move the value of input_buffer_pos to rax
    ret

.global setInPos
setInPos:
    # Rutinen ska sätta aktuell buffertposition för inbufferten till n. n måste dock ligga i intervallet
    # [0,MAXPOS], där MAXPOS beror av buffertens faktiska storlek. Om n<0, sätt positionen
    # till 0, om n>MAXPOS, sätt den till MAXPOS.
    # Parameter: önskad aktuell buffertposition (index), n i texten.
    # input: rdi = n
    cmpq $0, %rdi # Compare the input to 0
    jle setInPos_zero # If it is less than zero, set to zero
    cmpq $MAXPOS, %rdi # Compare the input to MAXPOS
    jge setInPos_max # If it is greater than MAXPOS, set to MAXPOS
    movq %rdi, input_buffer_pos # Set the input buffer position to the input
    jmp exit_setInPos

    setInPos_zero:
        movq $0, input_buffer_pos # Set the input buffer position to 0
        jmp exit_setOutPos

    setInPos_max:
        movq $MAXPOS, input_buffer_pos # Set the input buffer position to MAXPOS
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
    
    movq %rdi, %rax # Save rdi in rax, since we need rdi to use putChar
    cmpq $0, %rax # Compare the int to 0
    jge putInt_input_positive # If it is greater than zero (not neg), use the convert loop
    movq $45, %rdi # Put ascii for minus sign in rdi
    call putChar # Put the minus sign with putchar
    imulq $-1, %rax # Reset to a positive number

    putInt_input_positive:
        movq $0, %rcx # Zero rcx (will use for length)
        movq $10, %r10 # will use for modulo
    putInt_convert_int_loop:
        # Get the least significant digit of the number
        # Remainder will be put in rdx
        # Quotient will be put in rax
        movq $0, %rdx
        idivq %r10

        # Convert the digit to ASCII and put it into correct pos in reverse_buffer
        addq $48, %rdx # Add 48 to get the ascii value for the int
        pushq %rdx # Push the ascii value to the stack

        incq %rcx # Increment counter

        # Check if we have a quotient left
        cmpq $0, %rax
        jne putInt_convert_int_loop # If we have a quotient left, continue loop

    putInt_put_loop:
        popq %rdi # Pop the ascii value from the stack. Put in rdi so we can use putChar
        call putChar # Put the char in the output buffer
        decq %rcx # Decrease the counter
        cmpq $0, %rcx # Check if we have more chars to put (counter is not zero)
        jne putInt_put_loop # If we have more chars to put, continue loop

    # Terminate putInt
    ret


.global putText
putText:
    # Rutinen ska lägga textsträngen som finns i buf från och med den aktuella positionen i
    # utbufferten. Glöm inte att uppdatera utbuffertens aktuella position innan rutinen lämnas.
    # Om bufferten blir full så ska ett anrop till outImage göras, så att man får en tömd utbuffert
    # att jobba vidare mot.
    # Parameter: adress som strängen ska hämtas till utbufferten ifrån (buf i texten)
    # Input: rdi = buf
    movq %rdi, %r10 # Move the input to r10 so we can use rdi in our loop

    putText_loop:
        cmpb $0, (%r10) # Check if the buf given as input is empty
        je exit_putText_loop # Exit
        movq (%r10), %rdi # If its not empty, move it to rdi so we can call putChar
        call putChar # Call putchar to put char. Putchar will handle if it gets full
        incq %r10 # Increment the r10 adress to read next char next time
        jmp putText_loop # Loop
        
    exit_putText_loop:
        # Terminate putText
        ret


.global putChar
putChar:
    # Rutinen ska lägga tecknet c i utbufferten och flytta fram aktuell position i den ett steg.
    # Om bufferten blir full när getChar anropas ska ett anrop till outImage göras, så att man
    # får en tömd utbuffert att jobba vidare mot.
    # Parameter: tecknet som ska läggas i utbufferten (c i texten)
    # input: rdi = c
    
    # Check if output buffer is full
    cmpq $output_buffer_pos, MAXPOS 
    jl putChar_not_full
    call outImage

    putChar_not_full:
        movq $output_buffer, %r8 # Load output buffer adress into r8
        addq output_buffer_pos, %r8 # Add pos onto adress to get current adress
        movq %rdi, (%r8) # Put the char into the output buffer

        incq output_buffer_pos # Increment the output buffer position

    ret


.global getOutPos
getOutPos:
    # Rutinen ska returnera aktuell buffertposition för utbufferten.
    # Returvärde: aktuell buffertposition (index)
    movq output_buffer_pos, %rax # Move the value of output_buffer_pos to rax
    ret


.global setOutPos
setOutPos:
    # Rutinen ska sätta aktuell buffertposition för utbufferten till n. n måste dock ligga i intervallet
    # [0,MAXPOS], där MAXPOS beror av utbuffertens storlek. Om n<0 sätt den till 0, om
    # n>MAXPOS sätt den till MAXPOS.
    # Parameter: önskad aktuell buffertposition (index), n i texten 
    # Input: rdi = n

    cmpq $0, %rdi # Compare the input to 0
    jle setOutPos_zero # If it is less than zero, set to zero
    cmpq $MAXPOS, %rdi # Compare the input to MAXPOS
    jge setOutPos_max # If it is greater than MAXPOS, set to MAXPOS
    movq %rdi, output_buffer_pos # Set the output buffer position to the input
    jmp exit_setOutPos

    setOutPos_zero:
        movq $0, output_buffer_pos # Set the output buffer position to 0
        jmp exit_setOutPos

    setOutPos_max:
        movq $MAXPOS, output_buffer_pos # Set the output buffer position to MAXPOS
        jmp exit_setOutPos

    exit_setOutPos:
        ret
