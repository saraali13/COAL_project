INCLUDE Irvine32.inc
INCLUDELIB winmm.lib
INCLUDE macros.inc

; Prototype for PlaySound
PlaySound PROTO,
    pszSound:PTR BYTE,
    hmod:DWORD,
    fdwSound:DWORD

; Prototype for Windows API functions
GetStdHandle PROTO, nStdHandle:DWORD
SetConsoleCursorPosition PROTO, hConsoleOutput:DWORD, dwCursorPosition:COORD

.data
    ; COORD structure for cursor positioning
    cursorPos COORD <6,0>  ; X,Y position for time display

    ; Console handles
    hStdOut DWORD ?

    ; Time variables
    currHour   DWORD ?
    currMin    DWORD ?
    currSec    DWORD ?
    alarmHour  DWORD ?
    alarmMin   DWORD ?
    alarmFlag  DWORD 0       ; 0 = Off, 1 = On
    snoozeFlag DWORD 0       ; 0 = No snooze, 1 = Snoozed
    snoozeMin  DWORD 2       ; 2 minutes snooze duration

    ; Sound constants
    SND_ALIAS     EQU 00010000h
    SND_ASYNC     EQU 00000001h
    SND_FILENAME  EQU 00020000h
    SND_LOOP      EQU 00000008h
    SND_PURGE     EQU 00000040h
    
    ; Sound files
    alarmSoundFile BYTE "alarm.wav",0
    beepSoundFile  BYTE "beep.wav",0
    snoozeSoundFile BYTE "snooze.wav",0
    
    ; Messages
    promptAlarmHour   BYTE "Enter Alarm Hour (0-23): ", 0
    promptAlarmMin    BYTE "Enter Alarm Minute (0-59): ", 0
    alarmTriggeredMsg BYTE "ALARM TRIGGERED! Press 1 to Snooze, 2 to Stop: ", 0
    snoozeMsg         BYTE "Alarm Snoozed for 2 minutes", 0
    stopMsg           BYTE "Alarm Stopped", 0
    invalidInputMsg   BYTE "Invalid input! Please try again.", 0
    timeLabel         BYTE "Time: ", 0
    colonStr          BYTE ":", 0
    timeFormatError   BYTE "Error: Could not get system time", 0

.code
main PROC
    ; Get console handle for output
    INVOKE GetStdHandle, STD_OUTPUT_HANDLE
    mov hStdOut, eax

    ; Set initial cursor position
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos

    ; Input alarm time with validation
    call InputAlarmTime

    ; Display initial time label
    mov edx, OFFSET timeLabel
    call WriteString

START_CLOCK:
    ; Read current time
    call GetCurrentTime
    
    ; Update time display in place
    call UpdateTimeDisplay

    ; Check alarm condition
    call CheckAlarm

    ; Delay for 1 second
    mov eax, 1000
    call Delay

    ; Repeat loop
    jmp START_CLOCK

    exit
main ENDP

; =======================
; Update Time Display
; =======================
UpdateTimeDisplay PROC
    ; Set cursor position after "Time: "
    mov cursorPos.X, 6
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos
    
    ; Display hours
    mov eax, currHour
    cmp eax, 10
    jae HourTwoDigit
    push eax
    mov eax, 0
    call WriteDec
    pop eax
HourTwoDigit:
    call WriteDec
    
    mov edx, OFFSET colonStr
    call WriteString
    
    ; Display minutes
    mov eax, currMin
    cmp eax, 10
    jae MinuteTwoDigit
    push eax
    mov eax, 0
    call WriteDec
    pop eax
MinuteTwoDigit:
    call WriteDec
    
    mov edx, OFFSET colonStr
    call WriteString
    
    ; Display seconds
    mov eax, currSec
    cmp eax, 10
    jae SecondTwoDigit
    push eax
    mov eax, 0
    call WriteDec
    pop eax
SecondTwoDigit:
    call WriteDec
    
    ret
UpdateTimeDisplay ENDP

; =======================
; Input Alarm Time
; =======================
InputAlarmTime PROC
    ; Position cursor for input
    mov cursorPos.X, 0
    mov cursorPos.Y, 1
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos

HourInput:
    mov edx, OFFSET promptAlarmHour
    call WriteString
    call ReadInt
    cmp eax, 0
    jl HourInput
    cmp eax, 23
    jg HourInput
    mov alarmHour, eax

    ; Move to next line for minute input
    inc cursorPos.Y
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos

MinuteInput:
    mov edx, OFFSET promptAlarmMin
    call WriteString
    call ReadInt
    cmp eax, 0
    jl MinuteInput
    cmp eax, 59
    jg MinuteInput
    mov alarmMin, eax

    ; Clear input lines
    mov cursorPos.X, 0
    mov cursorPos.Y, 1
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos
    mov ecx, 60
ClearLoop:
    mov al, ' '
    call WriteChar
    loop ClearLoop
    
    inc cursorPos.Y
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos
    mov ecx, 60
ClearLoop2:
    mov al, ' '
    call WriteChar
    loop ClearLoop2

    ; Reset cursor to time display position
    mov cursorPos.X, 6
    mov cursorPos.Y, 0
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos

    mov alarmFlag, 1
    mov snoozeFlag, 0
    ret
InputAlarmTime ENDP

; =======================
; Get Current Time
; =======================
GetCurrentTime PROC
    ; Get system time
    mov eax, 0
    call GetMseconds
    
    ; Convert to seconds
    mov ebx, 1000
    xor edx, edx
    div ebx
    
    ; Calculate hours
    mov ebx, 3600
    xor edx, edx
    div ebx
    mov currHour, eax
    
    ; Calculate minutes
    mov eax, edx
    mov ebx, 60
    xor edx, edx
    div ebx
    mov currMin, eax
    
    ; Remaining seconds
    mov currSec, edx
    
    ; Handle snooze time if active
    cmp snoozeFlag, 1
    jne NoSnooze
    call HandleSnooze
    
NoSnooze:
    ret
GetCurrentTime ENDP

; =======================
; Handle Snooze Time
; =======================
HandleSnooze PROC
    ; Add snooze minutes to alarm time
    mov eax, alarmMin
    add eax, snoozeMin
    cmp eax, 60
    jl NoHourAdjust
    
    ; Adjust hour if minutes overflow
    sub eax, 60
    mov alarmMin, eax
    mov eax, alarmHour
    inc eax
    cmp eax, 24
    jl NoDayAdjust
    sub eax, 24
NoDayAdjust:
    mov alarmHour, eax
    jmp SnoozeDone
    
NoHourAdjust:
    mov alarmMin, eax
    
SnoozeDone:
    ; Play snooze sound
    INVOKE PlaySound, OFFSET snoozeSoundFile, 0, SND_FILENAME + SND_ASYNC
    
    mov snoozeFlag, 0
    ret
HandleSnooze ENDP

; =======================
; Alarm Check Logic
; =======================
CheckAlarm PROC
    cmp alarmFlag, 0
    je NoAlarm
    
    mov eax, currHour
    cmp eax, alarmHour
    jne NoAlarm
    
    mov eax, currMin
    cmp eax, alarmMin
    jne NoAlarm
    
    mov eax, currSec
    cmp eax, 0
    jne NoAlarm
    
    ; Alarm triggered!
    call TriggerAlarm
    
NoAlarm:
    ret
CheckAlarm ENDP

; =======================
; Trigger Alarm with Sound
; =======================
TriggerAlarm PROC
    ; Play alarm sound
    INVOKE PlaySound, OFFSET alarmSoundFile, 0, SND_FILENAME + SND_ASYNC + SND_LOOP
    
AlarmLoop:
    ; Display message
    mov cursorPos.X, 0
    mov cursorPos.Y, 2
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos
    mov edx, OFFSET alarmTriggeredMsg
    call WriteString
    
    ; Get user input
    call ReadInt
    
    ; Process input
    cmp eax, 1
    je SnoozeAlarm
    cmp eax, 2
    je StopAlarm
    
    ; Invalid input
    mov edx, OFFSET invalidInputMsg
    call WriteString
    call Crlf
    jmp AlarmLoop
    
SnoozeAlarm:
    mov snoozeFlag, 1
    mov cursorPos.X, 0
    mov cursorPos.Y, 3
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos
    mov edx, OFFSET snoozeMsg
    call WriteString
    call Crlf
    
    ; Stop the alarm sound
    INVOKE PlaySound, 0, 0, SND_PURGE
    
    ; Play confirmation beep
    INVOKE PlaySound, OFFSET beepSoundFile, 0, SND_FILENAME + SND_ASYNC
    
    ; Clear alarm message lines
    mov cursorPos.X, 0
    mov cursorPos.Y, 2
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos
    mov ecx, 60
ClearAlarmMsg:
    mov al, ' '
    call WriteChar
    loop ClearAlarmMsg
    
    mov cursorPos.X, 0
    mov cursorPos.Y, 3
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos
    mov ecx, 60
ClearSnoozeMsg:
    mov al, ' '
    call WriteChar
    loop ClearSnoozeMsg
    
    ; Reset cursor to time position
    mov cursorPos.X, 6
    mov cursorPos.Y, 0
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos
    
    jmp EndAlarm
    
StopAlarm:
    mov alarmFlag, 0
    mov cursorPos.X, 0
    mov cursorPos.Y, 3
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos
    mov edx, OFFSET stopMsg
    call WriteString
    call Crlf
    
    ; Stop the alarm sound
    INVOKE PlaySound, 0, 0, SND_PURGE
    
    ; Clear alarm message lines
    mov cursorPos.X, 0
    mov cursorPos.Y, 2
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos
    mov ecx, 60
ClearAlarmMsg2:
    mov al, ' '
    call WriteChar
    loop ClearAlarmMsg2
    
    mov cursorPos.X, 0
    mov cursorPos.Y, 3
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos
    mov ecx, 60
ClearStopMsg:
    mov al, ' '
    call WriteChar
    loop ClearStopMsg
    
    ; Reset cursor to time position
    mov cursorPos.X, 6
    mov cursorPos.Y, 0
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos
    
EndAlarm:
    ret
TriggerAlarm ENDP

END main
