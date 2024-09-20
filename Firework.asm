; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; #########################################################################
;                     COMPILER DIRECTIVES
; #########################################################################
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
;               Fireworks - with MMX blur and light effects
;                   by ronybc from Kerala,INDIA
;                 website: http://www.ronybc.8k.com |
.686p                           ;Create 32 bit code
.MMX
.model flat,stdcall             ;32 bit memory model ;Investigar PowerProf.dll
option casemap:none             ;Case sensitive
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; #########################################################################
;                     INCLUDE FILES
; #########################################################################
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
    Include         \masm32\include\windows.inc
    Include         \masm32\include\dialogs.inc
    Include         \masm32\include\kernel32.inc
    Include         \masm32\include\gdi32.inc
    Include         \masm32\include\user32.inc
    Include         \masm32\include\Shell32.inc
    Include         \masm32\include\advapi32.inc        ;Registry Access
    Include         \masm32\include\powrprof.inc        ;Power Profile
    ;Include         \masm32\include\scrnsave.inc
    ;
    ;Include         \masm32\include\masm32.inc
    ;include         \masm32\macros\macros.asm
    ;
    Includelib      \masm32\lib\kernel32.lib
    Includelib      \masm32\lib\gdi32.lib
    Includelib      \masm32\lib\user32.lib
    Includelib      \masm32\lib\Shell32.lib
    Includelib      \masm32\lib\advapi32.lib
    Includelib      \masm32\lib\powrprof.lib
    ;Includelib      \masm32\lib\scrnsave.lib
    ;
    Include         macros.inc
    ;
    Dialogx MACRO quoted_text_title,quoted_font,fsize,dstyle,xstyle,ctlcnt,tx,ty,wd,ht,bsize
        push esi
        push edi
        invoke GlobalAlloc,GMEM_FIXED OR GMEM_ZEROINIT,bsize
        mov esi, eax
        mov edi, esi
        mov DWORD PTR [edi+0],  DS_SETFONT OR dstyle
        mov DWORD PTR [edi+4],  xstyle
        mov WORD  PTR [edi+8],  ctlcnt
        mov WORD  PTR [edi+10], tx
        mov WORD  PTR [edi+12], ty
        mov WORD  PTR [edi+14], wd
        mov WORD  PTR [edi+16], ht
        add edi, 22
        ustring quoted_text_title
        mov WORD PTR [edi], fsize
        add edi, 2
        ustring quoted_font
    ENDM    
;
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; #########################################################################
                    ;PROCEDURES
; #########################################################################
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
    PreviewDlgProc              PROTO :DWORD,:DWORD,:DWORD,:DWORD
    NormalDlgProc               PROTO :DWORD,:DWORD,:DWORD,:DWORD
    ScreenSaverDlgProc          PROTO :DWORD,:DWORD,:DWORD,:DWORD
    GetCmdLine                  PROTO :DWORD,:DWORD                         ;dArgNumber,pCstring
    GetArgNumber                PROTO :DWORD,:DWORD,:DWORD,:DWORD
    AscciiToDword               PROTO :DWORD                                ;pszCstring
    KillProcess                 PROTO :DWORD,:DWORD                         ;pszProgram,dUnhide
    EnumWindowsProc             PROTO :DWORD,:DWORD                         ;hwinparent,lparam=userdefinedparam
    ScreenSaverConfigureDlgSp   PROTO :DWORD
    ScreenSaverConfigureDlg     PROTO :DWORD
    ScreenSaverConfigureDlgProc PROTO :DWORD,:DWORD,:DWORD,:DWORD
    ListBoxDlg                  PROTO :DWORD,:DWORD
    ListBoxDlgProc              PROTO :DWORD,:DWORD,:DWORD,:DWORD
    ListBoxProc                 PROTO :DWORD,:DWORD,:DWORD,:DWORD
    RegisterManager             PROTO :DWORD            ;FALSE=READ, TRUE=WRITE
    FillBuffer                  PROTO :DWORD,:DWORD,:BYTE
    ;
    random                      PROTO :DWORD    ;proc base:DWORD        ; Park Miller random number algorithm
    Light_Flash3                PROTO :DWORD,:DWORD,:DWORD,:DWORD,:DWORD;proc x1:DWORD, y1:DWORD, lum:DWORD, src:DWORD, des:DWORD
    Blur_MMX2                   PROTO                                   ;proc                 ; 24bit color version
    FShell_explodeOS            PROTO :DWORD                            ;proc hb:DWORD
    FShell_explodeAG            PROTO :DWORD                            ;proc hb:DWORD
    FShell_render               PROTO :DWORD,:DWORD                     ;proc hb:DWORD, color:DWORD
    FShell_recycle              PROTO :DWORD,:DWORD,:DWORD              ;proc hb:DWORD, x:DWORD, y:DWORD
    FireThread                  PROTO
    MoniThread                  PROTO :DWORD
    Switch                      PROTO :DWORD,:DWORD                     ;oMode:DWORD, iid:DWORD
    ;
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
.const
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; #########################################################################
                    ;EQUATES
; #########################################################################
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; struct spark {float x,xv,y,yv;};
; struct FireShell {DWORD life; float air; spark d[250];};
; sizeof FireShell = 250*4*4+8 = 4008 bytes
    ;
    EXX                         equ 4
    EXY                         equ 8
    AIR                         equ 12
    SPARC                       equ 16
    FLIES                       equ 20
    ;
    LEFT_NOISE                  equ 64
    ;       POWER_ACTION enum
    ;=====================================
    POWER_ACTION_NONE           equ 0
    POWER_ACTION_RESERVED       equ 1
    POWER_ACTION_SLEEP          equ 2
    POWER_ACTION_HIBERNATE      equ 3
    POWER_ACTION_SHUTDOWN       equ 4
    POWER_ACTION_SHUTDOWNRESET  equ 5
    POWER_ACTION_SHUTDOWNOFF    equ 6
    POWER_ACTION_WARMEJECT      equ 7
    ;       Constants for GlobalFlags
    ;=====================================
    ENABLESYSTRAYBATTERYMETER   equ 001H
    ENABLEMULTIBATTERYDISPLAY   equ 002H
    ENABLEPASSWORDLOGON         equ 004H
    ENABLEWAKEONRING            equ 008H
    ENABLEVIDEODIMDISPLAY       equ 010H
    ;       SYSTEM_POWER_STATE enum
    ;=====================================
    POWERSYSTEMUNSPECIFIED      equ 0
    POWERSYSTEMWORKING          equ 1
    POWERSYSTEMSLEEPING1        equ 2
    POWERSYSTEMSLEEPING2        equ 3
    POWERSYSTEMSLEEPING3        equ 4
    POWERSYSTEMHIBERNATE        equ 5
    POWERSYSTEMSHUTDOWN         equ 6
    POWERSYSTEMMAXIMUM          equ 7
    ;
    IDGROUP300                  equ 1
    IDLIST300                   equ 2
    IDC_BTN300                  equ 3
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
.data
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; #########################################################################
                    ;ITIALIZED DATA SECTION
; #########################################################################
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
    szAskForConfigTitle         db "Firework Screensaver: Please confirm!",0
    szAskForConfigText          db "This is a menu dialog box: What Do you want to do?",10,10
                                db "Click YES to open the Configuration Window.",10,10
                                db "Click NO to open the Playing Window",10,10
                                db "Click CANCEL to Preview Screensaver",0
    szAskForConfigTitleSp       db "Firework Screensaver: Por favor confirme!",0
    szAskForConfigTextSp        db "Esto es un men· de opciones: ┐Quщ desea hacer?",10,10
                                db "Haga clic en ""SI"" Para abrir la ventana de configuraciєn.",10,10
                                db "Haga clic en ""NO"" para abrir la ventana l·dica.",10,10
                                db "haciendo clic en ""CANCELAR"" se abrirс el protector de pantalla.",0
    ;
    szErrorWriteRegText         db "Error Accessing the Window's Registry",0
    szErrorWriteRegTitle        db "Registry error",0
    szSubKey                    db "Software\Microsoft\Screensavers\Apocalypse Firewoks",0
    szValueEfectsBlur           db "Blur",0
    szValueEfectsAir            db "Air",0
    szValueEfectsFar            db "Far",0
    szValueEfectsLife           db "Life",0
    szValueEfectsShells         db "Shells",0
    szValueEfectsSparks         db "Sparks",0
    szValueEfectsPower          db "Power",0
    szValueDoNotDisturbApp      db "DoNotDisturbApp1",0
    dDoNotDistrub               dd 0
    dValueEfectsBlur            dd 1
    dValueEfectsAir             dd 1
    dValueEfectsFar             dd 0
    dValueEfectsShells          dd 5
    dValueEfectsSparks          dd 400
    dValueEfectsLife            dd 500
    dValueEfectsPower           dd 5
    szApp1                      db MAX_PATH dup(0)
    szApp2                      db MAX_PATH dup(0)
    szApp3                      db MAX_PATH dup(0)
    ;
    szInfo                      db "Apocalypse Fireworks Version: 3.40229 - Freeware",13,10
                                db  13,10
                                db "WARNING: This is a Fireware, softwares that push CPU temperature",13,10
                                db "to its maximum. It does No harm, but overclockers better stay away :)",13,10
                                db "Entire source code of this program is free available at my website. ",13,10
                                db  13,10
                                db "If you like the work, help the author with donations.",13,10
                                db "see http://www.ronybc.8k.com/support.htm",13,10,13,10,9
                                db "Screensaver version by www.carabez.com",0
                                ;
    szInfoSp                    db "Apocalypse Fireworks Version: 3.40229 - Freeware",13,10
                                db  13,10
                                db "ATENCI╙N: ╔ste es un programa pirotщcnico que calentarс el microprocesador",13,10
                                db "al mсximo. No hace daёo, pero overclockers mejor quщdense alejados :)",13,10
                                db "El cєdigo fuente de щste programa estс disponible gratis en mi sitio. ",13,10
                                db  13,10
                                db "Si le agrada el trabajo, por favor, ayude al autor con donaciones.",13,10
                                db "vaya a la pсgina http://www.ronybc.8k.com/support.htm",13,10,13,10,9
                                db "La versiєn en forma de Protector de Pantalla",13,10,9,9
                                db "por www.carabez.com",0
                                ;
    fps                         db 64 dup (0)
    fmat                        db "fps = %u   [www.ronybc.8k.com]",0
    ClassName                   db "apocalypse",0
    szAppName                   db "Fireworks MMX ...by ronybc",0,0,0,0,0,0
    info                        db "Fireworks Version: 3.40229 - Freeware",13,10
                                db  13,10
                                db "WARNING: This is a Fireware, softwares that push CPU temperature",13,10
                                db "to its maximum. It does No harm, but overclockers better stay away :)",13,10
                                db "Entire source code of this program is free available at my website. ",13,10
                                db  13,10
                                db "If you like the work, help the author with donations.",13,10
                                db "see http://www.ronybc.8k.com/support.htm",13,10
                                db  13,10
                                db "SPACE & ENTER keys toggles 'Gravity and Air' and",13,10
                                db "'Light and Smoke' effects respectively.",13,10
                                db "And clicks explode..! close clicks produce more light",13,10
                                db  13,10
                                db "Manufactured, bottled and distributed by",13,10
                                db "Silicon Fumes Digital Distilleries, Kerala, INDIA",13,10
                                db 13,10
                                db "Copyright 1999-2004 й Rony B Chandran. All Rights Reserved",13,10
                                db 13,10
                                db "This isn't the Final Version",13,10
                                db "check http://www.ronybc.8k.com for updates and more",0
                                ;
    szUsageText                 db "SYNTAX:",10,10
                                db "Firework [parameter:handle]",10,10
                                db "/p:handle",10,9,"Preview Mode:",10,9
                                db      "handle= Parent window handle (decimal ascii)",10,9
                                db      "to insert the preview child window.",10
                                db "/c",10,9,"Popup the Configuration window,",10,9
                                db      "Values are stored in Window's Registry.",10
                                db "/s",10,9,"Screensaver Mode.",10
                                db "/r",10,9,"Standard Window Operation.",0
                                ;
    szUsageTitle                db "Apocalypse FireWork Usage",0
    szInvalidHandleText         db "Invalida Parent Window Handle",0
    szInvalidHandleTitle        db "NO Preview",0
    seed                        dd 1113335557
    wwidth                      dd 650               ; 1:1.618, The ratio of beauty ;)
    wheight                     dd 400               ; smaller the window faster the fires
    maxx                        dd 123               ; 123: values set on execution
    maxy                        dd 123               ; this thing is best for comparing
    lightx                      dd 123               ; cpu performance.
    lighty                      dd 123
    flash                       dd 123
    flfactor                    dd 0.92
    adg                         dd 0.00024           ; 0.00096 acceleration due to gravity
    xcut                        dd 0.00064
    nb                          dd 5                 ; number of shells
    nd                          dd 400               ; sparks per shell
    sb                          dd 0                 ; value set on execution
    maxpower                    dd 5
    minlife                     dd 500               ; altered @WndProc:WM_COMMAND:1300  100<->500
    motionQ                     dd 16                ; 01-25, altered @WndProc:WM_COMMAND:1210
    fcount                      dd 0
    GMode                       dd 1                 ; atmosphere or outer-space
    CMode                       dd 0                 ; color shifter
    EMode                       dd 1                 ; special effects
    click                       dd 0
    stop                        dd 0
    fadelvl                     dd 1
    chemtable                   dd 00e0a0ffh, 00f08030h, 00e6c080h, 0040b070h,  00aad580h        
    ;
    bminf                       BITMAPINFO <<40,0,0,1,24,0,0,0,0,0,0>>
    ;
    align 16
    abntbl                      db 2,0,0,0,0,0,0,0,0,1,1,0,0,1,0,0
                                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                                db 1,0,3,0,0,0,0,0,0,0,0,0,1,0,0,0
                                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                                db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                                ; 0 = OK char
                                ; 1 = delimiting characters   tab LF CR space ","
                                ; 2 = ASCII zero    This should not be changed in the table
                                ; 3 = quotation     This should not be changed in the table
    ;
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
.data?
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; #########################################################################
                    ;UNITIALIZED DATA SECTION
; #########################################################################
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
    dSpanish                    dd ?
    hInstance                   HINSTANCE ?
    hwnd                        LPVOID ?
    hmnu                        HWND ?
    wnddc                       HDC ?
    hFThread                    HANDLE ?
    hHeap                       HANDLE ?
    idThread1                   DWORD ?
    idThread2                   DWORD ?
    bitmap1                     LPVOID ?
    bitmap2                     LPVOID ?
    hFShells                    LPVOID ?
    msg                         MSG <>
    wc                          WNDCLASSEX <>
    ;
;    pe32x                       PROCESSENTRY32 <>
;    hProcessex                  HANDLE ?
;    bIsRunningLoop              BOOL ?
    ;
    hIcon                       dd ?
    hWinMain                    dd ?
    szCL                        db MAX_PATH dup(?)
    dOperation                  dd ? ;Mode: 1=Preview,2=Configuration,3=Debug,4=Normal
    hWinParent                  dd ?
    szReturn                    db MAX_PATH dup(?)
    hList_01                    dd ?
    lpListBox_01                dd ?
    hSelectWindow               dd ?
    rect                        RECT<>
    pOldProc                    dd ?
    dOnce                       dd ?
    pos                         POINT <>
    ;
    POWER_ACTION_POLICY         STRUCT  4 ;align 4
                                Action      dd ? ;POWER_ACTION
                                Flags       dd ?
                                EventCode   dd ?
    POWER_ACTION_POLICY         ENDS
    ;
    ;Registry storage structures for the POWER_POLICY data. There are three
    ;structures, MACHINE_POWER_POLICY, MACHINE_PROCESSOR_POWER_POLICY and
    ;USER_POWER_POLICY. the MACHINE_POWER_POLICY stores per machine data for
    ;which there is no UI.  USER_POWER_POLICY stores the per user data.
    ;
    USER_POWER_POLICY           STRUCT  4 ;align 4
                                    Revision            dd ?   ;1
                                    ;"system idle" detection
                                    ;=====================================
                                    IdleAc              POWER_ACTION_POLICY<?,?,?>
                                    IdleDc              POWER_ACTION_POLICY<?,?,?>
                                    IdleTimeoutAc       dd ?
                                    IdleTimeoutDc       dd ?
                                    IdleSensitivityAc   db ?
                                    IdleSensitivityDc   db ?
                                    ;Throttling Policy
                                    ;=====================================
                                    ThrottlePolicyAc    db ?
                                    ThrottlePolicyDc    db ?
                                    ;meaning of power action "sleep"
                                    ;=====================================
                                    MaxSleepAc          dd ? ;SYSTEM_POWER_STATE
                                    MaxSleepDc          dd ? ;SYSTEM_POWER_STATE
                                    ;For future use
                                    ;=====================================
                                    Reserved           dd 2 DUP(<?,?>)
                                    ;video policies
                                    ;=====================================
                                    VideoTimeoutAc      dd ? ;ULONG
                                    VideoTimeoutDc      dd ? ;ULONG
                                    ;hard disk policies
                                    ;=====================================
                                    SpindownTimeoutAc   dd ? ;ULONG
                                    SpindownTimeoutDc   dd ? ;ULONG
                                    ;processor policies
                                    ;=====================================
                                    OptimizeForPowerAc  dd ? ;BOOLEAN
                                    OptimizeForPowerDc  dd ? ;BOOLEAN
                                    FanThrottleToleranceAc db ? ;CHAR
                                    FanThrottleToleranceDc db ? ;CHAR
                                    ForcedThrottleAc    db ? ;CHAR
                                    ForcedThrottleDc    db ? ;CHAR
    USER_POWER_POLICY           ENDS
    ;
    MACHINE_POWER_POLICY        STRUCT 4 ;align 4
                                    Revision            dd ? ; 1
                                    ;meaning of power action "sleep"
                                    ;=====================================
                                    MinSleepAc          dd ? ;SYSTEM_POWER_STATE
                                    MinSleepDc          dd ? ;SYSTEM_POWER_STATE
                                    ReducedLatencySleepAc dd ? ;SYSTEM_POWER_STATE
                                    ReducedLatencySleepDc dd ? ;SYSTEM_POWER_STATE
                                    ;parameters for dozing
                                    ;=====================================
                                    DozeTimeoutAc       dd ?
                                    DozeTimeoutDc       dd ?
                                    DozeS4TimeoutAc     dd ?
                                    DozeS4TimeoutDc     dd ?
                                    ;processor policies
                                    ;=====================================
                                    MinThrottleAc       db ?
                                    MinThrottleDc       db ?
                                    pad1                db 2 dup(<?,?>)
                                    OverThrottledAc     POWER_ACTION_POLICY<?,?,?>
                                    OverThrottledDc     POWER_ACTION_POLICY<?,?,?>
    MACHINE_POWER_POLICY        ENDS
    ;Structure to manage global power policies at the user level. This structure
    ;contains data which is common across all power policy profiles.
    POWER_POLICY                STRUCT 4
                                    user USER_POWER_POLICY   <> ;?,<?,?,?>,<?,?,?>,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?>
                                    mach MACHINE_POWER_POLICY <> ;<?,?,?,?,?,?,?,?,?,?,?,<?,?>,<?,?,?>,<?,?,?>>
    POWER_POLICY                ENDS
    ;pp                          equ <POWER_POLICY> ;POWER_POLICY<>
;    pp                          STRUCT 4
;                                    user USER_POWER_POLICY   <> ;<?,<?,?,?>,<?,?,?>,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?>
;                                    mach MACHINE_POWER_POLICY <> ;<?,?,?,?,?,?,?,?,?,?,?,<?,?>,<?,?,?>,<?,?,?>>
;    pp                          ENDS
    dIdle                       dd ?
    ;
;      MOUSEINPUT      struct
;        ddx             dd ? ;dx
;        ddy             dd ? ;dy
;        mouseData       dd ?
;        dwFlags         dd ?
;        time            dd ?
;        dwExtraInfo     dd ?
;      MOUSEINPUT      ends
;      ;
;      KEYBDINPUT      struct
;        wVk             dw ?
;        wScan           dw ?
;        dwFlags         dd ?
;        time            dd ?
;        dwExtraInfo     dd ?
;      KEYBDINPUT      ends
;      ;
;      HARDWAREINPUT   struct
;        uMsg            dd ?
;        wParamL         dw ?
;        wParamH         dw ?
;      HARDWAREINPUT   ends
;      ;
      INPUT           struct
        ddType          dd ?  ;INPUT_MOUSE,INPUT_KEYBOARD,INPUT_HARDWARE
        UNION
          mi            MOUSEINPUT <>
          ki            KEYBDINPUT <>
          hi            HARDWAREINPUT <>
        ENDS
      INPUT           ends
      input           INPUT <>
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
.code
start:
    invoke GetModuleHandle,NULL
    mov hInstance,eax
    mov wc.hInstance,eax
    ;
    Invoke LoadIcon,hInstance,100
    mov hIcon,eax
    ;
    xor eax,eax
    mov hWinParent,eax
    mov dOperation,eax
    mov dOnce,eax
    mov dSpanish,eax
    Invoke GetKeyboardLayout,NULL
    mov cx,ax
    .if (ax==0440AH)||(ax==0480AH)||(ax==04C0AH)||(ax==0500AH)
        add dSpanish,1
    .endif
    .if (ax==0040AH)||(ax==0080AH)||(ax==00C0AH)||(ax==0100AH)||\
        (ax==0140AH)||(ax==0180AH)||(ax==01C0AH)||(ax==0200AH)||\
        (ax==0240AH)||(ax==0280AH)||(ax==02C0AH)||(ax==0300AH)||\
        (ax==0340AH)||(ax==0380AH)||(ax==03C0AH)||(ax==0400AH)
        add dSpanish,1
    .endif
    ;Invoke GetCmdLine,1,addr szCL ;1=Success,2=No Argument,3=Non Match Quotation Marks
    ;Invoke MessageBox,NULL,addr szCL,NULL,NULL
    Invoke GetDesktopWindow
    mov hWinParent,eax    
    ;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
    ;               COMMAND LINE
    ;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-    
    Invoke GetCmdLine,1,addr szCL ;1=Success,2=No Argument,3=Non Match Quotation Marks
    .if eax==2
        .if dSpanish
            Invoke MessageBox,NULL,addr szAskForConfigTextSp,addr szAskForConfigTitleSp,MB_YESNOCANCEL+MB_ICONQUESTION+MB_DEFBUTTON1
        .else
            Invoke MessageBox,NULL,addr szAskForConfigText,addr szAskForConfigTitle,MB_YESNOCANCEL+MB_ICONQUESTION+MB_DEFBUTTON1
        .endif
        .if eax == IDYES
            mov dOperation,2 ;1=Preview,2=Configuration,3=Debug,4=Sreensaver,5=Normal,6=Pass,7=Invalid Arg
        .elseif eax == IDNO
            mov dOperation,5 ;1=Preview,2=Configuration,3=Debug,4=Sreensaver,5=Normal,6=Pass,7=Invalid Arg
        .else
            mov dOperation,4
        .endif
    .elseif eax==3
        mov dOperation,7 ;1=Preview,2=Configuration,3=Debug,4=Sreensaver,5=Normal,6=Pass,7=Invalid Arg
    .else ; eax==1
        Invoke lstrlen, addr szCL
        .if eax < 2
            mov dOperation,7 ;1=Preview,2=Configuration,3=Debug,4=Sreensaver,5=Normal,6=Pass,7=Invalid Arg
        .else
            lea eax,szCL
            .if ( (byte ptr[eax]!='/') && (byte ptr[eax]!='-') )
                mov dOperation,7  ;1=Preview,2=Configuration,3=Debug,4=Sreensaver,5=Normal,6=Pass,7=Invalid Arg
            .else
                add eax,1
                mov cl,byte ptr[eax]
                .if ( (cl=='p') || (cl=='P') )
                    Invoke GetCmdLine,2,addr szCL
                    ;Invoke MessageBox,NULL,addr szCL,NULL,NULL
                    Invoke AscciiToDword,addr szCL
                    mov hWinParent,eax
                    Invoke GetTickCount
                    add seed,eax
                    Invoke IsWindow,hWinParent
                    .if eax==NULL
                        Invoke MessageBox,NULL,addr szInvalidHandleText,addr szInvalidHandleTitle,MB_OK
                        jmp Exit_App
                    .else
                        mov dOperation,1  ;1=Preview,2=Configuration,3=Debug,4=Sreensaver,5=Normal,6=Pass,7=Invalid Arg
                    .endif
                .elseif ( (cl=='s') || (cl=='S') )
                    Invoke GetDesktopWindow
                    mov hWinParent,eax
                    Invoke GetTickCount
                    add seed,eax
                    mov dOperation,4 ;1=Preview,2=Configuration,3=Debug,4=Sreensaver,5=Normal,6=Pass,7=Invalid Arg
                .elseif ( (cl=='c') || (cl=='C') )
                    ;Invoke MessageBox,NULL,addr szCL,NULL,NULL
                    mov dOperation,2 ;1=Preview,2=Configuration,3=Debug,4=Sreensaver,5=Normal,6=Pass,7=Invalid Arg
                    Invoke GetCmdLine,2,addr szCL
                    Invoke AscciiToDword,addr szCL
                    mov hWinParent,eax
                    Invoke GetTickCount
                    add seed,eax
                    Invoke IsWindow,hWinParent
                    .if eax==NULL
                        Invoke GetForegroundWindow
                        mov hWinParent,eax
                    .endif
                .elseif ( (cl=='d') || (cl=='D') )
                    mov dOperation,5 ;1=Preview,2=Configuration,3=Debug,4=Sreensaver,5=Normal,6=Pass,7=Invalid Arg
                .elseif ( (cl=='a') || (cl=='A') )
                    mov dOperation,7 ;1=Preview,2=Configuration,3=Debug,4=Sreensaver,5=Normal,6=Pass,7=Invalid Arg
                .elseif ( (cl=='r') || (cl=='R') )
                    mov dOperation,5 ;1=Preview,2=Configuration,3=Debug,4=Sreensaver,5=Normal,6=Pass,7=Invalid Arg
                .else
                    mov dOperation,7  ;1=Preview,2=Configuration,3=Debug,4=Sreensaver,5=Normal,6=Pass,7=Invalid Arg
                .endif
                ;
            .endif
        .endif
    .endif
    Invoke GetCmdLine,0,addr szCL
    ;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
    ;               OPERATION MODE
    ;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
    .if     dOperation==1 ;1=Preview
        call main
    .elseif dOperation==2 ;2=Configuration
        .if dSpanish
            Invoke ScreenSaverConfigureDlgSp,NULL
        .else
            Invoke ScreenSaverConfigureDlg,NULL
        .endif
        jmp Exit_App
    .elseif dOperation==3 ;3=Debug
        @@:
        call main
    .elseif dOperation==4 ;4=Sreensaver
        @@:
        call main      
    .elseif dOperation==5 ;5=Normal
        @@:
        call main
    .elseif (dOperation==7) || (dOperation==6) ;6=Pass,7=Invalid Arg
        Invoke MessageBox,NULL,addr szUsageText,addr szUsageTitle,MB_OK
        xor eax,eax
        jmp Exit_App
    .endif
    ;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
    ;               EXIT
    ;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
;    @@:
;        mov eax,idThread1
;        or  eax,idThread2
;        not eax
;        and eax,eax
;        jnz @B
    Exit_App:
    ;
    Invoke ExitProcess,eax
;ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; #########################################################################
                    ;WinMain For RunHide
; #########################################################################
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
align 4
main                            proc
                                LOCAL lpArgs:DWORD
    ;WS_POPUP+WS_OVERLAPPED+WS_CLIPCHILDREN+WS_CAPTION+WS_SYSMENU+WS_MINIMIZEBOX+WS_MAXIMIZEBOX+DS_CENTER+WS_THICKFRAME
    Invoke GlobalAlloc,GMEM_FIXED or GMEM_ZEROINIT, 32
    mov lpArgs, eax
    push hIcon
    pop [eax]
    Dialog  "FireWork Luncher","Ms Sans Serif",8, \        ; caption,font,pointsize MS Sans Serif
            WS_POPUP+WS_EX_TOPMOST+WS_OVERLAPPED+WS_CAPTION+WS_SYSMENU+WS_MINIMIZEBOX+WS_MAXIMIZEBOX+DS_CENTER+WS_THICKFRAME,\ ;WS_EX_TOOLWINDOW,\    ;Coment if Dialog Macro
            0, \                                ; control count
            0,0,680,420, \                    ; x y co-ordinates
            4096                                ; memory buffer size
    ;
    .if dOperation==1                   ;1=Preview
        CallModalDialog hInstance,0,PreviewDlgProc,ADDR lpArgs
    .elseif dOperation==4               ;4=Sreensaver
        CallModalDialog    hInstance,0,ScreenSaverDlgProc,ADDR lpArgs
        ;CallModelessDialog hInstance,0,ScreenSaverDlgProc,ADDR lpArgs ;Instance,Parent,DlgProc,lpExtra
    .else                               ;5=Normal
        CallModalDialog hInstance,0,NormalDlgProc,ADDR lpArgs
        ;CallModelessDialog hInstance,0,ScreenSaverDlgProc,ADDR lpArgs ;Instance,Parent,DlgProc,lpExtra
    .endif
    ;
    pop esi
    ;
    Invoke GlobalFree, lpArgs
    ;
    ret
    ;
main                            endp
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
;                       DIALOG PROCEDURE FOR WinMain
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
align 4
ScreenSaverDlgProc              proc hWnd:DWORD,uMsg:DWORD,wParam:DWORD,lParam:DWORD
                                ;
                                LOCAL bLoop:BOOL
                                LOCAL pe32:PROCESSENTRY32
                                LOCAL hProcesses:HANDLE
                                ;
                                LOCAL pParameter:DWORD
                                LOCAL dReturn:DWORD
                                LOCAL dPwrScheme:DWORD
                                LOCAL ps:SYSTEM_POWER_STATUS
                                LOCAL pp:POWER_POLICY
                                ;
                                LOCAL hForeThread:DWORD
                                LOCAL hAppThread:DWORD
                                ;LOCAL szMessage[MAX_PATH]:BYTE
                                ;szText szFormat,"Times %d,%d,%d,%d"

        ;
        .if uMsg == WM_INITDIALOG   ;CreateWindowEx: WM_NCCREATE, WM_NCCALCSIZE, and WM_CREATE messages to the window being created.
                                    ;Before returning, CreateWindow sends a WM_CREATE message to the window procedure.
            ;            
            Invoke RegisterManager,FALSE            
            ;
            .if dOperation==4 ;1=Preview,2=Configuration,3=Debug,4=Sreensaver,5=Normal,6=Pass,7=Invalid Arg
                ;===========================================
                ;Check for a running application
                mov bLoop,TRUE
                mov dDoNotDistrub,FALSE
                Invoke CreateToolhelp32Snapshot,TH32CS_SNAPPROCESS,0
                mov hProcesses,eax
                mov pe32.dwSize,SIZEOF PROCESSENTRY32
                ;                
                Invoke Process32First,hProcesses,addr pe32
                .if eax!=0
                    .while bLoop
                        Invoke CompareString,LOCALE_USER_DEFAULT,NORM_IGNORECASE,addr pe32.szExeFile, -1,addr szApp1, -1
                        .if eax==2
                            ;Invoke MessageBox,NULL,addr szApp1,addr pe32.szExeFile,NULL
                            mov dDoNotDistrub,TRUE
                            jmp @F
                        .endif
                        Invoke CompareString,LOCALE_USER_DEFAULT,NORM_IGNORECASE, addr pe32.szExeFile, -1,addr szApp2, -1
                        .if eax==2
                            ;Invoke MessageBox,NULL,addr szApp2,addr pe32.szExeFile,NULL
                            mov dDoNotDistrub,TRUE
                            jmp @F
                        .endif
                        Invoke CompareString,LOCALE_USER_DEFAULT,NORM_IGNORECASE, addr pe32.szExeFile, -1,addr szApp3, -1
                        .if eax==2
                            ;Invoke MessageBox,NULL,addr szApp3,addr pe32.szExeFile,NULL
                            mov dDoNotDistrub,TRUE
                            jmp @F
                        .endif
                        Invoke Process32Next, hProcesses,addr pe32
                        mov bLoop,eax
                    .endw
                    @@:
                    Invoke CloseHandle,hProcesses
                .endif                
                .if dDoNotDistrub==TRUE
                    Invoke SendMessage,hWnd,WM_SYSCOMMAND,SC_MONITORPOWER,-1 ;MONITOR_ON  equ -1 MONITOR_LOW equ 1 MONITOR_OFF equ 2
                    ;
                    mov input.ddType,INPUT_KEYBOARD
                    mov input.ki.wVk,0
                    mov input.ki.wScan,0
                    mov input.ki.dwFlags,0 ;KEYEVENTF_UNICODE ;OR KEYEVENTF_EXTENDEDKEY ;>>><<<; KEYEVENTF_KEYUP ;KEYEVENTF_UNICODE ;KEYEVENTF_EXTENDEDKEY,KEYEVENTF_KEYUP,KEYEVENTF_SCANCODE
                    mov input.ki.time,0
                    mov input.ki.dwExtraInfo,0
                    ;
                    ;mov input.ki.wVk,VK_SHIFT
                    ;mov input.ki.wScan,VK_CONTROL
                    Invoke SendInput,1,addr input,sizeof INPUT   ;keybd_event
                    add input.ki.dwFlags,KEYEVENTF_KEYUP ;OR KEYEVENTF_UNICODE   ;KEYEVENTF_SCANCODE + KEYEVENTF_KEYUP ;
                    Invoke SendInput,1,addr input,sizeof INPUT   ;keybd_event
                    ;
                    ;Invoke EndDialog,hWnd,0             ;Invoke EndDialog,hWin,0 ;Only for ModalDialog
                    ;Invoke PostQuitMessage,0
                    ;xor eax,eax
                    ;jmp Return_ScreenSaverDlgProc
                    ;
                    jmp Destroy_ScreenSaverDlgProc
                    ;
                .endif
                ;
                ;Invoke ShowWindow,hWnd,SW_SHOW
                ;Invoke SetForegroundWindow,hWnd
                                                
                Invoke GetCurrentProcess
                Invoke SetPriorityClass,eax,IDLE_PRIORITY_CLASS
                .if eax ;If the function succeeds, the return value is nonzero.
                    Invoke SetProcessShutdownParameters,03FFH,SHUTDOWN_NORETRY
                .endif
                xor eax,eax
                mov dPwrScheme,eax
                Invoke IsPwrSuspendAllowed
                add dPwrScheme,eax
                Invoke IsPwrHibernateAllowed
                add dPwrScheme,eax
                Invoke IsPwrShutdownAllowed
                add dPwrScheme,eax                
                .if dPwrScheme
                    Invoke GetActivePwrScheme,addr dPwrScheme
                    .if eax!=FALSE
                        ;                                                
                        Invoke ReadPwrScheme,dPwrScheme,addr pp 
                        .if eax!=FALSE
                        ;Invoke MessageBox,NULL,addr szCL,NULL,NULL                        
                            ;Monitor: pp.user.VideoTimeoutAc
                            ;HardDisks: pp.user.SpindownTimeoutAc
                            ;Idle: pp.user.IdleTimeoutAc
                            ;
                            Invoke GetSystemPowerStatus,addr ps
                            .if ps.ACLineStatus==TRUE
                                mov eax,pp.user.IdleTimeoutAc
                                mov ecx,pp.user.VideoTimeoutAc
                            .else
                                mov eax,pp.user.IdleTimeoutDc
                                mov ecx,pp.user.VideoTimeoutDc
                            .endif
                            ;.if eax > ecx
                            ;    mov eax,ecx
                            ;.endif
                            .if eax!=0
                                sub eax,1
                                mov dIdle,eax
                                ;Invoke SetTimer,hWnd,1124,1000,NULL
                            .endif
                        .endif
                        ;
                    .endif
                    ;
                .endif
            .endif            
            ;
            ;EnumDisplayMonitors
            Invoke SystemParametersInfo,SPI_SETSCREENSAVERRUNNING,FALSE,NULL,NULL
            ;
            mov eax,hWnd
            mov hWinMain,eax
            mov hwnd,eax
            ;
            mov pos.x,0
            mov pos.y,0
            ;
            @@:
                Invoke ShowCursor,FALSE
                .if eax!=-1
                    jmp @B
                .endif
            ;
            Invoke SystemParametersInfo,SPI_SETSCREENSAVERRUNNING,TRUE,NULL,NULL
            ;
            Invoke GetWindowRect,hWinParent,addr rect
            ;
            ;rect.right=GetSystemMetrics(SM_CXSCREEN);
            ;rect.bottom=GetSystemMetrics(SM_CYSCREEN);}

            mov ecx,rect.left
            mov eax,rect.right
            sub eax,ecx
            add eax,eax
            mov wwidth,eax
            mov ecx,rect.top
            mov eax,rect.bottom
            sub eax,ecx
            add eax,eax
            ;add eax,200
            mov wheight,eax
            ;
            Invoke SetWindowText,hWnd,NULL
            Invoke SetWindowLong,hWnd,GWL_STYLE,NULL
            ;Invoke MoveWindow,hWnd,0,0,wwidth,wheight,FALSE
            ;Invoke ShowWindow,hWnd,SW_SHOWNORMAL            
            Invoke SetWindowPos,hWnd,HWND_TOPMOST,0,0,wwidth,wheight,SWP_SHOWWINDOW 
            ;
            mov eax,dValueEfectsLife
            mov minlife,eax                         ;500==long interval between shoots,100==short interval
            mov eax,dValueEfectsShells
            mov nb,eax
            mov eax,dValueEfectsSparks
            mov nd,eax
            mov eax,dValueEfectsPower
            mov maxpower,eax
            ;
            mov stop,0
            mov pParameter,0
            Invoke CreateThread,0,4096,addr FireThread,addr pParameter,0,addr idThread2
            mov hFThread,eax
            .if dOperation==4 ;1=Preview,2=Configuration,3=Debug,4=Sreensaver,5=Normal,6=Pass,7=Invalid Arg
                ;This is by design: a saver is meant to let important stuff happen while it is running.
                mov eax,THREAD_PRIORITY_IDLE              
            .else
                mov eax,THREAD_PRIORITY_HIGHEST
            .endif
            Invoke SetThreadPriority,hFThread,eax            
            ;
            .if dValueEfectsBlur==FALSE
                Invoke Switch,addr EMode,1220
                mov flash,0
            .endif
            .if dValueEfectsAir==FALSE
                Invoke Switch,addr GMode,1200
            .endif
            .if dValueEfectsFar==TRUE
                Invoke Switch,addr CMode,1210
                mov ecx,CMode
                mov eax,16
                shr eax,cl
                mov motionQ,eax                     ; changing motionQ affects speed
            .endif
            ;
            .if dIdle
                Invoke SetTimer,hWnd,1124,1000,NULL
            .endif
            ;

            ;             
;            Invoke GetForegroundWindow
;            Invoke GetWindowThreadProcessId,eax,NULL
;            mov hForeThread,eax
;            Invoke GetCurrentThreadId
;            mov hAppThread,eax
;            sub eax,hForeThread
;            .if eax
;               Invoke AttachThreadInput,hForeThread,hAppThread,TRUE
;               Invoke BringWindowToTop,hWnd   
;               ;Invoke SetForegroundWindow,hWnd
;               Invoke ShowWindow,hWnd,SW_SHOW
;               Invoke AttachThreadInput,hForeThread,hAppThread,FALSE 
;            .else
;               Invoke BringWindowToTop,hWnd                  
;               Invoke ShowWindow,hWnd,SW_SHOW
;               ;
;               ;Invoke SetForegroundWindow,hWnd                            
;            .endif
            ;
;        .elseif uMsg == WM_SETFOCUS
;            Invoke GetForegroundWindow
;            Invoke GetWindowThreadProcessId,eax,NULL
;            mov hForeThread,eax
;            Invoke GetCurrentThreadId
;            mov hAppThread,eax
;            sub eax,hForeThread
;            .if eax
;               Invoke AttachThreadInput,hForeThread,hAppThread,TRUE
;               Invoke BringWindowToTop,hWnd   
;               ;Invoke SetForegroundWindow,hWnd
;               Invoke ShowWindow,hWnd,SW_SHOW
;               Invoke AttachThreadInput,hForeThread,hAppThread,FALSE 
;            .else
;               Invoke BringWindowToTop,hWnd                  
;               Invoke ShowWindow,hWnd,SW_SHOW
;               ;
;               ;Invoke SetForegroundWindow,hWnd                            
;            .endif        
;           ;
;           Invoke SetForegroundWindow,hWnd
;           mov dReturn,FALSE        ;An application should return zero if it processes this message.                    
        .elseif uMsg == WM_TIMER
            .if dIdle == 0
                jmp @F
            .endif
            sub dIdle,1
            jnz @F
                ;Invoke SuspendThread,hFThread
                ;Invoke KillTimer,hWnd,1124
;                Invoke SetSystemPowerState,\
;                    TRUE , \    ;Suspension technique. If TRUE, the system suspends using RAM-alive technique. Otherwise, suspends using hibernate technique.
;                    FALSE       ;If FALSE, the function sends a PBT_APMQUERYSUSPEND
;                .if eax == 0 ;If the system was not suspended, the return value is zero. To get extended error information, call GetLastError.
;                    Invoke GetSystemPowerStatus,addr ps
;                    .if ps.ACLineStatus==TRUE
;                        mov eax,pp.user.IdleTimeoutAc
;                    .else
;                        mov eax,pp.user.IdleTimeoutDc
;                    .endif
;                    mov dIdle,eax
;                    jmp @F
;                .endif
                Invoke SetSuspendState,FALSE,FALSE,FALSE
                                ;Hibernate:     If this parameter is TRUE, the system hibernates. If the parameter is FALSE, the system is suspended.
                                ;ForceCritical: Windows Server 2003, Windows XP, and Windows 2000:  If this parameter is TRUE, the system suspends operation immediately;
                                                ;if it is FALSE, the system broadcasts a PBT_APMQUERYSUSPEND event to each application to request permission
                                                ;to suspend operation.
                                ;DisableWakeEvent If this parameter is TRUE, the system disables all wake events. If the parameter is FALSE, any system wake events remain enabled.
                .if eax!=NULL   ;If the function succeeds, the return value is nonzero.
                    Invoke SuspendThread,hFThread
                    Invoke KillTimer,hWnd,1124
                .endif
;                ;
;                Invoke GetSystemPowerStatus,addr ps
;                .if ps.ACLineStatus==TRUE
;                    mov eax,pp.user.IdleTimeoutAc
;                .else
;                    mov eax,pp.user.IdleTimeoutDc
;                .endif
;                mov dIdle,eax
            @@:
            jmp Return_ScreenSaverDlgProc
;        .elseif uMsg == WM_POWER
;            .if wParam = PWR_SUSPENDREQUEST
;
;            .endif
        .elseif uMsg == WM_POWERBROADCAST
            .if wParam== PBT_APMQUERYSUSPEND
                mov eax,TRUE ;Return TRUE to grant the request to suspend. To deny the request, return BROADCAST_QUERY_DENY.
                jmp Return_ScreenSaverDlgProc
            .elseif wParam==PBT_APMPOWERSTATUSCHANGE
                jmp Destroy_ScreenSaverDlgProc
            .elseif ( (wParam==PBT_APMQUERYSUSPENDFAILED) || (wParam==PBT_APMQUERYSTANDBYFAILED) )
                Invoke GetSystemPowerStatus,addr ps
                .if ps.ACLineStatus==TRUE
                    mov eax,pp.user.IdleTimeoutAc
                    mov ecx,pp.user.VideoTimeoutAc
                .else
                    mov eax,pp.user.IdleTimeoutDc
                    mov ecx,pp.user.VideoTimeoutDc
                .endif
                ;.if eax > ecx
                ;    mov eax,ecx
                ;.endif
                .if eax!=0
                    sub eax,1
                    mov dIdle,eax
                .endif
                Invoke ResumeThread,hFThread
            .endif
            jmp Destroy_ScreenSaverDlgProc
            ;
        .elseif ( (uMsg==WM_SIZE) && (wParam!=SIZE_MINIMIZED) )
            xor edx,edx
            mov eax,lParam
            mov dx,ax
            shr eax,16
            shr edx,2
            shl edx,2
            add edx,LEFT_NOISE      ;Top Left white spot and left blur shining noise
            mov maxx,edx
            mov maxy,eax
            mov bminf.bmiHeader.biWidth,edx
            neg eax          ; -maxy
            mov bminf.bmiHeader.biHeight,eax 
            ;
;            Invoke GetForegroundWindow
;            Invoke GetWindowThreadProcessId,eax,NULL
;            mov hForeThread,eax
;            Invoke GetCurrentThreadId
;            mov hAppThread,eax
;            sub eax,hForeThread
;            .if eax
;               Invoke AttachThreadInput,hForeThread,hAppThread,TRUE
;               Invoke BringWindowToTop,hWnd   
;               Invoke SetForegroundWindow,hWnd
;               Invoke ShowWindow,hWnd,SW_SHOW
;               Invoke AttachThreadInput,hForeThread,hAppThread,FALSE 
;            .else
;               Invoke BringWindowToTop,hWnd                  
;               Invoke ShowWindow,hWnd,SW_SHOW
;               ;
;               Invoke SetForegroundWindow,hWnd                             
;            .endif        
;           ;
;           Invoke SetForegroundWindow,hWnd                                         
        .elseif (uMsg==WM_MOUSEMOVE)
            mov dReturn,FALSE
            ;jmp Destroy_ScreenSaverDlgProc
            mov eax,lParam
            movzx ecx,ax   ;xPos = LOWORD(lParam);  // horizontal position of cursor
            shr eax,16
            movzx edx,ax   ;yPos = HIWORD(lParam);  // vertical position of cursor
            .if ( (pos.x==0) && (pos.y==0) )
                mov pos.x,ecx
                mov pos.y,edx
            .else
                sub ecx,pos.x
                .if ( (ecx > 100) )
                    jmp Destroy_ScreenSaverDlgProc
                .endif
                sub edx,pos.y
                .if ( (edx > 100) )
                    jmp Destroy_ScreenSaverDlgProc
                .endif
            .endif
        .elseif ( (uMsg==WM_LBUTTONDOWN) || (uMsg==WM_MBUTTONDOWN) || (uMsg==WM_RBUTTONDOWN) || (uMsg==WM_KEYDOWN) || (uMsg==WM_KEYUP) )
            ;By default, these will cause the program to terminate.
            ;Unless the password option is enabled.  In that case the DlgGetPassword() dialog box is brought up.
            mov dReturn,FALSE
            .if dOnce==FALSE
                mov dOnce,TRUE
            .else
                jmp Destroy_ScreenSaverDlgProc
            .endif
        .elseif (uMsg == WM_ACTIVATEAPP)
            .if wParam==FALSE ;This parameter is TRUE if the window is being activated; it is FALSE if the window is being deactivated.
                mov dReturn,FALSE
                jmp Destroy_ScreenSaverDlgProc
            .endif
        .elseif (uMsg == WM_ACTIVATE)
            mov eax,wParam      ;Value of the low-order word of wParam. Specifies whether the window is being activated or deactivated.
            .if ax==WA_INACTIVE  ;If wParam is FALSE, terminates the screen saver.
                mov dReturn,FALSE
                jmp Destroy_ScreenSaverDlgProc
            .endif
        .elseif (uMsg==WM_NCACTIVATE)
            mov eax,wParam      ;Value of the low-order word of wParam. Specifies whether the window is being activated or deactivated.
            .if ax==FALSE  ;If wParam is FALSE, terminates the screen saver.
                mov dReturn,FALSE
                jmp Destroy_ScreenSaverDlgProc
            .endif
        .elseif (uMsg == WM_CLOSE)
            Destroy_ScreenSaverDlgProc:
            ;After it has finished it should call
            Invoke ResumeThread,hFThread
            Invoke SystemParametersInfo,SPI_SETSCREENSAVERRUNNING,FALSE,NULL,NULL
            mov stop,1                          ; stop running threads
            Invoke Sleep,100                    ; avoid FireThread drawing without window
            ;Invoke DestroyWindow,hWnd          ;Invoke DestroyWindow,hWin ;ModelessDialog
            Invoke EndDialog,hWnd,0             ;Invoke EndDialog,hWin,0 ;Only for ModalDialog
            mov eax,dReturn
            jmp Return_ScreenSaverDlgProc
        .elseif ( (uMsg == WM_DESTROY ) || (uMsg == WM_NCDESTROY) )
            .if stop==0                          ; stop running threads
                mov stop,1                          ; stop running threads
                Invoke ResumeThread,hFThread
                Invoke Sleep,100                    ; avoid FireThread drawing without window
                .if wnddc
                    Invoke ReleaseDC,hWinMain,wnddc
                .endif
            .endif
            Invoke PostQuitMessage,0
            xor eax,eax
            jmp Return_ScreenSaverDlgProc
        .elseif uMsg == WM_SYSCOMMAND
            and wParam,0FFFFFFF0H ;In WM_SYSCOMMAND messages, the four low-order bits of the uCmdType parameter are used internally by Windows
            .if ( (wParam == SC_SCREENSAVE) || (wParam == SC_CLOSE) )
                ;return FALSE if wParam is SC_SCREENSAVE or SC_CLOSE
                mov dReturn,FALSE
                ;jmp Destroy_ScreenSaverDlgProc
                jmp Exit_ScreenSaverDlgProc
            .else
                jmp DefWin_ScreenSaverDlgProc
            .endif
        .else
            DefWin_ScreenSaverDlgProc:
            Invoke DefWindowProc,hWnd,uMsg,wParam,lParam
            xor eax,eax
            jmp Return_ScreenSaverDlgProc
        .endif
        Exit_ScreenSaverDlgProc:
        mov eax,dReturn
        Return_ScreenSaverDlgProc:
    ret
ScreenSaverDlgProc              endp
; -------------------------------------------------------------------------
align 4
PreviewDlgProc                  proc hWnd:DWORD,uMsg:DWORD,wParam:DWORD,lParam:DWORD
                                ;
                                LOCAL pParameter:DWORD
        ;
        .if uMsg == WM_INITDIALOG
            ;
            mov eax,hWnd
            mov hWinMain,eax
            mov hwnd,eax
            ;
            Invoke GetWindowRect,hWinParent,addr rect
            mov ecx,rect.left
            mov eax,rect.right
            sub eax,ecx
            add eax,eax
            add eax,4
            mov wwidth,eax
            mov ecx,rect.top
            mov eax,rect.bottom
            sub eax,ecx
            add eax,eax
            add eax,4
            mov wheight,eax
            ;
            Invoke SetWindowText,hWinMain,NULL
            ;Set the preview window as the parent of this window
            Invoke SetParent,hWinMain, hWinParent
            ;Make this a child window so it will close when the parent dialog closes
            Invoke GetWindowLong,hWinMain,WS_CHILD ;GWL_STYLE OR WS_CHILD
            Invoke SetWindowLong,hWinMain,GWL_STYLE,eax
            ;Place our window inside the parent
            Invoke MoveWindow,hWinMain,-2,-2,wwidth,wheight,FALSE
            Invoke GetWindowLong,hWinParent,GWL_WNDPROC
            mov pOldProc,eax ;save old proc
            Invoke SetWindowLong,hWinMain,GWL_WNDPROC,addr PreviewDlgProc
            Invoke ShowWindow,hWinMain,SW_SHOWNORMAL
            Invoke UpdateWindow,hWinMain
            ;
            mov pParameter,0
            Invoke CreateThread,0,4096,addr FireThread,addr pParameter,0,ADDR idThread2
            mov hFThread,eax
            Invoke UpdateWindow,hWnd
            ;
            Invoke RegisterManager,FALSE
            ;
            .if dValueEfectsBlur==FALSE
                Invoke Switch,addr EMode,1220
                mov flash,0
            .endif
            ;
            .if dValueEfectsAir==FALSE
                Invoke Switch,addr GMode,1200
            .endif
            ;
            .if dValueEfectsFar==TRUE
                Invoke Switch,addr CMode,1210
                mov ecx,CMode
                mov eax,16
                shr eax,cl
                mov motionQ,eax                     ; changing motionQ affects speed
            .endif
            ;
            mov eax,dValueEfectsLife
            mov minlife,eax                         ;500==long interval between shoots,100==short interval
            mov eax,dValueEfectsShells
            mov nb,eax
            mov eax,dValueEfectsSparks
            mov nd,eax
            mov eax,dValueEfectsPower
            mov maxpower,eax
            ;
;            ;================= RESET ================
;            Invoke SuspendThread,hFThread   ; suffering technical difiiculties :)
;            mov eax,maxx                    ; major motiv - to see ZeroMem in acion
;            imul maxy
;            lea eax,[eax+eax*2]
;            invoke RtlZeroMemory,bitmap1,eax ; this thing is fast,
;            invoke RtlZeroMemory,bitmap2,eax ; but hidden from some API docs
;            push nb
;            push hFShells
;            @@:
;                mov eax,maxx
;               ;shr eax,1
;                shr eax,2
;                mov edx,[esp+4]
;                dec edx
;                imul eax,edx
;                mov ecx,maxy
;                shr ecx,1
;                Invoke FShell_recycle,[esp+8],eax,ecx
;                mov eax,sb
;                add [esp],eax
;                dec dword ptr[esp+4]
;            jnz @B
;            ;mov flash,6400
;            Invoke ResumeThread,hFThread
;            pop eax
;            pop eax
;            ;
        .elseif ( (uMsg==WM_SIZE) && (wParam!=SIZE_MINIMIZED) )
            xor edx,edx
            mov eax,lParam
            mov dx,ax
            shr eax,16
            shr edx,2
            shl edx,2
            add edx,LEFT_NOISE      ;Top Left white spot and left blur shining noise
            mov maxx,edx
            mov maxy,eax
            mov bminf.bmiHeader.biWidth,edx
            neg eax          ; -maxy
            mov bminf.bmiHeader.biHeight,eax
;        .elseif ( (uMsg==WM_SIZE) && (wParam==SIZE_MINIMIZED) )
;            Invoke EndDialog,hWnd,0
;        .elseif (uMsg == WM_ACTIVATE) ;WM_KILLFOCUS) || (uMsg == WM_ACTIVATEAPP) || (uMsg == WM_NCACTIVATE) ;WM_ACTIVATE
;            mov eax,wParam
;            .if ax==WA_INACTIVE
;                Invoke EndDialog,hWnd,0
;            .endif
;        .elseif (uMsg == WM_NOTIFY)
;                Invoke EndDialog,hWnd,0
        .elseif (uMsg == WM_NCACTIVATE) ;WM_KILLFOCUS) || (uMsg == WM_ACTIVATEAPP) || (uMsg == WM_NCACTIVATE) ;WM_ACTIVATE
            mov eax,wParam
            .if ax==FALSE
                jmp ExitMainDlgProc
            .endif
            .if dOnce==FALSE
                mov dOnce,TRUE
            .else
                jmp ExitMainDlgProc
            .endif
        .elseif uMsg == WM_CLOSE
            ExitMainDlgProc:
            ;Invoke TerminateThread,hFThread,NULL
            mov stop,1                          ; stop running threads
            Invoke Sleep,100                    ; avoid FireThread drawing without window
            Invoke DestroyWindow,hwnd
            Invoke PostQuitMessage,0
            ;Invoke EndDialog,hWnd,0
        .endif
        ;Invoke CallWindowProc,pOldProc,hWnd,uMsg,wParam,lParam
        xor eax,eax
    ret
PreviewDlgProc                  endp
; -------------------------------------------------------------------------
align 4
NormalDlgProc                   proc hWnd:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
                                ;
                                LOCAL pParameter:DWORD
    .if uMsg == WM_INITDIALOG
        ;
        mov eax,hWnd
        mov hWinMain,eax
        mov hwnd,eax
        ;
        Invoke SendMessage,hWnd,WM_SETICON,1,hIcon
        ;
        Invoke LoadMenu,hInstance,600
        mov hmnu,eax
        invoke SetMenu,hWinMain,hmnu
        invoke CheckMenuItem,hmnu,1200,MF_BYCOMMAND or MF_CHECKED
        invoke CheckMenuItem,hmnu,1220,MF_BYCOMMAND or MF_CHECKED
        invoke CheckMenuItem,hmnu,1300,MF_BYCOMMAND or MF_CHECKED
        ;
        Invoke ShowWindow,hWinMain,SW_SHOWNORMAL  ;SW_MAXIMIZE ;SW_SHOWNORMAL 
        mov pParameter,0
        invoke CreateThread,0,4096,addr MoniThread,addr pParameter,0,addr idThread1
        ;
        mov pParameter,0
        Invoke CreateThread,0,4096,addr FireThread,addr pParameter,0,addr idThread2
        mov hFThread,eax
        Invoke UpdateWindow,hWinMain

    .elseif uMsg==WM_MOUSEMOVE && wParam==MK_CONTROL
        xor edx,edx
        mov flash,2400
        mov eax,lParam
        mov dx,ax
        shr eax,16
        mov lightx,edx
        mov lighty,eax
    .ELSEIF uMsg==WM_SIZE && wParam!=SIZE_MINIMIZED
        xor edx,edx
        mov eax,lParam
        mov dx,ax
        shr eax,16
        shr edx,2
        shl edx,2
        add edx,LEFT_NOISE      ;Top Left white spot and left blur shining noise
        mov maxx,edx
        mov maxy,eax
        mov bminf.bmiHeader.biWidth,edx
        neg eax          ; -maxy
        mov bminf.bmiHeader.biHeight,eax
    .ELSEIF uMsg==WM_KEYDOWN && wParam==VK_SPACE
        Invoke Switch,addr GMode,1200
    .ELSEIF uMsg==WM_KEYDOWN && wParam==VK_RETURN
        Invoke Switch,addr EMode,1220
        mov flash,0
    .ELSEIF uMsg==WM_RBUTTONDOWN
        invoke MessageBox,hWnd,ADDR info,ADDR szAppName,MB_OK or MB_ICONASTERISK
    .ELSEIF uMsg==WM_LBUTTONDOWN
        xor edx,edx
        mov eax,lParam
        mov dx,ax
        shr eax,16
        push eax
        push edx
        mov edx,nb
        dec edx
        mov eax,click
        dec eax
        cmovs eax,edx
        mov click,eax
        imul sb
        add eax,hFShells
        push eax
        call FShell_recycle
    .ELSEIF ( (uMsg==WM_CLOSE) || (uMsg == WM_DESTROY) )
        mov stop,1                          ; stop running threads
        invoke Sleep,100                    ; avoid FireThread drawing without window
        invoke DestroyWindow,hwnd
        invoke PostQuitMessage,0
    .ELSEIF uMsg==WM_COMMAND
       .IF wParam==1010                     ;=-=-=-=-="&Exit "=-=-=-=-=
            Invoke SendMessage,hwnd,WM_CLOSE,0,0
       .ELSEIF wParam==1000                 ;=-=-=-=-="&Reset"=-=-=-=-=
            @@:
            Invoke SuspendThread,hFThread   ; suffering technical difiiculties :)
            mov eax,maxx                    ; major motiv - to see ZeroMem in acion
            imul maxy
            lea eax,[eax+eax*2]
            invoke RtlZeroMemory,bitmap1,eax ; this thing is fast,
            invoke RtlZeroMemory,bitmap2,eax ; but hidden from some API docs
            push nb
            push hFShells
            @@:
                mov eax,maxx
               ;shr eax,1
                shr eax,2
                mov edx,[esp+4]
                dec edx
                imul eax,edx
                mov ecx,maxy
                shr ecx,1
                Invoke FShell_recycle,[esp+8],eax,ecx
                mov eax,sb
                add [esp],eax
                dec dword ptr[esp+4]
            jnz @B
            ;mov flash,6400
            Invoke ResumeThread,hFThread
            pop eax
            pop eax
       .ELSEIF wParam==1200                     ;=-=-=-=-="&Gravity and Atmosphere "=-=-=-=-=
            Invoke Switch,addr GMode,1200
       .ELSEIF wParam==1210                     ;=-=-=-=-="&Color Shifting Chemical (Far view)"=-=-=-=-=
            Invoke Switch,addr CMode,1210
            mov ecx,CMode
            mov eax,16
            shr eax,cl
            mov motionQ,eax                     ; changing motionQ affects speed
       .ELSEIF wParam==1220                     ;=-=-=-=-="&Light and Smoke (blur MMX) "=-=-=-=-=
            Invoke Switch,addr EMode,1220
            mov flash,0
       .ELSEIF wParam==1300                     ;=-=-=-=-="&Delayed"=-=-=-=-=
            invoke CheckMenuItem,hmnu,1310,MF_BYCOMMAND or MF_UNCHECKED
            invoke CheckMenuItem,hmnu,1300,MF_BYCOMMAND or MF_CHECKED
            mov minlife,500                     ; long interval between shoots
       .ELSEIF wParam==1310                     ;=-=-=-=-="&Violent"=-=-=-=-=
            invoke CheckMenuItem,hmnu,1300,MF_BYCOMMAND or MF_UNCHECKED
            invoke CheckMenuItem,hmnu,1310,MF_BYCOMMAND or MF_CHECKED
            mov minlife,100        ; short interval
       .ELSEIF wParam==1400
            invoke MessageBox,hWnd,ADDR info,ADDR szAppName,MB_OK or MB_ICONASTERISK
       .ENDIF
    ;.ELSE
    ;    invoke DefWindowProc,hWnd,uMsg,wParam,lParam
    ;    ret
    .ENDIF
    ;
    ;Invoke CallWindowProc,pOldProc,hWnd,uMsg,wParam,lParam
    xor eax,eax
    ret

NormalDlgProc                   endp
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; #########################################################################
                    ;ScreenSaverConfigureDialog
; #########################################################################
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
align 4
ScreenSaverConfigureDlgSp         proc pDeviceData:DWORD
    ;
    Dialog "Configurar Apocalypse Firewoks","MS Sans Serif",8, \            ; caption,font,pointsize
            WS_OVERLAPPED OR WS_POPUP OR WS_VISIBLE OR WS_CAPTION OR WS_SYSMENU OR WS_EX_TOPMOST OR DS_CENTER, \     ; style OR WS_VISIBLE
            33, \                                            ; control count
            0,0,276,228, \                                  ; x y co-ordinates
            4096                                            ; memory buffer size
            ;===============================================================================================================================
            DlgGroup "Efectos",                                                                                 008,004,260,060,    1001
            DlgCheck "&Luz y Humo (Blur MMX).",WS_CHILD+WS_VISIBLE+WS_TABSTOP+BS_AUTOCHECKBOX+BS_FLAT,          032,016,210,012,    1002
            DlgCheck "Grav&edad y Atmєsfera.",WS_CHILD+WS_VISIBLE+WS_TABSTOP+BS_AUTOCHECKBOX+BS_FLAT,           032,030,210,012,    1003
            DlgCheck "C&olores Quэmicos (Vista Distante).",WS_CHILD+WS_VISIBLE+WS_TABSTOP+BS_AUTOCHECKBOX \
                                                                                                    +BS_FLAT,   032,044,210,012,    1004
            ;===============================================================================================================================
            DlgGroup "&Intervalo",                                                                              008,070,126,060,    1005
            DlgCheck "&Retardado.",WS_CHILD+WS_VISIBLE+WS_TABSTOP+BS_AUTOCHECKBOX+BS_FLAT,                      032,082,100,012,    1006
            DlgCheck "&Violento.",WS_CHILD+WS_VISIBLE+WS_TABSTOP+BS_AUTOCHECKBOX+BS_FLAT,                       032,096,100,012,    1007
            DlgStatic "Vi&da Mс&x.:",WS_CHILD OR WS_VISIBLE,                                                    032,112,040,012,    1008
            DlgEdit WS_CHILD OR WS_VISIBLE OR WS_BORDER OR WS_TABSTOP  OR ES_AUTOHSCROLL OR ES_NUMBER OR 8000H, 084,110,040,012,    1009
            DlgComCtl "msctls_updown32", UDS_AUTOBUDDY OR UDS_SETBUDDYINT OR UDS_ARROWKEYS OR UDS_ALIGNRIGHT \
                                                                            OR UDS_NOTHOUSANDS,                 218,110,028,012,    1010
            ;===============================================================================================================================
            DlgGroup "Fuego",                                                                                   142,070,126,060,    1011
            DlgStatic "Ca&bezas:",WS_CHILD OR WS_VISIBLE,                                                       166,084,040,012,    1012
            DlgEdit WS_CHILD OR WS_VISIBLE OR WS_BORDER OR WS_TABSTOP  OR ES_AUTOHSCROLL OR ES_NUMBER OR 8000H, 218,082,040,012,    1013
            DlgComCtl "msctls_updown32", UDS_AUTOBUDDY OR UDS_SETBUDDYINT OR UDS_ARROWKEYS OR UDS_ALIGNRIGHT \
                                                                            OR UDS_NOTHOUSANDS,                 218,082,028,012,    1014
            DlgStatic "C&hispas:",WS_CHILD OR WS_VISIBLE,                                                       166,098,040,012,    1015
            DlgEdit WS_CHILD OR WS_VISIBLE OR WS_BORDER OR WS_TABSTOP  OR ES_AUTOHSCROLL OR ES_NUMBER OR 8000H, 218,096,040,012,    1016
            DlgComCtl "msctls_updown32", UDS_AUTOBUDDY OR UDS_SETBUDDYINT OR UDS_ARROWKEYS OR UDS_ALIGNRIGHT \
                                                                            OR UDS_NOTHOUSANDS,                 218,096,028,012,    1017
            DlgStatic "Poder Mс&x.:",WS_CHILD OR WS_VISIBLE,                                                    166,112,040,012,    1018
            DlgEdit WS_CHILD OR WS_VISIBLE OR WS_BORDER OR WS_TABSTOP  OR ES_AUTOHSCROLL OR ES_NUMBER OR 8000H, 218,110,040,012,    1019
            DlgComCtl "msctls_updown32", UDS_AUTOBUDDY OR UDS_SETBUDDYINT OR UDS_ARROWKEYS OR UDS_ALIGNRIGHT \
                                                                            OR UDS_NOTHOUSANDS,                 218,110,028,012,    1020
            ;===============================================================================================================================
            DlgGroup "No molestar cuando estas aplicaciones estщn abiertas",                                    008,136,260,060,    1021
            DlgStatic "Aplicaciєn 1:",WS_CHILD OR WS_VISIBLE,                                                   032,150,054,012,    1022
            DlgEdit WS_CHILD OR WS_VISIBLE OR WS_BORDER OR WS_TABSTOP ,                                         084,148,156,012,    1023
            DlgButton "...",WS_CHILD OR WS_TABSTOP OR BS_FLAT,                                                  244,148,014,012,    1024
            DlgStatic "Aplicaciєn 2:",WS_CHILD OR WS_VISIBLE,                                                   032,164,054,012,    1025
            DlgEdit WS_CHILD OR WS_VISIBLE OR WS_BORDER OR WS_TABSTOP ,                                         084,162,156,012,    1026
            DlgButton "...",WS_CHILD OR WS_TABSTOP OR BS_FLAT,                                                  244,162,014,012,    1027
            DlgStatic "Aplicaciєn 3:",WS_CHILD OR WS_VISIBLE,                                                   032,178,054,012,    1028
            DlgEdit WS_CHILD OR WS_VISIBLE OR WS_BORDER OR WS_TABSTOP ,                                         084,176,156,012,    1029
            DlgButton "...",WS_CHILD OR WS_TABSTOP OR BS_FLAT,                                                  244,176,014,012,    1030
            ;===============================================================================================================================
            DlgButton "&Acerca...",WS_CHILD OR WS_TABSTOP OR BS_FLAT,                                           008,204,060,016,    1031
            DlgButton "&Guardar",WS_CHILD OR WS_VISIBLE OR WS_TABSTOP OR BS_FLAT,                               142,204,060,016,    1032
            DlgButton "&Cerrar",WS_CHILD OR WS_VISIBLE OR WS_TABSTOP OR 1 OR BS_FLAT,                           208,204,060,016,    1033
    ;
    CallModalDialog hInstance,hWinParent,ScreenSaverConfigureDlgProc,pDeviceData ;Instance,Parent,DlgProc,lpExtra
    ;CallModelessDialog hInstance,0,ScreenSaverConfigureDlgProc,pDeviceData ;Instance,Parent,DlgProc,lpExtra
    ;
    ;
    ret
    ;
ScreenSaverConfigureDlgSp         endp
align 4
ScreenSaverConfigureDlg         proc pDeviceData:DWORD
    ;
    Dialog "Configure Apocalypse Firewoks","MS Sans Serif",8, \            ; caption,font,pointsize
            WS_OVERLAPPED OR WS_POPUP OR WS_VISIBLE OR WS_CAPTION OR WS_SYSMENU OR WS_EX_TOPMOST OR DS_CENTER, \     ; style OR WS_VISIBLE
            33, \                                            ; control count
            0,0,276,176, \                                  ; x y co-ordinates
            4096                                            ; memory buffer size
            ;===================================== GROUP 1 =================================================================================
            DlgGroup "Efects",                                                                                  8  ,004,260,072,    1001
            DlgCheck "&Light And Smoke (Blur MMX).",WS_CHILD+WS_VISIBLE+WS_TABSTOP+BS_AUTOCHECKBOX+BS_FLAT,     32 ,022,210,12 ,    1002
            DlgCheck "&Gravity And Atmosphere.",WS_CHILD+WS_VISIBLE+WS_TABSTOP+BS_AUTOCHECKBOX+BS_FLAT,         32 ,036,210,12 ,    1003
            DlgCheck "C&olor Shifting Chemical (Far View).",WS_CHILD+WS_VISIBLE+WS_TABSTOP+BS_AUTOCHECKBOX \
                                                                                                    +BS_FLAT,   32 ,050,210,12 ,    1004
            ;===============================================================================================================================
            DlgGroup "&Interval",                                                                               8  ,082,126,060,    1005
            DlgCheck "&Delayed.",WS_CHILD+WS_VISIBLE+WS_TABSTOP+BS_AUTOCHECKBOX+BS_FLAT,                        32 ,094,100,12 ,    1006
            DlgCheck "&Violent.",WS_CHILD+WS_VISIBLE+WS_TABSTOP+BS_AUTOCHECKBOX+BS_FLAT,                        32 ,108,100,12 ,    1007
            DlgStatic "Max. Life:",WS_CHILD OR WS_VISIBLE,                                                           32 ,124, 40, 12,    1008
            DlgEdit WS_CHILD OR WS_VISIBLE OR WS_BORDER OR WS_TABSTOP  OR ES_AUTOHSCROLL OR ES_NUMBER OR 8000H, 84 ,122, 40, 12,    1009
            DlgComCtl "msctls_updown32", UDS_AUTOBUDDY OR UDS_SETBUDDYINT OR UDS_ARROWKEYS OR UDS_ALIGNRIGHT \
                                                                            OR UDS_NOTHOUSANDS,                 218,122, 28,12 ,    1010
            ;===============================================================================================================================
            DlgGroup "Fire",                                                                                    142,082,126,060,    1011
            DlgStatic "Shells:",WS_CHILD OR WS_VISIBLE,                                                         166,096, 40, 12,    1012
            DlgEdit WS_CHILD OR WS_VISIBLE OR WS_BORDER OR WS_TABSTOP  OR ES_AUTOHSCROLL OR ES_NUMBER OR 8000H, 218,094, 40, 12,    1013
            DlgComCtl "msctls_updown32", UDS_AUTOBUDDY OR UDS_SETBUDDYINT OR UDS_ARROWKEYS OR UDS_ALIGNRIGHT \
                                                                            OR UDS_NOTHOUSANDS,                 218,094, 28, 12,    1014
            DlgStatic "Sparks:",WS_CHILD OR WS_VISIBLE,                                                         166,110, 40, 12,    1015
            DlgEdit WS_CHILD OR WS_VISIBLE OR WS_BORDER OR WS_TABSTOP  OR ES_AUTOHSCROLL OR ES_NUMBER OR 8000H, 218,108, 40, 12,    1016
            DlgComCtl "msctls_updown32", UDS_AUTOBUDDY OR UDS_SETBUDDYINT OR UDS_ARROWKEYS OR UDS_ALIGNRIGHT \
                                                                            OR UDS_NOTHOUSANDS,                 218,108, 28, 12,    1017
            DlgStatic "Max. Power:",WS_CHILD OR WS_VISIBLE,                                                          166,124, 40, 12,    1018
            DlgEdit WS_CHILD OR WS_VISIBLE OR WS_BORDER OR WS_TABSTOP  OR ES_AUTOHSCROLL OR ES_NUMBER OR 8000H, 218,122, 40, 12,    1019
            DlgComCtl "msctls_updown32", UDS_AUTOBUDDY OR UDS_SETBUDDYINT OR UDS_ARROWKEYS OR UDS_ALIGNRIGHT \
                                                                            OR UDS_NOTHOUSANDS,                 218,122, 28,12 ,    1020
            ;===============================================================================================================================
            DlgGroup "Do not disturb when this application are running",                                        008,136,260,060,    1021
            DlgStatic "Application 1:",WS_CHILD OR WS_VISIBLE,                                                  032,150,054,012,    1022
            DlgEdit WS_CHILD OR WS_VISIBLE OR WS_BORDER OR WS_TABSTOP ,                                         084,148,156,012,    1023
            DlgButton "...",WS_CHILD OR WS_TABSTOP OR BS_FLAT,                                                  244,148,014,012,    1024
            DlgStatic "Application 2:",WS_CHILD OR WS_VISIBLE,                                                  032,164,054,012,    1025
            DlgEdit WS_CHILD OR WS_VISIBLE OR WS_BORDER OR WS_TABSTOP ,                                         084,162,156,012,    1026
            DlgButton "...",WS_CHILD OR WS_TABSTOP OR BS_FLAT,                                                  244,162,014,012,    1027
            DlgStatic "Application 3:",WS_CHILD OR WS_VISIBLE,                                                  032,178,054,012,    1028
            DlgEdit WS_CHILD OR WS_VISIBLE OR WS_BORDER OR WS_TABSTOP ,                                         084,176,156,012,    1029
            DlgButton "...",WS_CHILD OR WS_TABSTOP OR BS_FLAT,                                                  244,176,014,012,    1030
            ;===============================================================================================================================
            DlgButton "&About...",WS_CHILD OR WS_TABSTOP OR BS_FLAT,                                            8  ,150,060,16 ,    1031
            DlgButton "&Save",WS_CHILD OR WS_VISIBLE OR WS_TABSTOP OR BS_FLAT,                                  142,150,060,16 ,    1032
            DlgButton "&Close",WS_CHILD OR WS_VISIBLE OR WS_TABSTOP OR 1 OR BS_FLAT,                            208,150,060,16 ,    1033
    ;
    CallModalDialog hInstance,hWinParent,ScreenSaverConfigureDlgProc,pDeviceData ;Instance,Parent,DlgProc,lpExtra
    ;CallModelessDialog hInstance,0,ScreenSaverConfigureDlgProc,pDeviceData ;Instance,Parent,DlgProc,lpExtra
    ;
    ;
    ret
    ;
ScreenSaverConfigureDlg         endp

; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
align 4
ScreenSaverConfigureDlgProc     proc hwin:DWORD,uMsg:DWORD,wParam:DWORD,lParam:DWORD
                                ;
                                LOCAL dSensorIndex:DWORD  ;1-MAX_SENSORLIST
                                LOCAL dSensorCaptureStatus:DWORD
                                ;
                                LOCAL szGUID[128]:BYTE
                                LOCAL guid:_GUID
                                ;
                                LOCAL dSizeVerify:DWORD
                                LOCAL dSizeRegistry:DWORD
                                LOCAL dMaxTouches:DWORD
                                ;"
    ;
    .if uMsg == WM_INITDIALOG
        ;
            Invoke SendMessage,hwin,WM_SETICON,1,hIcon
            ;
            Invoke RegisterManager,FALSE
            ;
            .if dValueEfectsBlur
                Invoke CheckDlgButton,hwin,1002,BST_CHECKED
            .endif
            .if dValueEfectsAir
                Invoke CheckDlgButton,hwin,1003,BST_CHECKED
            .endif
            .if dValueEfectsFar
                Invoke CheckDlgButton,hwin,1004,BST_CHECKED
            .endif
            .if dValueEfectsLife==100
                Invoke CheckDlgButton,hwin,1007,BST_CHECKED
            .elseif dValueEfectsLife==500
                Invoke CheckDlgButton,hwin,1006,BST_CHECKED
            .endif
            ;
            Invoke SetDlgItemInt,hwin,1009,dValueEfectsLife,FALSE ;TRUE=Singed, FALSE=Unsigned
            Invoke GetDlgItem, hwin, 1010
            Invoke SendMessage, eax, UDM_SETRANGE, 0, 003203E8H   ;wordLower,wordUpper 50,1000
            ;
            Invoke SetDlgItemInt,hwin,1013,dValueEfectsShells,FALSE ;TRUE=Singed, FALSE=Unsigned
            Invoke GetDlgItem, hwin, 1014
            Invoke SendMessage, eax, UDM_SETRANGE, 0, 00010005H   ;wordLower,wordUpper 1,5
            ;
            Invoke SetDlgItemInt,hwin,1016,dValueEfectsSparks,FALSE ;TRUE=Singed, FALSE=Unsigned
            Invoke GetDlgItem, hwin, 1017
            Invoke SendMessage, eax, UDM_SETRANGE, 0, 00010190H   ;wordLower,wordUpper 1 ,400
            ;
            Invoke SetDlgItemInt,hwin,1019,dValueEfectsPower,FALSE ;TRUE=Singed, FALSE=Unsigned
            Invoke GetDlgItem, hwin, 1020
            Invoke SendMessage, eax, UDM_SETRANGE, 0, 0001000AH   ;wordLower,wordUpper 1,10
            ;
            Invoke SetDlgItemText,hwin,1023,addr szApp1
            Invoke SetDlgItemText,hwin,1026,addr szApp2
            Invoke SetDlgItemText,hwin,1029,addr szApp3
            ;
        ;
        .elseif uMsg == WM_COMMAND
            mov eax,wParam
            .if (wParam == 1006)
                shr eax,16
                .if ax==BN_CLICKED
                    ;
                    ;Invoke IsDlgButtonChecked,hwin,1007
                    ;.if eax==BST_CHECKED
                        Invoke CheckDlgButton,hwin,1007,BST_UNCHECKED
                    ;.elseif eax==BST_UNCHECKED
                    ;    Invoke CheckDlgButton,hwin,1007,BST_CHECKED
                    ;.endif
                    ;
                    Invoke SetDlgItemInt,hwin,1009,500,FALSE ;TRUE=Singed, FALSE=Unsigned
                    ;
                .endif
            .elseif (wParam == 1007)
                shr eax,16
                .if ax==BN_CLICKED
                    ;
                    ;Invoke IsDlgButtonChecked,hwin,1006
                    ;.if eax==BST_CHECKED
                        Invoke CheckDlgButton,hwin,1006,BST_UNCHECKED
                    ;.elseif eax==BST_UNCHECKED
                    ;    Invoke CheckDlgButton,hwin,1006,BST_CHECKED
                    ;.endif
                    ;
                    Invoke SetDlgItemInt,hwin,1009,100,FALSE ;TRUE=Singed, FALSE=Unsigned
                    ;
                .endif
            .elseif (wParam==1024)
                Invoke FillBuffer,addr szReturn,sizeof szReturn,0
                Invoke ListBoxDlg,hwin,hIcon
                Invoke lstrlen,addr szReturn
                .if eax
                    Invoke SetDlgItemText,hwin,1023,addr szReturn
                .endif
            .elseif (wParam==1027)
                Invoke FillBuffer,addr szReturn,sizeof szReturn,0
                Invoke ListBoxDlg,hwin,hIcon
                Invoke lstrlen,addr szReturn
                .if eax
                    Invoke SetDlgItemText,hwin,1026,addr szReturn
                .endif
            .elseif (wParam==1030)
                Invoke FillBuffer,addr szReturn,sizeof szReturn,0
                Invoke ListBoxDlg,hwin,hIcon
                Invoke lstrlen,addr szReturn
                .if eax
                    Invoke SetDlgItemText,hwin,1029,addr szReturn
                .endif
            .elseif     (wParam == 1031) || (wParam == 1032) || (wParam == 1033)
                ;********************* Button Actions *************
                shr eax,16
                .if ax==BN_CLICKED
                    .if     (wParam == 1031)        ;About
                        .if dSpanish
                            Invoke MessageBox,hwin,addr szInfoSp,addr szAppName,MB_OK OR MB_ICONASTERISK
                        .else
                            Invoke MessageBox,hwin,addr szInfo,addr szAppName,MB_OK OR MB_ICONASTERISK
                        .endif
                    .elseif (wParam == 1032)        ;Save
                        ;=======================
                        xor eax,eax
                        mov dValueEfectsBlur,eax      ;      dd 1
                        mov dValueEfectsAir,eax       ;      dd 1
                        mov dValueEfectsFar,eax       ;      dd 0
                        Invoke IsDlgButtonChecked,hwin,1002
                        .if eax==BST_CHECKED
                            add dValueEfectsBlur,1
                        .endif
                        Invoke IsDlgButtonChecked,hwin,1003
                        .if eax==BST_CHECKED
                            add dValueEfectsAir,1
                        .endif
                        Invoke IsDlgButtonChecked,hwin,1004
                        .if eax==BST_CHECKED
                            add dValueEfectsFar,1
                        .endif
                        ;
                        Invoke GetDlgItemInt,hwin,1009,addr dValueEfectsLife ,FALSE ;TRUE=Singed, FALSE=Unsigned
                        .if dValueEfectsLife==FALSE ;TRUE indicates success, FALSE indicates failure.
                            mov eax,500      ;    dd 500
                        .endif
                        .if eax<50 || eax>1000
                            Invoke  GetDlgItem, hwin, 1009
                            Invoke SetFocus,eax
                            jmp @F
                        .endif
                        mov dValueEfectsLife,eax
                        ;
                        Invoke GetDlgItemInt,hwin,1013,addr dValueEfectsShells,FALSE ;TRUE=Singed, FALSE=Unsigned
                        .if dValueEfectsShells==FALSE ;TRUE indicates success, FALSE indicates failure.
                            mov eax,5      ;    dd 5
                        .endif
                        .if eax==0 || eax>5
                            Invoke  GetDlgItem, hwin, 1013
                            Invoke SetFocus,eax
                            jmp @F
                        .endif
                        mov dValueEfectsShells,eax
                        ;
                        Invoke GetDlgItemInt,hwin,1016,addr dValueEfectsSparks,FALSE ;TRUE=Singed, FALSE=Unsigned
                        .if dValueEfectsSparks==FALSE ;TRUE indicates success, FALSE indicates failure.
                            mov eax,400      ;    dd 400
                        .endif
                        .if eax==0 || eax>400
                            Invoke  GetDlgItem, hwin, 1016
                            Invoke SetFocus,eax
                            jmp @F
                        .endif
                        mov dValueEfectsSparks,eax
                        ;
                        Invoke GetDlgItemInt,hwin,1019,addr dValueEfectsPower,FALSE ;TRUE=Singed, FALSE=Unsigned
                        .if dValueEfectsPower==FALSE ;TRUE indicates success, FALSE indicates failure.
                            mov eax,5      ;    dd 500
                        .endif
                        .if eax<1 || eax>10
                            Invoke  GetDlgItem, hwin, 1019
                            Invoke SetFocus,eax
                            jmp @F
                        .endif
                        mov dValueEfectsPower,eax
                        ;
                        Invoke GetDlgItemText,hwin,1023,addr szApp1,sizeof szApp1
                        Invoke GetDlgItemText,hwin,1026,addr szApp2,sizeof szApp2
                        Invoke GetDlgItemText,hwin,1029,addr szApp3,sizeof szApp3
                        ;
                        Invoke RegisterManager,TRUE
                        .if eax!=NULL
                            Invoke MessageBox,hwin,addr szErrorWriteRegText,addr szErrorWriteRegTitle,MB_OK
                        .endif
                        Invoke EndDialog,hwin,0 ;Only for ModalDialog
                        ;
                        @@:
                    .elseif (wParam == 1033)        ;Close
                        Invoke EndDialog,hwin,0 ;Only for ModalDialog
                    .endif
                .endif
            .endif
    .elseif ( (uMsg==WM_CLOSE) || (uMsg == WM_DESTROY) )
        ;
        Exit_DummyDlgProc:
        Invoke EndDialog,hwin,0 ;Only for ModalDialog
        ;Invoke DestroyWindow,hwin ;ModelessDialog
        ;
    .endif
    ;
    xor eax, eax
    ret
    ;
ScreenSaverConfigureDlgProc     endp
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; #########################################################################
                    ;ListBox Dialog
; #########################################################################
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
align 4
ListBoxDlg                      proc hParent:DWORD,lpIcon:DWORD

    Dialog "Selecting...","MS Sans Serif",8, \            ; caption,font,pointsize
            WS_OVERLAPPED or WS_SYSMENU or DS_CENTER, \     ; style
            3, \                                            ; control count
            0,0,268,240, \                                  ; x y co-ordinates
            1024                                            ; memory buffer size
    DlgGroup    "Running Applications",8,4,248,188,IDGROUP300
    DlgList WS_CHILD OR WS_VISIBLE OR WS_BORDER OR WS_TABSTOP OR LBS_NOTIFY OR LBS_STANDARD OR LBS_SORT,20,18,224,170,IDLIST300
    DlgButton   "Select",WS_TABSTOP OR 1  OR 8000H,104,202,60,16,IDC_BTN300


    CallModalDialog hInstance,hParent,ListBoxDlgProc,addr hParent

    ret

ListBoxDlg                      endp
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
;                     ListBoxDlg Procedure
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
align 4
ListBoxDlgProc                  proc hWin:DWORD,uMsg:DWORD,wParam:DWORD,lParam:DWORD
                                LOCAL bLoop:BOOL
                                LOCAL bResult:BOOL
                                LOCAL pe32:PROCESSENTRY32
                                LOCAL hProcesses:HANDLE
        ;
        .if uMsg == WM_INITDIALOG
            ; -----------------------------------------
            ; write the parameters passed in "lParam"
            ; to the dialog's GWL_USERDATA address.
            ; -----------------------------------------
            Invoke SetWindowLong,hWin,GWL_USERDATA,lParam
            mov eax, lParam
            mov eax, [eax+4]
            Invoke SendMessage,hWin,WM_SETICON,1,eax
            ;
            Invoke FillBuffer,addr szReturn,sizeof szReturn,0
            ;
            Invoke GetDlgItem, hWin,IDLIST300
            mov hList_01, eax
            ;
            mov eax,hWin
            mov hSelectWindow,eax
            ;
            mov bLoop,TRUE
            mov bResult,FALSE
            Invoke CreateToolhelp32Snapshot,TH32CS_SNAPPROCESS,0
            mov hProcesses,eax
            mov pe32.dwSize,sizeof pe32
            ;
            Invoke Process32First,hProcesses,addr pe32
;            push eax
;            .if eax==FALSE
;               Invoke GetLastError
;               invoke wsprintf,ADDR szApp1,ADDR fmat,eax
;               Invoke MessageBox,NULL,addr szApp1,addr szApp2,NULL
;            .endif
;            pop eax           
            .if eax
                .while bLoop
                    Invoke SendMessage,hList_01,LB_ADDSTRING,0,addr pe32.szExeFile
                    ;Invoke CompareString,LOCALE_USER_DEFAULT, NORM_IGNORECASE, addr pe32.szExeFile, -1, pFullPathLocal, -1
                    ;.if eax==2
;                        Invoke OpenProcess,PROCESS_ALL_ACCESS, FALSE, pe32.th32ProcessID
;                        .if eax!=NULL
;                            push eax
;                            ;.if dMostrar!=2 ;dMostrar Hide=0 Unhide=1 Kill=2
;                                lea edx,dlParam ;dlParam[2]:DWORD
;                                mov eax,pe32.th32ProcessID
;                                mov dword ptr[edx],eax
;                                mov eax,dMostrar
;                                mov dword ptr[edx+4],eax
;                                Invoke EnumWindows,addr EnumWindowsProc,addr dlParam ;pe32.th32ProcessID
;;                            .else
;;                                Invoke TerminateProcess,eax, 0
;;                            .endif
;                            pop eax
;                            Invoke CloseHandle,eax
;                            mov bResult,TRUE;
;                        .endif
                    ;.endif
                    Invoke Process32Next, hProcesses,addr pe32
                    mov bLoop,eax
                .endw
                Invoke CloseHandle,hProcesses
            .endif
            ;
            Invoke SendMessage,hList_01,LB_SETCURSEL,0, 0
            ;
            Invoke SetWindowLong,hList_01,GWL_WNDPROC,ListBoxProc
            mov lpListBox_01, eax
            ;
            Invoke SetFocus,hList_01
        .elseif uMsg == WM_COMMAND
            mov eax,wParam
            .if (wParam == IDC_BTN300)
                ;********************* Select *************
                Invoke SendMessage,hList_01,LB_GETCURSEL,0,0
                Invoke SendMessage,hList_01,LB_GETTEXT,eax,addr szReturn
                jmp Exit_ListBox
            .endif
        .elseif uMsg == WM_CLOSE
            Exit_ListBox:
            Invoke EndDialog,hWin,0
        .endif
    xor eax, eax
    ret
    ;
ListBoxDlgProc                  endp
align 4
ListBoxProc                     proc hCtl:DWORD,uMsg:DWORD,wParam:DWORD,lParam:DWORD
                                ;
                                ;LOCAL IndexItem  :DWORD
                                ;LOCAL Buffer[32] :BYTE
    ;
    .if uMsg == WM_LBUTTONDBLCLK
        jmp DoIt
    .elseif uMsg == WM_CHAR
        .if wParam == 13
            jmp DoIt
        .endif
    .endif
    jmp EndDo
    ;
    DoIt:
        ;
        Invoke SendMessage,hSelectWindow,WM_COMMAND,IDC_BTN300,0
        ;
    EndDo:

    Invoke CallWindowProc,lpListBox_01,hCtl,uMsg,wParam,lParam

    ret

ListBoxProc                     endp
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; #########################################################################
                    ;RegisterManager
; #########################################################################
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
align 4
RegisterManager                 proc dRequest:DWORD     ;Returns 0 on succes
                                LOCAL hReg:DWORD
                                LOCAL pType:DWORD
                                LOCAL dDisp:DWORD
                                LOCAL dSize:DWORD
                                ;
        ;
        xor eax,eax
        ;******************************************
        Invoke RegCreateKeyEx,HKEY_CURRENT_USER,addr szSubKey,NULL,NULL,REG_OPTION_NON_VOLATILE,KEY_ALL_ACCESS,NULL,addr hReg,addr dDisp ;KEY_ALL_ACCESS
        .if eax!=ERROR_SUCCESS
            xor eax,eax
            sub eax,1
        .else
            ;
            .if dRequest==TRUE      ;WRITE
                Invoke RegSetValueEx,hReg,addr szValueEfectsBlur,0,REG_DWORD,addr dValueEfectsBlur,sizeof DWORD
                Invoke RegSetValueEx,hReg,addr szValueEfectsAir,0,REG_DWORD,addr dValueEfectsAir,sizeof DWORD
                Invoke RegSetValueEx,hReg,addr szValueEfectsFar,0,REG_DWORD,addr dValueEfectsFar,sizeof DWORD
                Invoke RegSetValueEx,hReg,addr szValueEfectsLife,0,REG_DWORD,addr dValueEfectsLife,sizeof DWORD
                Invoke RegSetValueEx,hReg,addr szValueEfectsShells,0,REG_DWORD,addr dValueEfectsShells,sizeof DWORD
                Invoke RegSetValueEx,hReg,addr szValueEfectsSparks,0,REG_DWORD,addr dValueEfectsSparks,sizeof DWORD
                Invoke RegSetValueEx,hReg,addr szValueEfectsPower,0,REG_DWORD,addr dValueEfectsPower,sizeof DWORD
                ;
                Invoke lstrlen,addr szValueDoNotDisturbApp
                lea edx,szValueDoNotDisturbApp
                sub eax,1
                mov ecx,eax
                mov al,'1'
                mov byte ptr[edx+ecx],al
                Invoke lstrlen,addr szApp1
                Invoke RegSetValueEx,hReg,addr szValueDoNotDisturbApp,0,REG_SZ,addr szApp1,eax
                ;
                Invoke lstrlen,addr szValueDoNotDisturbApp
                lea edx,szValueDoNotDisturbApp
                sub eax,1
                mov ecx,eax
                mov al,'2'
                mov byte ptr[edx+ecx],al
                Invoke lstrlen,addr szApp2
                Invoke RegSetValueEx,hReg,addr szValueDoNotDisturbApp,0,REG_SZ,addr szApp2,eax
                ;
                Invoke lstrlen,addr szValueDoNotDisturbApp
                lea edx,szValueDoNotDisturbApp
                sub eax,1
                mov ecx,eax
                mov al,'3'
                mov byte ptr[edx+ecx],al
                Invoke lstrlen,addr szApp3
                Invoke RegSetValueEx,hReg,addr szValueDoNotDisturbApp,0,REG_SZ,addr szApp3,eax
                ;
            .else                   ;READ
                .if dDisp!=REG_CREATED_NEW_KEY
                    mov pType,REG_DWORD
                    mov dSize,sizeof DWORD
                    Invoke RegQueryValueEx,hReg,addr szValueEfectsBlur,0,addr pType,addr dValueEfectsBlur,addr dSize
                    .if eax!=ERROR_SUCCESS
                        mov dValueEfectsBlur,TRUE
                    .endif
                    mov dSize,sizeof DWORD
                    Invoke RegQueryValueEx,hReg,addr szValueEfectsAir,0,addr pType,addr dValueEfectsAir,addr dSize
                    .if eax!=ERROR_SUCCESS
                        mov dValueEfectsAir,TRUE
                    .endif
                    mov dSize,sizeof DWORD
                    Invoke RegQueryValueEx,hReg,addr szValueEfectsFar,0,addr pType,addr dValueEfectsFar,addr dSize
                    .if eax!=ERROR_SUCCESS
                        mov dValueEfectsFar,FALSE
                    .endif
                    mov dSize,sizeof DWORD
                    Invoke RegQueryValueEx,hReg,addr szValueEfectsLife,0,addr pType,addr dValueEfectsLife,addr dSize
                    .if eax!=ERROR_SUCCESS
                        mov dValueEfectsLife,100
                    .endif
                    mov dSize,sizeof DWORD
                    Invoke RegQueryValueEx,hReg,addr szValueEfectsShells,0,addr pType,addr dValueEfectsShells,addr dSize
                    .if eax!=ERROR_SUCCESS
                        mov dValueEfectsShells,5
                    .endif
                    mov dSize,sizeof DWORD
                    Invoke RegQueryValueEx,hReg,addr szValueEfectsSparks,0,addr pType,addr dValueEfectsSparks,addr dSize
                    .if eax!=ERROR_SUCCESS
                        mov dValueEfectsSparks,400
                    .endif
                    mov dSize,sizeof DWORD
                    Invoke RegQueryValueEx,hReg,addr szValueEfectsPower,0,addr pType,addr dValueEfectsPower,addr dSize
                    .if eax!=ERROR_SUCCESS
                        mov dValueEfectsPower,1
                    .endif
                    ;
                    Invoke lstrlen,addr szValueDoNotDisturbApp
                    lea edx,szValueDoNotDisturbApp
                    sub eax,1
                    mov ecx,eax
                    mov al,'1'
                    mov byte ptr[edx+ecx],al
                    mov pType,REG_SZ
                    mov dSize,sizeof szApp1
                    Invoke RegQueryValueEx,hReg,addr szValueDoNotDisturbApp,0,addr pType,addr szApp1,addr dSize
                    ;
                    Invoke lstrlen,addr szValueDoNotDisturbApp
                    lea edx,szValueDoNotDisturbApp
                    sub eax,1
                    mov ecx,eax
                    mov al,'2'
                    mov byte ptr[edx+ecx],al
                    mov pType,REG_SZ
                    mov dSize,sizeof szApp2
                    Invoke RegQueryValueEx,hReg,addr szValueDoNotDisturbApp,0,addr pType,addr szApp2,addr dSize
                    ;
                    Invoke lstrlen,addr szValueDoNotDisturbApp
                    lea edx,szValueDoNotDisturbApp
                    sub eax,1
                    mov ecx,eax
                    mov al,'3'
                    mov byte ptr[edx+ecx],al
                    mov pType,REG_SZ
                    mov dSize,sizeof szApp3
                    Invoke RegQueryValueEx,hReg,addr szValueDoNotDisturbApp,0,addr pType,addr szApp3,addr dSize
                .endif
            .endif
            ;
            Invoke RegCloseKey,hReg
            xor eax,eax
            ;
        .endif ;.if eax==ERROR_SUCCESS
        ;
    ret
RegisterManager                 endp
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; #########################################################################
                    ;FillBuffer  PROCEDURE
; #########################################################################
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
align 4
FillBuffer                      proc lpBuffer:DWORD,lenBuffer:DWORD,TheChar:BYTE
        ;
        push edi
        ;
        mov edi, lpBuffer   ; address of buffer
        mov ecx, lenBuffer  ; buffer length
        mov  al, TheChar    ; load al with character
        rep stosb           ; write character to buffer until ecx = 0
        ;
        pop edi
        ;
    ret
FillBuffer                      endp
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; #########################################################################
                    ;GetCommandLine  PROCEDURE
; #########################################################################
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
align 4
GetCmdLine                      proc dArgNumber:DWORD,pCstring:DWORD ;1=Success,2=No Argument,3=Non Match Quotation Marks
                                ;
                                ; 1 = successful operation
                                ; 2 = no argument exists at specified arg number
                                ; 3 = non matching quotation marks
        ;
        add dArgNumber, 1
        Invoke GetCommandLine
        Invoke GetArgNumber,eax,pCstring,dArgNumber,0
        ;
        .if eax >= 0
            mov ecx, pCstring
            .if byte ptr [ecx] != 0
                mov eax,1       ; successful operation
            .else
                mov eax,2       ; no argument at specified number
            .endif
        .elseif eax == -1
            mov eax, 3          ; non matching quotation marks
        .endif
        ;
    ret
GetCmdLine                      endp
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; #########################################################################
                    ;GetArgNumber  PROCEDURE
; #########################################################################
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
align 4
GetArgNumber                    proc uses esi edi ebx src:DWORD,dst:DWORD,num:DWORD,npos:DWORD
                                ;
    ;
    comment * ------------------------------------------
        Return values in EAX
        --------------------
        >0 = there is a higher number argument available
        0  = end of command line has been found
        -1 = a non matching quotation error occurred

        conditions of 0 or greater can have argument
        content which can be tested as follows.

        Test Argument for content
        -------------------------
        If the argument is empty, the first BYTE in the
        destination buffer is set to zero

        mov eax, destbuffer     ; load destination buffer
        cmp BYTE PTR [eax], 0   ; test its first BYTE
        je no_arg               ; branch to no arg handler
        print destbuffer,13,10  ; display the argument

        NOTE : A pair of empty quotes "" returns ascii 0
               in the destination buffer
        ----------------------------------------------- *
        ;
;        push ebx
;        push esi
;        push edi
        ;
        mov esi, src
        add esi, npos
        mov edi, dst
        ;
        mov BYTE PTR [edi], 0           ; set destination buffer to zero length
        xor ebx, ebx
        ;
        ; *********
        ; scan args
        ; *********
        bcscan:
            movzx eax, BYTE PTR [esi]
            add esi, 1
            cmp BYTE PTR [abntbl+eax], 1    ; delimiting character
            je bcscan
            cmp BYTE PTR [abntbl+eax], 2    ; ASCII zero
            je quit
            ;
            sub esi, 1
            add ebx, 1
            cmp ebx, num                    ; copy next argument if number matches
            je cparg
        ;
        gcscan:
            movzx eax, BYTE PTR [esi]
            add esi, 1
            cmp BYTE PTR [abntbl+eax], 0    ; OK character
            je gcscan
            cmp BYTE PTR [abntbl+eax], 2    ; ASCII zero
            je quit
            cmp BYTE PTR [abntbl+eax], 3    ; quotation
            je dblquote
            jmp bcscan                      ; return to delimiters
        ;
        dblquote:
            add esi, 1
            cmp BYTE PTR [esi], 0
            je qterror
            cmp BYTE PTR [esi], 34
            jne dblquote
            add esi, 1
            jmp bcscan                      ; return to delimiters
        ;
        ; ********
        ; copy arg
        ; ********
        cparg:
            xor eax, eax
            xor edx, edx
            cmp BYTE PTR [esi+edx], 34      ; if 1st char is a quote
            je cpquote                      ; jump to quote copy
            @@:
                mov al, [esi+edx]               ; copy normal argument to buffer
                mov [edi+edx], al
                test eax, eax
                jz quit
                add edx, 1
                cmp BYTE PTR [abntbl+eax], 1
            jl @B
            mov BYTE PTR [edi+edx-1], 0     ; append terminator
            jmp next_read
        ;
        ; ********************
        ; copy quoted argument
        ; ********************
        cpquote:
            add esi, 1
            @@:
                mov al, [esi+edx]               ; strip quotes and copy contents to buffer
                test al, al
                jz qterror
                cmp al, 34
                je write_zero
                mov [edi+edx], al
                add edx, 1
                jmp @B
        ;
        write_zero:
            add edx, 1                      ; correct EDX for final exit position
            mov BYTE PTR [edi+edx-1], 0     ; append terminator
        ;
        jmp next_read                    ; jump to next read setup
        ;
        ; *****************
        ; set return values
        ; *****************
        qterror:
            mov eax, -1                     ; quotation error
            jmp rstack
        ;
        quit:
            xor eax, eax                    ; set EAX to zero for end of source buffer
            jmp rstack
        ;
        next_read:
            mov eax, esi
            add eax, edx
            sub eax, src
        ;
        rstack:
;            pop edi
;            pop esi
;            pop ebx
        ;
    ret
GetArgNumber                    endp
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; #########################################################################
                    ;AscciiToDword  PROCEDURE
; #########################################################################
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
align 4
AscciiToDword                   proc pszCstring:DWORD
                                ;
        ; ----------------------------------------
        ; Convert decimal string into dword value
        ; return value in eax
        ; ----------------------------------------

        push esi
        push edi

        xor eax, eax
        mov esi, [pszCstring]
        xor ecx, ecx
        xor edx, edx
        mov al, [esi]
        inc esi
        cmp al, 2D
        jne proceed
            mov al, byte ptr [esi]
            not edx
            inc esi
        jmp proceed

        @@:
            sub al, 30h
            lea ecx, dword ptr [ecx+4*ecx]
            lea ecx, dword ptr [eax+2*ecx]
            mov al, byte ptr [esi]
            inc esi
        proceed:
        or al, al
        jne @B
        lea eax, dword ptr [edx+ecx]
        xor eax, edx

        pop edi
        pop esi
        ;
    ret
AscciiToDword                   endp
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; #########################################################################
                    ;KillProcess  PROCEDURE
; #########################################################################
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
align 4
KillProcess                     proc pszProgram:DWORD,dMostrar:DWORD ;dMostrar Hide=0 Unhide=1 Kill=2
                                LOCAL bLoop:BOOL
                                LOCAL bResult:BOOL
                                LOCAL pe32:PROCESSENTRY32
                                LOCAL hProcesses:HANDLE
                                ;
                                LOCAL Sh_st_info :STARTUPINFO
                                LOCAL Sh_sfi     :SHFILEINFO
                                ;
                                LOCAL szFullPathLocal[4096]:BYTE
                                LOCAL szExtentionLocal[5]:BYTE
                                LOCAL pFullPathLocal:DWORD
                                LOCAL dlParam[2]:DWORD
        ;
        mov bResult,FALSE
        mov pFullPathLocal,0
        lea eax, szExtentionLocal
        mov byte ptr[eax],'.'
        mov byte ptr[eax+1],'s'
        mov byte ptr[eax+2],'c'
        mov byte ptr[eax+3],'r'
        mov byte ptr[eax+4],0
        ;
        Invoke SearchPath,NULL,pszProgram,addr szExtentionLocal,sizeof szFullPathLocal,addr szFullPathLocal,addr pFullPathLocal
        ;
        Invoke SHGetFileInfo,addr szFullPathLocal,0,addr Sh_sfi,sizeof Sh_sfi,SHGFI_EXETYPE
        .if eax==0
            jmp ExitKillProcess
        .endif
        mov ecx,eax
        shr ecx,16
        .if ( (ax==4550H) && (cx==0) )
            ;WIN32_CON = PE Win32 CONSOLE 4550H
            mov     dword ptr [Sh_st_info.cb],sizeof STARTUPINFO
            Invoke  GetStartupInfoA, addr Sh_st_info
            mov ecx,dword ptr [Sh_st_info.lpTitle]
            mov pszProgram,ecx
            Invoke FindWindow,NULL,pszProgram
            .if eax!=0
                .if dMostrar==0 ;dMostrar Hide=0 Unhide=1 Kill=2
                    mov dMostrar,eax
                    Invoke ShowWindow,dMostrar,SW_HIDE ;SW_SHOW
                    Invoke SetForegroundWindow,dMostrar
                    mov bResult,TRUE
                .elseif dMostrar==1
                    mov dMostrar,eax
                    Invoke ShowWindow,dMostrar,SW_SHOW
                    Invoke SetForegroundWindow,dMostrar
                    mov bResult,TRUE
                .else
                    mov ecx,eax
                    Invoke GetWindowThreadProcessId,ecx, addr pe32.th32ProcessID
                    Invoke OpenProcess, PROCESS_ALL_ACCESS, FALSE, pe32.th32ProcessID
                    .if eax!=NULL
                        push eax
                        Invoke TerminateProcess,eax, 0
                        pop eax
                        Invoke CloseHandle,eax
                        mov bResult,TRUE
                    .endif
                .endif
            .endif
            ;
        .else ;.if ( (ax==4550H) && (cx==0) )
            ;
            mov bLoop,TRUE
            mov bResult,FALSE
            invoke CreateToolhelp32Snapshot,TH32CS_SNAPPROCESS,0
            mov hProcesses,eax
            mov pe32.dwSize,SIZEOF PROCESSENTRY32
            ;
            Invoke Process32First,hProcesses,addr pe32
            .if eax
                .while bLoop
                    Invoke CompareString,LOCALE_USER_DEFAULT, NORM_IGNORECASE, addr pe32.szExeFile, -1, pFullPathLocal, -1
                    .if eax==2
                        Invoke OpenProcess,PROCESS_ALL_ACCESS, FALSE, pe32.th32ProcessID
                        .if eax!=NULL
                            push eax
                            .if dMostrar!=2 ;dMostrar Hide=0 Unhide=1 Kill=2
                                lea edx,dlParam ;dlParam[2]:DWORD
                                mov eax,pe32.th32ProcessID
                                mov dword ptr[edx],eax
                                mov eax,dMostrar
                                mov dword ptr[edx+4],eax
                                Invoke EnumWindows,addr EnumWindowsProc,addr dlParam ;pe32.th32ProcessID
                            .else
                                Invoke TerminateProcess,eax, 0
                            .endif
                            pop eax
                            Invoke CloseHandle,eax
                            mov bResult,TRUE;
                        .endif
                    .endif
                    Invoke Process32Next, hProcesses,addr pe32
                    mov bLoop,eax
                .endw
                Invoke CloseHandle,hProcesses
            .endif
        .endif ;.if ( (ax==4550H) && (cx==0) )
        ;
        mov eax,bResult
        ;
    ExitKillProcess:
        ;
    ret
KillProcess                     endp
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; #########################################################################
                    ;EnumWindowsProc  PROCEDURE
; #########################################################################
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
align 4
EnumWindowsProc                 proc hWindow:DWORD,lparam:DWORD
                                LOCAL th32ProcessID:DWORD
                                LOCAL passeddMostrar:DWORD ;dMostrar Hide=0 Unhide=1 Kill=2
                                LOCAL passedth32ProcessID:DWORD
        ;
        mov edx,lparam
        mov eax,dword ptr[edx]
        mov passedth32ProcessID,eax
        mov eax,dword ptr[edx+4]
        mov passeddMostrar,eax                      ;
        ;
        Invoke GetWindowThreadProcessId,hWindow,addr th32ProcessID
        mov eax,passedth32ProcessID
        .if (th32ProcessID==eax)
            .if passeddMostrar==0 ;dMostrar Hide=0 Unhide=1 Kill=2
                Invoke ShowWindow,hWindow,SW_HIDE
            .else
                Invoke ShowWindow,hWindow,SW_SHOW
                Invoke SetForegroundWindow,hWindow
            .endif
            xor eax,eax
            add eax,1
        .endif
        ;To continue enumeration, the callback function must return TRUE; to stop enumeration, it must return FALSE.
        ;EnumWindows continues until the last top-level window is enumerated or the callback function returns FALSE.
    ret
EnumWindowsProc                 endp
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; #########################################################################
                    ;FireWork  PROCEDURES
; #########################################################################
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
align 4
random                          proc base:DWORD         ; Park Miller random number algorithm
                                LOCAL QCounter:QWORD                                
    Invoke QueryPerformanceCounter,addr QCounter
    lea edx,QCounter
    mov eax,dword ptr[edx+4]
    ;Invoke GetTickCount    
    add eax, seed
    mul ecx
    ;mov eax, seed              ; from M32lib/nrand.asm
    xor edx, edx
    mov ecx, 127773
    div ecx
    mov ecx, eax
    mov eax, 16807
    mul edx
    mov edx, ecx
    mov ecx, eax
    mov eax, 2836
    mul edx
    sub ecx, eax
    xor edx, edx
    mov eax, ecx
    mov seed, ecx
    div base
    mov eax, edx
    ret
random                          endp
; -------------------------------------------------------------------------
align 4
Light_Flash3                    proc uses esi edi ebx x1:DWORD, y1:DWORD, lum:DWORD, src:DWORD, des:DWORD
                                LOCAL mx:DWORD, my:DWORD, x2:DWORD, y2:DWORD, tff:DWORD
    mov eax,lum
    shr eax,1                  ; Light_Flash: dynamic 2D lighting routine
    mov lum,eax                ; does not uses any pre-computed data
    mov tff,255                ; ie. pure light frum tha melting cpu core :)
    mov eax,maxx
    mov mx,eax
    mov eax,maxy
    dec eax
    mov my,eax
    mov esi,src
    mov edi,des
    xor eax,eax
    mov y2,eax
ylp3:                          ; 2x2 instead of per pixel lighting
    xor eax,eax                ; half the quality, but higher speed
    mov x2,eax
xlp3:
    mov eax,y2
    sub eax,y1
    imul eax
    mov ecx,x2
    sub ecx,x1
    imul ecx,ecx
    add eax,ecx
    mov edx,lum
    imul edx,edx
    xor ebx,ebx
    cmp eax,edx
    ja @F                      ; jump to end causes time waves
    push eax
    fild dword ptr[esp]
    fsqrt
    fidiv lum                  ; this code is -nonlinear-
    fld1
    fsubrp st(1),st(0)
    fmul st(0),st(0)           ; curve
    fmul st(0),st(0)           ; curve more
    fimul tff
    fistp dword ptr[esp]

    pop ebx
    imul ebx,01010101h
@@:
    mov eax,y2
    imul maxx
    add eax,x2
    lea eax,[eax+eax*2]
    mov edx,maxx
    lea edx,[edx+edx*2]
    add edx,eax

    movd MM2,ebx               ; simply add with saturation
    movq MM0,[esi+eax]         ; gamma correction is against this code
    psllq MM2,32
    movq MM1,[esi+edx]
    movd MM3,ebx
    por MM2,MM3
    paddusb MM0,MM2
    movd [edi+eax],MM0
    paddusb MM1,MM2
    psrlq MM0,32
    movd [edi+edx],MM1
    movd ebx,MM0
    psrlq MM1,32
    mov [edi+eax+4],bx
    movd ecx,MM1
    mov [edi+edx+4],cx
    emms
@@:
    mov eax,x2
    add eax,2
    mov x2,eax
    cmp eax,mx
    jbe xlp3
    mov eax,y2
    add eax,2
    mov y2,eax
    cmp eax,my
    jbe ylp3
    ret
Light_Flash3                    endp
; -------------------------------------------------------------------------
align 4
Blur_MMX2                       proc uses esi edi ebx               ; 24bit color version
    emms 
    mov edi,bitmap2            ; (Developed under an old SiS6326 graphic card
    mov esi,bitmap1            ;  which prefers 24bit for faster operation)
    mov bitmap1,edi            ;  Note: SiS315 is excellent, good rendering quality
    mov bitmap2,esi
    pxor MM7,MM7
    mov eax,fadelvl
    imul eax,00010001h
    mov [ebp-4],eax
    mov [ebp-8],eax
    movq MM6,[ebp-8]
    mov eax,maxx
    lea eax,[eax+eax*2]
    mov ecx,eax
    imul maxy
    push eax                   ; maxy*maxx*3
    lea edx,[ecx-3]
    lea ebx,[ecx+3]
    neg edx                    ;if uncommented crash on W7x64
    xor eax,eax
    lea esi,[esi-3]
@@:
    movd MM0,[esi]             ; code enlarged version
    punpcklbw MM0,MM7          ; optimized for speed, not size
    movd MM1,[esi+8]
    movd MM2,[esi+16]
    punpcklbw MM1,MM7
    punpcklbw MM2,MM7

    movd MM3,[esi+6]
    movd MM4,[esi+14]
    movd MM5,[esi+22]
    punpcklbw MM3,MM7
    paddw MM0,MM3
    punpcklbw MM4,MM7
    paddw MM1,MM4
    punpcklbw MM5,MM7
    paddw MM2,MM5

    movd MM3,[esi+ecx]
    punpcklbw MM3,MM7
    paddw MM0,MM3
    movd MM4,[esi+ecx+8]
    movd MM5,[esi+ecx+16]
    punpcklbw MM4,MM7
    paddw MM1,MM4
    punpcklbw MM5,MM7
    paddw MM2,MM5

    movd MM3,[esi+edx]
    punpcklbw MM3,MM7
    paddw MM0,MM3
    movd MM4,[esi+edx+8]
    movd MM5,[esi+edx+16]
    punpcklbw MM4,MM7
    paddw MM1,MM4
    punpcklbw MM5,MM7
    paddw MM2,MM5

    psrlw MM0,2                ; neibours only, ie. smoky blur
    psrlw MM1,2
    psrlw MM2,2
    psubusw MM0,MM6            ; fade
    psubusw MM1,MM6
    psubusw MM2,MM6
    packuswb MM0,MM7
    lea esi,[esi+12]
    packuswb MM1,MM7
    packuswb MM2,MM7
    movd [edi+eax],MM0
    movd [edi+eax+8],MM1
    movd [edi+eax+16],MM2
    lea eax,[eax+12]
    cmp eax,[esp]
    jbe @B
    pop eax
    emms                       ; free fpu registers for following
    ret                        ; floating-point functions
Blur_MMX2                       endp
; -------------------------------------------------------------------------
align 4
FShell_explodeOS                proc hb:DWORD ;Outer Space
    mov ecx,hb
    add ecx,SPARC
    mov eax,nd
    dec eax
    shl eax,4
@@:
    fld dword ptr[ecx+eax]     ; x coordinate
    fadd dword ptr[ecx+eax+4]  ; x velocity
    fstp dword ptr[ecx+eax]
    fld dword ptr[ecx+eax+8]   ; y coordinate
    fadd dword ptr[ecx+eax+12] ; y velocity
    fstp dword ptr[ecx+eax+8]
    sub eax,16
    jnc @B
    dec dword ptr[ecx-SPARC]
    mov eax,[ecx-SPARC]        ; return(--life)
    ret
FShell_explodeOS                endp
; -------------------------------------------------------------------------
align 4
FShell_explodeAG                proc hb:DWORD ;Acceleration with Gravity
    mov ecx,hb
    fld adg                    ; acceleration due to gravity
    fld dword ptr[ecx+AIR]     ; air resistance
    add ecx,SPARC
    mov eax,nd
    dec eax
    shl eax,4
;   fs->air_drag = 1.0 - (float)(rnd(200)) / (10000.0 + fs->life);
;   fs->bicolor = !rnd(5) ? 120 : 0;
;   fs->flies = !rnd(10) ? 1 : 0; /* flies' motion */    
;       if (fs->flies)
;       {
;           fp->x += fp->xv = fp->xv * air_drag + frand(0.1) - 0.05;
;           fp->y += fp->yv = fp->yv * air_drag + frand(0.1) - 0.05 + G_ACCELERATION; //G_ACCELERATION 0.001
;       }
;       else
;       {
;           fp->x += fp->xv = fp->xv * air_drag + frand(0.01) - 0.005;
;           fp->y += fp->yv = fp->yv * air_drag + frand(0.005) - 0.0025 + G_ACCELERATION; //G_ACCELERATION 0.001
;       }    
@@:
    fld dword ptr[ecx+eax+4]   ; x velocity
    fmul st(0),st(1)           ; deceleration by air
    fst dword ptr[ecx+eax+4]
    fadd dword ptr[ecx+eax]    ; x coordinate
    fstp dword ptr[ecx+eax]
    fld dword ptr[ecx+eax+12]  ; y velocity
    fmul st(0),st(1)           ; deceleration by air
    fadd st(0),st(2)           ; gravity
    fst dword ptr[ecx+eax+12]
    fadd dword ptr[ecx+eax+8]  ; y coordinate
    fstp dword ptr[ecx+eax+8]
    sub eax,16
    jnc @B
    fcompp                     ; marks st(0) and st(1) empty
    dec dword ptr[ecx-SPARC]
    mov eax,[ecx-SPARC]        ; return(--life)
    ret
FShell_explodeAG                endp
; -------------------------------------------------------------------------
align 4
FShell_render                   proc uses esi edi ebx hb:DWORD, color:DWORD
    LOCAL expx:DWORD, expy:DWORD
    mov edi,hb
    mov eax,[edi+EXX]
    mov expx,eax
    mov eax,[edi+EXY]
    mov expy,eax
    add edi,SPARC
    mov ebx,color
    dec ebx
    ;and ebx,3
    lea ecx,chemtable
    mov edx,hFShells           ; floats are beautiful, and cheap source of
    add edx,32                 ; the chemical used for multi colored fires
    mov eax,CMode
    or eax,eax
    cmovz edx,ecx
    mov edx,[edx+ebx*4]
    mov ecx,nd
    dec ecx
    shl ecx,4
    mov esi,bitmap1
    push maxy                  ; using stack adds speed
    push maxx                  ; (local variables)
    push edx
@@:
    fld dword ptr[edi+ecx+4]
    fabs
    fld xcut                   ; low cost code for independant burnouts
    fcomip st(0),st(1)
    fistp dword ptr[esp-4]
    jae forget

    fld dword ptr[edi+ecx]
    fistp dword ptr[esp-4]
    fld dword ptr[edi+ecx+8]
    fistp dword ptr[esp-8]
    mov eax,[esp-8]
    cmp eax,[esp+8]
    jae forget
    mov ebx,[esp-4]
    cmp ebx,[esp+4]
    jae forget
    imul dword ptr[esp+4]
    add eax,ebx
    lea eax,[eax+eax*2]
    mov edx,[esp]
    mov [esi+eax],dx
    shr edx,16
    mov [esi+eax+2],dl
forget:
    sub ecx,16
    jnc @B
    ;add esp,12  'leave'ing (endp)
    ret
FShell_render                   endp
; -------------------------------------------------------------------------
align 4
FShell_recycle                  proc uses esi edi ebx hb:DWORD, x:DWORD, y:DWORD
    mov edi,hb
    mov eax,x
    mov [edi+EXX],eax
    mov eax,y
    mov [edi+EXY],eax
    mov eax,x
    mov lightx,eax             ; Light last one
    mov eax,y
    mov lighty,eax
    mov eax,flash              ; having only one light source
    add eax,3200               ; 3200 million jouls...!
    mov flash,eax              ; add if previous lighting not extinguished
    invoke random,20
    inc eax
    imul minlife
    mov ebx,eax                ; sync explosions by mouse clicks with rest
    mov eax,[edi]              ; by maintaining minimum delay of 'minlife'
    xor edx,edx
    idiv minlife
    add edx,ebx
    mov [edi],edx
    invoke random,30           ; like its real world counterpart, creation process
    add eax,10                 ; is long and boring but the end product is explodin..
    mov [esp-4],eax            ; refer C++ source also. Most of the below area
    mov eax,10000              ; is blind translation of that original C code
    mov [esp-8],eax            ; i crawled on that code as a Human C compiler...!
    fld1
    fild dword ptr[esp-4]
    fidiv dword ptr[esp-8]
    fsubp st(1),st(0)
    fstp dword ptr[edi+AIR]
    add edi,SPARC
    fild y
    fild x
    mov eax,1000
    mov [esp-4],eax
    fild dword ptr[esp-4]      ; 1000 (constant)
    invoke random,maxpower
    inc eax
    mov [esp-4],eax
    fild dword ptr[esp-4]      ; power
    mov ecx,nd
    dec ecx
    shl ecx,4
@@:
    push ecx
    invoke random,2000
    mov [esp-4],eax
    fild dword ptr[esp-4]
    fsub st(0),st(2)
    fdiv st(0),st(2)
    fmul st(0),st(1)
    mov ecx,[esp]
    fstp dword ptr[edi+ecx+4]
    fld st(0)
    fmul st(0),st(0)
    fld dword ptr[edi+ecx+4]
    fmul st(0),st(0)
    fsubp st(1),st(0)
    fsqrt
    invoke random,2000
    mov [esp-4],eax
    fild dword ptr[esp-4]
    fsub st(0),st(3)
    fdiv st(0),st(3)
    fmulp st(1),st(0)
    mov ecx,[esp]
    fstp dword ptr[edi+ecx+12]
    fld st(2)
    fstp dword ptr[edi+ecx]
    fld st(3)
    fstp dword ptr[edi+ecx+8]
    pop ecx
    sub ecx,16
    jnc @B
    fcompp
    fcompp
    ret
FShell_recycle                  endp
; -------------------------------------------------------------------------
align 4
FireThread                      proc uses esi edi ebx
                                LOCAL dScreenW:DWORD
                                LOCAL dScreenH:DWORD
                                LOCAL dScreenBits:DWORD
                                ;
        ;
        Invoke GetDC,hWinMain ;hwnd ;wnd ;hWinTarget
        mov wnddc,eax
        invoke GetProcessHeap
        mov hHeap,eax
        Invoke GetSystemMetrics,SM_CXSCREEN
        mov dScreenW,eax
        Invoke GetSystemMetrics,SM_CYSCREEN
        mov dScreenH,eax
        xor edx,edx
        mov ecx,dScreenW
        mul ecx
        shl eax,4
        mov dScreenBits,eax
        invoke HeapAlloc,hHeap,HEAP_ZERO_MEMORY OR HEAP_GENERATE_EXCEPTIONS,dScreenBits ;2048*2048*8 ;1024*1024*4=4194304
        ;add eax,4096*4 ;4096               ; blur: -1'th line problem
        mov ecx,dScreenW
        shl ecx,4
        add eax,ecx
        mov bitmap1,eax
        invoke HeapAlloc,hHeap,HEAP_ZERO_MEMORY OR HEAP_GENERATE_EXCEPTIONS,dScreenBits ;2048*2048*8 ;4194304
        ;add eax,4096*4;4096               ; blur: -1'th line problem
        mov ecx,dScreenW
        shl ecx,4
        add eax,ecx        
        mov bitmap2,eax
        ;
        mov eax,nd
        shl eax,4
        add eax,SPARC
        mov sb,eax                 ; size of FShell = nd*16+8
        imul nb                    ; array size   = nb*sb
        Invoke HeapAlloc,hHeap,HEAP_ZERO_MEMORY OR HEAP_GENERATE_EXCEPTIONS ,eax
        mov hFShells,eax
        ;
        finit                      ; initialise floating point unit
        mov ax,07fh                ; low precision floats
        mov word ptr[esp-4],ax     ; fireworks... not space rockets
        fldcw word ptr[esp-4]

        sub ebp,12                 ; as 3 local variables
        ;sub esp,12
        ;mov ebp,esp        

        mov eax,nb
        mov [ebp],eax
        mov eax,hFShells
        mov [ebp+4],eax
        ;
        ;Invoke MessageBox,NULL, addr szAppName,NULL,NULL
initshells:
;        mov eax,maxx              ; naah... not needed
;        shr eax,1                 ; trusting auto-zero
;        invoke FShell_recycle,[ebp+4],eax,maxy
;        mov eax,sb
;        add [ebp+4],eax
;        dec dword ptr[ebp]
;        jnz initshells
;        mov flash,6400
       ;
lp1:
        mov eax,motionQ
        mov dword ptr[ebp+8],eax
lp2:
        mov eax,nb
        mov [ebp],eax
        mov eax,hFShells
        mov [ebp+4],eax
lp3:
        invoke FShell_render,[ebp+4],[ebp]
        mov eax,GMode
        lea ecx,FShell_explodeAG
        lea ebx,FShell_explodeOS
        test eax,eax
        cmovz ecx,ebx
        push [ebp+4]
        call ecx
        test eax,eax
        jns @F
        Invoke random,maxy
        push eax
        mov eax,maxx
        add eax,eax
        Invoke random,eax
        mov edx,maxx
        shr edx,1
        sub eax,edx
        push eax
        push [ebp+4]
        call FShell_recycle
@@:
        mov eax,sb
        add [ebp+4],eax
        dec dword ptr[ebp]
        jnz lp3
        dec dword ptr[ebp+8]
        jnz lp2
        mov eax,EMode
        test eax,eax
        jz r1
        mov eax,CMode              ; switch pre/post blur according to -
        test eax,eax               ; current chemical in fire
        jz @F
        Invoke Blur_MMX2
@@:
        mov eax,stop
        test eax,eax
        jnz r3
        Invoke Light_Flash3,lightx,lighty,flash,bitmap1,bitmap2
        Invoke SetDIBitsToDevice,wnddc,0,0,maxx,maxy,\
               LEFT_NOISE,0,0,maxy,bitmap2,ADDR bminf,DIB_RGB_COLORS
        mov eax,CMode
        test eax,eax
        jnz r2
        invoke Blur_MMX2
        jmp r2
r1:
        mov eax,stop
        test eax,eax
        jnz r3
        invoke SetDIBitsToDevice,wnddc,0,0,maxx,maxy,\
               LEFT_NOISE,0,0,maxy,bitmap1,ADDR bminf,DIB_RGB_COLORS
        mov eax,maxx
        imul maxy
        lea eax,[eax+eax*2]
        invoke RtlZeroMemory,bitmap1,eax
r2:
        inc fcount                 ; count the frames
        fild flash
        fmul flfactor
        fistp flash
        ;
;        .if dOperation==5 ;1=Preview,2=Configuration,3=Debug,4=Sreensaver,5=Normal,6=Pass,7=Invalid Arg
            Invoke Sleep,5             ; control, if frames rate goes too high
;        .else
;            Invoke SwitchToThread
;            @@:
;            Invoke PeekMessageA,addr msg,hWinMain,0,0,PM_REMOVE
;            .if eax ;If a message is available, the return value is nonzero.
;                Invoke TranslateMessage,addr msg
;                Invoke DispatchMessage,addr msg
;                jmp @B
;            .endif
;        .endif
       ;
        mov eax,stop
        test eax,eax
        jz lp1
r3:
        ;Invoke IsWindow,hWinMain
        ;.if eax
            Invoke ReleaseDC,hWinMain,wnddc
            .if eax!=0 ;If the device context is not released, the return value is zero.
                mov wnddc,NULL
            .endif
        ;.endif
        invoke HeapFree,hHeap,0,bitmap1
        invoke HeapFree,hHeap,0,bitmap2
        invoke HeapFree,hHeap,0,hFShells
        mov idThread1,-1
        ;Invoke KillProcess,addr szCL,2
        ;mov eax,2003
        Invoke ExitThread,NULL ;2003
        ret ;hlt                        ; ...! i8085 memories
FireThread                      endp
; -------------------------------------------------------------------------
MoniThread                      proc uses esi edi ebx pVoid:DWORD
                                ;
    @@:
    invoke Sleep,1000
    invoke wsprintf,ADDR fps,ADDR fmat,fcount
    invoke SetWindowText,hWinMain,ADDR fps
    xor eax,eax
    mov fcount,eax
    mov eax,stop
    test eax,eax
    jz @B
    mov idThread2,-1
    invoke ExitThread,2003
    ret
MoniThread                      endp
; -------------------------------------------------------------------------
align 4
Switch                          proc uses esi edi ebx oMode:DWORD, iid:DWORD
    xor eax,eax
    mov edx,oMode
    or al,byte ptr [edx]
    setz  byte ptr [edx]
    mov eax,[edx]
    mov ecx,MF_CHECKED
    shl eax,3
    and eax,ecx
    or eax,MF_BYCOMMAND
    .if dOperation==5 ;Normal
        Invoke CheckMenuItem,hmnu,iid,eax
    .endif
    ret
Switch                          endp
; -------------------------------------------------------------------------
end start