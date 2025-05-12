INCLUDE Irvine32.inc 
INCLUDELIB winmm.lib ;for sound playback
INCLUDE macros.inc
INCLUDELIB kernel32.lib 

; Prototype for PlaySound
PlaySound PROTO,
    pszSound:PTR BYTE,
    hmod:DWORD,
    fdwSound:DWORD

; Prototype for Windows API functions
GetStdHandle PROTO, nStdHandle:DWORD

;Prototype for cursor positioning 
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
    msgDelayTime DWORD 3000  ; 3 seconds delay for messages

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
    blankLine         BYTE "                                                            ", 0

    ; Color constants
    COLOR_NORMAL      = white + (black * 16)    ; White text on black background
    COLOR_TIME        = lightGray + (black * 16)
    COLOR_LABEL       = yellow + (black * 16)
    COLOR_PROMPT      = cyan + (black * 16)
    COLOR_ALARM       = lightRed + (black * 16)
    COLOR_SNOOZE      = lightGreen + (black * 16)
    COLOR_STOP        = lightBlue + (black * 16)
    COLOR_ERROR       = red + (black * 16)

.code
main PROC

    ;Initialize console for output
    INVOKE GetStdHandle, STD_OUTPUT_HANDLE
    mov hStdOut, eax

    ; Set initial cursor position
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos

    ; Set default color
    mov eax, COLOR_NORMAL
    call SetTextColor

    ; Input alarm time with validation
    call InputAlarmTime

    ; Display initial time label with color
    mov eax, COLOR_LABEL
    call SetTextColor
    mov edx, OFFSET timeLabel
    call WriteString

;main clock loop
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
    ; Save current cursor position
    push cursorPos.X
    push cursorPos.Y
    
    ; Set color for time display
    mov eax, COLOR_TIME
    call SetTextColor
    
    ; Set cursor position after "Time: "
    mov cursorPos.X, 6
    mov cursorPos.Y, 0
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
    
    ; Restore cursor position
    pop cursorPos.Y
    pop cursorPos.X
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos
    
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

    ; Set prompt color
    mov eax, COLOR_PROMPT
    call SetTextColor

HourInput:
    mov edx, OFFSET promptAlarmHour
    call WriteString
    call ReadInt
    jno ValidHour   ; Check for overflow
    jmp InvalidHour
    
ValidHour:
    cmp eax, 0
    jl InvalidHour
    cmp eax, 23
    jg InvalidHour
    mov alarmHour, eax
    jmp MinutePrompt
    
InvalidHour:
    ; Display error message
    mov eax, COLOR_ERROR
    call SetTextColor
    mov edx, OFFSET invalidInputMsg
    call WriteString
    call Crlf
    ; Reset cursor position
    mov cursorPos.X, 0
    mov cursorPos.Y, 1
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos
    ; Clear the line
    mov ecx, 60

ClearHourLine:
    mov al, ' '
    call WriteChar
    loop ClearHourLine
    ; Reset cursor and try again
    mov cursorPos.X, 0
    mov cursorPos.Y, 1
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos
    mov eax, COLOR_PROMPT
    call SetTextColor
    jmp HourInput
    
MinutePrompt:
    ; Move to next line for minute input
    inc cursorPos.Y
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos

MinuteInput:
    mov edx, OFFSET promptAlarmMin
    call WriteString
    call ReadInt
    jno ValidMinute   ; Check for overflow
    jmp InvalidMinute
    
ValidMinute:
    cmp eax, 0
    jl InvalidMinute
    cmp eax, 59
    jg InvalidMinute
    mov alarmMin, eax
    jmp InputComplete
    
InvalidMinute:
    ; Display error message
    mov eax, COLOR_ERROR
    call SetTextColor
    mov edx, OFFSET invalidInputMsg
    call WriteString
    call Crlf
    ; Reset cursor position
    mov cursorPos.X, 0
    mov cursorPos.Y, 2
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos
    ; Clear the line
    mov ecx, 60

ClearMinuteLine:
    mov al, ' '
    call WriteChar
    loop ClearMinuteLine
    ; Reset cursor and try again
    mov cursorPos.X, 0
    mov cursorPos.Y, 2
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos
    mov eax, COLOR_PROMPT
    call SetTextColor
    jmp MinuteInput
    
InputComplete:
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
    
    ; Restore normal color
    mov eax, COLOR_NORMAL
    call SetTextColor
    
    ret
InputAlarmTime ENDP

; =======================
; Get Current Time
; =======================
GetCurrentTime PROC
    LOCAL sysTime:SYSTEMTIME
    
    ; Get system time
    INVOKE GetLocalTime, ADDR sysTime
    
    ; Store time components
    movzx eax, sysTime.wHour
    mov currHour, eax
    
    movzx eax, sysTime.wMinute
    mov currMin, eax
    
    movzx eax, sysTime.wSecond
    mov currSec, eax
    
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
    ; Save current cursor position
    push cursorPos.X
    push cursorPos.Y
    
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
    
    ; Display snooze message
    mov cursorPos.X, 0
    mov cursorPos.Y, 3
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos
    
    mov snoozeFlag, 0
    
    mov cursorPos.X, 0
    mov cursorPos.Y, 3
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos
    mov ecx, 60

ClearSnooze:
    mov al, ' '
    call WriteChar
    loop ClearSnooze
    
    ; Restore cursor position
    pop cursorPos.Y
    pop cursorPos.X
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos
    
    ; Restore normal color
    mov eax, COLOR_NORMAL
    call SetTextColor
    
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
    ; Save current cursor position
    push cursorPos.X
    push cursorPos.Y
    
    ; Play alarm sound
    INVOKE PlaySound, OFFSET alarmSoundFile, 0, SND_FILENAME + SND_ASYNC + SND_LOOP
    
AlarmLoop:
    ; Set alarm message color
    mov eax, COLOR_ALARM
    call SetTextColor
    
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
    
    ; Invalid input - set error color
    mov eax, COLOR_ERROR
    call SetTextColor

    ; Display invalid input message
    mov cursorPos.X, 0
    mov cursorPos.Y, 5             ; Choose a clear line for this message
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos
    mov edx, OFFSET invalidInputMsg
    call WriteString
    
    ; Clear the invalid input message before next loop
    mov eax, msgDelayTime
    call Delay
    mov cursorPos.X, 0
    mov cursorPos.Y, 5             ; Same Y position
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos
    mov edx, OFFSET blankLine
    call WriteString
    
    jmp AlarmLoop
    
SnoozeAlarm:
    mov snoozeFlag, 1
    mov cursorPos.X, 0
    mov cursorPos.Y, 3
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos
    
    ; Set snooze message color
    mov eax, COLOR_SNOOZE
    call SetTextColor
    
    mov edx, OFFSET snoozeMsg
    call WriteString
    
    ; Stop the alarm sound
    INVOKE PlaySound, 0, 0, SND_PURGE
    
    ; Play confirmation beep
    INVOKE PlaySound, OFFSET beepSoundFile, 0, SND_FILENAME + SND_ASYNC
    mov eax, msgDelayTime
    call Delay

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
    
    ; Restore cursor position
    pop cursorPos.Y
    pop cursorPos.X
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos
    
    ; Restore normal color
    mov eax, COLOR_NORMAL
    call SetTextColor
    
    jmp EndAlarm
    
StopAlarm:
    mov alarmFlag, 0
    mov cursorPos.X, 0
    mov cursorPos.Y, 3
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos
    
    ; Set stop message color
    mov eax, COLOR_STOP
    call SetTextColor
    
    mov edx, OFFSET stopMsg
    call WriteString
    
    ; Stop the alarm sound
    INVOKE PlaySound, 0, 0, SND_PURGE
    mov eax, msgDelayTime
    call Delay

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
    
    ; Restore cursor position
    pop cursorPos.Y
    pop cursorPos.X
    INVOKE SetConsoleCursorPosition, hStdOut, cursorPos
    
    ; Restore normal color
    mov eax, COLOR_NORMAL
    call SetTextColor
    
EndAlarm:
    ret
TriggerAlarm ENDP

END main
