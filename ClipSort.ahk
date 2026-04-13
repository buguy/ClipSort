#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
; ClipSort — AI-powered clipboard organizer
; Hotkey: Ctrl+Shift+D
; Debug:  Ctrl+Shift+Alt+D
;
; Text  → AI categorizes → saves as .md note
; Image → AI vision categorizes → saves as .png
; ============================================================

; === Configuration ===
; Edit these values to match your setup
TARGET_DIR := "D:\Notes"                   ; Any folder path
OPENROUTER_API_KEY := "YOUR_OPENROUTER_API_KEY_HERE"   ; Get from https://openrouter.ai/settings/keys
MODEL := "google/gemini-2.5-flash-lite"                ; Supports both text and vision

; === Hotkeys ===
^+d:: {
    RunClassify(false)
}

^+!d:: {
    RunClassify(true)
}

RunClassify(showDebug) {
    global TARGET_DIR, OPENROUTER_API_KEY, MODEL

    if (OPENROUTER_API_KEY = "YOUR_OPENROUTER_API_KEY_HERE") {
        MsgBox("Please set your OpenRouter API key in the script first.`n`nOpen ClipSort.ahk with a text editor and edit line 14.", "ClipSort Setup")
        return
    }

    clipType := GetClipboardType()

    if (clipType = "none") {
        TrayTip "ClipSort", "Clipboard is empty", "iconi"
        return
    }

    TrayTip "ClipSort", "AI categorizing...", "iconi"

    folderTree := ScanFolderTree(TARGET_DIR)

    if (clipType = "image") {
        tempPng := A_Temp "\clipsort_temp.png"
        if !SaveClipboardImage(tempPng) {
            TrayTip "ClipSort", "Failed to save image", "iconx"
            return
        }

        base64 := FileToBase64(tempPng)
        if (base64 = "") {
            TrayTip "ClipSort", "Failed to encode image", "iconx"
            return
        }

        if (showDebug) {
            b64Len := StrLen(base64)
            MsgBox("Base64 length: " b64Len " chars`n~" Round(b64Len / 1024) " KB", "Image Debug")
        }

        result := CallAIWithImage(base64, folderTree, OPENROUTER_API_KEY, MODEL, showDebug)

        if (result.error) {
            TrayTip "ClipSort", "AI error: " result.error, "iconx"
            return
        }

        folderPath := result.folder
        targetDir := TARGET_DIR "\" StrReplace(folderPath, "/", "\")
        if !DirExist(targetDir)
            DirCreate(targetDir)

        timeStamp := FormatTime(, "yyyyMMdd_HHmmss")
        parts := StrSplit(folderPath, "/")
        folderSuffix := parts[parts.Length]

        imgFileName := timeStamp "_" folderSuffix ".png"
        imgPath := targetDir "\" imgFileName
        FileCopy(tempPng, imgPath, true)
        FileDelete(tempPng)

        TrayTip "ClipSort", "Saved to " folderPath "/" imgFileName, "iconi"

    } else {
        clipText := A_Clipboard
        result := CallAIWithText(clipText, folderTree, OPENROUTER_API_KEY, MODEL, showDebug)

        if (result.error) {
            TrayTip "ClipSort", "AI error: " result.error, "iconx"
            return
        }

        folderPath := result.folder
        noteTitle := result.title
        targetDir := TARGET_DIR "\" StrReplace(folderPath, "/", "\")
        if !DirExist(targetDir)
            DirCreate(targetDir)

        timeStamp := FormatTime(, "yyyyMMdd_HHmmss")
        parts := StrSplit(folderPath, "/")
        folderSuffix := parts[parts.Length]
        fileName := timeStamp "_" folderSuffix
        filePath := targetDir "\" fileName ".md"

        fullTimestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        content := "# " noteTitle "`n`n"
        content .= "- **Created**: " fullTimestamp "`n"
        content .= "- **Category**: " folderPath "`n`n"
        content .= "---`n`n"
        content .= clipText
        WriteUTF8File(filePath, content)

        TrayTip "ClipSort", "Saved to " folderPath "/" fileName ".md", "iconi"
    }
}

; === Clipboard Type Detection ===
GetClipboardType() {
    if DllCall("IsClipboardFormatAvailable", "uint", 2) || DllCall("IsClipboardFormatAvailable", "uint", 8) {
        return "image"
    }
    if (A_Clipboard != "")
        return "text"
    return "none"
}

; === Save Clipboard Image via PowerShell -STA ===
SaveClipboardImage(outputPath) {
    psFile := A_Temp "\clipsort_save.ps1"
    if FileExist(psFile)
        FileDelete(psFile)

    psContent := "Add-Type -AssemblyName System.Windows.Forms`n"
    psContent .= "Add-Type -AssemblyName System.Drawing`n"
    psContent .= "$img = [System.Windows.Forms.Clipboard]::GetImage()`n"
    psContent .= "if ($img) {`n"
    psContent .= "  $maxW = 800`n"
    psContent .= "  $maxH = 800`n"
    psContent .= "  $w = $img.Width`n"
    psContent .= "  $h = $img.Height`n"
    psContent .= "  if ($w -gt $maxW -or $h -gt $maxH) {`n"
    psContent .= "    $ratio = [Math]::Min($maxW/$w, $maxH/$h)`n"
    psContent .= "    $nw = [int]($w * $ratio)`n"
    psContent .= "    $nh = [int]($h * $ratio)`n"
    psContent .= "    $bmp = New-Object System.Drawing.Bitmap($nw, $nh)`n"
    psContent .= "    $g = [System.Drawing.Graphics]::FromImage($bmp)`n"
    psContent .= "    $g.InterpolationMode = 'HighQualityBicubic'`n"
    psContent .= "    $g.DrawImage($img, 0, 0, $nw, $nh)`n"
    psContent .= "    $g.Dispose()`n"
    psContent .= "    $img.Dispose()`n"
    psContent .= "    $bmp.Save('" outputPath "')`n"
    psContent .= "    $bmp.Dispose()`n"
    psContent .= "  } else {`n"
    psContent .= "    $img.Save('" outputPath "')`n"
    psContent .= "    $img.Dispose()`n"
    psContent .= "  }`n"
    psContent .= "}`n"
    FileAppend(psContent, psFile)

    try {
        RunWait("powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File " psFile,, "Hide")
        if FileExist(psFile)
            FileDelete(psFile)
        return FileExist(outputPath)
    } catch {
        return false
    }
}

; === File to Base64 via PowerShell ===
FileToBase64(filePath) {
    resultFile := A_Temp "\clipsort_b64.txt"
    psFile := A_Temp "\clipsort_b64.ps1"
    if FileExist(resultFile)
        FileDelete(resultFile)
    if FileExist(psFile)
        FileDelete(psFile)

    line1 := "$bytes = [IO.File]::ReadAllBytes('" filePath "')"
    line2 := "$b64 = [Convert]::ToBase64String($bytes)"
    line3 := "$b64 | Out-File -Encoding ascii '" resultFile "'"
    FileAppend(line1 "`n" line2 "`n" line3, psFile)

    try {
        RunWait("powershell.exe -NoProfile -ExecutionPolicy Bypass -File " psFile,, "Hide")
        if FileExist(psFile)
            FileDelete(psFile)
        if FileExist(resultFile) {
            b64 := FileRead(resultFile)
            FileDelete(resultFile)
            return Trim(b64)
        }
    } catch {
    }
    return ""
}

; === Scan Two-Level Folder Structure ===
ScanFolderTree(vaultPath) {
    skipList := Map("attachments", 1, "Clippings", 1, "templates", 1, "Inbox", 1)
    tree := ""

    loop files vaultPath "\*", "D" {
        parent := A_LoopFileName
        if (SubStr(parent, 1, 1) = ".")
            continue
        if skipList.Has(parent)
            continue

        subs := []
        loop files vaultPath "\" parent "\*", "D" {
            subName := A_LoopFileName
            if (SubStr(subName, 1, 1) != ".")
                subs.Push(subName)
        }

        if (subs.Length > 0) {
            subList := ""
            for i, s in subs {
                subList .= parent "/" s
                if (i < subs.Length)
                    subList .= ", "
            }
            tree .= parent " (" subList ")\n"
        } else {
            tree .= parent "\n"
        }
    }

    if (tree = "")
        tree := "none"
    return tree
}

; === Write UTF-8 No BOM ===
WriteUTF8File(filePath, content) {
    stream := ComObject("ADODB.Stream")
    stream.Type := 2
    stream.Charset := "UTF-8"
    stream.Open()
    stream.WriteText(content)
    stream.Position := 0
    stream.Type := 1
    stream.Position := 3
    binaryStream := ComObject("ADODB.Stream")
    binaryStream.Type := 1
    binaryStream.Open()
    stream.CopyTo(binaryStream)
    binaryStream.SaveToFile(filePath, 2)
    binaryStream.Close()
    stream.Close()
}

; === Build Prompt ===
BuildPrompt(folderTree) {
    q := Chr(34)
    prompt := "You are a note categorizer. Given the content below, decide which folder to store it in.`n`n"
    prompt .= "Folder structure:`n" folderTree "`n"
    prompt .= "Rules:`n"
    prompt .= "- Use a subfolder path like " q "Tech/Coding" q " or " q "Finance/Investing" q " when a subfolder fits`n"
    prompt .= "- Use just the parent folder like " q "Tech" q " if no subfolder is a good fit`n"
    prompt .= "- If no existing folder fits, suggest a new path`n"
    prompt .= "- Folder names must be English, single word, capitalized, no spaces`n"
    prompt .= "- Title should be short and descriptive`n`n"
    return prompt
}

; === Call AI (Text) ===
CallAIWithText(text, folderTree, apiKey, model, showDebug) {
    displayText := text
    if (StrLen(displayText) > 1500)
        displayText := SubStr(displayText, 1, 1500)

    prompt := BuildPrompt(folderTree)
    prompt .= "Content:`n" displayText "`n`n"
    prompt .= "Reply EXACTLY in this format (2 lines only, no extra text):`n"
    prompt .= "FOLDER: path/to/folder`n"
    prompt .= "TITLE: Note Title Here"

    escapedPrompt := EscapeJSON(prompt)
    body := '{"model":"' model '","max_tokens":100,"messages":[{"role":"user","content":"' escapedPrompt '"}]}'

    return SendRequest(body, apiKey, showDebug)
}

; === Call AI (Image) ===
CallAIWithImage(base64, folderTree, apiKey, model, showDebug) {
    prompt := BuildPrompt(folderTree)
    prompt .= "I am sharing a screenshot. Look at the image and categorize it.`n`n"
    prompt .= "Reply EXACTLY in this format (2 lines only, no extra text):`n"
    prompt .= "FOLDER: path/to/folder`n"
    prompt .= "TITLE: Note Title Here"

    escapedPrompt := EscapeJSON(prompt)
    body := '{"model":"' model '","max_tokens":100,"messages":[{"role":"user","content":[{"type":"text","text":"' escapedPrompt '"},{"type":"image_url","image_url":{"url":"data:image/png;base64,' base64 '"}}]}]}'

    return SendRequest(body, apiKey, showDebug)
}

; === Send HTTP Request ===
SendRequest(body, apiKey, showDebug) {
    result := {folder: "", title: "", error: ""}

    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", "https://openrouter.ai/api/v1/chat/completions", false)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.SetRequestHeader("Authorization", "Bearer " apiKey)
        whr.SetRequestHeader("HTTP-Referer", "https://github.com/ClipSort")
        whr.SetRequestHeader("X-Title", "ClipSort")
        whr.Send(body)
        whr.WaitForResponse()

        statusCode := whr.Status
        if (statusCode != 200) {
            responseText := ReadUTF8Response(whr)
            result.error := "HTTP " statusCode " - " SubStr(responseText, 1, 300)
            return result
        }

        responseText := ReadUTF8Response(whr)

        if (showDebug) {
            MsgBox(SubStr(responseText, 1, 1500), "AI Raw Response (debug)")
        }

        result := ParseAIResponse(responseText, showDebug)
    } catch as e {
        result.error := e.Message
    }

    return result
}

; === Read UTF-8 Response ===
ReadUTF8Response(whr) {
    try {
        stream := ComObject("ADODB.Stream")
        stream.Type := 1
        stream.Open()
        stream.Write(whr.ResponseBody)
        stream.Position := 0
        stream.Type := 2
        stream.Charset := "UTF-8"
        responseText := stream.ReadText()
        stream.Close()
        return responseText
    } catch as e {
        return whr.ResponseText
    }
}

; === Parse AI Response ===
ParseAIResponse(responseText, showDebug := false) {
    result := {folder: "", title: "", error: ""}

    searchText := StrReplace(responseText, "\n", "`n")
    searchText := StrReplace(searchText, '\"', '"')
    searchText := StrReplace(searchText, "\\", "\")

    if (showDebug) {
        folderPos := InStr(searchText, "FOLDER:")
        if (folderPos > 0) {
            snippet := SubStr(searchText, folderPos, 200)
            MsgBox(snippet, "Found FOLDER at pos " folderPos)
        } else {
            MsgBox("FOLDER: not found in response", "Parse Debug")
        }
    }

    for _, line in StrSplit(searchText, "`n") {
        trimLine := Trim(line)

        if (result.folder = "" && RegExMatch(trimLine, "i)FOLDER\s*:\s*(.+)", &m)) {
            val := Trim(m[1])
            val := RegExReplace(val, "[*,`']", "")
            val := StrReplace(val, '"', "")
            val := Trim(val)
            if (val != "")
                result.folder := val
        }
        else if (result.title = "" && RegExMatch(trimLine, "i)TITLE\s*:\s*(.+)", &m)) {
            val := Trim(m[1])
            val := RegExReplace(val, "[*,`']", "")
            val := StrReplace(val, '"', "")
            val := Trim(val)
            if (val != "")
                result.title := val
        }
    }

    if (result.folder != "") {
        cleanFolder := ""
        loop parse result.folder {
            ch := A_LoopField
            if (RegExMatch(ch, "[a-zA-Z0-9/]"))
                cleanFolder .= ch
        }
        cleanFolder := Trim(cleanFolder, "/")
        if (cleanFolder != "")
            result.folder := cleanFolder
    }

    if (result.folder = "")
        result.folder := "Inbox"
    if (result.title = "")
        result.title := "Note_" FormatTime(, "yyyyMMdd_HHmmss")

    return result
}

; === JSON Escape ===
EscapeJSON(str) {
    str := StrReplace(str, "\", "\\")
    str := StrReplace(str, '"', '\"')
    str := StrReplace(str, "`n", "\n")
    str := StrReplace(str, "`r", "\r")
    str := StrReplace(str, "`t", "\t")
    return str
}
