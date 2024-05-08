# Uppgiften går ut på att implementera rutiner för att hantera inmatning och utmatning av
# data. För att klara av det behöver man reservera plats för två olika systembuffertar, en
# för inmatning och en för utmatning. Var och en av dessa buffertar behöver också någon
# variabel som håller reda på aktuell position i respektive buffert. Eftersom ett bibliotek ska
# implementeras måste nedanstående specifikation följas. Biblioteket ska ligga i en separat
# fil som kompileras och länkas tillsammans med testprogrammet Mprov64.s när sluttestet
# sker.
.data
    input_buffer: .space 2048 # 2 KB
    output_buffer: .space 2048 # 2 KB
    input_position: .word 0 # position in input_buffer
    output_position: .word 0 # position in output_buffer

.text
# --------- Inmatning ---------

# Rutinen ska läsa in en ny textrad från tangentbordet till er inmatningsbuffert för indata
# och nollställa den aktuella positionen i den. De andra inläsningsrutinerna kommer sedan att
# jobba mot den här bufferten. Om inmatningsbufferten är tom eller den aktuella positionen
# är vid buffertens slut när någon av de andra inläsningsrutinerna nedan anropas ska inImage
# anropas av den rutinen, så att det alltid finns ny data att arbeta med.
inImage:
    movl $3, %eax # add call number of sys_read into eax
    movl $0, %ebx # load file descriptor for standard input in ebx
    movl input_buffer, %ecx # Pointer to our input buffer
    movl $2048, %edx # The size of our input buffer

    int $0x80 # Make system call
    movb $0, [input_position] # Reset input position

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
getInt:
    movq input_position, %rbx      # Load current input position
    movq %rbx, %rdi                # Save initial position for later
    movq $0, %rcx                  # Initialize the integer value to zero
    movq $1, %rax                  # Set a flag to determine if the number is positive or negative (1 for positive, 0 for negative)
    movb (%rbx), %al               # Load the first character

    skip_whitespace:
        cmpb $' ', %al                 # Compare with space
        je  skip_whitespace_continue   # If space, continue skipping
        cmpb $'\t', %al                # Compare with tab
        je  skip_whitespace_continue   # If tab, continue skipping
        cmpb $'\n', %al                # Compare with newline
        je  skip_whitespace_continue   # If newline, continue skipping
        jmp parse_integer              # Otherwise, start parsing the integer

    skip_whitespace_continue:
        incq %rbx                      # Move to next character
        movb (%rbx), %al               # Load the next character
        testb %al, %al                 # Check for end of string
        jz  getInt_finished            # If end of string, finish parsing

    parse_integer:
        cmpb $'+', %al                 # Check if it's a positive sign
        je  positive_sign              # If positive sign, skip
        cmpb $'-', %al                 # Check if it's a negative sign
        jne parse_digit                # If not a sign, parse as digit

    positive_sign:
        incq %rbx                      # Move past the sign
        movq $1, %rax                  # Set flag for positive number
        movb (%rbx), %al               # Load the next character

    parse_digit:
        subb $'0', %al                 # Convert ASCII character to digit
        cmpb $0, %al                   # Check if it's a digit
        jl  getInt_finished            # If not a digit, finish parsing
        cmpb $9, %al                   # Check if it's greater than 9
        jg  getInt_finished            # If greater than 9, finish parsing

        movq %rcx, %rdx                # Move the current value to %rdx
        imulq $10, %rcx                # Multiply current value by 10
        addq %rax, %rcx                # Add the new digit to the current value

        # Check for overflow
        movq %rcx, %rsi                # Move the result to %rsi
        movq $0xFFFFFFFFFFFFFFFF, %rdi # Load a value with all bits set to 1
        shrq $63, %rdi                 # Shift to get a value of 1 if negative or 0 if positive
        xorq %rdi, %rsi                # Flip the bits if the number is negative
        cmpq %rsi, %rdx                # Compare with the previous value
        jne getInt_finished            # If overflow, finish parsing

        incq %rbx                      # Move to the next character
        movb (%rbx), %al               # Load the next character
        testb %al, %al                 # Check for end of string
        jz  getInt_finished            # If end of string, finish parsing
        jmp parse_digit                # Otherwise, continue parsing

    getInt_finished:
        movq %rbx, input_position      # Update input position
        movq %rcx, %rax                # Return the parsed integer
        testq %rax, %rax               # Check if it's negative
        jnz  getInt_negative           # If negative, skip negating the number
        ret                            # If positive, return the integer

    getInt_negative:
        negq %rax                      # Negate the integer
        ret                            # Return the negative integer
    
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
getText:
    movq input_position, %rbx      # Load current input position
    movq %rbx, %rdi                # Save initial position for later
    movq %rdi, %r8                 # Save initial position for counting characters
    movq $0, %rax                  # Initialize counter for transferred characters
    movq %rsi, %r9                 # Load maximum number of characters to transfer

    cmpq $0, %r9                   # Check if maximum number of characters is zero
    je  getText_finished           # If zero, finish immediately

    copy_loop:
        movb (%rbx), %al               # Load character from input buffer
        testb %al, %al                 # Check for end of string
        jz  getText_finished           # If end of string, finish

        cmpq %r8, %rbx                 # Compare with initial position
        je  copy_done                  # If reached initial position, finish

        movb %al, (%rdi)               # Copy character to destination buffer
        incq %rbx                      # Move to the next character
        incq %rdi                      # Move to the next destination position
        incq %rax                      # Increment the counter for transferred characters
        decq %r9                       # Decrement the remaining characters
        cmpq $0, %r9                   # Check if remaining characters is zero
        je  getText_finished           # If zero, finish

        jmp copy_loop                  # Repeat the copy loop

    copy_done:
        movq %rbx, input_position      # Update input position
        jmp getText_finished

    getText_finished:
        movq %rax, %rax                # Return the number of transferred characters
        ret                            # Return from the routine

# Rutinen ska returnera ett tecken från inmatningsbuffertens aktuella position och flytta
# fram aktuell position ett steg i inmatningsbufferten ett steg. Om inmatningsbufferten är
# tom eller aktuell position i den är vid buffertens slut vid anrop av getChar ska getChar
# kalla på inImage, så att getChar alltid returnerar ett tecken ur inmatningsbufferten.
# Returvärde: inläst tecken
getChar:
    movq input_position, %rbx      # Load current input position
    movb (%rbx), %al               # Load character from input buffer
    testb %al, %al                 # Check for end of string
    jnz  getChar_increment         # If not end of string, increment position
    call inImage                   # If end of string, read new data into input buffer
    movq input_position, %rbx      # Reload current input position
    movb (%rbx), %al               # Reload character from input buffer

getChar_increment:
    incq input_position            # Move to the next character
    ret                            # Return the read character

# Rutinen ska returnera aktuell buffertposition för inbufferten.
# Returvärde: aktuell buffertposition (index)
getInPos:
    movq input_position, %rax   # Load the address of input_position into %rax
    movq (%rax), %rax           # Dereference the address to get the current position
    ret                         # Return the current position

# Rutinen ska sätta aktuell buffertposition för inbufferten till n. n måste dock ligga i intervallet
# [0,MAXPOS], där MAXPOS beror av buffertens faktiska storlek. Om n<0, sätt positionen
# till 0, om n>MAXPOS, sätt den till MAXPOS.
# Parameter: önskad aktuell buffertposition (index), n i texten.
setInPos:
    movq %rdi, %rax                 # Load the desired position into %rax
    cmpq $0, %rax                   # Compare with 0
    jl  setInPos_negative_check     # If less than 0, jump to setInPos_negative_check
    movq $2047, %rdx                # Load the maximum position (MAXPOS) into %rdx
    cmpq %rdx, %rax                 # Compare with MAXPOS
    jle setInPos_update             # If less than or equal to MAXPOS, jump to setInPos_update
    movq $2047, %rax                # Set the position to MAXPOS
    jmp setInPos_update             # Jump to setInPos_update

    setInPos_negative_check:
        movq $0, %rax                   # Set the position to 0

    setInPos_update:
        movq %rax, input_position       # Store the new position in input_position
        ret                             # Return from the routine

# --------- Utmatning ---------

# Rutinen ska skriva ut strängen som ligger i utbufferten i terminalen. Om någon av de
# övriga utdatarutinerna når buffertens slut, så ska ett anrop till outImage göras i dem, så
# att man får en tömd utbuffert att jobba mot.
outImage:
    movl $4, %eax
    movl $1, %ebx
    movl output_buffer, %ecx
    movl $2048, %edx

    int $0x80 # Make system call
    movl $0, [output_position] # Reset output position

    ret

# Rutinen ska lägga ut talet n som sträng i utbufferten från och med buffertens aktuella
# position. Glöm inte att uppdatera aktuell position innan rutinen lämnas.
# Parameter: tal som ska läggas in i bufferten (n i texten)
    # Param: eax = int that should be put into the output buffer
putInt:
    movl output_buffer, %edi
    addl output_position, %edi # add current buffer position to the pointer
    movl $10, %ecx # put 10 in ecx for the division later

    convert_to_string:
        # 
        xorl %edx, %edx # clear edx
        divl %ecx # divide eax by 10, result in eax, remainder in edx
        addb "0", %dl  # make into ASCII
        decl %edi # decrease the buffer position
        xorl %edi, %edi # zero out edi
        movb %dl, %dil # store ASCII character in buffer
        testl %eax, %eax # check if eax is zero (ie all digits are handled)
        jne convert_to_string # if eax isn't zero do again

    # Update the buffer position
    incq [output_position]

    ret

# Rutinen ska lägga textsträngen som finns i buf från och med den aktuella positionen i
# utbufferten. Glöm inte att uppdatera utbuffertens aktuella position innan rutinen lämnas.
# Om bufferten blir full så ska ett anrop till outImage göras, så att man får en tömd utbuffert
# att jobba vidare mot.
# Parameter: adress som strängen ska hämtas till utbufferten ifrån (buf i texten)
putText:
    mov %rsi, %rdi # Copy string to rdi

    next_char:
        movb %sil, %al  # Load the next character
        testb %al, %al # Check for end of string
        jz done # If it is the end of the string, finish

        cmpq $2048, [output_position] # Check if the buffer is full
        jge full_buffert_put_text # If the buffer is full go to full_buffert

        movl output_position, %edx
        movb %al, output_buffer(%edx)
        incq [output_position] # Increase the buffer position
        incq %rsi # Move to the next character
        jmp next_char # Repeat for the next character

    full_buffert_put_text:
        call outImage # Empty the buffer
        movq $0, [output_position] # Reset buffer position
        jmp next_char # Repeat for the next character

    done: 
        ret

# Rutinen ska lägga tecknet c i utbufferten och flytta fram aktuell position i den ett steg.
# Om bufferten blir full när getChar anropas ska ett anrop till outImage göras, så att man
# får en tömd utbuffert att jobba vidare mot.
# Parameter: tecknet som ska läggas i utbufferten (c i texten)
putChar:
    cmpq $2048, [output_position]
    jge full_buffert_put_char # if buffer is full, call full_buffert

    movl output_position, %edx
    movb %al, output_buffer(%edx)
    incq [output_position] # increase buffer position
    
    full_buffert_put_char:
        call outImage # Empty the buffer
        movq $0, [output_position] # Reset buffer position
        movl output_position, %edx
        movb %al, output_buffer(%edx)
        incq [output_position] # Update the buffer position
    ret

# Rutinen ska returnera aktuell buffertposition för utbufferten.
# Returvärde: aktuell buffertposition (index)
getOutPos:
    movq output_position, %rax  # Load the current output position into %rax
    ret                          # Return from the routine

# Rutinen ska sätta aktuell buffertposition för utbufferten till n. n måste dock ligga i intervallet
# [0,MAXPOS], där MAXPOS beror av utbuffertens storlek. Om n<0 sätt den till 0, om
# n>MAXPOS sätt den till MAXPOS.
# Parameter: önskad aktuell buffertposition (index), n i texten
setOutPos:
    movq %rdi, %rax                 # Load the desired position into %rax
    cmpq $0, %rax                   # Compare with 0
    jl  setOutPos_negative_check    # If less than 0, jump to setOutPos_negative_check
    movq $2047, %rdx                # Load the maximum position (MAXPOS) into %rdx
    cmpq %rdx, %rax                 # Compare with MAXPOS
    jle setOutPos_update            # If less than or equal to MAXPOS, jump to setOutPos_update
    movq $2047, %rax                # Set the position to MAXPOS
    jmp setOutPos_update            # Jump to setOutPos_update

    setOutPos_negative_check:
        movq $0, %rax                   # Set the position to 0

    setOutPos_update:
        movq %rax, output_position     # Store the new position in output_position
        ret                             # Return from the routine
