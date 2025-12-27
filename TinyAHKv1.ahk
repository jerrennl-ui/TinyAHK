#SingleInstance Force
#Persistent
#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%
SetBatchLines -1
CoordMode, Mouse, Screen
CoordMode, ToolTip, Screen
SetTitleMatchMode 2

global isRecording := false
global isPlaying := false
global recorded := []
global loopPlayback := false
global playbackSpeed := 1.0
global keyState := {}
global mouseButtons := ["LButton", "RButton", "MButton"]
global lastMousePos := ""
global savedMacros := {}
global currentMacroName := ""
global totalEvents := 0
global currentEvent := 0
global macroDir := A_ScriptDir  ; Default to script directory

; Load settings from INI file - first check in macro directory, then script directory
settingsPath := macroDir . "\settings.ini"
if (FileExist(A_ScriptDir . "\settings.ini")) {
    settingsPath := A_ScriptDir . "\settings.ini"  ; For backward compatibility
}
IniRead, macroDir, %settingsPath%, Settings, MacroDir, %A_ScriptDir%

Menu, Tray, NoStandard
Menu, Tray, Add, ▶️ Play, TrayPlay
Menu, Tray, Add, ⏺ Record, TrayRecord
Menu, Tray, Add
Menu, Tray, Add, Set Macro Directory, SetMacroDirectory
Menu, Tray, Add
Menu, Tray, Add, ❌ Exit, MenuExit
Menu, Tray, Tip, TinyAHK Macro Recorder

Gui, Add, Button, gToggleRecord w150 h30 vBtnRecord, Start Recording
Gui, Add, Button, gStartPlayback w150 h30 vBtnPlay, Play
Gui, Add, Button, gStopPlayback w150 h30 vBtnStop, Stop
Gui, Add, Checkbox, vChkLoop gToggleLoop w150 h30, Loop Playback
Gui, Add, Text,, Speed:
Gui, Add, Slider, vSldSpeed gUpdateSpeed Range10-300 w150 h30, 100
Gui, Add, Button, gSaveMacro w150 h30, Save Macro
Gui, Add, Button, gLoadMacro w150 h30, Load Macro
Gui, Add, Button, gOpenMacroLibrary w150 h30, Macro Library
Gui, Add, Text, w150 h20 vCurrentMacro, Current: None
Gui, Add, Progress, w150 h20 vProgressBar cGreen, 0
Gui, Add, Text, w150 h2 0x10
Gui, Add, Text, w150 h100 vHotkeyText, Hotkeys:`nCtrl+Shift+R - Record`nCtrl+Shift+P - Play`nCtrl+Shift+Z - Stop`nCtrl+Q - Exit
Gui, Show, w180 h450, TinyAHK Macro Recorder

^q::ExitApp
^+r::Gosub, ToggleRecord
^+p::Gosub, StartPlayback
^+z::Gosub, StopPlayback

; Hotkeys for wheel recording
#If isRecording
WheelUp::Gosub, RecordWheelUp
WheelDown::Gosub, RecordWheelDown
#If

MenuExit:
ExitApp
return

SetMacroDirectory:
    FileSelectFolder, newMacroDir, *%macroDir%, 3, Select Macro Storage Folder
    if (ErrorLevel || newMacroDir = "")
        return
    
    macroDir := newMacroDir
    ; Create/update settings.ini in the macro directory
    settingsPath := macroDir . "\settings.ini"
    IniWrite, %macroDir%, %settingsPath%, Settings, MacroDir
    
    ; Remove old settings file from script directory if it exists
    oldSettings := A_ScriptDir . "\settings.ini"
    if (FileExist(oldSettings) && oldSettings != settingsPath) {
        FileDelete, %oldSettings%
    }
    
    ToolTip, Macro directory set to: %macroDir%
    SetTimer, RemoveToolTip, -2000
return

RecordWheelUp:
    if (isRecording) {
        recorded.Insert({type: "mouse", event: "wheel", amount: 1, time: A_TickCount})
    }
return

RecordWheelDown:
    if (isRecording) {
        recorded.Insert({type: "mouse", event: "wheel", amount: -1, time: A_TickCount})
    }
return

StopPlayback:
    if (isPlaying) {
        isPlaying := false
        GuiControl, Enable, BtnPlay
        GuiControl, Disable, BtnStop
        GuiControl,, ProgressBar, 0
        ToolTip, Playback stopped
        SetTimer, RemoveToolTip, -800
    }
return

ToggleRecord:
    if (isRecording) {
        isRecording := false
        SetTimer, RecordInput, Off
        keyState := {}
        GuiControl,, BtnRecord, Start Recording
        GuiControl, Enable, BtnPlay
        ToolTip, Recording stopped.
        SetTimer, RemoveToolTip, -800
    } else {
        recorded := []
        keyState := {}
        isRecording := true
        SetTimer, RecordInput, 20
        GuiControl,, BtnRecord, Stop Recording
        GuiControl, Disable, BtnPlay
        ToolTip, Recording started...
        SetTimer, RemoveToolTip, -800
    }
return

StartPlayback:
    if (isRecording) {
        ToolTip, Cannot play while recording!
        SetTimer, RemoveToolTip, -800
        return
    }

    if (isPlaying)
        return
        
    if (recorded.MaxIndex() = "") {
        ToolTip, No macro recorded or loaded.
        SetTimer, RemoveToolTip, -800
        return
    }

    isPlaying := true
    loopSpeed := playbackSpeed
    GuiControl, Disable, BtnPlay
    GuiControl, Enable, BtnStop
    
    ; Setup progress bar
    totalEvents := recorded.MaxIndex()
    currentEvent := 0
    GuiControl,, ProgressBar, 0
    GuiControl, +Range0-%totalEvents%, ProgressBar
    
    Loop {
        if (recorded.MaxIndex() = "")
            break
        lastTick := recorded[1].time
        for i, entry in recorded {
            if (!isPlaying)
                break
                
            ; Update progress bar
            currentEvent := i
            GuiControl,, ProgressBar, %currentEvent%
            
            delay := (entry.time - lastTick) / loopSpeed
            lastTick := entry.time
            if (delay > 0)
                Sleep, %delay%
            
            if (entry.type = "mouse") {
                if (entry.event = "move") {
                    x := entry.x ? entry.x : 0
                    y := entry.y ? entry.y : 0
                    MouseMove, %x%, %y%, 0
                } else if (entry.event = "click") {
                    btn := entry.button ? entry.button : "Left"
                    Click, %btn%
                } else if (entry.event = "down") {
                    btn := entry.button ? entry.button : "Left"
                    MouseClick, %btn%, , , , , D
                } else if (entry.event = "up") {
                    btn := entry.button ? entry.button : "Left"
                    MouseClick, %btn%, , , , , U
                } else if (entry.event = "wheel") {
                    amt := entry.amount ? entry.amount : 1
                    Loop, % Abs(amt) {
                        if (amt > 0)
                            MouseClick, WheelUp
                        else
                            MouseClick, WheelDown
                    }
                }
            } else if (entry.type = "key") {
                if (entry.key) {
                    keyName := entry.key
                    if (entry.event = "down")
                        Send, {%keyName% down}
                    else if (entry.event = "up")
                        Send, {%keyName% up}
                }
            }
        }
        if (!loopPlayback || !isPlaying)
            break
    }
    isPlaying := false
    GuiControl, Enable, BtnPlay
    GuiControl, Disable, BtnStop
    GuiControl,, ProgressBar, 0
return

ToggleLoop:
    Gui, Submit, NoHide
    loopPlayback := ChkLoop
return

UpdateSpeed:
    Gui, Submit, NoHide
    playbackSpeed := SldSpeed / 100.0
return

SaveMacro:
    if (recorded.MaxIndex() = "") {
        ToolTip, No macro recorded to save.
        SetTimer, RemoveToolTip, -800
        return
    }
    InputBox, macroName, Save Macro, Enter a name for this macro:,, 300, 130
    if (ErrorLevel || macroName = "")
        return
    savePath := macroDir . "\" . macroName . ".txt"
    FileDelete, %savePath%
    FileAppend, MACRO_NAME|%macroName%`n, %savePath%
    for i, rec in recorded {
        key := rec.key ? rec.key : ""
        button := rec.button ? rec.button : ""
        x := rec.x ? rec.x : ""
        y := rec.y ? rec.y : ""
        amount := rec.amount ? rec.amount : ""
        line := rec.type "|" rec.event "|" rec.time "|" key "|" button "|" x "|" y "|" amount
        FileAppend, %line%`n, %savePath%
    }
    savedMacros[macroName] := recorded.Clone()
    currentMacroName := macroName
    GuiControl,, CurrentMacro, Current: %currentMacroName%
    ToolTip, Macro "%macroName%" saved to %macroDir%.
    SetTimer, RemoveToolTip, -2000
return

LoadMacro:
    FileSelectFile, loadPath, 3, %macroDir%, Load Macro File, Macro Files (*.txt)
    if (loadPath = "")
        return
    recorded := []
    macroName := ""
    Loop, Read, %loadPath%
    {
        if (A_LoopReadLine = "")
            continue
        
        if (InStr(A_LoopReadLine, "MACRO_NAME|") = 1) {
            parts := StrSplit(A_LoopReadLine, "|")
            if (parts.MaxIndex() >= 2)
                macroName := parts[2]
            continue
        }
        
        parts := StrSplit(A_LoopReadLine, "|")
        if (parts.MaxIndex() < 3)
            continue
        obj := {}
        obj.type := parts[1]
        obj.event := parts[2]
        obj.time := parts[3]
        if (obj.type = "key") {
            if (parts.MaxIndex() >= 4 && parts[4] != "")
                obj.key := parts[4]
        } else if (obj.type = "mouse") {
            if (parts.MaxIndex() >= 5 && parts[5] != "")
                obj.button := parts[5]
            if (parts.MaxIndex() >= 6 && parts[6] != "")
                obj.x := parts[6]
            if (parts.MaxIndex() >= 7 && parts[7] != "")
                obj.y := parts[7]
            if (parts.MaxIndex() >= 8 && parts[8] != "")
                obj.amount := parts[8]
        }
        recorded.Insert(obj)
    }

    if (macroName = "") {
        SplitPath, loadPath, , , , nameNoExt
        macroName := nameNoExt
    }

    currentMacroName := macroName
    savedMacros[macroName] := recorded.Clone()
    GuiControl,, CurrentMacro, Current: %currentMacroName%
    ToolTip, Macro "%macroName%" loaded from file.
    SetTimer, RemoveToolTip, -800
return

OpenMacroLibrary:
    Gui, Library:New, +Resize +MinSize, Macro Library
    Gui, Add, Text, w300, Search Macros:
    Gui, Add, Edit, vSearchTerm gSearchMacros w300
    Gui, Add, ListView, vMacroList gSelectMacro w300 h300, Macro Name
    Gui, Add, Button, gSetDirFromLib w300 h30, Change Macro Directory
    Gui, Add, Button, gLoadSelectedMacro w300 h30, Load Selected Macro
    Gui, Show
    RefreshMacroList("")
return

SetDirFromLib:
    Gui, Library:Destroy
    Gosub, SetMacroDirectory
    Gosub, OpenMacroLibrary
return

SearchMacros:
    Gui, Submit, NoHide
    RefreshMacroList(SearchTerm)
return

RefreshMacroList(filter) {
    global macroDir
    Gui, ListView, MacroList
    LV_Delete()
    
    Loop, Files, %macroDir%\*.txt
    {
        if (filter != "") {
            if !InStr(A_LoopFileName, filter)
                continue
        }
        
        macroName := ""
        Loop, Read, %A_LoopFileFullPath%
        {
            if (InStr(A_LoopReadLine, "MACRO_NAME|")) {
                parts := StrSplit(A_LoopReadLine, "|")
                if (parts.MaxIndex() >= 2)
                    macroName := parts[2]
                break
            }
        }
        
        if (macroName = "") {
            SplitPath, A_LoopFileName, , , , nameNoExt
            macroName := nameNoExt
        }
        
        LV_Add("", macroName)
    }
    LV_ModifyCol(1, "AutoHdr")
}

SelectMacro:
    if (A_GuiEvent = "DoubleClick") {
        Gosub, LoadSelectedMacro
    }
return

LoadSelectedMacro:
    Gui, ListView, MacroList
    row := LV_GetNext()
    if (!row)
        return
    
    LV_GetText(macroName, row, 1)
    if (macroName = "")
        return
    
    ; Find the file with this macro name
    filePath := ""
    Loop, Files, %macroDir%\*.txt
    {
        currentName := ""
        Loop, Read, %A_LoopFileFullPath%
        {
            if (InStr(A_LoopReadLine, "MACRO_NAME|")) {
                parts := StrSplit(A_LoopReadLine, "|")
                if (parts.MaxIndex() >= 2)
                    currentName := parts[2]
                break
            }
        }
        
        if (currentName = "") {
            SplitPath, A_LoopFileName, , , , nameNoExt
            currentName := nameNoExt
        }
        
        if (currentName = macroName) {
            filePath := A_LoopFileFullPath
            break
        }
    }
    
    if (filePath = "")
        return
    
    recorded := []
    macroName := ""
    
    Loop, Read, %filePath%
    {
        if (A_LoopReadLine = "")
            continue
        
        if (InStr(A_LoopReadLine, "MACRO_NAME|") = 1) {
            parts := StrSplit(A_LoopReadLine, "|")
            if (parts.MaxIndex() >= 2)
                macroName := parts[2]
            continue
        }
        
        parts := StrSplit(A_LoopReadLine, "|")
        if (parts.MaxIndex() < 3)
            continue
        
        obj := {}
        obj.type := parts[1]
        obj.event := parts[2]
        obj.time := parts[3]
        
        if (obj.type = "key") {
            if (parts.MaxIndex() >= 4 && parts[4] != "")
                obj.key := parts[4]
        } else if (obj.type = "mouse") {
            if (parts.MaxIndex() >= 5 && parts[5] != "")
                obj.button := parts[5]
            if (parts.MaxIndex() >= 6 && parts[6] != "")
                obj.x := parts[6]
            if (parts.MaxIndex() >= 7 && parts[7] != "")
                obj.y := parts[7]
            if (parts.MaxIndex() >= 8 && parts[8] != "")
                obj.amount := parts[8]
        }
        recorded.Insert(obj)
    }
    
    if (macroName = "") {
        SplitPath, filePath, , , , nameNoExt
        macroName := nameNoExt
    }
    
    currentMacroName := macroName
    savedMacros[macroName] := recorded.Clone()
    GuiControl,, CurrentMacro, Current: %currentMacroName%
    ToolTip, Macro "%macroName%" loaded from library.
    SetTimer, RemoveToolTip, -800
    
    Gui, Library:Destroy
return

LibraryGuiClose:
    Gui, Library:Destroy
return

RecordInput:
    MouseGetPos, mx, my
    now := A_TickCount

    posStr := mx "," my
    if (posStr != lastMousePos) {
        recorded.Insert({type: "mouse", event: "move", x: mx, y: my, time: now})
        lastMousePos := posStr
    }

    for i, btn in mouseButtons {
        isDown := GetKeyState(btn, "P")
        if (isDown && !keyState[btn]) {
            recorded.Insert({type: "mouse", button: btn, event: "down", time: now})
            keyState[btn] := true
        } else if (!isDown && keyState[btn]) {
            recorded.Insert({type: "mouse", button: btn, event: "up", time: now})
            keyState[btn] := false
        }
    }

    keyList = 
    (LTrim Join
        a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z
        0,1,2,3,4,5,6,7,8,9
        Space,Enter,Tab,Esc,Backspace,Delete,Insert,Home,End,PgUp,PgDn
        Up,Down,Left,Right
        F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,F11,F12
        LControl,RControl,LShift,RShift,LAlt,RAlt,LWin,RWin
        ``,-,=,[,],\,;,',`,,.,/
        CapsLock,ScrollLock,NumLock,PrintScreen,Pause,Break
        Numpad0,Numpad1,Numpad2,Numpad3,Numpad4,Numpad5,Numpad6,Numpad7,Numpad8,Numpad9
        NumpadDot,NumpadDiv,NumpadMult,NumpadAdd,NumpadSub,NumpadEnter
    )

    Loop, Parse, keyList, `,
    {
        key := A_LoopField
        isDown := GetKeyState(key)
        if (isDown && !keyState[key]) {
            recorded.Insert({type: "key", key: key, event: "down", time: now})
            keyState[key] := true
        } else if (!isDown && keyState[key]) {
            recorded.Insert({type: "key", key: key, event: "up", time: now})
            keyState[key] := false
        }
    }
return

RemoveToolTip:
    SetTimer, RemoveToolTip, Off
    ToolTip
return

TrayPlay:
    Gosub, StartPlayback
return

TrayRecord:
    Gosub, ToggleRecord
return

GuiClose:
    ExitApp
return