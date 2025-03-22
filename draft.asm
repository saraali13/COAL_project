INCLUDE Irvine32.inc

.data
currHour   DWORD ?
currMin    DWORD ?
currSec    DWORD ?
alarmHour  DWORD ?
alarmMin   DWORD ?
alarmFlag  DWORD 0  ; 0 = Off, 1 = On

promptAlarmHour   BYTE "Enter Alarm Hour (0-23): ", 0
promptAlarmMin    BYTE "Enter Alarm Minute (0-59): ", 0
alarmTriggeredMsg BYTE "ALARM TRIGGERED! Beep Beep!", 0
currentTimeMsg    BYTE "Current Time: ", 0

.code
main PROC
    ; Input alarm time
    mov edx, OFFSET promptAlarmHour
    call WriteString
    call ReadInt
    mov alarmHour, eax

    mov edx, OFFSET promptAlarmMin
    call WriteString
    call ReadInt
    mov alarmMin, eax

    mov alarmFlag, 1  ; Enable the alarm

START_CLOCK:
    ; Read current system time
    call GetCurrentTime

    ; Display current time
    mov edx, OFFSET currentTimeMsg
    call WriteString

    ; Display hours
    mov eax, currHour
    call WriteDec
    mov al, ':'
    call WriteChar

    ; Display minutes
    mov eax, currMin
    call WriteDec
    mov al, ':'
    call WriteChar

    ; Display seconds
    mov eax, currSec
    call WriteDec
    call Crlf

    ; Check alarm condition
    call CheckAlarm

    ; Delay for 1 second
    call DelayOneSecond

    ; Repeat loop
    jmp START_CLOCK

    exit
main ENDP

; =======================
; Get Current Time
; =======================
GetCurrentTime PROC
    ; Use Irvine32 macro to fetch system time
    call GetMseconds
    mov eax, edx   ; Total seconds since midnight

    ; Calculate hours
    mov ecx, 3600
    xor edx, edx
    div ecx
    mov currHour, eax

    ; Calculate minutes
    mov eax, edx
    mov ecx, 60
    xor edx, edx
    div ecx
    mov currMin, eax

    ; Remaining seconds
    mov currSec, edx
    ret
GetCurrentTime ENDP

; =======================
; Alarm Check Logic
; =======================
CheckAlarm PROC
    cmp alarmFlag, 1
    jne CONTINUE_CLOCK

    CMP currHour, alarmHour
    jne CONTINUE_CLOCK
    CMP currMin, alarmMin
    jne CONTINUE_CLOCK

    ; Display Alarm Triggered Message
    mov edx, OFFSET alarmTriggeredMsg
    call WriteString
    call Crlf

    ; Audible Beep
    mov eax, 500      ; Frequency in Hz
    mov ebx, 1000     ; Duration in ms
    call Delay        ; Beep sound

    ; Disable alarm after ringing
    mov alarmFlag, 0

CONTINUE_CLOCK:
    ret
CheckAlarm ENDP

; =======================
; Delay Function (1 Second)
; =======================
DelayOneSecond PROC
    mov ecx, 1000  ; Delay for 1000 milliseconds (1 second)
    call Delay
    ret
DelayOneSecond ENDP

END main
