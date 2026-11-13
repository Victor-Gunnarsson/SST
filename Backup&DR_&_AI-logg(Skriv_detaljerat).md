# Backup & DR samt AI-logg

Detta dokument beskriver vår backup-lösning, Disaster Recovery plan (DRP) samt en AI-logg.

## Backup

En daglig backup tas på vår Windows Server 2025 (srv-dc01) där backupen innehåller kritiska konfigurationsfiler och data för servern och Active Directory-databasen. Om servern av någon anledning skulle krascha i form av en attack, hårdvaru- eller mjukvarufel eller annan oförutsedd olycka som brand eller översvämning kan denna backup användas för att äterställa systemet till vanligt drift. Dock är själva operativsystemet inte säkerhetskopierat så om det är något fel med det så behövs operativsystemet installeras om, men efter det så kan vår backup användas för att återställa till den normala driften.

För att vi ska kunna ta en backup måste den externa disken monteras först, disken ligger på vår Ubuntu-server som en Samba-utdelning. En speciell användare är skapad på båda servarna som heter `backupuser` som vi använder för att verifiera anslutningen. Denna användare är också medlem i AD-gruppen "Backup Operators" för att kunna få köra tjänsten Windows Server Backup.

Först lägger vi in användarnamn och lösenord i Powershell (kör som administrator):
`cmdkey /add:192.168.50.10 /user:backupuser /pass:SäkertLösenord123!`

Efter det lägger vi till själva utdelningen och märker den som `B:` med kommandot:
`New-PSDrive -Name "B" -PSProvider FileSystem -Root "\\192.168.50.10\backups" -Persist`

Nu ska B: ses under diskarna och pekar då på Samba-utdelningen på Ubuntu-servern.

### Steg-för-steg skapande av schemalagd backup

I Tools-menyn i Server Manager start du Windows Server Backup, om den inte är installerad gör du det under "Add Roles and Features".

1. Välj Backup Schedule... i menyn till höger
2. Custom (man väljer vilka filer/delar istället för hela servern), i *Select Items* tryck *Add Item* och välj ”System State” vilket tar backup på de kritiska konfigurationsfiler och data för servern och Active Directory-databasen. 
3. Efteråt välj tid och dag, vi har valt varje dag kl 02:00.
4. Sedan plats där backupen ska sparas, välj sista alternativet ”Back up to a shared network folder” och specificera hela sökvägen till vår Samba-backup (\\192.168.50.10\backups).
5. Skriv in användarnamnet för backup-användaren (backupuser) samt lösenord.
6. I sista steget ser man en sammanfattning, kontrollera så allt stämmer och spara.

### Steg-för-steg återställning av backup

1. I samma verktyg (Windows Server Backup) välj Recover i menyn till höger.
2. Välj andra alternativet ”A backup is stored on another location” eftersom backupen är lagrad på vår Samba-server.
3. Välj ”Remote shared folder” och skriv in hela sökvägen (\\192.168.50.10\backups), verktygen kommer se äldsta och nyaste backupen.
4. Välj vilket datum för backupen, här står det också vad som går att återställa.
5. Välj vad som ska återställas, antingen filer/mappar, hela volymer (t.ex. C:), applikationer eller System state. För att återställa System State måste servern bootas om till DSRM (Directory Services Restore Mode), se nedan för steg.
6. Välj vart filerna ska återställas.
7. Kolla sammanfattningen och bekräfta.
8. Efter filerna är återställda kolla så de faktiskt innehåller den data som raderades.

## Disaster Recovery (DR)


## AI-logg

### Användning av AI

Vi har använt AI vid olika tillfällen när vi har installerat och konfigurerat alla system och tjänster. Det är oftast vid felsökning som användning av AI har blivit aktuellt då vi gärna testar först och om vi stöter på problem, förhinder eller om vi inte förstår så har AI varit ett utmärkt verktyg. Exempel kan vara uppsättning av Samba där vi funderade på exakt hur vi skulle konfigurera eller hur vi skulle lösa det med att ta backup från vår Windows Server till en dedikerad Samba-utdelning för just backups på vår Ubuntu-server där Windows klagade på kopplingen då användarnamnen eller lösenordet inte stämde. AI kunde då lokalisera problemet och komma med olika lösningar som vi applicerade för att lösa problemet.

Steg för att använda AI på ett korrekt sätt;
1. Beskriv situationen och vad man vill åstakomma (t.ex. Jag har problem med Samba, jag har testat xyz, vad kan jag göra för att gå vidare?)
2. Gå igenom svaret från AI grundligt och kör inget kommando eller skript utan att ha gått igenom så att inga olovliga ändringar görs.
3. Ställ AI mot AI genom kopiera kommandot/skriptet och fråga en annan AI vad der gör. Gör en webbsök på svaret efter primära källor (man-sidor, Microsoft, Canonical)
4. Kör kommandot/skriptet och kontrollera resultatet.

### AI-logg

Vår AI-logg, sorterad på senaste först.

| Datum | AI-verktyg | Anledning | Prompt | Svar | Verifiering |
|-------|------------|-----------|--------|------|-------------|
|   12/11/2026    |      Copilot      |    Justera fstab i Ubuntu       |   Frågade hur jag lägger till en ny disk/partition i fstab för att automatiskt montera den     |   Fick olika kommandon att köra för att identifiera UUID som används i fstab och själva raden som ska läggas in i /etc/fstab  |      Dubbelkollade med att söka efter fstab-exempel för att se en utörlig fil       |
|    10/11/2026   |     Copilot       |   Felsökning av Backup till Samba-utdelning        |   Beskrev mitt problem och felmeddelanden och vad jag ville åstakomma   |   Fick svar att dubbelkolla användare på Windows-servern samt att lägga till i korrekt grupp.   |      Kollade svaret och alla kommandon ser korrekta ut, gjorde webbsök på kommadon.      |
|    04/11/2026   |     Copilot       |     Konfiguration av UFW      |    Frågade om UFW-konfiguration får strikt åtkomst och bara tillåta vissa tjänster    |   Fick svar med kommandon för att stänga default incoming och tillåta utgående tillsammans med hur man tillåter enstaka tjänster  |      Kikade på flera uppsättningar av UFW via en webbsök.   |
|       |            |           |        |      |             |