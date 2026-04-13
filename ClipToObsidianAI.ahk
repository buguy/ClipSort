#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
; ClipToObsidian AI 自動分類存檔（文字 + 圖片）
; 快捷鍵：Ctrl+Shift+D
; Debug：Ctrl+Shift+Alt+D
;
; 文字 → AI 分類 → 存到對應資料夾
; 圖片 → AI 看圖分類 → 圖片存到對應資料夾
; ============================================================

; === 設定區 ===
VAULT_PATH := "D:\Obsidian\Obsidian"
OPENROUTER_API_KEY := "YourAPIKey"
MODEL := "google/gemini-2.5-flash-lite"

; === 主快捷鍵 ===
^+d:: {
    RunClassify(false)
}

; === Debug 快捷鍵 ===
^+!d:: {
    RunClassify(true)
}

RunClassify(showDebug) {
    global VAULT_PATH, OPENROUTER_API_KEY, MODEL

    ; 判斷剪貼簿類型：圖片 or 文字
    clipType := GetClipboardType()

    if (clipType = "none") {
        TrayTip "ClipToObsidian AI", "剪貼簿沒有內容", "iconi"
        return
    }

    TrayTip "ClipToObsidian AI", "AI 分類中...", "iconi"

    folderTree := ScanFolderTree(VAULT_PATH)

    if (clipType = "image") {
        ; 圖片流程：存暫存檔 → 轉 base64 → 送 AI
        tempPng := A_Temp "\clip_temp.png"
        if !SaveClipboardImage(tempPng) {
            TrayTip "ClipToObsidian AI", "圖片儲存失敗", "iconx"
            return
        }

        base64 := FileToBase64(tempPng)
        if (base64 = "") {
            TrayTip "ClipToObsidian AI", "圖片轉碼失敗", "iconx"
            return
        }

        if (showDebug) {
            b64Len := StrLen(base64)
            MsgBox("Base64 長度: " b64Len " 字元`n約 " Round(b64Len / 1024) " KB", "Image Debug")
        }

        result := CallAIWithImage(base64, folderTree, OPENROUTER_API_KEY, MODEL, showDebug)

        if (result.error) {
            TrayTip "ClipToObsidian AI", "AI 呼叫失敗: " result.error, "iconx"
            return
        }

        ; 把圖片移到目標資料夾
        folderPath := result.folder
        noteTitle := result.title
        targetDir := VAULT_PATH "\" StrReplace(folderPath, "/", "\")
        if !DirExist(targetDir)
            DirCreate(targetDir)

        timeStamp := FormatTime(, "yyyyMMdd_HHmmss")
        parts := StrSplit(folderPath, "/")
        folderSuffix := parts[parts.Length]

        ; 存圖片
        imgFileName := timeStamp "_" folderSuffix ".png"
        imgPath := targetDir "\" imgFileName
        FileCopy(tempPng, imgPath, true)
        FileDelete(tempPng)

        TrayTip "ClipToObsidian AI", "截圖已存到 " folderPath "/" imgFileName, "iconi"

    } else {
        ; 文字流程（跟之前一樣）
        clipText := A_Clipboard
        result := CallAIWithText(clipText, folderTree, OPENROUTER_API_KEY, MODEL, showDebug)

        if (result.error) {
            TrayTip "ClipToObsidian AI", "AI 呼叫失敗: " result.error, "iconx"
            return
        }

        folderPath := result.folder
        noteTitle := result.title
        targetDir := VAULT_PATH "\" StrReplace(folderPath, "/", "\")
        if !DirExist(targetDir)
            DirCreate(targetDir)

        timeStamp := FormatTime(, "yyyyMMdd_HHmmss")
        parts := StrSplit(folderPath, "/")
        folderSuffix := parts[parts.Length]
        fileName := timeStamp "_" folderSuffix
        filePath := targetDir "\" fileName ".md"

        fullTimestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        content := "# " noteTitle "`n`n"
        content .= "- **Created**：" fullTimestamp "`n"
        content .= "- **Category**：" folderPath "`n`n"
        content .= "---`n`n"
        content .= clipText
        WriteUTF8File(filePath, content)

        TrayTip "ClipToObsidian AI", "已存到 " folderPath "/" fileName ".md", "iconi"
    }
}

; === 判斷剪貼簿類型 ===
GetClipboardType() {
    ; CF_BITMAP = 2, CF_DIB = 8, CF_DIBV5 = 17
    if DllCall("IsClipboardFormatAvailable", "uint", 2) || DllCall("IsClipboardFormatAvailable", "uint", 8) {
        return "image"
    }
    if (A_Clipboard != "")
        return "text"
    return "none"
}

; === 用 PowerShell 存剪貼簿圖片（-STA 模式，縮小到 max 800px） ===
SaveClipboardImage(outputPath) {
    psFile := A_Temp "\clip_save.ps1"
    if FileExist(psFile)
        FileDelete(psFile)

    ; 截圖存檔並縮小，避免 base64 太大
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

; === 檔案轉 Base64（用 PowerShell .ps1 檔案避免引號問題） ===
FileToBase64(filePath) {
    resultFile := A_Temp "\clip_b64.txt"
    psFile := A_Temp "\clip_b64.ps1"
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

; === 掃描兩層資料夾結構 ===
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

; === 寫入 UTF-8 無 BOM ===
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

; === 建立 prompt 文字 ===
BuildPrompt(folderTree) {
    q := Chr(34)
    prompt := "You are a note categorizer. Given the content below, decide which folder to store it in.`n`n"
    prompt .= "Folder structure:`n" folderTree "`n"
    prompt .= "Rules:`n"
    prompt .= "- Use a subfolder path like " q "AI/Tools" q " or " q "Crypto/DeFi" q " when a subfolder fits`n"
    prompt .= "- Use just the parent folder like " q "Tech" q " if no subfolder is a good fit`n"
    prompt .= "- If no existing folder fits, suggest a new path`n"
    prompt .= "- Folder names must be English, single word, capitalized, no spaces`n"
    prompt .= "- Title should be short and descriptive`n`n"
    return prompt
}

; === 呼叫 AI（純文字） ===
CallAIWithText(text, folderTree, apiKey, model, showDebug) {
    result := {folder: "", title: "", error: ""}

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

; === 呼叫 AI（圖片） ===
CallAIWithImage(base64, folderTree, apiKey, model, showDebug) {
    result := {folder: "", title: "", error: ""}

    prompt := BuildPrompt(folderTree)
    prompt .= "I am sharing a screenshot. Look at the image and categorize it.`n`n"
    prompt .= "Reply EXACTLY in this format (2 lines only, no extra text):`n"
    prompt .= "FOLDER: path/to/folder`n"
    prompt .= "TITLE: Note Title Here"

    escapedPrompt := EscapeJSON(prompt)

    ; OpenRouter vision 格式：content 是 array
    body := '{"model":"' model '","max_tokens":100,"messages":[{"role":"user","content":[{"type":"text","text":"' escapedPrompt '"},{"type":"image_url","image_url":{"url":"data:image/png;base64,' base64 '"}}]}]}'

    return SendRequest(body, apiKey, showDebug)
}

; === 發送 HTTP 請求 ===
SendRequest(body, apiKey, showDebug) {
    result := {folder: "", title: "", error: ""}

    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", "https://openrouter.ai/api/v1/chat/completions", false)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.SetRequestHeader("Authorization", "Bearer " apiKey)
        whr.SetRequestHeader("HTTP-Referer", "https://github.com/ClipToObsidian")
        whr.SetRequestHeader("X-Title", "ClipToObsidian AI")
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

; === UTF-8 讀取回應 ===
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

; === 解析 AI 回應 ===
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

    ; 清理 folder path
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

; === JSON 跳脫 ===
EscapeJSON(str) {
    str := StrReplace(str, "\", "\\")
    str := StrReplace(str, '"', '\"')
    str := StrReplace(str, "`n", "\n")
    str := StrReplace(str, "`r", "\r")
    str := StrReplace(str, "`t", "\t")
    return str
}
