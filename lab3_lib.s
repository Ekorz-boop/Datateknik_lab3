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
# --- What we use registers for ---
# rbx = output buffer
# rcx = output buffer pos
# rdi = input buffer pos
# rsi = input buffer

# --- Egna funktioner ---
# OBS! Lägg till en extra pushq $0 / popq %rax i de funktioner som anropar externa funktioner.
put_into_output_buffer:
    # rbx = output buffer memory adress, rcx = output buffer pos, al = value to put into output buffer
    pushq $0
    pushq %rbx # Caller owned register, save it
    # Calculate the correct position in the output buffer
    imulq $8, %rcx, %r8 # Multiply the current position with 8 to get the correct position in the buffer
    addq %r8, %rbx # Add the position to the buffer to get the correct position
    # Put the value into the output buffer
    movb %al, (%rbx)

    # Terminate put_into_output_buffer
    pop %rbx
    ret


put_into_input_buffer:
    pushq $0
    # rsi = input buffer memory adress, rdi = input buffer pos, al = value to put into input buffer
    # Calculate the correct position in the input buffer
    imulq $8, %rdi, %r8 # Multiply the current position with 8 to get the correct position in the buffer
    addq %r8, %rsi # Add the position to the buffer to get the correct position
    # Put the value into the input buffer
    movb %al, (%rsi)

    # Terminate put_into_input_buffer
    ret


# --------- Inmatning ---------
# Rutinen ska läsa in en ny textrad från tangentbordet till er inmatningsbuffert för indata
# och nollställa den aktuella positionen i den. De andra inläsningsrutinerna kommer sedan att
# jobba mot den här bufferten. Om inmatningsbufferten är tom eller den aktuella positionen
# är vid buffertens slut när någon av de andra inläsningsrutinerna nedan anropas ska inImage
# anropas av den rutinen, så att det alltid finns ny data att arbeta med.
.global inImage
inImage:
    push $0
    movq $input_buffer, %rdi # arg1
    movq $64, %rsi # arg2
    movq stdin, %rdx # arg3
    call fgets
    
    movq $0, input_buffer_pos # Reset input buffer position

    # Terminate inImage
    ret


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
.global getInt
getInt:
    
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
.global getText
getText:

# Rutinen ska returnera ett tecken från inmatningsbuffertens aktuella position och flytta
# fram aktuell position ett steg i inmatningsbufferten ett steg. Om inmatningsbufferten är
# tom eller aktuell position i den är vid buffertens slut vid anrop av getChar ska getChar
# kalla på inImage, så att getChar alltid returnerar ett tecken ur inmatningsbufferten.
# Returvärde: inläst tecken
.global getChar
getChar:
    pushq $0
    movq input_buffer_pos, %rdi # Get the current position of the input buffer
    leaq input_buffer, %rsi # Get the input buffer memory adress

    cmpq $0, %rdi  # Skriv om
    je inImage # If we have an empty buffer, call inImage to get new characters

    # Calculate memory adress
    movq $8, %r8 
    imulq %rdi, %r8 # 8 * position (since 8 bits is a symbol)
    addq %rsi, %r8 # Add that onto the base adress to get current adress
    # Get character from that adress
    movq %r8, %rax 

    # Check if we are out of bounds
    cmpq $64, %rdi
    je inImage # If we reached the end of buffer, call inImage to get new characters
    cmpq $0, %rdi  # Skriv om
    jne increment_pos # Check again if the position is zero. Because if it is zero here, 
    # we did already take the correct character before resetting the position via inImage when
    # we saw we was at the last character, making incrementing the position not correct.
    jmp exit_getChar

    increment_pos: 
        incq %rdi # Increment the position

    exit_getChar:
        # Terminate getChar
        ret


# Rutinen ska sätta aktuell buffertposition för inbufferten till n. n måste dock ligga i intervallet
# [0,MAXPOS], där MAXPOS beror av buffertens faktiska storlek. Om n<0, sätt positionen
# till 0, om n>MAXPOS, sätt den till MAXPOS.
# Parameter: önskad aktuell buffertposition (index), n i texten.
.global setInPos
setInPos:                         # Return from the routine

# --------- Utmatning ---------

# Rutinen ska skriva ut strängen som ligger i utbufferten i terminalen. Om någon av de
# övriga utdatarutinerna når buffertens slut, så ska ett anrop till outImage göras i dem, så
# att man får en tömd utbuffert att jobba mot.
.global outImage
outImage:
    push $0
    # Move value fo outbuffer to rbx
    movq $output_buffer, %rdi
    call puts

    # Terminate outImage
    ret

# Rutinen ska lägga ut talet n som sträng i utbufferten från och med buffertens aktuella
# position. Glöm inte att uppdatera aktuell position innan rutinen lämnas.
# Parameter: tal som ska läggas in i bufferten (n i texten)
# Param: eax = int that should be put into the output buffer
.global putInt
putInt:
    push $0
    pushq %rbx # Caller owned register, save it
    # Move the current outoput position into rcx
    movq output_buffer_pos, %rcx
    # Load output buffer into rbx
    leaq output_buffer, %rbx
    call putInt_loop

    # Terminate putInt
    popq %rbx
    ret

    putInt_loop:
        # Move the first 8 bits of n into al
        movb (%eax), %al
        # Check if it's 0, if it is we are done
        cmpb $0, %al
        je exit_putInt_loop
        # Move the first 8 bits of n into the output buffer at the current position
        addb $48, %al # Convert the number to ascii
        call put_into_output_buffer
        # Increment position (check so we don't go out of bounds first)
        cmpq $64, %rcx
        call outImage
        inc %rcx
        # Delete first 8 bits with rightshift to read the next 8 bits in the next iteration
        shrq $8, %rax
        jmp putInt_loop

    exit_putInt_loop:
        ret


# Rutinen ska lägga textsträngen som finns i buf från och med den aktuella positionen i
# utbufferten. Glöm inte att uppdatera utbuffertens aktuella position innan rutinen lämnas.
# Om bufferten blir full så ska ett anrop till outImage göras, så att man får en tömd utbuffert
# att jobba vidare mot.
# Parameter: adress som strängen ska hämtas till utbufferten ifrån (buf i texten)
.global putText
putText:

# Rutinen ska lägga tecknet c i utbufferten och flytta fram aktuell position i den ett steg.
# Om bufferten blir full när getChar anropas ska ett anrop till outImage göras, så att man
# får en tömd utbuffert att jobba vidare mot.
# Parameter: tecknet som ska läggas i utbufferten (c i texten)
.global putChar
putChar:
    pushq $0
    pushq %rbx # Caller owned register, save it
    call getChar # Get character c from input buffer
    # Check if the output buffer is full
    leaq output_buffer, %rbx
    movq output_buffer_pos, %rcx
    cmpq $64, %rcx
    je outImage # If the output buffer is full, call outImage to empty it
    # Move the character to the output buffer
    call put_into_output_buffer
    # Increment the output buffer position
    inc %rcx

    # Terminate putChar
    pop %rbx
    ret

# Rutinen ska returnera aktuell buffertposition för utbufferten.
# Returvärde: aktuell buffertposition (index)
.global getOutPos
getOutPos:                      # Return from the routine

# Rutinen ska sätta aktuell buffertposition för utbufferten till n. n måste dock ligga i intervallet
# [0,MAXPOS], där MAXPOS beror av utbuffertens storlek. Om n<0 sätt den till 0, om
# n>MAXPOS sätt den till MAXPOS.
# Parameter: önskad aktuell buffertposition (index), n i texten
.global setOutPos
setOutPos:

