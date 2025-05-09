# Topology

```
+-------------+               +-------------+
| frr-100-r10 | eth1 <-> eth1 | frr-200-r10 | 
|  AS65000    |               |  AS65001    |
+-------------+               +-------------+
eth0: 10.0.100.10/24          eth0: 10.0.200.10/24
eth1: 10.0.101.100/24         eth1: 10.0.101.200/24

```

- `frr-100-r10`: 屬於 AS65000，Router-ID 為 `10.0.100.10`
- `frr-200-r10`: 屬於 AS65001，Router-ID 為 `10.0.200.10`
- 兩者透過 eth1（10.0.101.0/24）互為 eBGP 鄰居

---

# Daemon 互動架構圖
```
+------------------+
|   vtysh (CLI)    |
+------------------+
        |
        v
+------------------+
|      zebra       | <--> Linux Kernel Routing Table
+------------------+
        ^
        |
  +-------------+         +--------------+
  |    bgpd     | <-----> |   Neighbor   |
  +-------------+         +--------------+

```
- `bgpd` 與鄰居建立 BGP session，交換路由。
- `zebra` 是中心交換站，將路由整合後安裝至系統。
- `vtysh` 是 CLI，讓使用者可操作 `bgpd`/`zebra` 等設定。

---

# Flow
1. bgpd 與對方節點建立 TCP 179 的 BGP session。
2. 彼此透過 redistribute connected 分享其 eth0 的 connected network。
3. 路由資訊傳送給 zebra，由其決定是否寫入 Linux routing table。
4. zebra 負責讓 ip route 與 ip r 看到 BGP 學到的路由。
5. 使用者可用 vtysh CLI 查詢 show ip bgp, show ip route 驗證學習結果。


---

# 📄 frr-100-r10/frr.conf（AS 65000）

```bash
frr version 10.2.2
```
- 指定 FRRouting 的版本，這裡使用的是 `10.2.2`。

```bash
frr defaults traditional
```
- 使用傳統預設設定格式（不啟用 integrated config split 等新格式），便於學習與管理。

```bash
hostname frr-100-r10
```
- 設定此路由器的主機名稱，對應容器名稱，可在 vtysh CLI 中顯示。

```bash
service integrated-vtysh-config
```
- 啟用整合設定，允許使用 `vtysh` 存取並修改所有守護行程（如 bgpd, zebra）設定。

```bash
log syslog informational
```
- 將資訊等級以上的 log 訊息記錄至 syslog。

---

```bash
interface eth0
 ip address 10.0.100.10/24
```
- 設定 eth0 介面 IP，屬於本機網段（將透過 `redistribute connected` 宣告出去）。
- `redistribute connected`
    | 功能                    | 說明                                                   |
    | --------------------- | ---------------------------------------------------- |
    | 自動化路由宣告               | 不用手動列出 network，所有介面上連的路由自動被納入考量                      |
    | 倚賴 zebra 的 route 感知機制 | bgpd 並不直接存取 kernel routing table，而是透過 zebra 取得資訊     |
    | 可與 route-map 控制配合     | 搭配 `match interface` 等條件，只輸出來自特定介面的 connected routes |

    - BGP 原生只宣告你明確指定的 network（使用 network x.x.x.x/yy 指令），但在許多情況下，你希望：
        - 自動將 router 上啟用的某些 IP interface（也就是 connected route）直接讓 BGP 宣告給鄰居。
        - 避免手動輸入 network 指令。
        - 這時候就會使用 `redistribute connected`
    - redistribute connected 的「橋接」動作是由 zebra 與 bgpd 合作完成：
        ```
        +--------------+
        |  connected   | ← 由 kernel 加入的介面路由（如 eth0/eth1）
        +------+-------+
                |
                | 被 zebra 掃描到（例如 eth0: 10.0.100.10/24）
                v
        +--------------+
        |    zebra     | ← 接收到 connected route，並通知 bgpd
        +------+-------+
                |
                | 根據 bgpd 的設定
                v
        +--------------+
        |    bgpd      | ← 若設定了 "redistribute connected"，就會將這些路由放進 BGP table
        +--------------+
                |
                v
        +--------------+
        |  BGP peer(s) | ← 將 route 宣告給鄰居
        +--------------+
        ```
    - `redistribute connected` + route-map
        - 可以只讓特定介面（如 eth1）所屬的路由能被送出去：
            ```
            route-map EXPORT permit 10
            match interface eth1
            route-map EXPORT deny 100

            router bgp 65000
            address-family ipv4 unicast
            redistribute connected
            neighbor 10.0.101.200 route-map EXPORT out
            ```
        - 這樣 10.0.100.10/24 雖然是 connected route，也會被過濾掉，只有透過 eth1 連出的 connected route 才會被送給對方。


```bash
interface eth1
 ip address 10.0.101.100/24
```
- 設定 eth1 IP，這是與 BGP 鄰居互連的介面。

---

```bash
route-map EXPORT permit 10
 match interface eth1
```
- 定義 `EXPORT` route-map：允許從 `eth1` 匹配的路由被匯出（對外輸出）。

```bash
route-map EXPORT deny 100
```
- 其餘未匹配的全部拒絕。

```bash
route-map IMPORT permit 10
```
- 匯入時允許所有路由（未設任何 match，表示全通過）。

---

```bash
router bgp 65000
```
- 啟用 BGP，並指定本地 AS 號為 65000。

```bash
 bgp router-id 10.0.100.10
```
- 設定 router-id，此為 BGP 的唯一識別碼，通常設為 loopback 或 eth0 位址。

```bash
 neighbor 10.0.101.200 remote-as 65001
```
- 設定鄰居 IP 與其 AS（此為 eBGP，因 AS 不同）。

```bash
 address-family ipv4 unicast
```
- 啟用 IPv4 unicast address family（用於標準 IP 網路路由）。

```bash
  redistribute connected
```
- 將本地 connected 路由（如 eth0 上的 10.0.100.10）納入 BGP 宣告。

```bash
  neighbor 10.0.101.200 route-map IMPORT in
```
- 套用 `IMPORT` route-map 控制從鄰居接收的路由（此例無條件允許）。

```bash
  neighbor 10.0.101.200 route-map EXPORT out
```
- 套用 `EXPORT` route-map 控制傳送給鄰居的路由。

---

```bash
line vty
```
- 啟用 VTY（虛擬終端）存取，允許遠端登入與 CLI 控管。

---
# 📄 frr-200-r10/frr.conf（AS 65001）

- 與 `frr-100-r10` 類似

---
