# ClipToObsidian AI 自動分類存檔 — 使用手冊

## 專案概述

一個快捷鍵搞定：自動把剪貼簿的**文字或截圖**透過 AI 判斷分類，存到 Obsidian Vault 對應的資料夾中。

- **文字** → AI 分類 → 存成 `.md` 筆記
- **截圖** → AI 看圖分類 → 存成 `.png` 圖片

---

## 系統需求

- Windows 10/11
- AutoHotkey v2.0+（[下載](https://www.autohotkey.com/)）
- Obsidian（Vault 路徑：`D:\Obsidian\Obsidian`）
- PicPick（截圖工具，截圖到剪貼簿）
- OpenRouter 帳號 + API Key（[申請](https://openrouter.ai/)）
- OpenRouter 帳戶需有儲值餘額（每月約 $0.08 美金）

---

## 檔案清單

| 檔案 | 用途 | 備註 |
|---|---|---|
| `ClipToObsidianAI.ahk` | 主腳本，常駐背景 | 放在 `C:\Users\user\Downloads\` |
| `InitObsidianFolders.ahk` | 一次性建立資料夾結構 | 執行一次後可刪除 |
| `ClipToObsidian.ahk` | 舊版腳本（Ctrl+Shift+S 存 Daily Note） | 可選擇是否同時使用 |

---

## 首次設定

### 1. 建立資料夾結構

雙擊執行 `InitObsidianFolders.ahk`，自動建立以下資料夾：

```
AI/          Tools, News, OpenSource, Prompts, Models, Research
Tech/        Coding, Gadgets, Networking, Security
Life/        Travel, Food, Shopping
Health/      Fitness, Meditation, Nutrition
Finance/     Investing, Budgeting
Crypto/      Bitcoin, Altcoins, DeFi
Work/        DDPM, NKVM
Projects/    ClickbaitKiller, ClipToObsidian
```

完成後會跳出「新建了 X 個資料夾」的提示，之後可以刪除這個腳本。

### 2. 設定 API Key

用文字編輯器打開 `ClipToObsidianAI.ahk`，找到第 12 行：

```
OPENROUTER_API_KEY := "YOUR_OPENROUTER_API_KEY_HERE"
```

換成你的 OpenRouter API Key。

### 3. 啟動腳本

雙擊 `ClipToObsidianAI.ahk`，右下角系統匣會出現 AutoHotkey 圖示。

### 4.（選用）開機自動啟動

按 `Win+R` → 輸入 `shell:startup` → 把 `ClipToObsidianAI.ahk` 的捷徑放進去。

---

## 使用方式

### 存文字

1. 選取文字 → Ctrl+C 複製
2. 按 **Ctrl+Shift+D**
3. 等待 1-3 秒，通知：「已存到 AI/Tools/20260413_120000_Tools.md」

### 存截圖

1. 用 PicPick 截圖到剪貼簿
2. 按 **Ctrl+Shift+D**
3. 等待 2-5 秒，通知：「截圖已存到 Finance/Budgeting/20260413_135012_Budgeting.png」

### 使用建議

- **能複製文字就用文字** — 文字分類比截圖更準確，因為 AI 能直接理解完整內容
- **截圖適合** — 圖表、影片畫面、無法選取的文字、UI 介面等
- 截圖會自動縮小到 800x800 以內再送 AI，節省 token

---

## 快捷鍵一覽

| 快捷鍵 | 功能 |
|---|---|
| `Ctrl+Shift+D` | AI 分類存檔（自動偵測文字/截圖） |
| `Ctrl+Shift+Alt+D` | AI 分類存檔（Debug 模式，顯示 AI 原始回應） |

---

## 筆記格式

### 文字筆記（.md）

```markdown
# AI 判斷的標題

- **Created**：2026-04-13 12:00:00
- **Category**：AI/Tools

---

（你複製的原文內容）
```

檔名格式：`20260413_120000_Tools.md`

### 截圖（.png）

直接存成 PNG 圖片，不產生額外的 md 檔案。

檔名格式：`20260413_135012_Budgeting.png`

---

## AI 分類邏輯

每次按快捷鍵時，腳本會：

1. 偵測剪貼簿類型（文字 or 圖片）
2. 掃描 Vault 下兩層資料夾結構
3. 文字 → 直接送給 AI；截圖 → 存暫存 PNG → 縮小 → 轉 base64 → 送給 AI
4. AI 回傳最適合的資料夾路徑和建議標題
5. 自動存到對應資料夾（不存在會自動建立）

如果 AI 判斷沒有適合的現有資料夾，會自動建議並建立新資料夾。

如果 AI 回應解析失敗，會 fallback 到 `Inbox` 資料夾。

---

## 自訂設定

所有設定都在腳本開頭的「設定區」：

```ahk
VAULT_PATH := "D:\Obsidian\Obsidian"
OPENROUTER_API_KEY := "sk-or-..."
MODEL := "google/gemini-2.5-flash-lite"
```

### 換模型

| 模型 | Model ID | 特點 | 月成本 |
|---|---|---|---|
| Gemini 2.5 Flash Lite（目前） | `google/gemini-2.5-flash-lite` | Vision + 文字，穩定快速 | ~$0.08 |
| Gemma 4 26B | `google/gemma-4-26b-a4b-it` | Vision + 文字，偶爾 provider error | ~$0.10 |
| Llama 3.3 70B | `meta-llama/llama-3.3-70b-instruct` | 純文字，不支援截圖 | ~$0.08 |
| Llama 3.3 70B 免費版 | `meta-llama/llama-3.3-70b-instruct:free` | 純文字，免費但較慢 | $0 |

### 新增資料夾

直接在 Obsidian 或檔案總管中建立新資料夾即可，腳本每次執行時會自動掃描最新的資料夾結構。

### 忽略清單

以下資料夾不會出現在 AI 的選項中：

- `.obsidian`（隱藏資料夾）
- `attachments`
- `Clippings`
- `templates`
- `Inbox`

如需修改，編輯腳本中 `ScanFolderTree` 函數的 `skipList`。

---

## 費用說明

使用 Gemini 2.5 Flash Lite，透過 OpenRouter 按 token 計費：

| 類型 | 每次成本 | 一天 50 次 | 一個月 |
|---|---|---|---|
| 文字分類 | ~$0.00005 | $0.0025 | ~$0.08 |
| 截圖分類 | ~$0.0002 | $0.01 | ~$0.30 |

費用可在 [OpenRouter Dashboard](https://openrouter.ai/activity) 查看。

---

## 常見問題

**Q：按快捷鍵後顯示「剪貼簿沒有內容」？**
複製的內容可能是 rich text 格式。試試先貼到記事本再複製，確保是純文字。

**Q：截圖顯示「圖片儲存失敗」？**
確認 PicPick 截圖是存到剪貼簿（不是存檔）。也可以用 Windows 內建的 Print Screen 測試。

**Q：AI 一直把內容放到 Inbox？**
用 Debug 模式（Ctrl+Shift+Alt+D）查看 AI 的原始回應，確認是否有回傳 FOLDER: 格式。

**Q：截圖分類跟文字分類結果不一樣？**
正常現象。文字分類更準確，因為 AI 直接讀完整內容。截圖需要先「看懂」圖片再判斷。建議能複製文字就用文字。

**Q：如何結束腳本？**
右下角系統匣找到 AutoHotkey 的綠色 H 圖示 → 右鍵 → Exit。

**Q：可以跟舊版 ClipToObsidian.ahk 同時使用嗎？**
可以。舊版用 Ctrl+Shift+S 存到 Daily Note，新版用 Ctrl+Shift+D 做 AI 分類，互不衝突。

---

## 技術架構

```
Ctrl+Shift+D
    │
    ├─ 文字？ → 送文字給 AI → FOLDER + TITLE → 存 .md
    │
    └─ 圖片？ → PowerShell -STA 存 PNG
                  → 縮小到 800px
                  → 轉 base64
                  → 送給 AI Vision → FOLDER + TITLE → 存 .png
```

- **AI 模型**：Google Gemini 2.5 Flash Lite（via OpenRouter）
- **API 格式**：OpenAI-compatible chat completions
- **圖片處理**：PowerShell + System.Drawing（-STA 模式存取剪貼簿）
- **檔案編碼**：UTF-8 無 BOM（ADODB.Stream）
