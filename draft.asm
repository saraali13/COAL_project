INCLUDE Irvine32.inc
INCLUDELIB winmm.lib
INCLUDE macros.inc

; Prototype for PlaySound
PlaySound PROTO,
    pszSound:PTR BYTE,
    hmod:DWORD,
    fdwSound:DWORD

.data
    ; Time variables
    currHour   DWORD ?
    currMin    DWORD ?
    currSec    DWORD ?
    alarmHour  DWORD ?
    alarmMin   DWORD ?
    alarmFlag  DWORD 0       ; 0 = Off, 1 = On
    snoozeFlag DWORD 0       ; 0 = No snooze, 1 = Snoozed
    snoozeMin  DWORD 5       ; Snooze duration in minutes

    ; Sound constants (now defined as EQU instead of DWORD)
    SND_ALIAS     EQU 00010000h
    SND_ASYNC     EQU 00000001h
    SND_FILENAME  EQU 00020000h
    SND_LOOP      EQU 00000008h
    SND_PURGE     EQU 00000040h
    
    ; Sound files
    alarmSoundFile BYTE "alarm.wav",0  ; Make sure this file exists in your directory
    beepSoundFile  BYTE "beep.wav",0
    
    ; Messages
    promptAlarmHour   BYTE "Enter Alarm Hour (0-23): ", 0
    promptAlarmMin    BYTE "Enter Alarm Minute (0-59): ", 0
    alarmTriggeredMsg BYTE "ALARM TRIGGERED! Press 1 to Snooze, 2 to Stop: ", 0
    snoozeMsg         BYTE "Alarm Snoozed for 5 minutes", 0
    stopMsg           BYTE "Alarm Stopped", 0
    invalidInputMsg   BYTE "Invalid input! Please try again.", 0
    currentTimeMsg    BYTE "Current Time: ", 0
    colonStr          BYTE ":", 0
    timeFormatError   BYTE "Error: Could not get system time", 0

.code
main PROC
    ; Input alarm time with validation
    call InputAlarmTime

START_CLOCK:
    ; Read and display current time
    call GetCurrentTime
    call DisplayTime

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
; Input Alarm Time with Validation
; =======================
InputAlarmTime PROC
HourInput:
    mov edx, OFFSET promptAlarmHour
    call WriteString
    call ReadInt
    cmp eax, 0
    jl HourInput
    cmp eax, 23
    jg HourInput
    mov alarmHour, eax

MinuteInput:
    mov edx, OFFSET promptAlarmMin
    call WriteString
    call ReadInt
    cmp eax, 0
    jl MinuteInput
    cmp eax, 59
    jg MinuteInput
    mov alarmMin, eax

    mov alarmFlag, 1  ; Enable the alarm
    mov snoozeFlag, 0 ; Reset snooze flag
    ret
InputAlarmTime ENDP

; =======================
; Get Current Time
; =======================
GetCurrentTime PROC
    ; Get system time using Irvine32 functions
    mov eax, 0
    call GetMseconds   ; Get milliseconds since midnight
    
    ; Convert to seconds
    mov ebx, 1000
    xor edx, edx
    div ebx            ; eax = seconds since midnight
    
    ; Calculate hours
    mov ebx, 3600      ; seconds per hour
    xor edx, edx
    div ebx
    mov currHour, eax
    
    ; Calculate minutes
    mov eax, edx
    mov ebx, 60        ; seconds per minute
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
    mov snoozeFlag, 0  ; Reset snooze flag
    ret
HandleSnooze ENDP

; =======================
; Display Current Time
; =======================
DisplayTime PROC
    mov edx, OFFSET currentTimeMsg
    call WriteString
    
    ; Display hours
    mov eax, currHour
    call WriteDec
    
    mov edx, OFFSET colonStr
    call WriteString
    
    ; Display minutes (with leading zero if needed)
    mov eax, currMin
    cmp eax, 10
    jae NoLeadZeroMin
    push eax
    mov eax, 0
    call WriteDec
    pop eax
NoLeadZeroMin:
    call WriteDec
    
    mov edx, OFFSET colonStr
    call WriteString
    
    ; Display seconds (with leading zero if needed)
    mov eax, currSec
    cmp eax, 10
    jae NoLeadZeroSec
    push eax
    mov eax, 0
    call WriteDec
    pop eax
NoLeadZeroSec:
    call WriteDec
    
    call Crlf
    ret
DisplayTime ENDP

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
    cmp eax, 0        ; Only trigger at start of minute
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
    ; Play alarm sound (async and loop)
    INVOKE PlaySound, OFFSET alarmSoundFile, 0, SND_FILENAME + SND_ASYNC + SND_LOOP
    
AlarmLoop:
    ; Display message
    mov edx, OFFSET alarmTriggeredMsg
    call WriteString
    
    ; Get user input
    call ReadInt
    
    ; Process input
    cmp eax, 1        ; Snooze
    je SnoozeAlarm
    cmp eax, 2        ; Stop
    je StopAlarm
    
    ; Invalid input
    mov edx, OFFSET invalidInputMsg
    call WriteString
    call Crlf
    jmp AlarmLoop
    
SnoozeAlarm:
    mov snoozeFlag, 1
    mov edx, OFFSET snoozeMsg
    call WriteString
    call Crlf
    
    ; Stop the alarm sound
    INVOKE PlaySound, 0, 0, SND_PURGE
    
    ; Play confirmation beep
    INVOKE PlaySound, OFFSET beepSoundFile, 0, SND_FILENAME + SND_ASYNC
    
    jmp EndAlarm
    
StopAlarm:
    mov alarmFlag, 0
    mov edx, OFFSET stopMsg
    call WriteString
    call Crlf
    
    ; Stop the alarm sound
    INVOKE PlaySound, 0, 0, SND_PURGE
    
EndAlarm:
    ret
TriggerAlarm ENDP

END main
