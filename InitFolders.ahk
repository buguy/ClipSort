#Requires AutoHotkey v2.0

; ============================================================
; ClipSort — One-time folder structure setup
; Run once to create starter folders, then delete this script.
; Edit the folder list below to match your needs.
; ============================================================

TARGET := "D:\Notes"  ; <-- Change to your folder path

folders := [
    "Tech", "Tech\Coding", "Tech\Gadgets", "Tech\Networking", "Tech\Security",
    "AI", "AI\Tools", "AI\News", "AI\OpenSource", "AI\Prompts", "AI\Models", "AI\Research",
    "Finance", "Finance\Investing", "Finance\Budgeting",
    "Crypto", "Crypto\Bitcoin", "Crypto\Altcoins", "Crypto\DeFi",
    "Health", "Health\Fitness", "Health\Meditation", "Health\Nutrition",
    "Life", "Life\Travel", "Life\Food", "Life\Shopping",
    "Work",
    "Projects"
]

count := 0
for _, f in folders {
    path := TARGET "\" f
    if !DirExist(path) {
        DirCreate(path)
        count++
    }
}

MsgBox("Done! Created " count " new folders.", "ClipSort Setup")
ExitApp
