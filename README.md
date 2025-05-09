# 🧩 FRRouting 主要元件說明

| 守護程式 (Daemon) | 功能角色             | 在本範例中的作用                                                    |
| ------------- | ---------------- | ----------------------------------------------------------- |
| **zebra**     | kernel routing table 協調者（路由交換中心） | 負責與 Linux kernel 的 routing table 溝通，並接收來自 bgpd 的路由資訊後安裝到系統中 |
| **bgpd**      | BGP 協定守護程式       | 負責與對端進行 BGP session 的建立、維持、路由交換                             |
| **staticd**   | 靜態路由守護程式         | 支援設定手動靜態路由（預設啟動）                                   |
| **watchfrr**  | 監控與重啟 FRR 守護程式   | 自動監控其他 FRR 守護行程（如 bgpd/zebra），若崩潰會自動重啟                      |
| **vtysh**     | 整合 CLI 界面        | 提供 CLI 操作介面，可進行 bgp/zebra 等設定的即時編輯與查詢                       |




# Daemon 詳細介紹

## 1. zebra
- 處理 interface 狀態變更（如 eth0/eth1 UP/DOWN）。
- 接收來自 bgpd 的學習路由，並評估是否安裝至 Linux routing table。
- 實作 route redistribution 橋接，例如：redistribute connected。

## 2. bgpd
- 根據 `router bgp` block 建立 BGP Session
- 維護 BGP routing table，包含 learned routes、local announced routes
- 根據 policy（route-map、prefix-list）做路由過濾與選擇

## 3. staticd
- 若設定靜態路由會在此守護程式中管理

## 4. watchfrr
- 負責監控上面三個進程，一旦 bgpd 或 zebra 當掉，會自動重啟

## 5. vtysh
- 整合 CLI 工具，讓你可以像 Cisco CLI 一樣進入 configure terminal，查詢路由、設定鄰居等