# FibLimitAssist 项目说明文档

> 半自动斐波那契限价下单辅助 EA（MT5 / MQL5）
>
> 本文档与代码同步维护：**凡调整 `FibLimitAssist.mq5` 的功能或逻辑，必须同步更新本文档**，确保二者一致。

---

## 1. 项目定位

- **半自动 EA**：交易方向、行情判断 **完全由人工完成**。
- EA 只负责四件事：
  1. 绘制斐波那契绘图 UI；
  2. 按钮交互；
  3. 风险手数计算；
  4. 下发 `ORDER_LIMIT` 限价挂单。
- **无自动行情识别、无自动开仓。**
- 每张图表附加一个独立 EA 实例，各有一套斐波那契，互不干扰。
- **会话持久化约定**：
  - 会话内（缩放、切换周期）绘图、按钮、数据保持不丢失；
  - **切周期时线条位置按周期记忆**（v1.36）：每个周期独立记住自己的线条位置，切走再切回同周期可恢复上次调整的位置（用临时全局变量实现）；
  - MT5 重启后绘图状态丢失（临时全局变量清空），重新生成默认斐波那契，属可接受范围。

---

## 2. 文件清单

| 文件 | 说明 |
|------|------|
| `FibLimitAssist.mq5` | EA 源代码 |
| `FibLimitAssist项目说明文档.md` | 本文档（与代码同步维护） |
| `readme.txt` | 原始需求规格（源头） |

---

## 3. 斐波那契结构与方向

### 3.1 方向定义

| 模式 | 起点 | 终点 |
|------|------|------|
| 上涨 | 低点 = `1.00` | 高点 = `0.00` |
| 下跌 | 高点 = `1.00` | 低点 = `0.00` |

方向由 EA **根据 1.00 与 0.00 端点的相对位置自动判定**：
- `price_1.00 < price_0.00` → 上涨；
- `price_1.00 > price_0.00` → 下跌；
- 两者相等 → 方向未定义（禁止下单）。

### 3.2 固定分割比例

```
1.00、0.79、0.49、0.21、0.00   （共 5 条水平价位线）
```

理论比例价位公式（上涨、下跌通用）：

```
price_r = price_1.00 + (1 - r) × (price_0.00 - price_1.00)
```

### 3.3 对象权限

| 对象 | 可拖拽 | 下单按钮 | STEP 按钮 | 说明 |
|------|:---:|:---:|:---:|------|
| `1.00` | ✅ | ❌ | ✅ | 整体端点；拖动时 0.79/0.49 强制回归理论比例 |
| `0.00` | ✅ | ❌ | ✅ | 整体端点；拖动时 0.79/0.49 强制回归理论比例 |
| `0.79` | ✅ | ✅ | ✅ | 可单独拖拽改价位；右侧按钮下单 |
| `0.49` | ✅ | ✅ | ✅ | 可单独拖拽改价位；右侧按钮下单 |
| `0.21` | ❌ | ❌ | ❌ | 仅绘图，无任何交互 |

> **STEP 微调按钮**（v1.17 新增 / v1.72 端点改 Williams 分形跳转）：`1.00` / `0.79` / `0.49` / `0.00` 四条线各有一对 **▲ / ▼** 小按钮（图表左侧，UP 左 / DOWN 右）。`0.79` / `0.49` 内部线单击移动步长 = swing 区间 × `InpStepPercent%`（默认 1%），双击同按钮 300ms 内 = ×10 加速。`1.00`/`0.00` 端点 STEP 与鼠标拖动端点行为对齐（v1.30）：移动端点时 `0.79`/`0.49` 同步按理论比例回归；`0.79`/`0.49` 挂单线 STEP 仅动自身一条线、互相不打扰，且不能跨过对方或顶/底端点，撞界时拒绝移动并 PlaySound 反馈（v1.21 放开端点 STEP 限制）。按钮位置按视觉高/低端自动适配（顶线按钮在线下、底线按钮在线上、中间线按钮中心与线对齐，v1.22）。配色浅灰底黑字（v1.24）。
>
> **v1.72 端点 STEP 改为 Williams 分形跳转**：`1.00` / `0.00` 两条端点线的 ▲/▼ 按钮不再走 `InpStepPercent%` 百分比步长，而是按当前价比较判定上下界后，在图表可见区 `j=1..firstBar` 范围内**跳转到最近一个 Williams 分形**。规则：
> - **上界**（当前价更高的那条）▲ 按钮：找 `K[j].High > K[j±1].High` 且 `K[j].High > 当前上界价` 的最近高分形
> - **上界** ▼ 按钮：找 `K[j].High > K[j±1].High` 且 `K[j].High < 当前上界价` 的最近高分形
> - **下界**（当前价更低的那条）▲ 按钮：找 `K[j].Low < K[j±1].Low` 且 `K[j].Low > 当前下界价` 的最近低分形
> - **下界** ▼ 按钮：找 `K[j].Low < K[j±1].Low` 且 `K[j].Low < 当前下界价` 的最近低分形
> - "最近" = 在 `j=1`（最右已收线）→ `firstBar`（最左可见）方向扫到的第一个匹配，即离 shift=0 时间最近的同向分形
> - 排除 `shift=0` 未收线 bar（Williams 定义需 j+1 存在，j 至少 1）
> - 移动后 0.79/0.49 立即按理论比例回归（复用 `ApplyStepDrag` 行为）
> - 找不到分形 → `Alert` 提示，**端点保持不变**
> - 单/双击行为一致（端点不依赖 `mult`，双击状态仍记录避免与 0.79/0.49 串台）
>
> **端点位置记忆**（v1.36）：`1.00`/`0.00`/`0.79`/`0.49` 位置**按周期记忆**——用临时全局变量（key 含 `_Period`，天然按周期隔离）在切周期时保存、重新加载时恢复。同周期切走再切回，恢复上次调整的位置；首次加载或 MT5 重启后清空时，才按当前可见价格区间重新生成默认 fib。风险档位（`g_riskPercent`）同样会话内持久。历史：v1.15 曾移除端点记忆（每次插入完全重置），v1.36 因用户反馈切周期丢位置而恢复。

> **线条水平方向**：5 条线均为 **OBJ_HLINE 横跨整个图表**，拖拽时只能上下改价（不能左右拉伸，避免与价格拖拽相互干扰）。
>
> **标签位置**：仅保留 `0.21` 一个标签（v1.07 删除了 `1.00`/`0.00` 端点标签，避免与按钮重叠）。像素定位（`OBJ_LABEL`），右边缘统一对齐到右侧按钮列右边缘（`w − 8`，与 0.79/0.49、CALL 按钮右对齐），纵向位置对齐线的价格像素 Y 减 2（位于线的上方）。

> ⚠️ **规格歧义说明**：原始 `readme.txt` 中「对象权限」第 2 条写作 `0.00、0.21：仅绘图，不可拖拽`，与第 1 条（`1.00、0.00` 可拖拽）及「初始化流程」（拖拽 1.00 起点、**0.00 终点**定义区间）矛盾。本实现按 **`0.00` 为可拖拽端点、`0.21` 仅绘图** 解读（第 2 条的 `0.00` 视为笔误）。如需改为「0.00 不可拖拽」，请明确告知。

> **多空切换按钮**（SWAP，v1.26 位置改 / v1.61 改为左对齐）：**水平方向改为左对齐链**——`x = stepBox + 8`（`stepBox` = STEP 按钮列右边缘，即与底部 HIDE 按钮同 X），**垂直放在最上面那根线（`MathMax(price_1.00, price_0.00)`）下方 4px**（不再被线穿过）。点击后对调 `1.00`（起点）与 `0.00`（终点），方向自动翻转，`0.79`/`0.49` 回归理论比例。按钮文字实时显示当前方向（`LONG` / `SHORT` / `FLAT`），底色随方向变化（绿 / 红 / 灰）。**点击后立即自动回弹**（不再 sticky）。v1.61 改左对齐的原因：原居中布局让顶部右侧留白过大，与底部 `HIDE/RISK/FVG` 左列无视觉对齐。
>
> **ADJUST 一键调整按钮**（v1.13 新增 / v1.61 跟随 LONG / **v1.68 重写为 FVG-based 逻辑**）：水平方向 `x = stepBox + 8 + 80 + 4 = stepBox + 92`，即 LONG 右侧 4px（与底部 RISK 跟随 HIDE 同款模式），垂直同样在线下方 4px。**v1.68 新逻辑**（保留原 v1.13 Williams Fractal 作为回退）：
> 1. 复用现有 `DetectFVG` 在图表可见区扫描当前周期所有 FVG，取 `formTime` 最大的（即最近一个）；其 K2（中间脉冲 K 线）必须已收线（K2 ≥ bar 1）。
> 2. **看涨 FVG → 强制 LONG**：
>    - `g_p1` (1.00) = K2 左侧最近一个 **Williams 低分形**（K[j].Low < K[j-1].Low 且 K[j].Low < K[j+1].Low；扫描从 K2+1 向左到 firstBar，第一个匹配即返回）
>    - `g_p0` (0.00) = K2 → bar 0 范围内 max High（**含实时 K 线**的 tick 最高价）
> 3. **看跌 FVG → 强制 SHORT**（镜像）：
>    - `g_p1` (1.00) = K2 左侧最近一个 **Williams 高分形**
>    - `g_p0` (0.00) = K2 → bar 0 范围内 min Low（含实时 K 线）
> 4. 0.79/0.49 立即回归理论值（与拖动端点行为一致）。
> 5. **失败/回退**：若找不到有效 FVG（弹 Alert "未找到有效 FVG, 回退到 Williams Fractal 逻辑"），或看涨/看跌 FVG 左侧无 Williams 分形（弹 Alert 拒绝），自动回退到 v1.13–v1.67 的 `FindNearestSwing` Williams Fractal 逻辑。
>
> 适用范围：仅当前周期（`InpFVG_HigherTF_Enabled` 高级别 FVG 不参与 ADJUST，避免跨周期 K 线时间错位）。`InpAdjustDepth`/`Deviation`/`Backstep` 三个参数仅在回退路径使用。
>
> **CANCEL 取消挂单按钮**（v1.61 改为跟随 ADJUST）：水平方向 `x = stepBox + 8 + 80 + 4 + 80 + 4 = stepBox + 176`，即 ADJUST 右侧 4px（与底部 FVG 跟随 RISK 同款模式）。原右对齐（`g_btnX = w - 108`）已废弃，顶部三个按钮全部左对齐形成"LONG → ADJUST → CANCEL"链，与底部"HIDE → RISK → FVG"链视觉对齐。

### 3.4 一键清场/保本按钮

| 按钮 | 文字 | 位置 | 作用 |
|------|------|------|------|
| 取消挂单 | `CANCEL` | 最上面那根线的**下方 4px**，**ADJUST 右侧 4px**（v1.61 改为左对齐链第三环，原右对齐 `g_btnX` 废弃） | 一键取消**当前图表品种**的全部挂单（不限魔术号，含手动挂的 LIMIT/STOP/STOP_LIMIT；不含其他品种的挂单） |
| 一键保本（v1.08 新增） | `EVEN` | **v1.65 移到顶部第二排**：X = `stepBox + 8`（与顶部 LONG/SWAP 同 X，形成上下一列），Y = `yBtnTop + UI(22) + UI(4)`（顶部第一排正下方，间距 4px） | 遍历**当前图表品种**的全部持仓：**盈利仓位的 SL 改到入场价**（锁住利润，标准 breakeven）；**亏损仓位的 TP 改到入场价**（价格回到入场即保本离场）。已是入场价的自动跳过。 |
| 平一半 | `CHALF`（v1.08 由 CLOSE HALF 改名） | **v1.65 移到顶部第二排 / v1.67 宽 100→80**：X = `stepBox + 92`（与顶部 ADJUST 同 X），Y 同上。**v1.67 改宽**：CHALF 由 100 缩为 80，与 ADJUST 完全对齐，X 位置恢复 v1.65 的 stepBox+92 | 按手数砍半平掉**当前图表品种**的全部持仓；砍半后 < 品种最小手数则**全平该仓位** |
| 清仓 | `CALL`（v1.08 由 CLOSE ALL 改名） | **v1.65 移到顶部第二排 / v1.67 X 恢复**：X = `stepBox + 176`（与顶部 CANCEL 同 X），Y 同上。CALL 宽度保持 100 与 CANCEL 完全对齐 | 一键平掉**当前图表品种**的全部持仓，**不涉及挂单** |

### 3.5 功能控制按钮（最下面那根线上方）

| 按钮 | 文字 | 位置 | 作用 |
|------|------|------|------|
| 隐藏/显示 | `HIDE` / `SHOW` | **v1.64 回到底部左侧**：X = `stepBox + 8`（STEP 列右 8px，类顶部 LONG 位置），垂直与底部其他按钮同 Y（最下面线上方 4px 即 `yBtn`）。v1.63 顶部方案撤销。 | 切换显示 EA 全部斐波那契线条与挂单/仓位按钮（**HIDE 按钮自身始终显示**；**v1.59 起 FVG 按钮 / FVG 矩形 / FVG 标签独立于 HIDE**，由 FVG 按钮单独控制；波段线 `FLAW_` 也不受 HIDE 影响）。状态会话内有效，MT5 重启/EA 重附后恢复显示。底色浅灰（与 CANCEL 同色，v1.25）；HIDE 态保留橙黄警示。 |
| 风险档位 | `0.5%` / `1%` / `2%` | **v1.64 回到底部 HIDE 右侧**：X = `stepBox + 92`（HIDE 右侧 4px），垂直同底部 Y | 循环切换单笔风险档位：`0.5% → 1% → 2% → 0.5%`。当前档位影响**所有下单动作**（0.79/0.49 挂单、市价单）。会话内持久化。 |
| FVG 切换（v1.45 新增） | `FVG` / `OFF` | **v1.64 回到底部 RISK 右侧**：X = `stepBox + 176`（RISK 右侧 4px），垂直同底部 Y。宽 80。v1.63 顶部方案撤销。 | 切换 FVG 矩形显示（公允价值缺口）：`OFF`=隐藏（按钮文字 OFF、底色橙黄、按下 sticky），`FVG`=显示（上涨浅绿 / 下跌浅红 / 完全填补浅灰；v1.58 起不再区分未填补与部分填补）。**v1.59 起完全独立于 HIDE**——HIDE 主 fib UI 时 FVG 按钮和矩形仍可见，按钮由用户独立控制。 |
| 实时浮盈（v1.08 新增） | `(-1012)` / `(+2564)` 等 | `MARKET` 按钮**左侧**，右对齐文字 | 账户全部持仓的**当前浮动盈亏**合计（含 swap）。盈利 `(+数字)` 绿色，亏损 `(-数字)` 红色，接近 0 显示灰色 `(0)`。每 tick 更新。 |
| 市价下单 | `BUY MKT` / `SELL MKT` / `--` | 水平居中（线的中点），**最下面线上方 4px**（v1.32 固定） | 方向为 `LONG` 时显示 `BUY MKT`（绿），`SHORT` 时显示 `SELL MKT`（红），`FLAT` 时显示 `--`（灰）。止损 = `1.00 价 ± Range×1%`，盈亏比 1:1。 |
| 当日盈亏（v1.08 新增） | `(+2564)` / `(-580)` 等 | `MARKET` 按钮**右侧**，左对齐文字 | 自**切日时区** 00:00 起所有 deals（已平仓 + 当前未平仓浮盈）盈亏合计。切日基准由 `InpDayResetTimezone` 决定（v1.12：默认 `CET_AUTO` = FTMO 布拉格时间，自动判断欧洲夏令时；也可 LOCAL/强制 CET/CEST）。盈利绿、亏损红、接近 0 灰。每 tick 更新。 |
| 突破挂单（v1.31 新增） | `BUY STP` / `SELL STP` / `--`（v1.33 缩短自 `BUY/SELL STOP`） | 水平居中与 MARKET 同中心、**最下面线下方 4px**（v1.32 与 MARKET 关于底线上/下镜像对称） | 点击后下突破挂单 `ORDER_TYPE_BUY_STOP`（LONG）/`SELL_STOP`（SHORT）：入场 = 视觉 topPrice + 1 tick（LONG） / botPrice − 1 tick（SHORT）；SL/TP/手数与 MARKET 共用公式（1:1 盈亏比，无限价时间）。`FLAT` 时显示 `--`（灰，点击无效并弹窗提示）。**STOP 挂单也被 `CANCEL` 一键清除**（v1.32）。 |

- 所有按钮均随区间上下线移动；点击即执行，无二次确认。
- 执行结果通过 `Alert` 弹窗与 `Print` 日志反馈（成功 / 失败数量）。
- ⚠️ `CANCEL` / `CALL` / `CHALF` / `EVEN` 均为**当前图表品种（`_Symbol`）级操作**：只作用于本图表品种的挂单或持仓，**不会影响其他品种**（不限魔术号，含手动单）；点击即执行，无二次确认。
- ℹ️ 与之相对，`MARKET` 两侧的**实时浮盈 / 当日盈亏**数字是**账户级**（遍历全部品种的持仓与已平仓 deals），详见第 3.5 节对应按钮说明。

### 3.6 区间计算

```
Range = |price_1.00 − price_0.00|
止损向外偏移 = Range × 1%   （输入参数 InpSL_OffsetPercent 可调）
```

### 3.7 盈亏比标签（v1.34 新增）

位于**最下面那根线下方 4px**，与 `CALL` 关于底线上/下镜像对称（CALL 在底线上方 26px），由 3 段 `OBJ_LABEL` 右对齐拼接组成：

| 段 | 文本格式 | 颜色 | 含义 |
|----|---------|:---:|------|
| A | `(+1.4)` / `(-0.5)` / `(0.0)` | 绿 / 红 / 灰 | **浮盈占比** = ∑当前浮盈 / ∑止盈金额（可正可负） |
| B | `:3.2)` | 棕 | **风险回报比** = ∑止盈金额 / ∑止损金额（恒正） |
| C | ` 42%` | 灰 | **完成度百分比** = 浮盈占比 × 100，四舍五入 |

**计算口径**：仅扫当前图表 `_Symbol` 的全部持仓（含手续费/库存费），无 TP/SL 时对应项为 0。**每 tick 刷新**（v1.35 接入 OnTick 平时分支，与 PnL 数字同节奏）。

**典型解读**：
- `(+1.4:3.2) 42%` — 浮盈已实现止盈目标的 140%，按当前 TP/SL 距离比回报 3.2 倍，整体进度 42%。
- `(-0.5:3.2) -15%` — 浮亏为当前止盈目标的 50%，整体进度 −15%。

---

## 4. 下单逻辑

### 4.1 限价挂单（0.79 / 0.49 按钮）

点击 `0.79` / `0.49` 右侧按钮 → **直接下发 `ORDER_LIMIT` 限价单，无二次确认弹窗**。

| | 上涨模式（低点 1.00 → 高点 0.00） | 下跌模式（高点 1.00 → 低点 0.00） |
|---|---|---|
| 订单类型 | `ORDER_TYPE_BUY_LIMIT` | `ORDER_TYPE_SELL_LIMIT` |
| 入场价 | 当前 0.79 / 0.49 线价位 | 当前 0.79 / 0.49 线价位 |
| 止损 SL | `price_1.00 − Range × 1%`（点击瞬间 1.00 价） | `price_1.00 + Range × 1%`（点击瞬间 1.00 价） |
| 止盈 TP | 入场 + (入场−SL) × **盈亏比** | 入场 − (SL−入场) × **盈亏比** |
| **0.79 盈亏比** | **3 : 1** | **3 : 1** |
| **0.49 盈亏比** | **1 : 1** | **1 : 1** |
| 最大亏损 | Balance × `g_riskPercent` / 100（RISK 按钮控制） | 同左 |
| 过期时间 | 无（`ORDER_TIME_GTC`） | 无（`ORDER_TIME_GTC`） |

按钮文字格式：`0.79 (0.23)` / `0.49 (0.12)`（保留比例与手数；方向由按钮颜色绿/红区分）。

### 4.2 市价下单（MARKET 按钮）

点击 `BUY MKT` / `SELL MKT` 按钮 → **直接以当前 ASK/BID 市价成交，无二次确认**。

| | 上涨模式（LONG） | 下跌模式（SHORT） |
|---|---|---|
| 订单类型 | `ORDER_TYPE_BUY` | `ORDER_TYPE_SELL` |
| 入场价 | `SymbolInfoDouble(_Symbol, SYMBOL_ASK)` | `SymbolInfoDouble(_Symbol, SYMBOL_BID)` |
| 止损 SL | `price_1.00 − Range × 1%` | `price_1.00 + Range × 1%` |
| 止盈 TP | ASK + (ASK − SL) × 1 | BID − (SL − BID) × 1 |
| 盈亏比 | **1 : 1** | **1 : 1** |
| 最大亏损 | Balance × `g_riskPercent` / 100 | 同左 |

按钮文字：`BUY MKT`（绿，LONG 时）/ `SELL MKT`（红，SHORT 时）/ `--`（灰，FLAT 时点击无效并弹窗提示）。

### 4.3 突破挂单（STOP 按钮，v1.31 新增）

点击 `BUY STP` / `SELL STP` 按钮 → **直接下发突破挂单 `ORDER_TYPE_BUY_STOP` / `SELL_STOP`，无二次确认**。

| | 上涨模式（LONG） | 下跌模式（SHORT） |
|---|---|---|
| 订单类型 | `ORDER_TYPE_BUY_STOP` | `ORDER_TYPE_SELL_STOP` |
| 入场价 | `topPrice + 1 tick`（突破视觉高点挂买入） | `botPrice − 1 tick`（跌破视觉低点挂卖出） |
| 止损 SL | `price_1.00 − Range × 1%` | `price_1.00 + Range × 1%` |
| 止盈 TP | entry + (entry − SL) × 1 | entry − (SL − entry) × 1 |
| 盈亏比 | **1 : 1** | **1 : 1** |
| 最大亏损 | Balance × `g_riskPercent` / 100 | 同左 |
| 过期时间 | 无（`ORDER_TIME_GTC`） | 无（`ORDER_TIME_GTC`） |

按钮文字：`BUY STP`（绿，LONG 时）/ `SELL STP`（红，SHORT 时）/ `--`（灰，FLAT 时点击无效并弹窗提示）。突破挂单也被 `CANCEL` 一键清除（v1.32 扩展过滤条件）。

---

## 5. 手数计算规则

1. 最大允许亏损金额 = `Balance × g_riskPercent / 100`，`g_riskPercent` 由 RISK 按钮循环控制（0.5/1/2%）。
2. 按「入场价 − 止损」价格距离反算理论手数：

   ```
   lot = 亏损金额 × tickSize / (价格距离 × tickValue)
   ```

3. **截断保留 N 位小数（默认 2 位），不四舍五入**：
   - `0.023 → 0.02`，`0.027 → 0.02`。
4. 截断后再向下对齐到品种手数步长（`SYMBOL_VOLUME_STEP`）。
5. 截断后手数 < 品种最小手数（`SYMBOL_VOLUME_MIN`）→ **弹窗提示，拒绝挂单**。
6. 区间极小导致手数异常巨大：**不设硬上限，交由人工把关**。

---

## 6. 线条 / 按钮文字显示

- `0.79`、`0.49` 按钮文字格式（含实时比例与手数，方向由按钮颜色绿/红区分）：

  ```
  上涨：0.79 (0.23)  /  0.49 (0.12)
  下跌：0.79 (0.18)  /  0.49 (0.09)
  ```
- 按钮上的比例数字为**实时实际比例**：拖动 `0.79`/`0.49` 线后，比例按当前价位相对区间实时换算，手数同步重算。

- 括号内为**当前实时计算的手数**；仅展示手数，SL、TP 不在图表显示。
- `1.00`、`0.00`、`0.21` 显示为纯比例文字（`1.00` / `0.00` / `0.21`）。
- **`0.79` / `0.49` 线颜色随方向动态变化**（v1.25）：long → 绿、short → 红、方向未定义 → 灰，与下单按钮底色一致，实时刷新。

---

## 7. 挂单校验与拦截（任意一条不满足 → 弹窗拒绝、不发单）

1. 上涨：入场价 > `0.00` 高点 → 拒绝。
2. 下跌：入场价 < `0.00` 低点 → 拒绝。
3. 平台订单规则校验：买单 SL 必须低于入场价；卖单 SL 必须高于入场价；TP 亦须符合 MT5 价格约束；不合规直接弹窗拒绝。
4. 手数截断后小于品种最小手数 → 拒绝。

> 补充：实际下单时仍以 `OrderSend` 返回码为准，任何平台级拒绝（如挂单价距市价过近等）都会弹窗显示错误码与说明。

---

## 8. 拖拽与状态行为

1. 拖拽整体端点（`1.00` / `0.00`）：`0.79` / `0.49` 强制回归理论比例价位；标签手数实时刷新；**不改动服务器已有挂单**。
2. 单独拖拽 `0.79` / `0.49`：线条、按钮同步移动，标签手数实时刷新；**不改动服务器已有挂单**。
3. 所有拖拽只影响**未来新点击的挂单**；历史挂单完全不变。
4. 用户手动删除 EA 绘制的斐波那契图形：服务器 Limit 挂单保留，人工自行管理。
5. EA 从图表移除：图表绘图、按钮全部清除；服务器挂单保留不变。
6. **STEP ▲/▼ 微调**（v1.17）：只移动目标线并保留其他线当前位置；**端点 STEP**（v1.30）与鼠标拖动行为对齐——移动 `1.00`/`0.00` 时 `0.79`/`0.49` 同步按理论比例回归；`0.79`/`0.49` 撞界拒绝移动并 PlaySound 反馈；**不改动服务器已有挂单**。
7. **ADJUST 一键调整**（v1.13）：把 `1.00`/`0.00` 对齐到最近高低点后，`0.79`/`0.49` 回归理论比例；**不改动服务器已有挂单**。

---

## 9. EA 初始化流程

1. EA 附加到图表 → 生成一套斐波那契绘图对象。
2. 端点/挂单线位置**按周期记忆**（v1.36）：先尝试用临时全局变量恢复上次位置；首次加载或 MT5 重启后清空时，才按**最近 `InpDefaultSpanBars` 根已收盘 K 线的 High/Low** 重新生成默认斐波那契（v1.38，数据驱动）。风险档位（`g_riskPercent`）同样会话内持久（切换周期/缩放保留）。
3. 用户**手动拖拽 `1.00` 起点、`0.00` 终点定义高低区间**（或点 ADJUST 一键对齐最近高低点）。
4. 之后可再拖拽 `0.79`、`0.49`（或点 STEP ▲/▼ 微调）调整入场位置，点按钮下单。

---

## 10. 输入参数

| 参数 | 默认值 | 说明 |
|------|:---:|------|
| `InpSL_OffsetPercent` | 1.0 | 止损向外偏移占区间百分比（%） |
| `InpLotDecimals` | 2 | 手数截断保留的小数位（不四舍五入） |
| `InpMagicNumber` | 20260903 | 订单魔术号 |
| `InpOrderComment` | FibLimitAssist | 订单注释 |
| `InpDayResetTimezone` | `DAY_TZ_CET_AUTO` | 当日盈亏切日时区（v1.12）：`LOCAL`=本机 00:00、`CET_AUTO`=CE(S)T 自动判断夏令时（FTMO 布拉格时间，推荐）、`CET`=强制 GMT+1、`CEST`=强制 GMT+2 |
| `InpAdjustDepth` | 12 | [ADJUST] 分形识别窗口：左右各 N 根 bar（类比 zigzag ExtDepth，v1.13） |
| `InpAdjustDeviation` | 5 | [ADJUST] 候选与前一同向极值最小偏差，单位点（类比 zigzag ExtDeviation，v1.13） |
| `InpAdjustBackstep` | 3 | [ADJUST] 候选最小时间距离，单位 bar（类比 zigzag ExtBackstep，替换紧挨假信号，v1.13） |
| `InpStepPercent` | 1.0 | [STEP] 单击移动步长占 swing 区间百分比（%）；双击同按钮 300ms 内 = ×10（v1.17） |
| `InpUIScale` | 0.0 | [UI] **按钮尺寸**缩放系数（v1.27；v1.28 拆分为尺寸/字号两个；v1.29 修复 Wine 误判）：`0`=按平台智能默认（Wine/mac=1.0，原生 Windows=0.6）；正数=手动覆盖（按钮过大时调小，如 0.5~0.7） |
| `InpFontScale` | 0.0 | [UI] **字号**缩放系数（v1.28 新增，与 `InpUIScale` 解耦）：`0`=按平台智能默认（始终 1.0，字保持清晰）；正数=手动覆盖（如 0.8=字略小） |
| `InpDefaultSpanBars` | 60 | [默认区间]（v1.38）用最近多少根**已收盘** K 线的 High/Low 作为默认斐波那契区间基准（数据驱动，解决切周期 `ChartGetDouble(CHART_PRICE_MAX/MIN)` 返回 0/过窄导致线条挤死/跑出屏）；`0`=恢复旧"图表窗口视图"基准（不推荐） |
| `InpWaveLineEnabled` | true | [波段画线] **总开关**（v1.44 新增，默认开）：`true`=只要检测周期内找到一对有效分型且波段幅度达标就画线；`false`=不画线，并清除已有线。**与 `InpSignalEnabled` 完全独立**——可单独控制画线与提醒。 |
| `InpSignalEnabled` | false | [信号] **总开关**（v1.40，默认关）：`false`=信号提醒模块完全不运行（零开销）；`true`=开启形态识别与提醒 |
| `InpSignalDirection` | `SIG_DIR_BOTH` | [信号] 检测方向：`BOTH`=双向 / `LONG`=仅做多 / `SHORT`=仅做空 |
| `InpSignalTF` | `PERIOD_M5` | [信号] 检测周期（**独立于图表周期**，默认 M5）：EA 挂任何图表都按此固定周期检测形态 |
| `InpSignalBars` | 80 | [信号] 检测回看根数（扫描最近多少根 bar 找形态） |
| `InpSignalMinScore` | 40 | [信号] 最低评分：信号评分低于此值不提醒（0~100） |
| `InpBullMinBars` | 3 | [信号] 波段（上涨/下跌）最少根数 |
| `InpBullMaxBars` | 20 | [信号] 波段最多根数 |
| `InpBullBodyRatio` | 0.6 | [信号] 大实体判定：实体/振幅 ≥ 0.6 才算大实体阳线（做多）/ 大实体阴线（做空） |
| `InpBullMinATR` | 1.0 | [信号] 波段最小涨幅/跌幅（**ATR 倍数**，防噪声、跨周期自适应）：波段幅度 ≥ N×ATR 才算有效波段（替代旧百分比方案） |
| `InpSignalATRPeriod` | 14 | [信号] ATR 计算周期 |
| `InpPullbackDepth` | 0.5 | [信号] 触发回调位（50%）：价格回调/反弹到波段幅度的 50% 位即触发提醒 |
| `InpPullbackMinBars` | 1 | [信号] 回调/反弹段最少根数 |
| `InpPullbackMaxBars` | 25 | [信号] 回调/反弹段最多根数 |

> 单笔风险百分比已迁移到 RISK 按钮（运行时循环切换 0.5/1/2%）。
> 盈亏比已按比例分档（0.79=3:1，0.49=1:1，市价=1:1），不再需要全局参数。

---

## 11. 交易信号提醒（v1.40 新增）

**功能**：识别「强势上涨→弱势回调」（做多）与「强势下跌→弱势反弹」（做空）形态，评分后通过 **PC 弹窗（`Alert()`）** + **手机推送（`SendNotification()`）** 提醒。这是一个**独立的只读提醒服务**，不参与任何下单，总开关 `InpSignalEnabled` 默认关闭。

### 11.1 形态定义

```
做多（强势上涨 → 弱势回调）：
  底分型(3根, 中间最低) → 若干大实体阳线 → 顶分型(3根, 中间最高) → 回调至 50% 位

做空（强势下跌 → 弱势反弹）—— 镜像：
  顶分型(3根, 中间最高) → 若干大实体阴线 → 底分型(3根, 中间最低) → 反弹至 50% 位
```

- **分型**：3 根 K 线构成的极值形态。底分型 = 中间低点 < 两边低点；顶分型 = 中间高点 > 两边高点。
- **强势**：同等涨/跌幅用时更短（根数少、平均每根幅度大）。
- **弱势回调**：回调浅、耗时磨（每根回调幅度远小于波段每根幅度）。
- **波段首末根可非阳线**：底分型中间根与顶分型中间根可以是阴线/阳线，但**中间尽量都是大实体阳线**（`实体/振幅 ≥ InpBullBodyRatio`）。

### 11.2 识别与触发规则

| 规则 | 说明 |
|------|------|
| 结构识别 | **只用已收盘 bar**（`shift≥1`），避免行情重绘导致假信号；顶/底分型须右侧 bar 收盘确认（滞后 1 根） |
| 触发（做多） | 实时价 `BID` **触达** 50% 位（`顶分型价 − 波段幅度 × InpPullbackDepth`） |
| 触发（做空） | 实时价 `ASK` **触达** 50% 位（`底分型价 + 波段幅度 × InpPullbackDepth`） |
| 失效（做多） | 实时价**跌破波段起点**（底分型最低点）→ 信号作废，不再提醒 |
| 失效（做空） | 实时价**反弹突破波段起点**（顶分型最高点）→ 信号作废 |
| 防噪声 | 波段幅度须 ≥ `InpBullMinATR × ATR(14)`（ATR 取 `InpSignalTF` 周期，跨周期自适应） |

### 11.3 评分公式（0~100，加权）

| 维度 | 权重 | 计算逻辑 |
|------|:---:|------|
| 波段强度 | 30% | 平均每根幅度 / ATR（每根走满 1 个 ATR 得满分） |
| 实体质量 | 20% | 波段中间根里大实体（阳/阴）占比 |
| 回调弱势度 | 25% | 回调斜率 / 波段斜率（回调越慢、越浅越弱势，得分越高） |
| 分型确认度 | 15% | 底/顶分型中间超出两侧的幅度（相对 ATR） |
| 形态完整度 | 10% | 波段根数贴近理想值 8（每差 1 根扣 10） |

总分 < `InpSignalMinScore`（默认 40）不提醒。

### 11.4 提醒与去重

- **PC 弹窗**：`Alert()`；**手机推送**：`SendNotification()`。
- **波段去重**：以分型中间那根 bar 的**时间戳**作为波段唯一 ID，做多/做空各维护一个「已提醒 ID」。同一波段只提醒一次；**新波段（新时间戳）立即提醒，不受冷却限制**。
- 提醒文本示例：`[FibLimitAssist] 强势看涨信号 (US100.cash M5) 评分 78/100 | 涨幅 23.0点/9根 | 回调 7.0点/6根`。

### 11.5 手机推送前提

`SendNotification()` 要生效，须在 MT5 里配置：`工具 → 选项 → 通知` → 勾选 **「启用推送通知」** → 填入 **MetaQuotes ID**（手机 MT5 App `设置 → 消息` 里查看），并勾选 **「允许来自本地程序端的通知」**。未配置时仅 PC 弹窗有效，推送静默失败，不影响 EA 运行。

### 11.6 波段高低点画线（v1.43 新增，v1.44 与信号触发解耦）

把「最近一个有效波段」的高低点用一条**趋势线（OBJ_TREND）**连接起来，直观标出当前波段区间。

#### 核心设计：画线与信号触发完全解耦

| 关注点 | 画线（v1.44 起） | 信号提醒（v1.40 起） |
|--------|------------------|----------------------|
| 触发条件 | **只要波段定义成立就画** | 形态 + 触达 50% + 未跌破起点 + 评分 ≥ 阈值 |
| 总开关 | `InpWaveLineEnabled`（默认开） | `InpSignalEnabled`（默认关） |
| 用户动作 | 仅画线，无任何提醒 | Alert 弹窗 + 手机推送 |
| 执行时机 | 每个 tick 由 OnTick 调用 | 每个 tick 由 OnTick 调用 |
| 何时更新 | **波段特征变化**（起止分型 shift/方向/时间 5 量任一改变）才重画 | 波段去重 ID 变化时才再提醒 |

> 设计意图：**波段画线**是「图表辅助」功能，给交易者直观看到当前波段；**信号提醒**是「交易决策辅助」功能，提示交易机会。两者独立运行、各自可控。

#### 波段定义成立的条件（画线逻辑）

`FindLatestWave()` 每 tick 扫描检测周期（`InpSignalTF`）：

1. **找最近一个分型**（顶或底，shift ≥ 2 已收盘确认）作为波段**终点**
2. **往后找最近的相反分型**作为波段**起点**
3. 终点是顶 → 做多波段（底→顶，DIR_UP 绿线）；终点是底 → 做空波段（顶→底，DIR_DOWN 红线）
4. **防噪声门槛**：波段幅度 ≥ `InpBullMinATR × ATR`（与信号模块共用同一 ATR 倍数，跨周期自适应）

不要求：根数限制（默认 3~20 是信号提醒的，画线不限）、价格触达、评分。

#### 画线属性

| 项 | 规则 |
|----|------|
| 颜色 | 上涨 → **绿色**（`CLR_BUY_BG`）；下跌 → **红色**（`CLR_SELL_BG`） |
| 数量 | **只保留最新一个波段**——波段特征变化时先删旧线再画新线 |
| 画线对象 | `OBJ_TREND`（趋势线），线宽 2，非射线、不可选中 |
| HIDE | **不受 HIDE 按钮影响**——波段线用独立前缀 `FLAW_`（不以 `g_prefix` 开头），`ApplyHidden()` 遍历时天然跳过 |
| 清理 | `OnDeinit` 单独 `ObjectDelete(WaveName())`，切周期/移除不残留旧线；`InpWaveLineEnabled=false` 时也会立即清掉旧线 |
| 稳定判断 | 用 `(iStart, iEnd, dir, tStart, tEnd)` 五量去重——同一波段不重复画，避免每 tick 闪烁 |

#### 图表周期 ≠ 检测周期怎么办（关键）

**无需任何处理，天然兼容。** 原因是画线锚点用的是「**绝对时间 + 价格**」这两个**与周期无关**的量：

- 波段检测在 `InpSignalTF`（如 M5）上进行，找到的高/低点本质是两个坐标：`(该 bar 开盘时间的绝对 datetime, 该 bar 的 High/Low 价格)`。
- `iTime()` 返回的是**绝对时间戳**，`iHigh()/iLow()` 返回的是**绝对价格**——同一品种同一时刻只有一个价格，与你在哪个周期看图无关。
- 画线时把这两个 `(时间, 价格)` 坐标直接填进 `OBJ_TREND` 的锚点，MT5 会在**任意图表周期**上把它们精确落到对应的位置。

因此：EA 挂在 M1 / M5 / H1 / H4 / D1 任意图表，只要 `InpSignalTF` 固定为 M5，画出来的波段线永远精确对齐那个 M5 波段的高低点，不会错位。实现细节优化：

1. **锚点居中**：锚点时间取「分型 bar 开盘时间 + 半个检测周期」（`PeriodSeconds(InpSignalTF)/2`），让线端点落在分型 K 线**中央**。
2. **覆盖旧线**：`DrawWaveLine()` 先 `ObjectDelete` 旧线再 `ObjectCreate`（同名对象存在时 `ObjectCreate` 会返回 false，不先删会导致新波段无法覆盖旧线）。

---

## 12. 编译与使用

1. 用 MetaEditor 打开 `FibLimitAssist.mq5`，按 `F7` 编译。
2. 将编译后的 `FibLimitAssist.ex5` 拖到任意图表附加。
3. 拖拽 `1.00` / `0.00` 端点定义高低区间（或点 `ADJUST` 一键对齐图表最近高低点）。
4. （可选）拖拽或点 STEP ▲/▼ 微调 `0.79` / `0.49` 入场位。
5. 点击 `0.79` / `0.49` 右侧按钮下发限价单（盈亏比 0.79=3:1，0.49=1:1）。
6. 点击 `BUY MKT` / `SELL MKT` 按钮下市价单（盈亏比 1:1）。
7. 点击 `BUY STP` / `SELL STP` 按钮下突破挂单（盈亏比 1:1，与 MKT 关于底线下镜像对称）。
8. 顶部按钮（最上面线下方 4px）：`SWAP` 切换多空方向、`ADJUST` 一键对齐最近高低点、`CANCEL` 取消**当前品种**全部挂单（含 LIMIT/STOP/STOP_LIMIT）；底部按钮：风险档位（`0.5%`/`1%`/`2%`）循环切换、`HIDE` 隐藏/显示所有 UI、`BUY MKT`/`SELL MKT` 市价下单（居中，两侧实时盈亏数字）、`EVEN` 一键保本、`CHALF` 平一半、`CALL` 全平（EVEN/CHALF/CALL 均只作用于当前品种）；左侧四条主线各一对 STEP ▲/▼ 微调按钮；底线下 4px 实时显示 3 段盈亏比标签 `(浮盈占比:风险回报比) 完成度%`。

---

## 13. 变更记录

| 版本 | 日期 | 变更内容 |
|------|------|---------|
| 1.00 | 2026-09-03 | 首版：斐波那契绘图 + 限价下单 + 手数截断 + 校验拦截 + 会话持久化 |
| 1.01 | 2026-09-03 | 修复按钮文字截断；0.21 线加深改点划线；拖动后比例/手数实时刷新；新增多空切换 SWAP 按钮 |
| 1.02 | 2026-09-03 | 多空按钮文字简化为 LONG/SHORT/FLAT 并锚定顶部线左对齐；新增「取消所有挂单」「清仓」两个一键清场按钮（右对齐挂上下线） |
| 1.03 | 2026-09-03 | 线条改为向右延伸的水平射线（默认从图表中间到最右，左端可左右拉伸）；CLOSE ALL 按钮移到最下面线上方避免溢出屏幕；1.00/0.00 标签改为线左上方，0.21 标签改为线右上方（靠右对齐），解决左侧文字乱码/截断问题 |
| 1.04 | 2026-09-04 | 线条回退为 OBJ_HLINE 横线（射线版本拖拽时上下左右容易混淆，回退为简单水平线）；三个标签统一改为像素定位右对齐 |
| 1.05 | 2026-09-04 | SWAP 按钮移到 CANCEL 左侧；0.79/0.49 按钮文字格式改为 `0.79 (0.23)`（去掉 BL/SL，靠颜色区分方向）；0.49 盈亏比从 2:1 调整为 1:1；新增 CLOSE HALF（按手数砍半平仓，<最小手数则全平）、RISK 按钮（循环 0.5/1/2% 风险档位）、MARKET 按钮（市价下单 1:1）、HIDE/SHOW 按钮（隐藏/显示所有 EA 组件，自身始终显示）；删除 InpRiskPercent / InpRiskReward 两个 input 参数 |
| 1.06 | 2026-09-04 | 修复 HIDE 按钮无效（OBJ_BUTTON 的 OBJPROP_HIDDEN 在 MT5 无效，改用移出屏幕隐藏按钮，线/标签仍用 HIDDEN）；RISK 按钮文字去掉 `RISK` 前缀（`0.5%`/`1%`/`2%`）；MARKET 按钮加宽至 110 并水平居中到最下面线中点；CLOSE HALF 加宽至 130、CLOSE ALL 加宽至 110 解决文字截断 |
| 1.07 | 2026-09-04 | HIDE 对线条也生效（HLine 改用 `OBJPROP_PRICE=1e20` 移出屏外）；删除 `1.00`/`0.00` 端点标签（与按钮重叠），仅保留 0.21；修复 RISK 档位切换后文字不刷新（CycleRisk 末尾补 RefreshAll）；动作型按钮点击后自动回弹（HIDE 保留 sticky）；SWAP 居中；HIDE/SHOW 配色区分（深灰/橙黄）；RISK 三档配色（0.5% 绿 / 1% 黄 / 2% 红） |
| 1.08 | 2026-09-04 | 0.79/0.49 挂单按钮缩窄至 120；CLOSE HALF→`CHALF`、CLOSE ALL→`CALL`（宽 100）；新增 `EVEN` 一键保本按钮（盈利仓 SL=入场价，亏损仓 TP=入场价）；MARKET 按钮两侧新增实时盈亏数字标签（左=全部持仓浮盈，右=本地 00:00 起当日盈亏；绿(+)/红(-)/灰(0)，每 tick 刷新）；修复编译错误（补上 CLR_PLUS/CLR_MINUS/CLR_PNL_NEUTRAL 颜色宏） |
| 1.09 | 2026-09-04 | 修复 0.79/0.49 挂单按钮未靠右对齐（右边缘统一对齐到 w−8，与 CALL/CANCEL 同列）；SWAP 按钮从区间中点移到**最上面那根线**的中点 |
| 1.10~1.12 | 2026-09-05~06 | ⚠️ 另一台电脑本地迭代，未产生独立提交（内容并入 v1.13 一次推送）。其中 **v1.12** 新增当日盈亏**切日时区** `InpDayResetTimezone`（`LOCAL` / `CET_AUTO` / `CET` / `CEST`，默认 FTMO 布拉格时间，自动判断欧洲夏令时） |
| 1.13 | 2026-09-06 | 新增 **ADJUST** 按钮：一键将 1.00/0.00 调整到图表最近的高低点（移植 zigzag 分形识别），新增参数 `InpAdjustDepth`(12) / `InpAdjustDeviation`(5) / `InpAdjustBackstep`(3)；**0.79 挂单盈亏比 2:1 → 3:1** |
| 1.14 | 2026-09-06 | ⚠️ 无独立提交（版本号跳号 / 被 v1.15 取代），无可考变更 |
| 1.15 | 2026-09-06 | **移除 fib 端点位置记忆**（每次插入完全重新初始化，仅风险档位会话内持久）；对象命名前缀增加 `_Period`，防止 ChartID 复用导致跨周期串扰 |
| 1.16 | 2026-09-06 | 修复 DoAdjust 漏掉 0.79/0.49 回归理论值（端点改了但旧手调值残留导致按钮位置错乱） |
| 1.17 | 2026-09-06 | 1.00/0.79/0.49/0.00 四条线各新增一对 **STEP ▲/▼ 微调按钮**（单击步长 = swing 区间 × `InpStepPercent%`，双击 300ms 内 ×10，跨线禁止） |
| 1.18 | 2026-09-06 | 调整 STEP 按钮布局（1.00 按钮在 1.00 线下方、0.79/0.49 线从按钮中心穿过、0.00 按钮在 0.00 线上方） |
| 1.19 | 2026-09-07 | 修复 STEP 按钮跳动/消失 bug（改用 ApplyStepDrag 只动目标线，不再顺手重置 0.79/0.49 到理论值） |
| 1.20 | 2026-09-07 | 修复 ClampStepMove 撞 fib 边界时瞬移到 0.79/0.49 位置的 bug（改为拒绝移动、保持原价） |
| 1.21 | 2026-09-07 | 放开 1.00/0.00 端点 STEP 限制（用户主动设的边界，可推开挂单线）；撞 fib 边界时 PlaySound 反馈 |
| 1.22 | 2026-09-07 | STEP 按钮位置按**视觉高/低端**判定（long/short 自动适配）；ClampStepMove 改用 topPrice/botPrice 替代 ratio；HIDE/RISK 右移到 STEP 按钮右侧避免 long 时重叠 |
| 1.23 | 2026-09-07 | 修复 long 模式 fib 系数反转导致 0.79 DOWN / 0.49 UP 失灵（按 upperLine/lowerLine 视觉位置自适应） |
| 1.24 | 2026-09-07 | STEP 按钮配色调浅（底色深灰 → 浅灰 `C'200,200,200'`，文字白 → 黑） |
| 1.25 | 2026-09-07 | HIDE 改浅灰底（与 CANCEL 同色）；EVEN/CHALF/CALL 三按钮等距 4px；0.79/0.49 线随方向变色（long 绿 / short 红） |
| 1.26 | 2026-09-07 | SWAP/ADJUST/CANCEL 三按钮统一放到**最上面线下方 4px**，不再被线穿过 |
| 1.27 | 2026-09-07 | 新增 **UI 界面缩放系数** `InpUIScale`（默认 1.0）：统一缩放所有按钮/标签的尺寸、字号与固定像素偏移。解决**远程 Windows 服务器上按钮过大**的问题（Mac/Wine 版正常，远程 RDP 高 DPI 下 EA 固定像素按钮被放大）。用法：服务器上把 `InpUIScale` 调小（如 0.6~0.8）；`0` = 自动按 `TERMINAL_SCREEN_DPI/96` 计算（远程 RDP 可能检测不准，建议手动）。 |
| 1.28 | 2026-09-07 | **拆分尺寸/字号缩放**（关键改进）：① 新增 `InpFontScale` 独立控制字号；② `InpUIScale`/`InpFontScale` 默认值改为 `0` 触发**智能默认**：通过 `TerminalInfoString(TERMINAL_DATA_PATH)` 含 `\` 判断平台 → Windows 默认按钮 0.6 / 字号 1.0（按钮缩小但文字保持清晰可读，彻底解决 v1.27 把字号也缩糊的问题），mac/Wine 默认 1.0/1.0 不变；④ 用户把任一参数改成非 0 正数即可手动覆盖智能默认；⑤ 内部新增 `Font(int)` 缩放辅助函数，8 处 `OBJPROP_FONTSIZE` 改用 `Font()`，尺寸/位置仍用 `UI()`。**部署服务器时无需再手动改参数**，开箱即用。 |
| 1.29 | 2026-09-07 | **修复 Wine 误判**：v1.28 用 `TERMINAL_DATA_PATH` 含 `\` 判 Windows，但 Wine 版（mac）数据路径同样含 `\`，导致 mac 首次加载被误当 Windows 缩放到 0.6。改用 `IsWine()` 双信号检测：① `#import "kernel32.dll"` 的 `GetLogicalDrives()` 探测 Z 盘（Wine 把 Unix 根 `/` 映射为 Z:，原生 Windows 几乎不会分配 Z 盘）；② 兜底（DLL 被禁用时）检测数据目录在 `Program Files`（Wine 便携模式）而非 `AppData`（原生 Windows 标准安装）。修复后：mac/Wine → UI 1.0，原生 Windows → UI 0.6。**同时补上 v1.28 遗漏的 `#property version` 号（1.27 → 1.29）**。 |
| 1.30 | 2026-09-07 | **STEP 按钮对齐鼠标拖动端点行为**：原 v1.19 为避免按钮跳动改成「端点 STEP 不重置 0.79/0.49」，v1.30 用户反馈与鼠标拖动端点不一致。改 `ApplyStepDrag`：命中 `RATIO_100`/`RATIO_000` 时同步 `g_p79/g_p49 = TheoPrice(...)` 重置到理论比例价位；命中 `0.79`/`0.49` 本身仍只动单条线、互相不打扰。与 `ApplyDrag` 端点分支行为统一：端点变 → 中间线成比例回归。 |
| 1.31 | 2026-09-07 | **新增 BUY/SELL STOP 突破挂单按钮**（`STOP`，位置见 3.5）：挂在**视觉 topPrice + 1 tick**（LONG / `BUY STP`）/ **botPrice − 1 tick**（SHORT / `SELL STP`）；SL/TP/手数与 MARKET 共用公式（1:1 盈亏比）；订单类型 `ORDER_TYPE_BUY_STOP` / `ORDER_TYPE_SELL_STOP`，无限价时间（`ORDER_TIME_GTC`）。 |
| 1.32 | 2026-09-07 | **修复 STOP 按钮布局两个问题**：① STOP 抢占 `g_btnX` 致 CALL/CHALF/EVEN/CANCEL/挂单按钮/PnL 标签右链全部错位——回退到 v1.25 的 X（与 MARKET 同中心、不再吃右链）；② STOP/MARKET **关于底线镜像对称**（MARKET 顶边距底线 4px 上方 / STOP 顶边距底线 4px 下方）。同时把 `CancelAllPending` 过滤条件加上 `BUY/SELL STOP`/`STOP_LIMIT`，确保 STOP 挂单也能被一键取消。 |
| 1.33 | 2026-09-07 | **STOP 按钮文字缩短**：`BUY STOP` → `BUY STP`、`SELL STOP` → `SELL STP`（按钮宽度 110 受限，完整 `STOP` 单词会被截断；`STP` 在交易语境下表意明确）。**顺带补上 v1.31/v1.32 漏改的 `#property version` 号**。 |
| 1.34 | 2026-09-07 | **底线下新增盈亏比标签**（位置见 3.7）：由 3 段 `OBJ_LABEL` 组成，右对齐到 CALL 右边缘，与 CALL 关于底线上/下镜像对称（共用 `g_btnX + UI(100)` 右锚点，Y = `botPrice + UI(4)`）。新增 `CalcRatioMetrics` 计算 3 个指标：① 浮盈占比 = ∑浮盈/∑止盈金额；② 风险回报比 = ∑止盈/∑止损金额（恒正）；③ 完成度百分比 = 浮盈占比 × 100。颜色：浮盈占比正→绿、负→红、0→灰；风险回报比始终棕色；完成度始终灰。**bug**：OnTick 平时分支未调 `UpdateRatioLabels`，浮盈金额每 tick 变但比例卡住不动。 |
| 1.35 | 2026-09-07 | **修 v1.34 盈亏比标签刷新节奏 bug**：在 `OnTick` `else` 平时分支（无新柱）追加 `UpdateRatioLabels()`，与 `UpdatePnLDisplay` 同节奏每 tick 刷。性能：每次扫一次 `PositionsTotal()` + 几次 `PositionGetDouble`，对持仓 < 100 的账户几乎零开销。校验：大括号 240/240 ✓，sha256 `bd88a03b...`。 |
| 1.36 | 2026-09-08 | **恢复端点位置记忆（按周期）**：解决「4h 调好位置 → 切 1h → 切回 4h 位置丢失」的问题。新增 `SaveFibPositions()`/`LoadFibPositions()` 用**临时全局变量**（`GlobalVariableTemp`，重启清空）保存 `g_p1/g_p0/g_p79/g_p49`，key 含 `_Period` 天然按周期隔离。`OnDeinit` 保存、`OnInit` 先尝试恢复（无记忆才用可见区间生成默认）。**顺带把风险档位 `risk` 也改用临时变量**，与「会话内持久、重启清空」的文档约定对齐（此前用非临时变量实际跨重启残留）。 |
| 1.38 | 2026-09-08 | **修复切换周期线条挤死/跑出屏**：用户反馈某些周期首次加载后线条全挤在一起（D1）、部分线路跑到图表外（M30/M15/M5/M1）。根因（日志实证）：`OnInit` 用 `ChartGetDouble(0, CHART_PRICE_MAX/MIN, 0)` 生成默认区间，但这是**图表"可视窗口"属性**——切周期瞬间可能返回 `0/0`（D1 触发兜底用 ASK/BID，span 退化到点差 1.95 点，5 线全挤死），或返回过窄/错位区间（M30 等下限线超出屏幕）。修复：① 默认区间改用**最近 `InpDefaultSpanBars`(默认 60) 根已收盘 bar 的 High/Low**（数据驱动，`iHigh`/`iLow`，跳过未收盘 bar）；② 兜底退化为当前价 ±2% 对称区间；③ 加最小 span 保护（`< 10 点`）。**`LoadFibPositions` 同时加强校验**：端点跨度必须 ≥ `max(10 点, 价格×0.2%)`，否则视为旧版异常残留拒绝加载、走默认（防止旧"挤死"位置被记忆还原）。 |
| 1.39 | 2026-09-08 | **移除 kernel32.dll 依赖**（不再需要勾选 Allow DLL imports）：v1.29 用 `#import "kernel32.dll"` 的 `GetLogicalDrives()` 探测 Wine 的 Z: 盘，导致 MT5 在属性/Dependencies 里显示依赖 `kernel32.dll`、需用户手动勾选 `Allow DLL imports`（且账户禁用 DLL 导入时 EA 无法加载）。改为**纯路径判断**（无需 DLL）：`IsWine()` 只看 `TERMINAL_DATA_PATH` —— 数据目录在 `AppData`（原生 Windows 标准安装）→ 非 Wine；数据目录在 `Program Files`（Wine 便携模式，含 mac 打包）→ Wine。修复后：EA 零 DLL 依赖，Dependencies 干净、无需勾选，服务器禁用 DLL 也能加载；mac/Win 缩放检测逻辑不变（mac→UI 1.0，原生 Win→UI 0.6）。 |
| 1.40 | 2026-09-09 | **新增交易信号提醒模块**（见第 11 章）：识别「强势上涨→弱势回调」（做多）/「强势下跌→弱势反弹」（做空）形态 + 5 维评分 + `Alert()` PC 弹窗 + `SendNotification()` 手机推送。核心要点：① 独立只读模块，总开关 `InpSignalEnabled` 默认关，关闭时零开销；② 缠论 3 根分型（底/顶）识别，不复用 ADJUST 的 Williams Fractals（语义不同）；③ 只用已收盘 bar 识别结构，触达/失效用实时价（做多 BID / 做空 ASK）；④ 防噪声用 **ATR 倍数**（`InpBullMinATR`，跨周期自适应，替代旧「占价格 %」方案）；⑤ 防重用**按波段去重**（分型 bar 时间戳作 ID，替代时间冷却，避免误杀相邻新波段）；⑥ 检测周期 `InpSignalTF` 独立于图表周期。新增 13 个 `[信号]` 前缀输入参数。 |
| 1.41 | 2026-09-09 | **修复 v1.40 编译错误**：`SignalATR()` 里 `iATR()` 调用方式错误——MQL5 的 `iATR()` 签名是 `int iATR(string symbol, ENUM_TIMEFRAMES period, int ma_period)`，只接收 **3 个参数**、返回 **indicator handle(int)**，而非 ATR 数值。此前写成 4 参数 `iATR(_Symbol, InpSignalTF, InpSignalATRPeriod, 0)` 且当 double 用，导致 metaeditor 报 `wrong parameters count` 编译失败。改为：`iATR()` 拿 handle → `CopyBuffer(handle,0,0,1,buf)` 取 ATR 值 → `IndicatorRelease()` 释放；shift=0 未完成则取 shift=1，再兜底当前价 0.5%。**另精简 10 条过长的 `#property description`（`description is too long` 警告，不影响编译但清理干净）**。 |
| 1.42 | 2026-09-09 | **修复 HIDE 后线条不停闪现**：根因是 `RefreshAll()` 执行顺序——它先调用 `UpdateLabel`/`UpdateButton` 等把对象**写回可见位置**，最后才 `ApplyHidden()` 移走；而 `UpdateLabel` 的注释声称「`g_hidden` 时跳过」，但该判断**从未实际实现**，导致每次 `RefreshAll`（新 bar、缩放平移、余额变化触发）都经历一次「显示→隐藏」往返，MQL5 的 `ObjectSetDouble` 改价即时生效 → 肉眼闪烁。修复：`RefreshAll()` 开头加**隐藏态早退**——`g_hidden=true` 时只刷新 HIDE 按钮文字 + 重新 `ApplyHidden()` + `ChartRedraw()`，跳过所有定位函数。 |
| 1.43 | 2026-09-09 | **信号波段画线标记**（见 11.6）：把检测到的最新波段高低点用**趋势线（OBJ_TREND）**连接起来——上涨（做多）绿色、下跌（做空）红色，只保留最新一个波段。两个关键设计：① **不受 HIDE 影响**——波段线用独立对象前缀 `FLAW_`（不以 `g_prefix` 开头），`ApplyHidden()` 遍历时天然跳过，`OnDeinit` 单独清理；② **与图表周期无关**——锚点用「分型 bar 中央的**绝对时间** + **价格**」，即使 `InpSignalTF`（检测周期）≠ 图表周期，线也精确落在真实高低点上。 |
| 1.44 | 2026-09-09 | **波段画线与信号触发完全解耦**（见 11.6）：v1.43 把画线绑在"信号命中"那一刻才画——用户反馈这与需求不符（波段定义成立就应画线，3/4/5 只是提醒条件）。重构：① 新增独立开关 `InpWaveLineEnabled=true`（默认开，与 `InpSignalEnabled` 完全独立）；② 新增 `FindLatestWave()` 函数只判断"波段定义"——找最近一对分型（顶+底，shift≥2 已收盘确认）+ 幅度 ≥ `InpBullMinATR×ATR`，**不**依赖触达/失效/评分；③ 新增 `UpdateWaveLine()` 主入口，每 tick 由 `OnTick` 调用（紧跟 `CheckSignals` 之后），用 `(iStart, iEnd, dir, tStart, tEnd)` 五量去重——同一波段不重画避免闪烁；④ `CheckSignals` 移除 `DrawWaveLine()` 调用，画线统一由 `UpdateWaveLine()` 负责；⑤ `DetectBullSignal`/`DetectBearSignal` 移除波段坐标赋值（统一由 `UpdateWaveLine` 设置）。设计意图：**波段画线是「图表辅助」**（直观标当前波段），**信号提醒是「交易决策辅助」**（提示机会），两者独立运行、各自可控。 |
| 1.52 | 2026-09-12 | **FVG 检测与状态分类修复**：① `DetectFVG` 调用参数顺序搞反（`firstBar`/`lastBar` 传反），guard `firstBarShift < lastBarShift+2` 恒为 true → 一个 FVG 都检测不到；② `ClassifyFVGStatus` 把 `top`（下沿/低价）当上沿、`bot`（上沿/高价）当下沿判定，完全填补条件退化成「低点碰上沿」→ 大量 FVG 被误判 Filled → 因 `ShowFilled=false` 全部隐藏。 |
| 1.53 | 2026-09-12 | **FVG 半透明填充方案**：ARGB alpha（`C'48,r,g,b'`）在部分 MT5 build 上对 `OBJPROP_BGCOLOR` 不生效，改用同色系浅色调做填充（边框深、填充浅）。 |
| 1.54 | 2026-09-12 | **FVG 填充色修复**：根因——`OBJPROP_BGCOLOR` 对 `OBJ_RECTANGLE` **无效**（MT5 的矩形对象填充色由 `OBJPROP_COLOR` 控制，BGCOLOR 是给按钮/编辑框用的）。之前设的 BGCOLOR 被矩形完全忽略，填充色还是跟边框同色（深色）。修复：删除 `FVGStatusFillColor` 函数与 BGCOLOR 调用，`FVGStatusColor` 直接返回浅色调（`_F` 后缀宏），矩形整体变浅不挡价格线。 |
| 1.55 | 2026-09-12 | **波段画线总开关默认改为关**：`InpWaveLineEnabled` 默认值 `true` → `false`。开箱体验改为"不画波段线"，需用户手动在参数里开启。与信号提醒（`InpSignalEnabled` 默认关）对齐——辅助功能默认不干扰主图。 |
| 1.56 | 2026-09-12 | **FVG 完全填补条件方向相关修复**：`ClassifyFVGStatus` 的完全填补条件原本是 `h >= rec.bot && l <= rec.top`（K 线同时覆盖上下沿），但**对看跌 FVG 永远不成立**——价格反弹填补时，K 线整体在区间上方，`low` 永远 > `top`，所以看跌 FVG 一旦被部分填补就**永远卡在 P 状态**，无法升到 F。修复：完全填补改为方向相关——看涨 FVG（DIR_UP）需 `l <= rec.top`（回落穿下沿），看跌 FVG（DIR_DOWN）需 `h >= rec.bot`（反弹穿上沿）。 |
| 1.57 | 2026-09-12 | **FVG 部分填补只画剩余未填补部分**：`FVGRecord` 新增 `fillLevel` 字段（部分填补时记录价格进入缺口的最深处：DIR_UP 取最低 low，DIR_DOWN 取最高 high）。`ClassifyFVGStatus` 在循环里持续更新。绘制时 `UpdateFVGDisplay` 按方向调整矩形上下边界：DIR_UP 底边抬到 `fillLevel`、DIR_DOWN 顶边压到 `fillLevel`，矩形只覆盖真正未填的区间，不再把已填补部分也画成彩色，视觉干扰大幅减少。 |
| 1.58 | 2026-09-12 | **FVG 配色简化**：由 6 色（U绿/U红/P蓝/P橙/F灰 × 边框填充）简化为 3 色（看涨浅绿 / 看跌浅红 / 填补浅灰），不再区分未填补（U）与部分填补（P），只按方向（上涨/下跌）着色。`FVGStatusColor` 仅判断 `dir` + 是否 Filled，逻辑收敛。 |
| 1.59 | 2026-09-12 | **FVG 与 HIDE 完全解耦**：HIDE 按钮不再隐藏 FVG 按钮 / FVG 矩形 / FVG 标签，FVG 显示状态仅由独立的 FVG 按钮控制。改动：① `ApplyHidden` 跳过 `FVG_BTN` 按钮 + `FVG_R_*` 矩形 + `FVG_L_*` 标签（HIDE 不再碰它们）；② `UpdateFVGDisplay` 入口条件由 `(!g_fvgEnabled \|\| g_hidden)` 改为 `(!g_fvgEnabled)`，HIDE 时 FVG 矩形不被删除；③ `UpdateFVGButton` 删除跟随 `g_hidden` 切换 `OBJPROP_HIDDEN` 的两行代码。设计意图：FVG 是"独立于主 fib UI 的辅助图层"，类似 `FLAW_` 波段线的设计——HIDE 只影响斐波那契画线与挂单/仓位按钮，不应波及辅助图层。 |
| 1.60 | 2026-09-12 | **F 状态矩形止于填补 K 线**：之前 F（完全填补）矩形的 X2 也用 `lastBarTime`，延伸到最新 K 线，与"已填补不再存在"的语义冲突。修复：① `FVGRecord` 新增 `fillTime` 字段（`DetectFVG` 初始化为 0）；② `ClassifyFVGStatus` 在 F 状态判定时记录 `fillTime = iTime(_, _, i)`（填补那根 K 线的起点）；③ `UpdateFVGDisplay` 绘制时引入局部变量 `rectEndTime`——U/P 用 `lastBarTime`（延伸至最新 K 线）、F 用 `fillTime`（止于填补 K 线起点）；④ 右上角状态标签的 X 锚点时间也同步改为 `rectEndTime`，与矩形右边界对齐。`fillTime == 0` 时 fallback 到 `lastBarTime`（防御性兜底，正常流程下 `iTime` 不会为 0）。 |
| 1.60 fix | 2026-09-12 | **rectEndTime 作用域 + description 精简**：① v1.60 `rectEndTime` 编译错误修复——原在 `if(show)` 块内声明，但下方 `if(showLbl)` 块也用到，作用域不重叠。提升到 `for` 循环顶部声明；② `#property description too long` × 9 警告修复——MT5 内部对 description 总字符数有限制（约 1024 字节），17 条 description 累计 1551 字符导致从某行起报"too long"。精简到 7 条，累计 405 字符，v1.50-v1.59 的变更记录合并为"详见项目说明文档第 13 章"单行。 |
| 1.61 | 2026-09-12 | **顶部按钮布局重构 — 左对齐链**：原 LONG (SWAP) 居中 `(w-80)/2`，ADJUST 跟随 LONG 右侧 4px，CANCEL 右对齐 `g_btnX = w-108`——顶部右侧留白过大、与底部 HIDE/RISK/FVG 左列无视觉对齐。重构后顶部三个按钮全部左对齐形成"LONG → ADJUST → CANCEL"链，与底部"HIDE → RISK → FVG"链视觉对齐。改动：① `UpdateSwapButton` X = `stepBox + 8`（STEP 列右 8px，类 HIDE 位置）；② `UpdateAdjustButton` X = `stepBox + 92`（LONG 右侧 4px，类 RISK 跟随 HIDE 模式）；③ `UpdateTopButtons` 中 CANCEL X = `stepBox + 176`（ADJUST 右侧 4px，类 FVG 跟随 RISK 模式），原 `g_btnX` 用法废弃。三个函数各自计算 `stepBox`（少量重复，换 RefreshAll 调用顺序无关性）。**STEP 几何宏 `#define STEP_BTN_*` 上移**——`UpdateSwapButton`/`UpdateAdjustButton` 重构后前置引用 STEP 宏，但 MQL5 按文件顺序解析 `#define`（不像 C 预处理器全单元展开），原位置（`CreateStepButton` 之前）在两个函数之后导致 `undeclared identifier` × 8 编译错误。宏定义上移到 `UpdateSwapButton` 之前（line 600-604），原位置保留一行注释指引。 |
| 1.62 | 2026-09-12 | **EVEN/CHALF/CALL 镜像到底部下方**：原布局：最下面线上方右侧（`yBtn`），X 右对齐到 `g_btnX`，三按钮等距 4px 排开。新布局：最下面线下方 4px（与 STOP 同侧 `y + UI(4)`），X 分别对齐顶部 SWAP/ADJUST/CANCEL（`stepBox + 8/92/176`），形成"顶部按钮链 + 镜像仓位按钮 + STOP 居中"三层对称布局——顶部"配置 / 取消"，底部镜像"仓位管理 / 突破"。复用 `UpdateBottomButtons` 顶部已声明的 `stepBox`，无需重复计算。原 `g_btnX` 用法完全废弃。 |
| 1.62 revert | 2026-09-12 | **v1.62 位置错误 — 由 v1.63 修正**：v1.62 把 EVEN/CHALF/CALL 放到 `y + UI(4)`（最下面线下方），实际显示在 K 线下方，与用户意图"放在 SHORT/ADJUST/CANCEL 正下方"不符——"正下方"应为 yBtn（最下面线上方 26px）。用户截图也显示三个红框在 K 线上方（最下面线上方）。**v1.63 修正**：EVEN/CHALF/CALL 改回 yBtn，X 仍与顶部按钮对齐；底部左侧位置释放给 EVEN/CHALF/CALL，原 HIDE/RISK/FVG 同步移到顶部 CANCEL 右侧形成 6 按钮一长链。 |
| 1.63 | 2026-09-12 | **完整对称布局 + HIDE/RISK/FVG 上移顶部**：① EVEN/CHALF/CALL 改回 yBtn（最下面线上方 26px，与 MARKET 同行），X = `stepBox + 8/92/176` 与顶部 SWAP/ADJUST/CANCEL 左右对齐——形成"顶部 6 按钮链 + 底部镜像 3 仓位按钮 + 中间 MARKET/STOP"三层对称；② HIDE/RISK/FVG 从底部左侧移到顶部 CANCEL 右侧（X = `xCancel + 100 + 4` / +84 / +84），形成顶部一长链 `LONG → ADJUST → CANCEL → HIDE → RISK → FVG`，释放底部左侧位置；③ `UpdateTopButtons` 增加 HIDE/RISK/FVG 三个 `ObjectSetInteger` 设置；④ `UpdateBottomButtons` 中原 HIDE/RISK/FVG 位置代码删除。 |
| 1.63 revert | 2026-09-12 | **v1.63 验证后用户改回原方案**：顶部 6 按钮一长链 + 底部镜像 3 仓位按钮的实际效果与用户预期不符——用户希望 HIDE/RISK/FVG 留在底部左侧（与 LONG/ADJUST/CANCEL 形成左右镜像），EVEN/CHALF/CALL 维持右侧右对齐。**v1.64 撤销 v1.63**： |
| 1.64 | 2026-09-12 | **撤销 v1.63 — 恢复 v1.61 布局**：① `UpdateTopButtons` 删除 v1.63 新增的 HIDE/RISK/FVG `ObjectSetInteger` 设置（顶部按钮链回到 `LONG → ADJUST → CANCEL` 3 个）；② `UpdateBottomButtons` 恢复 HIDE/RISK/FVG 到左侧 `stepBox + 8/92/176` 位置（与顶部 LONG/ADJUST/CANCEL 左右镜像对齐）；③ EVEN/CHALF/CALL 恢复右侧 `g_btnX` 右对齐（`g_btnX - 100 - 4 - 80 - 4` / `g_btnX - 100 - 4` / `g_btnX`），三按钮等距 4px。视觉布局回到 v1.61 状态。 |
| 1.64 → 1.65 | 2026-09-12 | **用户改回最终方案 — EVEN/CHALF/CALL 顶部第二排**：v1.64 恢复"底部右侧右对齐"后用户再次提出新需求——EVEN/CHALF/CALL 应在顶部第一排（LONG/ADJUST/CANCEL）**正下方第二排**，X 严格对齐顶部三个按钮（`stepBox + 8/92/176`），Y = 第一排 Y + 按钮高 + 4px 间距，形成"LONG/EVEN \| ADJUST/CHALF \| CANCEL/CALL"上下 3×2 对称矩阵。**v1.65 实现**： |
| 1.65 | 2026-09-12 | **EVEN/CHALF/CALL 移到顶部第二排**：① `UpdateTopButtons` 新增三个按钮的 `ObjectSetInteger` 设置——X = `stepBox + 8/92/176`（与顶部 LONG/ADJUST/CANCEL 完全对齐），Y = `yBtn + UI(22) + UI(4)`（第一排 Y + 按钮高 + 4px 间距）；② `UpdateBottomButtons` 删除原 v1.61-v1.64 三个按钮的 `g_btnX` 右对齐定位块；③ 函数注释同步更新（`UpdateBottomButtons` 头部注释的"右侧 EVEN/CHALF/CALL"行删除）。最终布局：顶部 3×2 对称矩阵（LONG/EVEN \| ADJUST/CHALF \| CANCEL/CALL）+ 中间 0.79/0.49 挂单 + 底部左侧 HIDE/RISK/FVG + 底部居中 MARKET/STP。 |
| 1.65 → 1.66 | 2026-09-12 | **用户反馈 CHALF/CALL 重叠**：v1.65 直接复用顶部链 X (stepBox+8/92/176) 看似对齐，实则因 CHALF 宽 100 ≠ ADJUST 宽 80，导致 CHALF 右沿 (`92+100=192`) 与 CALL 左沿 (`176`) 重叠 16px（CHALF 文字被 CALL 边框遮住，视觉上两按钮融为一块）。**v1.66 修复**： |
| 1.66 | 2026-09-12 | **修 v1.65 第二排 CALL X 重叠 bug**：CALL X 从 `stepBox + 176` 改为 `stepBox + 196`，按实际按钮宽度递进 `EVEN(80) + 4 + CHALF(100) + 4 = 196`。三按钮 X 终值：`stepBox + 8/92/196`。EVEN/CHALF 与顶部 LONG/ADJUST 左对齐保持不变；CALL 比 CANCEL 右移 20px（因 CHALF 比 ADJUST 宽 20px），保证 4px 间距。 |
| 1.66 → 1.67 | 2026-09-12 | **用户提出第三种方案 — 让按钮宽度对齐而非 X 偏移**：v1.66 的 X 偏移方案（`stepBox+8/92/196`）虽解决了重叠，但 CALL 相对 CANCEL 右移 20px 视觉上不对称。用户希望直接让第二排按钮宽度等于顶部对应按钮宽度，恢复干净的 `stepBox+8/92/176` 递进，三对按钮左右边缘完全对齐。**v1.67 实现**： |
| 1.67 | 2026-09-12 | **第二排 CHALF 宽 100→80 — 按钮宽度与顶部对齐**：① `CreateActionButton(CloseHalfName(), 100, "CHALF", ...)` 改为 `(CloseHalfName(), 80, "CHALF", ...)`（CHALF 与 ADJUST 同样 80 宽）；② `UpdateTopButtons` 中 CALL X 从 `stepBox+8+80+4+100+4 = 196` 改回 `stepBox+8+80+4+80+4 = 176`（与顶部 CANCEL 同 X）；③ 撤回 v1.66 的 X 偏移方案，顶部两排共 6 按钮形成"宽 80/80/100"两两对齐的 3×2 矩阵。最终 X 终值：`stepBox + 8/92/176`（与 v1.65 一致）；宽度：EVEN(80)=LONG(80) / CHALF(80)=ADJUST(80) / CALL(100)=CANCEL(100)。 |
| 1.68 | 2026-09-12 | **ADJUST 重写为 FVG-based 逻辑**（v1.13 Williams Fractal 退居回退路径）。**新流程**：①复用 `DetectFVG(_Period, firstBar, lastBar)` 在图表可见区扫当前周期 FVG（不含 higherTF），取 `formTime` 最大的（即最近一个）；②按 FVG 方向分两支 — 看涨 FVG 强制 LONG：`g_p1` = K2 左侧最近 Williams 低分形（3-bar 严格定义 `K[j].Low < K[j±1].Low`，扫描 j=K2+1→firstBar 第一个匹配），`g_p0` = K2→bar0 max High（含实时 K 线 tick 价）；看跌 FVG 强制 SHORT：镜像交换（`g_p1`=Williams 高，`g_p0`=K2→bar0 min Low）；③赋值后 `g_p79`/`g_p49` 回归理论值，`RefreshAll()` 重画，Alert 输出 FVG 类型/K2 索引/高低点价格与时间/方向/Range。**回退条件**：找不到有效 FVG（`FindMostRecentFVG_K2` 返回 -1）→ Alert 提示并回退；找到 FVG 但左侧无 Williams 分形 → Alert 拒绝，**不动**。**新增**：`IsWilliamsLow(int j)` / `IsWilliamsHigh(int j)` 严格 3-bar Williams 判定；`FindMostRecentFVG_K2(int &fvgDir)` 找最近 FVG 的 K2 索引；`DoAdjustFVG()` 包装新逻辑返回 bool。`DoAdjust()` 改为先试 FVG 失败回退到原 `FindNearestSwing` body。 |
| 1.69 | 2026-09-13 | **ADJUST FVG 检测修复 — 跳过未成熟 FVG**。v1.68 的 `FindMostRecentFVG_K2` 只取 `formTime` 最大的单个 FVG：若该 FVG 的 K3 是当前未收线 K 线（shift=0），`iBarShift` 返回 0 触发 `k3Shift < 1` 直接 `return -1`，即使图表上往左还有多个已收线的成熟 FVG 也不会使用。**v1.69 修复**：改为按 `formTime` 降序逐个尝试，用 `tried[]` 标记已试 FVG，跳过 K3 未收线（`k3Shift < 1`）的，返回第一个满足 K2 已收线的成熟 FVG。 |
| 1.70 | 2026-09-13 | **ADJUST FVG 优先级 — 跳过已完全填补 FVG**。v1.69 的 `FindMostRecentFVG_K2` 按 `formTime` 降序逐个尝试时，会选中最近一个即使是 `status=2`（完全填补）的 FVG——这不对，ADJUST 应作用于"还有效"的缺口。**v1.70 修复**：在 K2 已收线判定通过后，**先调 `ClassifyFVGStatus(arr[best], _Period)` 判 status**，若 `status == 2` 则 `continue` 试次近的，最终返回第一个 `status=0` (未填补) 或 `status=1` (部分填补) 的 FVG。若可见区所有 FVG 都已完全填补，函数仍 `return -1`，`DoAdjust` 已在 v1.68 走 Williams Fractal 回退路径，行为自然衔接。`ClassifyFVGStatus` 纯函数无副作用，仅按需调用（每个候选 FVG 调一次到两次，整体 O(N) 仍可接受）。 |
| 1.71 | 2026-09-13 | **FVG 绘制延迟一根 K 线 bug 修复**。用户反馈 K1(shift0) 未收线时，K2/K3/K4 形成的 FVG 不绘制，等 K1 收线后才出现。**根因**：`UpdateFVGDisplay` 算矩形右边界时 `lastBarTime = iTime(_Period, 1)`（最后一根已收线 K 线起点），而 FVG 的 `formTime = iTime(shift 1)`（C3 收线时刻）。当 C3 正好是 shift1 时，**`formTime == lastBarTime`，矩形 X1==X2 零宽，肉眼不可见**——要等下一根 K 线收线、iTime(1) 后移到 K1 起点后才获得非零宽度。`DetectFVG` 其实一直检测到了这条 FVG（`FindMostRecentFVG_K2` 也能用），所以 ADJUST 看似"提前"检测到未画的 FVG——根因是检测（shift 索引）和绘制（X 时间坐标）用了不同坐标系。**v1.71 修复**：把 `lastBarTime` 改为 `iTime(_Period, 0)`（当前正在形成 K 线的起点），fallback 才退回 `iTime(_Period, 1)`。这样 U/P 状态 FVG 的矩形 X2 始终是当前实时 K 线起点，X1(formTime) 严格 < X2，从 C3 收线起就有正常宽度，与 ADJUST 检测时机自然同步。F 状态走 `fillTime` 分支不受影响。 |
| 1.72 | 2026-09-13 | **1.00/0.00 端点 STEP 改为按 Williams 分形跳转**。原 v1.17 端点 STEP 走 `InpStepPercent%` 百分比步长，但用户在 0.79/0.49 拖动后经常需要把端点对齐到真实的高低分形上，按百分比微调 1% 一下一下挪效率低。**v1.72 新逻辑**：①点击端点 STEP 时先按 `MathMax/MathMin(g_p1, g_p0)` 判定当前 ratio 是上界还是下界；②在图表可见区 `j=1..firstBar` 范围内按方向扫 Williams 分形：上界找高分形 (`K[j].High > K[j±1].High`)，下界找低分形 (`K[j].Low < K[j±1].Low`)；③方向匹配 — 上界 ▲ 找 `High > 当前价`、上界 ▼ 找 `High < 当前价`、下界 ▲ 找 `Low > 当前价`、下界 ▼ 找 `Low < 当前价`；④第一个匹配即返回（离 shift=0 时间最近）；⑤命中后 `ApplyStepDrag` 移动端点，0.79/0.49 自动按理论比例回归。**找不到分形 → Alert 提示，端点保持不变**。**0.79/0.49 保持原 `InpStepPercent%` 百分比 + 双击 ×10 行为不变**。**新代码**：`ApplyStepToFractal(double ratio, int dir)`，内含上界/下界分支 + IsWilliamsLow/IsWilliamsHigh 复用；`ApplyStepButton` 在 ratio 为 1.00/0.00 时直接转调新函数。**前向声明**：因 `ApplyStepToFractal` 在文件中靠前（line ~820）而 `IsWilliamsLow/High` 在 v1.68 段（line ~2657）才定义，加了 `bool IsWilliamsLow(int j);` / `bool IsWilliamsHigh(int j);` 两个前向声明。MQL5 支持函数前向声明。`InpStepPercent` 输入参数注释同步更新说明"仅作用于 0.79/0.49"。 |
| 1.73 | 2026-09-13 | **BUY STP / SELL STOP 入场价改为"最新已收线 K 线 ± 1 tick"**。原 v1.31 突破单入场 = 视觉 `MathMax(g_p1, g_p0) ± 1 tick`（即 fib 端点上方/下方 1 tick），与 fib 线条位置强绑定 — 用户把端点拖远后突破单挂得离谱。**v1.73 解耦**：LONG → BUY STOP `entry = iHigh(_Period, 1) + _Point`（最新已收线 K 线最高价上方 1 tick）；SHORT → SELL STOP `entry = iLow(_Period, 1) - _Point`（最新已收线 K 线最低价下方 1 tick）。"最新已收线" = `shift=1`（排除当前正在形成的 `shift=0`）。`PlaceStopOrder` 内 `topPrice`/`botPrice` 局部变量删除（不再需要），加 `iHigh/iLow(1) <= 0` 数据校验拒绝下单。**SL / TP / lot 逻辑完全不变**：SL 仍锚 `g_p1 ± Range × InpSL_OffsetPercent/100`（与 MKT 共用），TP 仍 1:1 盈亏比，lot 仍 `CalcLot`。STOP 按钮 tooltip 同步更新为新描述。`#property version` 1.72 → 1.73。 |
| 1.74 | 2026-09-13 | **MKT + STP 改为横向相邻 4px 整体居中**。原 v1.32-v1.73 是 MARKET 单按钮居中 + STOP 在 MARKET 正下方 `y + UI(4)` 镜像对称（上下排）。**v1.74 改为左右排**：MARKET(110) 在左，STOP(110) 在 MARKET 右边 4px，两者同 Y (`yBtn`)，整对宽度 224 关于图表中心 `w/2` 左右对称。LONG / SHORT 模式统一：STP 永远在 MKT 右边（用户要求两种方向一致）。**配套调整**：MKT 两侧的 P/L 标签 (`PnLLeftName`/`PnLRightName`) 从"贴着 MKT 边缘"改为"贴着 MKT+STP 整对边缘"——`PL_LEFT` X 改为 `pairLeft - 6`（整对左 4px），`PL_RIGHT` X 改为 `stopX + marketW + 6`（整对右 4px），仍然分别右/左对齐。`UpdateBottomButtons` 新增 `pairW = marketW + UI(4) + marketW` 和 `pairLeft = (w - pairW) / 2` 计算。`#property version` 1.73 → 1.74。 |
| 1.75 | 2026-09-13 | **MKT 与 STP 中间新增实时点差标签 "(1.5)"**。用户要求在 sell mkt 与 sell stp 中间（实际两个按钮之间的物理位置）显示当前品种的实时点差，格式 `(1.5)` 带括号。**关键改动**：①新增 `SpreadName()` 对象名 `g_prefix + "SPREAD"`；②新增 `CreateSpreadLabel()` 创建 OBJ_LABEL — 字体 `Font(7)`，颜色 `CLR_PNL_NEUTRAL`（灰，避免抢眼），锚点 `ANCHOR_CENTER_UPPER`；③新增 `UpdateSpreadDisplay()` 每 tick 调用 — 读 `SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)`（单位 points），除以 10 得 pips，`StringFormat("(%.1f)")` 输出；④`UpdateBottomButtons` 中 `gapW` 从 `UI(4)` 扩到 `UI(40)` 以容纳 ~30px 标签宽度，整对宽度 110+40+110=260 关于 `w/2` 左右对称（与 v1.74 的 4px 紧贴冲突，但 4px 无法容纳可读文字，按用户新需求优先）；⑤`spreadX = pairLeft + marketW + gapW/2`（gap 几何中心）；Y 用 `yBtn + UI(4)` 与 P/L 标签同高；⑥`CreateObjects` 新增 `CreateSpreadLabel(SpreadName())`；⑦`RefreshAll` 和 `OnTick` else 分支各新增 `UpdateSpreadDisplay()` 调用；⑧`ApplyHidden` 无需改 — OBJ_LABEL 且以 `g_prefix` 开头自动进入隐藏分支。`#property version` 1.74 → 1.75。 |
| 1.76 | 2026-09-13 | **修 v1.75 编译错误 — `ANCHOR_CENTER_UPPER` undeclared**。v1.75 用了 `ANCHOR_CENTER_UPPER` 锚点（X 居中、Y 顶部），用户 MT5 build 报"undeclared identifier"——该常量在较老的 MT5 版本中不存在（官方文档列出 9 个 ENUM_ANCHOR_POINT，但部分 build 只支持 7 个）。**v1.76 改用 `ANCHOR_CENTER`**（X 和 Y 都居中），这是所有 MT5 build 都支持的常量；同时调整 Y 从 `yBtn + UI(4)`（顶部对齐）改为 `yBtn + UI(11)`（按钮中线，让 ANCHOR_CENTER 把文字放在 22px 按钮的视觉正中）。水平居中效果不变（仍在 gap 几何中心 `spreadX`）。`#property version` 1.75 → 1.76。 |
| 1.77 | 2026-09-13 | **修 v1.75-v1.76 点差标签括号压按钮边缘**。用户反馈 `(1.5)` / `(15.0)` 的左右括号刚好压在 MARKET / STOP 按钮边缘上——v1.75-v1.76 的 gap=UI(40)≈40px 装不下 Font(7) 的 5 字符文字（实际宽度 ~35-45px），括号紧贴按钮边框。**v1.77 把 gap 从 UI(40) 扩到 UI(56)≈56px**：给文字每侧 ~8-10px 余量，视觉清晰不重叠。整对宽度从 260 变成 276（110+56+110），仍关于 `w/2` 居中；spreadX 计算和 P/L 标签位置公式都基于 `pairLeft` / `stopX` 自动适配，不需要改其他坐标。同时把 Y 从 `yBtn + UI(11)` 微调到 `yBtn + UI(9)`，配合 ANCHOR_CENTER 让文字在 22px 按钮高度内视觉更居中（之前 11 偏下）。`#property version` 1.76 → 1.77。 |
| 1.78 | 2026-09-13 | **FVG 标签显隐由输入参数控制，默认关闭**。用户要求把 FVG 矩形右上角小标签（`U·M15` / `P·H1` / `F·M5` 形式）的显隐权交还给用户，而不是默认一直显示。**v1.78 新增 input 参数 `InpFVG_ShowLabel = false`**，放在 `[FVG]` 输入块里（紧跟 `InpFVG_ShowFilled` 之后），注释明确说明"默认关 — 默认只画矩形不画文字"。`UpdateFVGDisplay` 中 `showLbl` 公式从 `show && width>200` 改为 `show && InpFVG_ShowLabel && width>200`——三层过滤：状态可见 + 用户开关 + 窗口宽度兜底。**行为对比**：v1.47-v1.77 是标签始终跟随 FVG 矩形显示（只要窗口够宽），v1.78 起用户必须把 `InpFVG_ShowLabel` 改成 `true` 才显示标签。矩形本身的显隐仍由原来的三个 `InpFVG_ShowUnfilled/Partial/Filled` 控制，与新参数完全独立——可以单独"显示矩形不显示文字"或"显示文字不显示矩形"。`#property version` 1.77 → 1.78。 |
| 1.79 | 2026-09-13 | **装饰线比例由 0.21 改为 0.19**。用户要求把 fib 装饰线的比例从 0.21（标准 fib 0.236 反推的回调位）改成 0.19（更贴近当前交易风格的回测最佳位）。**v1.79 全量重命名 `RATIO_021` → `RATIO_019`**，值 `0.21` → `0.19`；同步更新的位置：①`#define RATIO_019 0.19` 替换 `RATIO_021`；②`CLR_DECO` 注释从"0.21 装饰线"改为"0.19 装饰线"；③`CreateObjects` 中 `CreateHLine(HName(RATIO_019), ...)` 和 `CreateLabelRight(LName(RATIO_019), "0.19", CLR_DECO)`（显示文字也从字面量改）；④`RefreshAll` 中 `UpdateLabel(HName(RATIO_019), ...)` 和 `UpdateLabelRight(LName(RATIO_019), ..., "0.19")`；⑤ADJUST 回退路径日志 `0.21 =` → `0.19 =`；⑥`RatioOfHLine` 拖拽识别注释从"0.21 不可拖拽"改为"0.19 不可拖拽"；⑦ADJUST tooltip 描述从"0.21/0.49/0.79 自动按新 Range 重新计算"改为"0.19/0.49/0.79"。**0.19 线的视觉行为完全等同于原 0.21 线**（dash-dot 样式、CLR_DECO 灰、不可拖拽、不可挂单），只是价位从 `p1 + 0.79*(p0-p1)` 变成 `p1 + 0.81*(p0-p1)`（更靠近 0.00 端点 ~0.02 区间）。`#property version` 1.78 → 1.79。 |
| 1.80 | 2026-09-13 | **0.79 挂单 TP 从 3:1 盈亏比改为 0.19 装饰线位置**。用户要求 0.79 挂单默认止盈不再是"3 倍 SL 距离"那种线性盈亏比，而是锚定到 fib 装饰线的绝对价位（与 v1.79 的 0.19 线位置一致）。**v1.80 重写 `PlaceOrder` 分支**：0.79 → 调用新增的 `PlaceOrderWithAbsoluteTP(r, TheoPrice(RATIO_019, g_p1, g_p0))`；0.49 → 保持 `PlaceOrderWithRR(r, 1.0)` 不变。**新函数 `PlaceOrderWithAbsoluteTP`** 复用 `PlaceOrderWithRR` 的 SL 公式（`g_p1 ± range × InpSL_OffsetPercent%`）和 lot 计算逻辑，仅 TP 改用传入的绝对价位（不再按 RR 倍数计算）。**几何验证**：0.19 线位于 1.00/0.00 区间的另一端（相对 0.79 远离 1.00）——LONG 模式 0.79 入场靠下、TP=0.19 靠上（盈利侧）✓；SHORT 模式 0.79 入场靠上、TP=0.19 靠下（盈利侧）✓。**TP 方向校验**：用户把 0.79 拖过 0.19 线时 TP 不再位于盈利侧，新代码 `if(DIR_UP && tpPrice <= entry)` / `if(DIR_DOWN && tpPrice >= entry)` 会 Alert 拒绝下单，避免发"TP 反向"的挂单。**SL 公式完全不变**（仍锚 `g_p1`，与 MKT/STP 共用）；**0.49 挂单行为完全不变**（仍 1:1 RR）。`#property version` 1.79 → 1.80。 |
| 1.81 | 2026-09-13 | **FVG 右侧新增 FILL 按钮 — 切换填补态 (status=2) 显隐**。用户要求在 FVG 按钮右侧加一个 FILL 按钮，运行时切换"已被填补的 FVG"显示/隐藏。**关键设计**：①输入参数 `InpFVG_ShowFilled` **保留**（默认 `false`），作为主开关；②新按钮控制运行时态 `g_fillShown`（默认 `false`）；③**有效显示 = `InpFVG_ShowFilled && g_fillShown`** ——AND 关系，两者都必须为 true 才显示 status=2 矩形。**改动**：①新增全局 `bool g_fillShown = false`；②新增 `FillButtonName() → "FILL_BTN"`；③新增颜色宏 `CLR_FILL_OFF C'100,100,100'`（浅灰）/ `CLR_FILL_ON C'60,160,200'`（青蓝，与 FVG CLR_FVG_ON 橙黄区分）；④`CreateObjects` 中 `CreateActionButton(FillButtonName(), 80, "OFF", CLR_FILL_OFF, "切换...")` 默认 "OFF" 文字；⑤`UpdateBottomButtons` 中 FILL 按钮 X = `xRisk + UI(80) + UI(4) + UI(80) + UI(4)` = FVG 右侧 4px；⑥新增 `UpdateFillButton()` 函数同步文字/颜色/sticky：`eff = g_fillShown && InpFVG_ShowFilled`，按下=`!eff`；⑦`UpdateFVGDisplay` 中 `show` 公式对 status=2 增加 `&& g_fillShown` 条件（U/P 不受影响）；⑧`ApplyHidden` 排除 `FillButtonName()`（与 FVG 按钮同样独立于 HIDE）；⑨OnChartEvent 新增 `if(sparam == FillButtonName())` 分支 — 翻转 `g_fillShown` → `UpdateFillButton()` + `UpdateFVGDisplay()`；⑩`RefreshAll` 新增 `UpdateFillButton()` 调用。**视觉效果**：默认 FILL 灰底 "OFF"，按下变青蓝 "FILL"；若用户点 ON 但 `InpFVG_ShowFilled=false`，按钮变青蓝但实际不显示矩形（按钮颜色根据 eff 计算——当 InpFVG_ShowFilled=false 时 eff=false，文字仍 "OFF"——视觉提示用户需先开输入参数）。`#property version` 1.80 → 1.81。 |
| 1.82 | 2026-09-13 | **InpFVG_ShowFilled 默认 false → true；EVEN/CHALF/CALL 从顶部第二排移到 0.49 挂单线**。两件事一起做：①**输入参数默认翻转** — `InpFVG_ShowFilled` 从 `false` 改为 `true`，使填补态矩形在 FILL 按钮 ON 时默认能显示（之前用户必须先改输入参数才能用 FILL 按钮看到任何效果）；②**EVEN/CHALF/CALL 重新定位** — 用户要求三个仓位管理按钮移到 0.49 挂单线位置，让挂单线穿过按钮几何中心。**改动**：①输入参数注释同步更新（"默认关" → "默认开 — 主开关"）；②`UpdateTopButtons` 第二排 EVEN/CHALF/CALL 逻辑替换：用 `ChartTimePriceToXY(0, 0, RightAnchor(), LevelPrice(RATIO_049), mx, my)` 获取 0.49 线屏幕 Y，按钮 Y = `my - UI(11)`（UI(11) = UI(22)/2 按钮高的一半，让按钮中心 = 0.49 线屏幕 Y）；③**X 位置完全不变**（仍是 stepBox+8/92+80+4+80+4，CHALF 100px 宽不重叠）；④**g_p49 跟随用户拖动** — 用 `LevelPrice(RATIO_049)`（内部会取用户拖动过的 g_p49，无 g_p49 时取理论值），所以用户拖动 0.49 挂单线时三个按钮同步上下移动。**位置变化**：v1.65-v1.81 EVEN/CHALF/CALL 在顶部第二排（顶部线下方 UI(26) 处）；v1.82 移到 0.49 线高度（chart 中段，距顶部线约 0.49 倍 range）。**新增边界检查**：`if(yBtn49 < 0) yBtn49 = 0` 防止 0.49 线接近图表上沿时按钮 Y 为负。`#property version` 1.81 → 1.82。 |
| 1.83 | 2026-09-13 | **FVG 和 FILL 两个按钮合并为单按钮 3 状态循环**。v1.81 引入的 FILL 按钮让用户必须分别管"主开关按钮 (FVG)"和"填补态按钮 (FILL)"——两个按钮在视觉上挤在一起且语义重叠（都跟 FVG 显示有关）。**v1.83 合并为一个按钮，循环 3 态**：①**FVG 态**（默认）：文字 "FVG"，浅灰底 `CLR_FVG_OFF` — 只显示未/部分填补的 FVG 矩形（绿/红），对应 v1.82 `g_fvgEnabled=true && g_fillShown=false`；②**FILL 态**：文字 "FILL"，青蓝底 `CLR_FILL_ON` — 再叠加显示完全填补的 FVG（灰），对应 `g_fvgEnabled=true && g_fillShown=true`；③**OFF 态**：文字 "OFF"，橙黄底 `CLR_FVG_ON` — 全隐藏，对应 `g_fvgEnabled=false`。**循环顺序**：FVG → FILL → OFF → FVG（点击切换）。**实现细节**：①**状态机**——新增 `int g_fvgState = 0`（0/1/2），替代 v1.81 的 `bool g_fvgEnabled + bool g_fillShown` 双布尔（派生关系：`g_fvgEnabled = (state != 2)`, `g_fillShown = (state == 1)`）；②**新增 `AdvanceFVGState()`** 函数——`g_fvgState = (g_fvgState + 1) % 3; UpdateFVGButton(); UpdateFVGDisplay(); ChartRedraw(0);`；③**删除 `g_fillShown` / `FillButtonName()` / `UpdateFillButton()`** 三个 v1.81 引入的符号；④**重写 `UpdateFVGButton()`**——根据 state 派生文字 + 颜色 + sticky（OFF 态 sticky=true 高亮提示关闭）；⑤**事件处理**——`OnChartEvent` 中 FVG 按钮点击从 `g_fvgEnabled = !g_fvgEnabled; g_fillShown = !g_fillShown;` 改为单行 `AdvanceFVGState()`；⑥**`UpdateFVGDisplay`** 中 status=2 条件从 `g_fillShown` 改为 `(g_fvgState == 1)`；⑦**颜色宏**——`CLR_FILL_OFF` 删除（与 `CLR_FVG_OFF` 重复），保留 `CLR_FILL_ON` 给 FILL 态。**`InpFVG_ShowFilled` 仍保留**（默认 true）——与 `g_fvgState==1` 仍是 AND 关系（state=1 时只有 `InpFVG_ShowFilled=true` 才画 F 矩形）。**按钮位置对调**——v1.82 是 HIDE→RISK→FVG（左到右），v1.83 改为 HIDE→FVG→RISK（FVG 紧贴 HIDE 右侧作为辅助开关，RISK 移到最右）。`UpdateBottomButtons` 中 `xFVG = xHide + UI(80) + UI(4)`，`xRisk = xFVG + UI(80) + UI(4)`。**三按钮宽度统一 80 与 HIDE 一致**（RISK/FVG 原本就是 80，仅位置对调；用户额外要求宽度统一，验证无变化）。`#property version` 1.82 → 1.83。 |
| 1.84 | 2026-09-13 | **0.79 挂单拆成两半仓 — 不同 TP 让利润奔跑**。v1.80 的"0.79 TP=0.19 装饰线"一刀切止盈对趋势行情太保守——价格突破 0.19 线继续走时止盈被吃，剩下的方向无法捕捉。**v1.84 用户要求拆单管理**：①**半仓 1** 保留 v1.80 逻辑 — TP = 0.19 装饰线位置 `TheoPrice(0.19)`，确保部分利润落袋（保守兜底）；②**半仓 2** TP 突破区间 — `tp2 = 2 × tp019 - entry`（沿 0.79→0.19 方向再延伸等距），几何上位于 1.00/0.00 区间**外**很远（LONG 在 0.00 上方 / SHORT 在 0.00 下方），让利润奔跑捕捉大波段。**关键设计**：①**两笔独立挂单**（不是 EA 内部管理）— MT5 终端里直接看到两笔独立 LIMIT 订单，同 entry + 同 SL + 不同 TP + lot 各半，用户可手动平仓/调整任意一笔；②**总风险不变** — 原来 `CalcLot` 算出的 lot 对半拆（每半仓承担一半风险 = `0.5 × riskMoney`），**不是双倍下注**；③**注释区分** — 订单注释加 `(1/2)` `(2/2)` 后缀（`"FibLimitAssist" (14) + " (2/2)" (6) = 20 字符`，MT5 31 字符上限内安全），方便在交易历史里识别两笔；④**lot 校验** — `totalLot < 2 × volMin` 时拒绝下单（每半仓 < volMin 会触发券商最小手数校验），不强行拆；⑤**TP 方向校验** — 两半仓 TP 都必须在 entry 盈利侧（用户把 0.79 拖过 0.19 时会触发 Alert 拒绝）。**改动**：①新增 `PlaceOrder079Split()` 函数，包含区间校验、SL 计算（复用 v1.80 公式 `g_p1 ± range × 1%`）、双 TP 计算、lot 校验和双 `SendLimitOrderEx` 调用；②`PlaceOrder(RATIO_079)` 分支从 `PlaceOrderWithAbsoluteTP` 改为 `PlaceOrder079Split`；③`SendLimitOrder` 改为薄包装（`SendLimitOrderEx(... , InpOrderComment)`），新增 `SendLimitOrderEx` 函数支持自定义注释，所有原 `SendLimitOrder` 调用点不变；④清理死代码 — `PlaceOrderWithAbsoluteTP`（v1.80 引入的 44 行函数，v1.84 拆分后不再被调用）整段删除。**几何示例**（LONG，g_p1=100, g_p0=110）：0.79 入场 = 102.1，半仓 1 TP = 108.1（v1.80 逻辑），半仓 2 TP = **114.1**（远超 0.00=110）。`#property version` 1.83 → 1.84。 |
| 1.85 | 2026-09-13 | **InpUIScale 默认 0 → 1 — 强制按钮按原始尺寸显示**。v1.27 引入 `InpUIScale` 时为了让 Windows 远程服务器用户不被大按钮挡住图表，默认 0 = 按平台智能默认（Mac/Wine=1.0、Windows=0.6 自动缩小到 60%）。**v1.85 用户要求**：所有平台统一按 1:1 原始像素显示，按钮更大、视觉更清晰，**Windows 远程服务器按钮从 60% 放大到 100%**。**改动**：①`input double InpUIScale = 0.0` → `1.0`；②输入参数注释更新为"默认 1=原始尺寸, 0=按平台自动; 正数=强制值"；③保留 v1.27 的"正数=强制"语义不变（用户想再调小仍可手动设 0.6~0.8）。**Mac/Wine/96DPI 屏幕行为不变**（这些平台原本就是 1.0）。**唯一受影响**：Windows 远程服务器/VPS 上按钮变大 ~67%（0.6→1.0），用户需确认按钮不挡图表后保留。`#property version` 1.84 → 1.85。 |
| 1.86 | 2026-09-13 | **新增 0.73 装饰线（青色虚线，不可拖动）**。用户要求在 fib 区间新增一条参考线，比例 0.73（介于 0.79 挂单线和 0.49 之间靠 0.79 一侧上方 0.6 range 处），只做显示用、不可拖动。**关键设计**：①**inline 模式** — 不抽专用函数（`LineCreate0P73/Move0P73/Delete0P73`），完全镜像现有 0.19 装饰线的 inline 写法（`CreateHLine` + `UpdateLabel` + `CreateLabelRight` + `UpdateLabelRight` 四处直接调用），保持代码一致性最低改动；②**颜色区分** — 新增 `CLR_DECO_073 C'100,150,200'`（淡蓝色），与 0.19 的 `CLR_DECO C'115,115,115'`（灰色）一眼可分；样式同为 `STYLE_DASHDOT` 虚点划线、`width=1`、`back=false`（不挡蜡烛）；③**不可拖动** — 与 0.19 同样的设计：`CanMoveHLine`/`OnChartEvent` 都没注册这个对象名的事件，所以用户不能拖动；④**位置跟随** — 每次 `RefreshAll` 都按当前 `g_p1/g_p0` 重算 `TheoPrice(0.73)`，跟随端点移动；⑤**清理** — 复用现有 `ObjectsDeleteAll(0, g_prefix, -1, -1)` 在 `OnDeinit` 自动删除（前缀匹配），无需额外清理代码。**几何位置**（LONG 模式，pL=110, pH=120, range=10）：根据 `TheoPrice(r) = p1 + (1-r) × (p0-p1)` 公式 — 0.73 价位 = `110 + (1-0.73) × 10 = 110 + 0.27 × 10 = 112.7`。**位置顺序**（从低到高）：1.00 (110) → 0.79 挂单位置 (112.1) → **0.73 装饰线 (112.7)** → 0.49 挂单位置 (115.1) → 0.19 装饰线 (118.1) → 0.00 (120)。0.73 在 0.79 **上方 0.6 range**（`0.73 - 0.79 = 0.06 range × 10 = 0.6`），与 0.79 挂单位置不重叠，仅作视觉参考（不参与挂单或 TP 计算）。`#property version` 1.85 → 1.86。 |
| 1.87 | 2026-09-13 | **端点 1.00/0.00 线宽 2 → 1 — 与中线统一宽度**。用户要求上下边界线调整细一些 — 原来 `CreateObjects` 中 1.00/0.00 两条端点线用 `STYLE_SOLID, 2`（粗实线），视觉上比 0.79/0.49 中线（`STYLE_SOLID, 1`）粗一倍，在某些深色背景下显得"压"在图表上、抢镜。**v1.87 改为 width=1**：①`CreateHLine(HName(RATIO_100), g_p1, true, CLR_END, STYLE_SOLID, 2)` → `STYLE_SOLID, 1`；②`CreateHLine(HName(RATIO_000), g_p0, true, CLR_END, STYLE_SOLID, 2)` → `STYLE_SOLID, 1`。**视觉层级**：现在所有"主线"（1.00/0.00/0.79/0.49）统一宽度 1，颜色区分（端点 `CLR_END` 灰 vs 中线 `CLR_FLAT_BG` 动态方向色 DIR_UP=绿/DIR_DOWN=红/DIR_FLAT=灰），装饰线（0.19/0.73）仍是 `STYLE_DASHDOT` 宽 1。**视觉更轻盈**，减少对图表的视觉干扰。**逻辑零变化** — 只是 `OBJPROP_WIDTH` 整数从 2 改成 1，不影响线条位置、可拖动性、对象命名、`OnDeinit` 清理逻辑。`#property version` 1.86 → 1.87。 |
| 1.88 | 2026-09-19 | **InpUIScale 默认 1 → 0 — 恢复平台自动智能默认**。v1.85 把 `InpUIScale` 默认改成 1（强制 1:1 原始像素）后，用户在实际使用中发现 Windows 远程服务器上的按钮虽然变大变清晰，但也更容易挡住图表关键 K 线 / 拖拽端点。**v1.88 用户要求恢复 v1.27 的平台自动智能默认**：①`input double InpUIScale = 1.0` → `0.0`；②输入参数注释更新为"0=按平台自动; 正数=强制值"；③行为恢复 — Windows 远程服务器按钮从 100% 缩小到 60%（v1.27 默认行为），Mac/Wine/96DPI 屏幕保持 1.0 不变。**保留 v1.85 的"正数=强制"语义**不变 — 用户仍可手动设为 1.0（强制原始尺寸）或 0.6~0.8（自定义缩小）。**逻辑零变化** — 只改输入参数默认值，不改 `g_uiScale = (InpUIScale > 0.01) ? InpUIScale : defaultUIScale;` 这一行的逻辑分支结构。`#property version` 1.87 → 1.88。 |
| 1.89 | 2026-09-19 | **取消 Windows=0.6 平台默认 — `defaultUIScale` 统一 1.0**。用户认为 v1.27 引入的"Windows 自动缩小到 0.6"过于激进，长期遮挡感已超过清晰度收益；v1.85→v1.88 反复横跳（1.0↔0.6）说明决策不收敛，决定**取消平台区分**。**v1.89 改动**：①`OnInit` 中 `bool isWindows = !IsWine()` 整行删除（仅此一处使用，已无引用）；②`defaultUIScale = isWindows ? 0.6 : 1.0` → `defaultUIScale = 1.0`（恒为 1.0，不查平台）；③`defaultFontScale = 1.0` 保持不变（字号始终不缩）；④输入参数 `InpUIScale` 默认 0 不变（仍走 `defaultUIScale` 自动默认分支）；⑤"正数=强制值"语义保留 — 用户想再缩回 0.6 仍可手动设 `InpUIScale=0.6`。**结果**：Windows RDP/VPS 用户现在默认看到 v1.85 那种 100% 原始像素的大按钮（更清晰但也更大）；想恢复 v1.27~v1.88 那种 60% 缩小需手动设 `InpUIScale=0.6`。**逻辑简化**：①`g_uiScale` 计算分支不变（仍是 `InpUIScale > 0.01 ? InpUIScale : defaultUIScale`），只是 default 从平台分支改为常量；②`IsWine()` 函数仍保留供其他用途（Wine 检测在其他位置可能用到，删除检测会引入回归风险）。`#property version` 1.88 → 1.89。 |
| 1.90 | 2026-09-19 | **删除信号提醒与波段画线全部代码 — 简化 EA**。v1.40 引入信号提醒（强弱回调形态识别 + 5维评分 + Alert/SendNotification 推送）和 v1.43 引入波段画线（独立前缀 FLAW_ 趋势线），用户在实际使用中发现：①**信号提醒误报率高** — 5维评分门槛 40 分常在震荡市频繁触发，但实际胜率不理想，反而干扰交易节奏；②**波段画线用独立前缀脱离主 UI** — 不被 `ApplyHidden` 隐藏（HIDE 按钮无效），也不被 `ObjectsDeleteAll(g_prefix)` 清理（切周期残留旧线），增加维护负担；③**两个功能相互纠缠** — 信号触发和画线虽 v1.44 起解耦，但共用 Williams 分型/ATR/InpSignalTF 等基础设施，删除一个另一个几乎必然要重构。**v1.90 用户要求彻底移除**，让 EA 回归"fib 限价下单辅助"的本心。**改动清单**：①**14 个输入参数删除**：`InpWaveLineEnabled` + `InpSignalEnabled` + `InpSignalDirection` + `InpSignalTF` + `InpSignalBars` + `InpSignalMinScore` + `InpBullMinBars` + `InpBullMaxBars` + `InpBullBodyRatio` + `InpBullMinATR` + `InpSignalATRPeriod` + `InpPullbackDepth` + `InpPullbackMinBars` + `InpPullbackMaxBars`；②**`enum ENUM_SIGNAL_DIR` 删除**（含 `SIG_DIR_BOTH/LONG/SHORT` 三个常量）；③**13 个函数删除**：`IsBigBullBar` + `IsBigBearBar` + `IsTopFractal` + `IsBottomFractal` + `FindLatestWave` + `SignalATR` + `SignalTFStr` + `ScoreSignal` + `DetectBullSignal` + `DetectBearSignal` + `UpdateWaveLine` + `DrawWaveLine` + `CheckSignals`；④**7 个全局变量删除**：`g_sigLongID` + `g_sigShortID` + `g_waveT1` + `g_waveT2` + `g_waveP1` + `g_waveP2` + `g_waveDir`；⑤**`WaveName()` 函数删除**（独立前缀 `FLAW_` 模式随画线一起下线）；⑥**`OnTick` 调用清理** — 移除 `CheckSignals()` 和 `UpdateWaveLine()` 两行（每 tick 不再跑波形扫描，CPU 占用略降）；⑦**`OnDeinit` 调用清理** — 移除 `ObjectDelete(0, WaveName())`（不再有 `FLAW_` 前缀对象需要单独清）；⑧**`ApplyHidden` 注释更新** — 删除"与波段线 (FLAW_ 独立前缀) 设计意图一致"的旁注（`FLAW_` 已不存在）；⑨**`#property description` 清理** — 删除第 13 行的"v1.40+ 信号提醒"描述符。**关键不变 / 独立性验证**：①**Williams 分形系统完全不受影响** — `InpAdjustDepth` + `InpAdjustDeviation` + `InpAdjustBackstep` + `IsWilliamsLow` + `IsWilliamsHigh` + `BuildSwingCandidates` + `FindNearestSwing` + `FindMostRecentFVG_K2` + `DoAdjustFVG` + `DoAdjust` 全部保留（ADJUST 高低点对齐功能正常），与信号模块用的简单 3 根比较分型完全不同；②**FVG 系统完全不受影响** — `InpFVG_*` + `g_fvgState` + `UpdateFVGDisplay` + `AdvanceFVGState` 全部保留（FVG 矩形 + FILL 按钮 3 态循环正常）；③**UI 缩放完全不受影响** — `InpUIScale` + `InpFontScale` + `g_uiScale` + `g_fontScale` 全部保留（按钮缩放正常）；④**下单系统完全不受影响** — `PlaceOrder*` + `CalcLot` + `SendLimitOrderEx` 等全部保留（LIMIT/MKT/STOP 单 + 0.79 拆两半仓正常）；⑤**`ObjectsDeleteAll(g_prefix)` 主清理机制不变** — 所有 `g_prefix` 对象（FIB 端点线 + 按钮 + FVG 矩形 + 标签）仍按前缀一次性清理，切周期干净。**净行数**：删除约 450 行（输入参数块 + 13 个函数 + 注释），新增约 10 行（v1.90 changelog + 注释微调）。`#property version` 1.89 → 1.90。 |
| 1.91 | 2026-09-19 | **新增信号提醒 + ADJUST 按钮钉在右下角**。v1.90 删完信号后用户发现仍需要一个轻量提醒：**当价格首次回调到区间 0.49 位置时弹窗+日志**（不评分、不推送、只提醒一次），用来辅助 0.49 挂单入场时机判断。同时把**ADJUST 按钮改为钉在图表右下角**（之前随 LONG 同行，被 fib 线和缩放挤压），**原 ADJUST 位置让给新增的 SIGNAL 切换按钮**。**核心算法**：①**价位计算**：`g_pullbackLevel = g_p1 - 0.49 * (g_p1 - g_p0)`（从顶部回撤 49%，与可拖动的 0.49 线解耦 — 即使用户把 0.49 线拖到任何位置也不影响）；②**方向判定**：`Dir()` 函数返回 `DIR_UP`（1.00 在上）→ long 等待价格从上方穿越向下（`prev > level && bid <= level`），`DIR_DOWN`（1.00 在下）→ short 等待价格从下方穿越向上（`prev < level && ask >= level`），`DIR_FLAT` 直接返回；③**"首次"语义**：跨价位那一 tick 报警一次后锁定（`g_pullbackFired = true`），直到下次解锁条件触发；④**解锁条件**：①`g_p1` 或 `g_p0` 与上次记录的 `g_prevP1/P0` 比较，差值 > `_Point` 视为用户拖动了端点线 → 重置状态机（`g_pullbackFired = false`，`g_prevSamplePrice = 0` 强制下一 tick 重新采样）；②用户点 SIGNAL 按钮关闭再开 → `ToggleSignalAlert()` 强制重置。**新增**：①**1 个输入参数**：`input bool InpSignalAlert = false`（默认关）；②**5 个全局变量**：`g_pullbackLevel` + `g_prevSamplePrice` + `g_pullbackFired` + `g_prevP1` + `g_prevP0`；③**5 个新函数**：`SignalName()`（对象名 + `g_prefix + "SIGNAL"`） + `CreateSignalButton()`（80×22 按钮，Tooltip 含用法） + `UpdateSignalButton()`（2态文字 SIGNAL/OFF + 浅绿/深灰色 + sticky 同步）+ `UpdateSignalButtonPosition()`（占原 ADJUST 位置 — LONG 右侧 4px，与 SWAP/CANCEL 同 Y） + `ToggleSignalAlert()`（运行时切换，重置状态机） + `CheckPullbackSignal()`（主入口 — 内部判断 `InpSignalAlert`，关闭时零开销直接 return）；④**1 个新按钮对象**：`g_prefix + "SIGNAL"`（80×22），随 `ObjectsDeleteAll(g_prefix)` 一起清理。**改动**：①**`UpdateAdjustButton` 重写** — 改为读取 `ChartGetInteger(CHART_WIDTH_IN_PIXELS/CHART_HEIGHT_IN_PIXELS)` 取当前像素尺寸，`X = w - UI(80) - UI(4)` / `Y = h - UI(22) - UI(4)`（右下 4px 偏移，按 UI 缩放系数），旧逻辑（依赖 `topPrice` 的 `ChartTimePriceToXY`）删除；②**`OnTick` 新增一行** `CheckPullbackSignal()`（内部判断总开关，关闭时零开销）；③**`RefreshAll` 新增一行** `UpdateSignalButtonPosition()`（同时原有 `UpdateAdjustButton()` 因逻辑重写会自动跟随图表尺寸）；④**`OnChartEvent` 新增 `SignalName()` 点击分支** → `ToggleSignalAlert()`（含 Print 日志）；⑤**`OnInit` 创建按钮块新增一行** `CreateSignalButton()`（紧跟 `CreateAdjustButton()` 之后）；⑥**`#property description` 新增 v1.91 行** 概要说明。**关键不变 / 独立性验证**：①**Williams 分形（ADJUST 按钮）功能不变** — `DoAdjust()` 逻辑未动，只是按钮位置从顶部移到右下角，OnChartEvent 点击分支未动；②**FVG 系统不受影响** — FVG 矩形 + 3 态按钮继续工作；③**UI 缩放正常** — ADJUST 按钮大小仍受 `InpUIScale` 控制（右下偏移用 `UI(4)` 而非常数 4）；④**CHARTEVENT_CHART_CHANGE 已有的 `g_dirty = true` 处理**自动适配 ADJUST 按钮跟随图表尺寸变化（无需新增事件分支）；⑤**报警价位与可拖动 0.49 线完全解耦** — 即使用户拖 0.49 线，报警价位仍按 `g_p1/g_p0` 边界计算（用户原话："0.49 是上下界的0.49，不是指的0.49线，因为0.49线是可以拖动的"）。**关键边界情况**：①**DIR_FLAT 时不报警** — `MathAbs(g_p1 - g_p0) < _Point` 直接 return，避免 DIR_FLAT 状态下无意义报警；②**首 tick 仅采样不评估** — 开关刚开 / 边界刚改完的下一 tick 只记录 `g_prevSamplePrice`，下一 tick 才开始跨价位检测，避免"开关一开就立刻报警"（价格已远在 level 另一侧的场景）；③**1.00/0.00 端点线反向（DIR_UP↔DIR_DOWN）时** — `g_p1` 和 `g_p0` 数值互换都会被 `g_prevP1/P0` 差异检测捕获，重置状态机；④**长 tick 间隔时** — 跨价位可能在多个 tick 内完成（一个 tick 内价格从 level 上方跳到下方），但只要 `g_prevSamplePrice > level && px <= level` 条件满足（即上次采样还在 level 上方，当前已在下方），仍可正确触发。**净行数**：新增约 120 行（5 个函数 + 输入参数 + 注释 + changelog）。`#property version` 1.90 → 1.91。 |
| 1.92 | 2026-09-19 | **修复编译错误 "InpSignalAlert - constant cannot be modified"**。v1.91 直接在 `ToggleSignalAlert()` 里 `InpSignalAlert = !InpSignalAlert`，但 MQL5 规定 `input` 变量是**编译期常量**，运行时赋值会编译报错。**v1.92 修复**：①**拆成两层** — `input bool InpSignalAlert = false`（仅作启动默认值，编译期常量）+ `bool g_signalAlert = false`（运行时变量，按钮切换它）；②**OnInit 初始化** — 加 3 行 `g_signalAlert = InpSignalAlert;` `g_pullbackLevel = ...` `g_prevP1/P0 = g_p1/g_p0`（在 `DetectTimezone()` 之前，此时 `g_p1/g_p0` 还是 0，但首次 OnTick 会因 p1/p0 从 0 变成有效值而触发 `BoundariesChanged` 重置，等价于"启动即干净"）；③**改读运行时变量** — `UpdateSignalButton()` / `ToggleSignalAlert()` / `CheckPullbackSignal()` 全部从 `InpSignalAlert` 改为 `g_signalAlert`（共 5 处）；④**注释同步** — 输入参数注释改为"启动默认开关 (默认关; MQL5 input 不能运行时改, 切换由运行时变量 g_signalAlert 承担, OnInit 时拷贝此值)"，UpdateSignalButton 注释加"读 g_signalAlert 而非 InpSignalAlert: MQL5 input 是编译期常量, 按钮切换改运行时变量"，OnTick 注释改为"内部判断 g_signalAlert"；⑤**#property description 新增 v1.92 行**。**净行数**：新增 8 行（`g_signalAlert` 全局变量声明 + OnInit 3 行初始化 + 注释更新），修改 5 处（`InpSignalAlert` → `g_signalAlert`），删除 0 行。`#property version` 1.91 → 1.92。 |
| 2.00 | 2026-09-20 | **SIGNAL 总开关扩展第四类：盈亏播报**。当 `g_signalAlert=true` 且当前 chart 品种有持仓，服务器时间整 15 分钟（00/15/30/45）推送一条实时盈亏到手机。**发送渠道**：SendNotification（MT5 推送 → 需在工具→选项→通知中配置 MetaQuotes ID）+ Print 日志（双通道）；不弹 Alert 避免每 15 分钟打断。**节流锁** `g_lastPnLReportMin`（上次发送的服务器分钟），同一分钟内多次 OnTick 只发一次；非整 15 分钟时清空锁等下一个边界。**盈亏计算**：profit + swap（持仓期间累计换仓费），佣金在开仓时已扣不重复计入。**多品种支持**：每个 chart 跑一个 EA 实例，仅播报当前 chart 品种。**消息格式**：`"[FibLimitAssist] SYMBOL P&L: ±X.XX USD (N 单)"`。**改动**：新增 `CheckPnLReport()` 函数 + 4 个状态变量（共用 g_signalAlert 总开关）+ OnTick 末尾调用一次。`#property version` 1.99 → 2.00。 |
| 2.05 | 2026-09-22 | **修复 SIGNAL/HIDE 按钮跨周期被重置的 bug**。用户报告"日周期设置好提醒后，切换其他周期又切换回来，提醒按钮复原"。**根因**：`SaveFibPositions()` 只保存 p1/p0/p79/p49 四个价位，没保存 `g_signalAlert` 和 `g_hidden`；切周期时 OnDeinit(REASON_CHARTCHANGE) 调 SaveFibPositions → OnInit 在 LoadFibPositions 后被 InpSignalAlert 默认 false 覆盖 → 按钮复原为 OFF。**修复**：扩展 SaveFibPositions/LoadFibPositions，把 `g_hidden` 和 `g_signalAlert` 用 `GlobalVariableTemp + GlobalVariableSet` 持久化（按 g_prefix 区分，与 fib 端点同样的会话内临时全局变量机制，客户端重启自动清空）；布尔用 0.0/1.0 编码 double。**改动**：SaveFibPositions 末尾 2 行 + LoadFibPositions 末尾 2 行。`#property version` 2.04 → 2.05。 |
| 2.06 | 2026-09-22 | **SIGNAL 三类报警新增手机推送**。用户报告"PC 端配置正常，测试消息可发，alert/experts 日志正常，但 journal 里没看到 notification 相关消息，手机收不到推送"。**根因**：SIGNAL 触发的三类报警（0.49 回调 / 突破上界 g_p0 / 突破下界 g_p1）只用了 `Alert()` + `Print()`，**从未调用 `SendNotification()`** — 整个 EA 只有 `CheckPnLReport`（盈亏播报，v2.00）推过一次，这就是 journal 看不到 notification 的原因。**修复**：在三类报警的 Alert+Print 之后追加 `SendNotification(msg)`，失败时 Print 错误提示（PC 端默认 MetaQuotes ID 与测试消息同 ID，所以推送通道本身没问题 — 是代码根本没调）。**防重复推送**：沿用 fired 锁（`g_pullbackFired`/`g_breakUpFired`/`g_breakDownFired`）— Alert/Print/SendNotification 三通道在同一 if 分支内，fired 一锁全锁，无需新增独立 sent 锁（避免过度设计）。**MT5 SendNotification 限制**：同一消息 5 秒内自动去重，每秒最多 1 条 — 三类报警消息格式不同不会冲突。**改动**：4 处 — CheckPullbackSignal ④⑤⑥ 三处报警后追加 SendNotification（各 2 行）；ToggleSignalAlert 注释更新；全局变量注释更新；版本号 + 描述。无需新增变量，无需持久化。`#property version` 2.05 → 2.06。 |
| 2.07 | 2026-09-22 | **SIGNAL 三类报警措辞改为方向中性（与 LONG/SHORT 无关）**。用户报告"刚刚收到一条推送 价格向上突破上界 g_p0=157.20400（区间底=157.31500），为什么上界比区间底还低？"**根因**：三类报警措辞"上界 g_p0 / 下界 g_p1 / 区间顶 g_p0 / 区间底 g_p1"是 LONG 视角写死的（假设 g_p1<g_p0 即 1.00 在下=low，0.00 在上=high）；SWAP 后变 SHORT（g_p1>g_p0 即 1.00 在上=high，0.00 在下=low），消息里"上界 g_p0"实际是下界、"区间底 g_p1"实际是上界 — 数值反了。**根因更深**：v1.99 设计原意就是"不依赖 Dir 任何方向都报"（见 CheckPullbackSignal 函数头注释），但措辞却用 LONG 视角术语 — 这是 v1.99 留下的措辞漏洞，v2.06 把同样的错措辞一并推送到了手机。**修复**：把"上界 g_p0 / 下界 g_p1 / 区间顶 g_p0 / 区间底 g_p1"统一替换为方向中性的"0.00 端点 / 1.00 端点 / 对端"措辞 — 端点名只与 fib 系数绑定，与 SWAP 后视觉上下无关；"向上突破/向下突破"也改为"向上穿越/向下穿越"（中性描述，不暗示哪边是上哪边是下）；Range 保留（区间宽度与方向无关）。**新消息示例**："`[FibLimitAssist] long 价格首次回调到区间 0.49 位置: 157.21 (1.00 端点=157.315, 0.00 端点=157.204, Range=0.111)`" / "`[FibLimitAssist] 价格向上穿越 0.00 端点 g_p0=157.204 (1.00 端点=157.315, Range=0.111)`" / "`[FibLimitAssist] 价格向下穿越 1.00 端点 g_p1=157.315 (0.00 端点=157.204, Range=0.111)`"。**额外发现的 bug**：原 0.49 回调消息的"`区间顶=g_p1, 底=g_p0`"参数顺序本就是错的（LONG 时 g_p1=low 写"顶"，g_p0=high 写"底"），这次顺带修了（改为"1.00 端点=g_p1, 0.00 端点=g_p0"，与端点名对齐）。**改动**：6 处 — CheckPullbackSignal 函数头注释 2 行（设计意图改写 + v2.07 标注）+ 0.49 回调消息 1 处 + 向上穿越注释+消息 2 处 + 向下穿越注释+消息 2 处。无逻辑变化（阈值比较 `pxBrk > g_p0` / `< g_p1` 完全不动），无新增变量，无持久化。`#property version` 2.06 → 2.07。 |
| 2.08 | 2026-09-22 | **SIGNAL 突破检测阈值改为 max/min(g_p1,g_p0)，措辞改为"突破区间上沿/下沿"**。v2.07 修复了措辞（"端点名"中性化）但**没改检测阈值** — SHORT 模式下 `pxBrk > g_p0` 等于"价格向上穿过下沿"却报"向上穿越 0.00 端点"，阈值语义仍与消息措辞矛盾。用户反馈"不管 long/short，价格高的为上沿，价格低的为下沿，统一为突破区间上沿/下沿"。**修复**：①**检测阈值**从 `g_p0`/`g_p1` 改为 `highEdge=max(g_p1,g_p0)` / `lowEdge=min(g_p1,g_p0)` — "上沿/下沿"按当前数值高低动态判定，不再依赖端点 fib 系数或 SWAP 状态；②**措辞**从"0.00 端点/1.00 端点"改为"区间上沿/区间下沿"（用户指定，比端点名更直观）；③**"穿越"改回"突破"**（用户指定，配合区间沿措辞）；④0.49 回调消息也改用 highEdge/lowEdge 显示两端点（虽然 0.49 回调本身没这个方向问题，但显示的端点信息用"上沿/下沿"更一致）；⑤`g_breakUpFired` 语义从"突破 g_p0"改为"突破 highEdge"，`g_breakDownFired` 类似。**新消息示例**："`[FibLimitAssist] 突破区间上沿, 价格: 157.315 (下沿=157.204, Range=0.111)`" / "`[FibLimitAssist] 突破区间下沿, 价格: 157.204 (上沿=157.315, Range=0.111)`" — 两种模式下消息结构完全相同，只在数值上反映差异。**改动**：8 处 — CheckPullbackSignal 函数头注释 1 处（4 行）+ 0.49 回调消息 1 处（新增 3 个局部变量 highEdge/lowEdge/range + 重排变量声明顺序）+ 向上穿越注释+阈值+消息 3 处（阈值 `g_p0` → `highEdge`，消息"穿越 0.00 端点"→"突破区间上沿"）+ 向下穿越注释+阈值+消息 3 处（阈值 `g_p1` → `lowEdge`，消息"穿越 1.00 端点"→"突破区间下沿"）。`highEdge/lowEdge/range` 在 ⑤ 块前声明为函数体局部变量，⑥ 块直接复用（避免重复计算）。**逻辑改动说明**：v2.06/v2.07 的阈值 `pxBrk > g_p0` 在 SHORT 模式下等效于"价格向上穿过下沿"，**不会被报警**（因为用户是 SHORT 模式期望"破下沿"是反弹信号，不是要报警的"突破"）；改为 `pxBrk > highEdge` 后真正实现了"价格真破上沿才报警"，SHORT 模式下 g_p0=157.204 是下沿，g_p1=157.315 是上沿 → 价格真破 157.315 时才报"突破区间上沿"。这是预期行为变化（与用户期望对齐），不是 bug 修复 — 之前 v2.06/v2.07 在 SHORT 模式下错把"反弹穿过下沿"报为"突破上界"才是 bug。`#property version` 2.07 → 2.08。 |
| 2.09 | 2026-09-22 | **SIGNAL 三类报警消息加上 `_Symbol` 标的品种信息**。用户要求"所有的提醒要带有标的品种信息"，因为多 chart 跑同一 EA 时（用户可能 EURUSD/XAUUSD 各开一个 chart 各挂一个 EA 实例），推送无法区分是哪个品种触发的 — v2.06/v2.07/v2.08 消息前缀都是 `[FibLimitAssist]` 无品种信息，手机端看到推送只能看推送时间推断是哪个 chart 报的，不直观。**修复**：三个 `StringFormat` 都在 `[FibLimitAssist]` 后加 `%s` 传 `_Symbol`，风格与 v2.00 盈亏播报（`[FibLimitAssist] %s P&L: ...`）保持一致。**新消息示例**："`[FibLimitAssist] EURUSD long 价格首次回调到区间 0.49 位置: 1.08765 (区间上沿=1.08912, 下沿=1.08680, Range=0.00232)`" / "`[FibLimitAssist] XAUUSD 突破区间上沿, 价格: 157.315 (下沿=157.204, Range=0.111)`" / "`[FibLimitAssist] XAUUSD 突破区间下沿, 价格: 157.204 (上沿=157.315, Range=0.111)`"。**SendNotification 去重问题**：MT5 同一消息 5 秒内自动去重（每秒最多 1 条），三类报警的消息格式现在按品种区分 — **不同品种**的同类报警不会冲突（因为 `_Symbol` 不同消息字符串不同）；**同品种**的同类报警仍按 fired 锁去重，不会撞 SendNotification 去重。**改动**：4 处 — 0.49 回调 1 行 `StringFormat`（加 `_Symbol` 参数 + 格式串加 `%s`）+ 向上穿越 1 行 + 向下穿越 1 行 + 函数头注释 1 行（v2.09 标注）。**无逻辑变化**，无新增变量，无持久化。`#property version` 2.08 → 2.09。 |
| 2.10 | 2026-09-22 | **盈亏播报消息用"盈/亏"替代 "+/-" 符号**。用户要求"提醒消息 改成 盈 亏 代替 + -"。**原因**：推送中纯符号 `+12.50 USD` 手机端无文字语义，看一眼分不清是盈是亏，用中文"盈/亏"一目了然。**修复**：`CheckPnLReport` 中把 `(netPnl >= 0) ? "+" : ""` 改为 `(netPnl >= 0) ? "盈" : "亏"`，同时用 `MathAbs(netPnl)` 取绝对值显示金额（符号已被"盈/亏"取代，不再需要双重符号）。**注意**：0 视为"盈"（与 `netPnl >= 0` 一致，0 不亏）。**新消息示例**："`[FibLimitAssist] EURUSD P&L: 盈 12.50 USD (2 单)`" / "`[FibLimitAssist] XAUUSD P&L: 亏 5.20 USD (1 单)`" / "`[FibLimitAssist] EURUSD P&L: 盈 0.00 USD (3 单)`"。**改动**：2 处 — `CheckPnLReport` 中 `sign` 变量名改 `status`（语义更准，不再是 sign）+ `StringFormat` 参数调整（`%s%.2f` → `%s %.2f` 加 `MathAbs`）。**无逻辑变化**，无新增变量，无持久化。`#property version` 2.09 → 2.10。 |
| 2.11 | 2026-09-22 | **RISK 按钮循环档位从三档扩展为四档（新增 0.25%）**。用户要求"比例切换 增加一个 0.25%"。原三档（0.5/1/2）循环，新增 0.25 作为最低档（循环顺序 **0.25 → 0.5 → 1 → 2 → 0.25**），方便用户用更小仓位试探行情或长线超轻仓。**修复**：① `g_riskValues` 数组从 `[3]={0.5, 1.0, 2.0}` 扩为 `[4]={0.25, 0.5, 1.0, 2.0}`，`CycleRisk` 函数用 `ArraySize` 自动适配，无需改循环逻辑；② `UpdateRiskButton` 三档配色扩为**四档配色**：新增 `CLR_RISK_VERYLOW` 浅绿 `C'180,220,180'`（0.25% 用），保留原 `CLR_RISK_LOW`/`MID`/`HI`（0.5/1/2%）— 视觉梯度：**浅绿(0.25, 极低风险) → 绿(0.5, 低) → 黄(1, 中) → 红(2, 高)**；③ `UpdateRiskButton` 文本格式化精度 `1` → `2`（`DoubleToString(d, 2)`），因为 0.25 精度 1 显示为 "0.3" 错误；同时增加去尾 "00" 逻辑，0.50 → "0.5"，1.00 → "1"（不出现 "0.50"/"1.00" 这种末尾补零）；④ RISK 按钮 tooltip 文字从 "0.5% → 1% → 2% → 0.5%" 改为 "0.25% → 0.5% → 1% → 2% → 0.25%"；⑤ 注释中 "(0.5/1/2)" 全部改为 "(0.25/0.5/1/2)"；⑥ v2.11 注释标注。**`CycleRisk` 函数体完全不动**（`ArraySize` 自适应），**`CalcLot` 函数体不动**（仍是 `g_riskPercent/100`，与档位数无关）。**无新增变量**（`CLR_RISK_VERYLOW` 是 `#define`），**无持久化改动**（旧 `GlobalVariable "risk"` 仍存旧档位数值，下次 `LoadRisk` 时若无匹配会默认 1.0%，因 MT5 重启或 session 切换后才需要迁移）。`#property version` 2.10 → 2.11。 |

> **版本缺口已回补**：v1.10~v1.44 已全部同步至本文档。其中 v1.10/v1.11/v1.12/v1.14 在 git 中无独立提交（本地迭代后随 v1.13 一次性推送，或被后续版本号跳号），内容以代码注释标注为准。
