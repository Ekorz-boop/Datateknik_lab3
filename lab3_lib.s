# Uppgiften går ut på att implementera rutiner för att hantera inmatning och utmatning av
# data. För att klara av det behöver man reservera plats för två olika systembuffertar, en
# för inmatning och en för utmatning. Var och en av dessa buffertar behöver också någon
# variabel som håller reda på aktuell position i respektive buffert. Eftersom ett bibliotek ska
# implementeras måste nedanstående specifikation följas. Biblioteket ska ligga i en separat
# fil som kompileras och länkas tillsammans med testprogrammet Mprov64.s när sluttestet
# sker.



# --------- Inmatning ---------

inImage:
# Rutinen ska läsa in en ny textrad från tangentbordet till er inmatningsbuffert för indata
# och nollställa den aktuella positionen i den. De andra inläsningsrutinerna kommer sedan att
# jobba mot den här bufferten. Om inmatningsbufferten är tom eller den aktuella positionen
# är vid buffertens slut när någon av de andra inläsningsrutinerna nedan anropas ska inImage
# anropas av den rutinen, så att det alltid finns ny data att arbeta med.




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



getChar:
# Rutinen ska returnera ett tecken från inmatningsbuffertens aktuella position och flytta
# fram aktuell position ett steg i inmatningsbufferten ett steg. Om inmatningsbufferten är
# tom eller aktuell position i den är vid buffertens slut vid anrop av getChar ska getChar
# kalla på inImage, så att getChar alltid returnerar ett tecken ur inmatningsbufferten.
# Returvärde: inläst tecken



getInPos:
# Rutinen ska returnera aktuell buffertposition för inbufferten.
# Returvärde: aktuell buffertposition (index)



setInPos:
# Rutinen ska sätta aktuell buffertposition för inbufferten till n. n måste dock ligga i intervallet
# [0,MAXPOS], där MAXPOS beror av buffertens faktiska storlek. Om n<0, sätt positionen
# till 0, om n>MAXPOS, sätt den till MAXPOS.
# Parameter: önskad aktuell buffertposition (index), n i texten.



# --------- Utmatning ---------

outImage:
# Rutinen ska skriva ut strängen som ligger i utbufferten i terminalen. Om någon av de
# övriga utdatarutinerna når buffertens slut, så ska ett anrop till outImage göras i dem, så
# att man får en tömd utbuffert att jobba mot.


putInt:
# Rutinen ska lägga ut talet n som sträng i utbufferten från och med buffertens aktuella
# position. Glöm inte att uppdatera aktuell position innan rutinen lämnas.
# Parameter: tal som ska läggas in i bufferten (n i texten)



putText:
# Rutinen ska lägga textsträngen som finns i buf från och med den aktuella positionen i
# utbufferten. Glöm inte att uppdatera utbuffertens aktuella position innan rutinen lämnas.
# Om bufferten blir full så ska ett anrop till outImage göras, så att man får en tömd utbuffert
# att jobba vidare mot.
# Parameter: adress som strängen ska hämtas till utbufferten ifrån (buf i texten)



putChar:
# Rutinen ska lägga tecknet c i utbufferten och flytta fram aktuell position i den ett steg.
# Om bufferten blir full när getChar anropas ska ett anrop till outImage göras, så att man
# får en tömd utbuffert att jobba vidare mot.
# Parameter: tecknet som ska läggas i utbufferten (c i texten)



getOutPos:
# Rutinen ska returnera aktuell buffertposition för utbufferten.
# Returvärde: aktuell buffertposition (index)



setOutPos:
# Rutinen ska sätta aktuell buffertposition för utbufferten till n. n måste dock ligga i intervallet
# [0,MAXPOS], där MAXPOS beror av utbuffertens storlek. Om n<0 sätt den till 0, om
# n>MAXPOS sätt den till MAXPOS.
# Parameter: önskad aktuell buffertposition (index), n i texten



