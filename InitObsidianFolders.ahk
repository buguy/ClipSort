#Requires AutoHotkey v2.0

; ============================================================
; 一次性執行：建立 Obsidian Vault 預設資料夾結構
; 跑完一次就可以刪掉這個腳本
; ============================================================

VAULT := "D:\Obsidian\Obsidian"

folders := [
    "Life", "Life\Travel", "Life\Food", "Life\Shopping",
    "Health", "Health\Fitness", "Health\Meditation", "Health\Nutrition",
    "Finance", "Finance\Investing", "Finance\Budgeting",
    "Crypto", "Crypto\Bitcoin", "Crypto\Altcoins", "Crypto\DeFi",
    "AI", "AI\Tools", "AI\News", "AI\OpenSource", "AI\Prompts", "AI\Models", "AI\Research",
    "Tech", "Tech\Coding", "Tech\Gadgets", "Tech\Networking", "Tech\Security",
    "Work", "Work\DDPM", "Work\NKVM",
    "Projects", "Projects\ClickbaitKiller", "Projects\ClipToObsidian"
]

count := 0
for _, f in folders {
    path := VAULT "\" f
    if !DirExist(path) {
        DirCreate(path)
        count++
    }
}

MsgBox("完成！新建了 " count " 個資料夾。", "InitFolders")
ExitApp
