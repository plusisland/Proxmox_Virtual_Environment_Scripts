# GitHub Experiment Overview | GitHub 實驗概述

This GitHub repository serves as a personal experimental platform.  
The main objective is to verify whether individuals without programming knowledge can create correct and executable code with the assistance of AI.

本 GitHub 為個人實驗場，主要目標是驗證不懂程式語法的人，是否能透過人工智慧的協助建立正確可執行的程式碼。

## Experiment Process | 實驗流程

1. Each Bash shell script will include a reference link in the second line that explains the source of the code.
2. The goal is to feed reference materials into ChatGPT to generate the code.
3. Code optimization and reduction will be performed using **Gemini**.
4. Finally, **Grok** will be used for code review.
5. The code will undergo physical testing on actual hardware to verify its feasibility and correctness.

每個 Bash shell 第二行附上此段程式碼參考的說明網址，實驗目標為將參考資料餵給 ChatGPT 建立程式碼，使用 **Gemini** 做程式碼優化與刪減，最後使用 **Grok** 做審核。程式碼會經過實機驗證其可行性與正確性。

## Hardware Setup | 硬體環境

The hardware environment used for this experiment is the **R2 POE with POE Function**.  
You can find more information about it [here](https://www.ikoolcore.com/en-tw/products/ikoolcore-r2-poe-firewall).

使用的硬體環境為 **R2 POE with POE Function**，更多資訊請參見[官方網站](https://www.ikoolcore.com/en-tw/products/ikoolcore-r2-poe-firewall)。

Additionally, we are utilizing a **MiniPCIe M.2 E-Key WiFi Module** model **MediaTek MT7922** as part of the environment setup.

並藉由 MiniPCIe 配備 **M.2 E-Key WiFi Module 型號為 MediaTek MT7922** 作為環境。

## Code Comparison | 程式碼比較

The code generated will be compared with the community-maintained **Proxmox VE Helper-Scripts** to assess whether the goal is achieved and if the resulting code is more efficient and optimized.

程式碼會與社群維護的 **Proxmox VE Helper-Scripts** 程式碼做比較，檢查是否達成目標且能生成更高效能精簡的程式碼。

For official environment use, you should opt for the community-maintained code.  
You can find the community scripts [here](https://community-scripts.github.io/ProxmoxVE/scripts).

如果您要正式環境使用，您應該選擇社群維護的程式碼，請參見[社群腳本](https://community-scripts.github.io/ProxmoxVE/scripts)。
