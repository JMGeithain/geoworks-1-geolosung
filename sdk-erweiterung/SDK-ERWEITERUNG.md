# SDK-Erweiterung: Datum, Zwischenablage und Autostart unter GeoWorks 1.28

Stand: 22. November 2026, erarbeitet für GeoLosung 1.2.
Gilt für das Zielprofil des SDK pcgeos-1-sdk-v2: deutsches GeoWorks Ensemble 1.2,
Kernel-Protokoll 622.3, UI-Protokoll 693.0.

Alle Angaben stammen aus der Untersuchung der Systemdateien `UI.GEO` und
`DCLOCK24.GEO` der Installation. Übernommen wurden nur Nummern und
Registerbelegungen, kein Code.

Bestätigt heißt: in GeoWorks selbst ausgeführt. Ungetestet heißt: nur aus den
Systemdateien abgeleitet und im 8086-Emulator von GeoLosung geprüft.

## 1. Heutiges Datum

Bestätigt (GeoLosung 1.0 zeigt das richtige Datum).

| Aufruf | Register |
|---|---|
| Kernel 95 | Leitet eine DOS-Funktion weiter. `AH = 2Ah` liefert `CX` = Jahr, `DH` = Monat, `DL` = Tag, `AL` = Wochentag |

Die Digital-Uhr `DCLOCK24.GEO` fragt genauso mit `AH = 2Ch` die Uhrzeit ab.

```nasm
 mov ah,0x2a
 KCALL 95            ; CX = Jahr, DH = Monat, DL = Tag
```

## 2. Zwischenablage (Text kopieren)

Bestätigt (GeoLosung 1.2: Einfügen in GeoWrite funktioniert). Fertige Routine: `g1clip.inc`, Aufruf `g1_clip_text`.

### UI-Exporte (Modul `ui`, Importindex 0, Aufruf mit `LC 0,n`)

Sie liegen alle in Ressource 6 von `UI.GEO`.

| Export | Bedeutung (GEOS-2-Name) | Register |
|---:|---|---|
| 127 | ClipboardRegisterItem | `BX:AX` = Datei:Kopfblock, `BP` = 0 (normal) oder 4000h (Quick-Transfer) |
| 128 | ClipboardQueryItem | `BP` = Flags. Liefert `BX:AX` = Datei:Kopfblock und die Formatliste nach `ES:DI` |
| 129 | ClipboardRequestItemFormat | `CX` = Format. Liefert `AX` = VM-Block, `CX`/`DX` = Zusatzwerte |
| 130 | ClipboardDoneWithItem | `BX:AX` = Datei:Kopfblock |
| 132 / 133 / 134 | aktuelles, Quick- und vorheriges Element | Liefert `BX:AX` |
| 135 | ClipboardGetClipboardFile | Liefert `BX` = VM-Datei (`SYSTEM\ZWISCHEN.000`) |
| 136 / 137 | Benachrichtigungsliste an/ab | `CX:DX` = Objekt |

### Kernel-Aufrufe (wie der Textbaustein der UI sie verwendet)

| Kernel | Bedeutung | Register |
|---:|---|---|
| 0 | MemAlloc | `AX` = Größe, `CL` = 50h, `CH` = 60h |
| 4 | Blockflags für VM-Blöcke | `BX` = Block. Vor dem Anhängen `AH` = 80h, `DL` = 0, `DH` = 8 |
| 24 | LMem-Heap anlegen | `DS` = Block, `BX` = Handle, `DX` = Kopfgröße (24h), `AX` = 0, `CL` = 80h, `CH` = 10h |
| 25 | LMemAlloc | `DS` = Block, `CX` = Größe. Liefert `AX` = Chunk |
| 28 | LMemReAlloc | `DS` = Block, `AX` = Chunk, `CX` = neue Größe |
| 149 | GeodeGetProcessHandle | Liefert `BX` |
| 399 / 398 | Klammer um jedes VMAttach | Siehe unten |
| 411 | VMAttach | `CX` = Speicherblock, `AX` = 0. Liefert `AX` = VM-Block |

Die Klammer aus 399 und 398 ruft die UI vor und nach jedem VMAttach genau so auf:

```nasm
 push ax
 xchg ax,bx
 KCALL 399
 xchg ax,bx
 KCALL 398
 xchg ax,bx
 pop ax
```

Kernel 399 wandelt dabei das Datei-Handle in `AX` in ein Handle in `BX` um und
nach dem Anhängen wieder zurück. Deshalb steht in `BX` danach wieder die
Clipboard-Datei, die ClipboardRegisterItem braucht.

### Aufbau eines Clipboard-Elements

**Kopfblock (43h Byte):**

| Offset | Inhalt |
|---|---|
| 00h | Besitzer: Chunk |
| 02h | Besitzer: Handle |
| 04h | Flags 4000h |
| 06h | Name, NUL-beendet (die UI schreibt „Unbenannter Text“) |
| 27h | Anzahl der Formate |
| 29h | 10 Format-Kennungen (Wörter). 0 = Text, 1 = Grafik (GString) |
| 3Dh | Je Format 6 Byte: Zusatz 1, Zusatz 2, VM-Block |

**Textformat (Format 0):** ein LMem-Block mit 24h Byte Kopf.

| Offset | Inhalt |
|---|---|
| 10h | Chunk mit dem reinen Text: ohne NUL, Absätze mit CR (0Dh), GEOS-Zeichensatz |
| 12h, 14h, 16h | Laufdaten für Zeichen-, Absatz- und Typattribute. 0 = einheitlich |
| 18h | Grafiken. 0 = keine |
| 00h | Wird vor dem Anhängen auf 0 gesetzt |

Beim Einfügen liest der Textbaustein die Textlänge aus der Chunkgröße. Ein
abschließendes NUL wäre deshalb als Zeichen mit eingefügt.

### Nachrichten des Textbausteins (VisText, GeoWorks 1.28)

| Nachricht | Bedeutung |
|---|---|
| 011Eh | Ausschneiden |
| 011Fh | Kopieren |
| 0120h | Einfügen |
| 2254h | Textformat für die Zwischenablage erzeugen |
| 2253h | Text aus einem Textformat-Block einsetzen |

## 3. Autostart beim Hochfahren

Bestätigt (GeoLosung 1.2).

`UI.GEO` liest in `GEOS.INI`, Abschnitt `[ui]`, den Schlüssel `execOnStartup`:

- Die Namen werden durch Leerzeichen, Tabulator oder Zeilenwechsel getrennt.
- Jeder Name wird nacheinander gestartet, wie `welcome.geo` aus `GEOWORKS\SYSAPPL`.
- Fehlt der Schlüssel, startet die UI nur `welcome.geo`.
- Steht der Schlüssel da, startet sie nur die aufgezählten Programme.

`welcome.geo` (der Startbildschirm mit GeoManager) muss deshalb zuerst mit
aufgezählt werden:

```ini
[ui]
execOnStartup = welcome.geo geolos.geo
```

Dabei liegt `GEOLOS.GEO` zusätzlich in `GEOWORKS\SYSAPPL`, also dort, wo auch
`WELCOME.GEO` liegt.
