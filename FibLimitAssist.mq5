//+------------------------------------------------------------------+
//|                                                 FibLimitAssist.mq5 |
//|                               半自动斐波那契限价下单辅助 EA        |
//|        交易方向 / 行情判断完全人工，EA 只负责绘图 + 按钮 + 下单     |
//+------------------------------------------------------------------+
#property copyright "FibLimitAssist"
#property version   "2.11"
#property description "半自动斐波那契限价下单辅助 (v2.11)"
#property description "拖拽 1.00/0.00 → 0.79/0.49 挂限价单, STEP 微调, MKT/STP 市价与突破单, EVEN/CHALF/CALL 仓位管理"
#property description "盈亏比实时标签 + ADJUST 高低点对齐 + HIDE 一键隐藏 + UI 缩放 (尺寸/字号分离) + Wine 检测修复"
#property description "v1.45+ 新增 FVG 矩形: 看涨浅绿/看跌浅红/填补浅灰, 3 色方案; 选项含可见区扫描/高级别叠加/最小宽度"
#property description "FVG 完全独立于 HIDE; F 状态矩形止于填补 K 线起点; 部分填补只画剩余未填补 (v1.57)"
#property description "v1.50-v1.59 修复详情见项目说明文档第 13 章 (描述符总数受限, 变更记录仅保留概要)"
#property description "v1.61 顶部按钮左对齐链: LONG→ADJUST→CANCEL 类似底部 HIDE→RISK→FVG 链, stepBox+8/92/176 递进"
#property description "v1.74 MKT+STP 横向相邻 4px 整体居中 (替代原 MARKET 居中 + STOP 上下排), LONG/SHORT 统一 STP 在 MKT 右边"
#property description "v1.75 MKT 与 STP 中间新增实时点差标签 (1.5), gap 4px→40px 容纳标签, ANCHOR_CENTER 居中显示"
#property description "v1.77 spread gap 40px→56px (修 v1.75-v1.76 括号压按钮边缘), 整对 110+56+110=276 关于 w/2 居中; Y yBtn+11→yBtn+9 视觉更居中"
#property description "v1.78 FVG 标签显隐由 InpFVG_ShowLabel 控制 (默认 false, 只画矩形不画文字); 保留 width>200 兜底"
#property description "v1.79 装饰线由 0.21 改为 0.19 (RATIO_021 → RATIO_019), 标签/水平线/ADJUST 提示/拖拽识别同步"
#property description "v1.80 0.79 挂单 TP 改为 0.19 装饰线位置 (原 3:1 RR); 新增 PlaceOrderWithAbsoluteTP, SL 公式不变, 加 TP 方向校验 (防 0.79 拖过 0.19)"
#property description "v1.81 FVG 右侧新增 FILL 按钮 (切换 status=2 填补态显隐, 默认 OFF), 与 InpFVG_ShowFilled AND 关系; 新增 g_fillShown 全局, UpdateFillButton 同步文字/颜色"
#property description "v1.82 InpFVG_ShowFilled 默认 false→true (主开关默认开, FILL 按钮仍默认 OFF); EVEN/CHALF/CALL 从顶部第二排移到 0.49 挂单线, X 不变, Y=screenY(0.49)-UI(11) 让线穿按钮中"
#property description "v1.83 FVG/FILL 按钮合并为单按钮 3 状态循环: FVG(只显 U/P) → FILL(再显完全填补) → OFF(全隐藏) → FVG; 删除 g_fillShown/FillButtonName/UpdateFillButton, 新增 g_fvgState 状态机 + AdvanceFVGState; FVG 与 RISK 位置对调 (新顺序 HIDE→FVG→RISK), 三按钮宽 80 与 HIDE 对齐"
#property description "v1.84 0.79 挂单拆成两半仓: 半仓 1 TP=0.19 装饰线 (v1.80 逻辑), 半仓 2 TP=0.79→0.19 距离的 2 倍 (= 2×tp019 - entry); SL 相同, lot 各半 (总风险不变), 两笔独立挂单同 entry 触发"
#property description "v1.85 InpUIScale 默认 0 → 1: 强制按原始尺寸 (1:1 像素) 显示所有按钮/标签, 取消 v1.27 平台自动缩小 (Windows=0.6) 的默认行为; Mac/Wine 不变, Windows 远程服务器按钮变大"
#property description "v1.86 新增 0.73 装饰线 (青色虚线, 不可拖动, 与 0.19 灰色虚线区分): 价格从 0.00 起占区间 73% 处的结构参考线; 用 inline 模式与 0.19 共用 CreateHLine/UpdateLabel/CreateLabelRight/UpdateLabelRight, 不抽专用函数"
#property description "v1.87 端点 1.00/0.00 线宽 2→1: 与 0.79/0.49 中线统一宽度 (STYLE_SOLID width=1), 仅用 CLR_END 灰色 vs CLR_FLAT_BG 动态方向色区分边界与挂单线; 视觉更轻盈, 减少对图表的遮挡"
#property description "v1.88 InpUIScale 默认 1 → 0: 恢复 v1.27 的平台自动智能默认 (Windows=0.6 自动缩小到 60%, Mac/Wine=1.0 原始尺寸); 取消 v1.85 强制 1:1 原始像素, Windows 远程服务器按钮回归较小尺寸"
#property description "v1.89 取消 Windows=0.6 平台默认: defaultUIScale 统一 1.0 (Windows 和 Wine/mac 一律按原始 1:1 像素), 删除 isWindows 平台检测; 用户想再缩回 0.6 可手动设 InpUIScale=0.6; 字号 defaultFontScale 仍为 1.0 不变"
#property description "v1.90 删除信号提醒与波段画线全部代码: 移除 InpWaveLineEnabled/InpSignal*/InpBull*/InpPullback* 等 14 个输入参数 + ENUM_SIGNAL_DIR 枚举 + 13 个函数 (IsBigBullBar/IsBigBearBar/IsTopFractal/IsBottomFractal/FindLatestWave/SignalATR/SignalTFStr/ScoreSignal/DetectBullSignal/DetectBearSignal/UpdateWaveLine/DrawWaveLine/CheckSignals) + 7 个全局变量 (g_sigLongID/g_sigShortID/g_waveT1-2/g_waveP1-2/g_waveDir) + WaveName() 函数 + OnTick/OnDeinit 调用; Williams 分形 (InpAdjust*/IsWilliamsLow/High/BuildSwingCandidates/FindNearestSwing) 与 FVG/UI/下单完全独立, 不受影响"
#property description "v1.91 新增信号提醒 (InpSignalAlert 默认 false): 价位 = 区间顶部回撤 49% (g_p1 - 0.49×Range, 与可拖动 0.49 线解耦); 方向由 Dir() 判定 (long=等价格从上方穿越向下, short=等价格从下方穿越向上); 跨价位瞬间报警一次后锁定, 直到 p1/p0 调整或按钮重开重置; 新增 SIGNAL/OFF 切换按钮 (占用原 ADJUST 位置 — LONG 右侧 4px, 与 SWAP/CANCEL 同 Y); ADJUST 按钮改为钉在图表右下角 (右下 4px 偏移, 跟随周期切换/缩放/拖动端点线自动重新定位, 通过 ChartGetInteger CHART_WIDTH/HEIGHT_IN_PIXELS 实现, CHARTEVENT_CHART_CHANGE 设 g_dirty=true 触发 RefreshAll)"
#property description "v1.92 修复编译错误 'InpSignalAlert constant cannot be modified': MQL5 input 是编译期常量, 运行时不能赋值; 拆成 input InpSignalAlert (启动默认值) + 运行时变量 g_signalAlert (按钮切换); OnInit 把 InpSignalAlert 拷给 g_signalAlert, ToggleSignalAlert/UpdateSignalButton/CheckPullbackSignal 全部改读 g_signalAlert"
#property description "v1.93 修复 SIGNAL 按钮 tooltip 编译错误 (519-520 行): 用户在 MetaEditor 编译时报告 '1未能识别中文字符' 系列错误 + 'UpdateSignalButton() 意外的令牌', 怀疑 MetaEditor 对 4 行连续中文字符串字面量解析异常; 改用局部 string 变量承载多行 tooltip 后再传入 ObjectSetString (与 ADJUST 按钮的 + 拼接形成对照), 保持中文与 · 字符原样"
#property description "v1.94 修复 SIGNAL 按钮第一次点击无视觉反馈的 bug: ToggleSignalAlert 末尾缺少 ChartRedraw(0) 调用, UpdateSignalButton 写入的 TEXT/BGCOLOR/STATE 在 OnChartEvent 返回前不立即生效, 需等下一次 RefreshAll/ChartRedraw 才显示, 导致用户感觉第一次点击没反应 (实际 g_signalAlert 已翻转, 第二次 redraw 才把 SIGNAL 显示出来); 对比 AdvanceFVGState 直接调 ChartRedraw(0), ToggleHide 经 RefreshAll → ChartRedraw(0); 修复方案在 ToggleSignalAlert 末尾加 ChartRedraw(0), 与其他 sticky 按钮同步; 顺便在 CreateSignalButton 中显式设置 OBJPROP_STATE=false + OBJPROP_BGCOLOR=深灰, 与 CreateActionButton 初始化模式一致 (v1.93 仅靠 UpdateSignalButton 派生, 极端情况可能有视觉闪烁)"
#property description "v1.95 调整 SIGNAL 按钮配色: 开(SIGNAL)=红色 C'200,60,60' (警示色, 与 CHALF 橙红 C'230,140,40'/CALL 橙 C'200,120,20' 同一暖色系但更红更醒目), 关(OFF)=灰色 C'120,120,120' (与 CANCEL 按钮一致 — 两个按钮同处顶部第二排, 配色统一视觉不杂乱); 同步修改 CreateSignalButton 初始化 BGCOLOR 和 UpdateSignalButton 三元表达式; 配色方案在 CLAUDE.md/SKILL 中没指定具体 RGB, 我选了红偏暗 (R=200) 而非纯红 clrRed (R=255) 避免太刺眼, 与其他按钮饱和度一致"
#property description "v1.96 按用户要求统一按钮配色: ① SIGNAL 开状态由红 C'200,60,60' 改为黄 C'255,193,7' (直接复用 RISK 1% 的 CLR_RISK_MID, 暖色系提示监控中); ② EVEN/CHALF/CALL 三个仓位管理按钮由 蓝/橙红/橙 全部改为灰 C'120,120,120' (与 CANCEL 一致 — 5 个顶部按钮[CANCEL/CALL/CHALF/EVEN]全灰形成中性背景组, RISK/SIGNAL 用黄高亮突出当前档位/状态); 同步 CreateActionButton 三处 BGCOLOR 参数 + UpdateSignalButton 三元表达式的 SIGNAL 颜色"
#property description "v1.97 缩短仓位按钮文字 + 统一宽度: ① CALL 文字 → 'all', 宽 100→80 (与 EVEN 同宽); ② CHALF 文字 → 'half', 宽 80 不变; 顶部第二排三按钮 (EVEN/half/all) 宽全 80 — 但 X 计算早用 UI(80) 算 (v1.67 已统一), 实际位置不变, 仅 'all' 右沿缩进 20px (stepBox+256 → 比 v1.96 短 20px); g_btnX = w-UI(108) 不动, 仍作挂单列/盈亏比标签右对齐锚点 (该值与 CALL 实际宽度解耦, 因为 v1.65 起 CALL 位置按 stepBox 算而非按图表宽); 同步注释 UpdateButtonX / UpdateTopButtons 中 CALL 宽度的历史说明"
#property description "v1.98 仓位按钮文字全部大写: 'all' → 'ALL', 'half' → 'HALF' (与 CANCEL/EVEN/RISK/HIDE 等其他按钮大小写风格保持一致 — 之前小写是为短文字配窄宽 80 节省视觉空间, 但用户反馈希望与 EVEN 等已有大写按钮对齐, 风格统一); 宽度仍 80 不变; tooltip 中文不受影响"
#property description "v1.99 SIGNAL 总开关扩展: 共用按钮 (g_signalAlert) 现在驱动三类报警: ① 0.49 回调 (DIR 驱动 long/short, BID/ASK 双价探测, 与 v1.91 一致); ② 向上突破上界 g_p0 (任何方向, BID 跨上); ③ 向下突破下界 g_p1 (任何方向, BID 跨下); 新增两个独立的 fired 锁 g_breakUpFired/g_breakDownFired (与 g_pullbackFired 并列, 三类各自锁定, 互不阻塞); 边界 p1/p0 调整 (差异>_Point) 同时重置三个 fired + 强制下一 tick 重新采样 (避免边界刚改完立刻报警); ToggleSignalAlert 切换按钮时三个 fired 全重置; 报价选择: 0.49 回调沿用 DIR 驱动 BID/ASK (与 v1.91 兼容), 突破统一用 BID (保守报价 — BID 突破上界等价于市价已超过, BID 突破下界等价于市价已跌破); tooltip 改用 '①/②/③' 三条说明; g_prevSamplePrice 改为缓存 BID (原来是 DIR 决定, 现统一为 BID — 0.49 回调比较时 short 走 ASK, 偏差 = 点差, 仍能正确捕获跨价位)"
#property description "v2.00 SIGNAL 总开关扩展第四类: 盈亏播报 — 当 g_signalAlert=true 且当前 chart 品种有持仓, 服务器时间整 15 分钟 (00/15/30/45) 推送一条实时盈亏; 发送渠道 SendNotification (MT5 推送 → 手机, 需在工具→选项→通知中配置 MetaQuotes ID) + Print 日志 (双通道); 不弹 Alert 避免每 15 分钟打断; 节流锁 g_lastPnLReportMin (上次发送的服务器分钟), 同一分钟内多次 OnTick 只发一次, 非整 15 分钟时清空; 盈亏 = profit + swap (持仓期间累计换仓费); 多品种支持: 每个 chart 跑一个 EA 实例, 仅播报当前 chart 品种, 不同 chart 自动播报不同品种; 消息格式 '[FibLimitAssist] SYMBOL P&L: ±X.XX USD (N 单)' 简洁一眼可读; 新增 CheckPnLReport() 函数, 在 OnTick 末尾调用 (CheckPullbackSignal 之后)"
#property description "v2.01 HIDE 按钮不再隐藏 ADJUST 按钮: ApplyHidden 的 skip 列表新增 adjBtn (与 fvgBtn 同列) — ADJUST 是钉在右下角的一键调整快捷键, 隐藏时仍需可见; 修改 ApplyHidden 函数加 adjBtn 变量 + if 多加一个 || 条件; 改动 3 行 (1 行声明 + 1 行 skip 条件 + 1 行注释); 不影响 ADJUST 位置跟随 (UpdateAdjustButton 仍在 RefreshAll 显示分支被调, 早退分支未调, 这是 v1.91 设计 — HIDE 时 ADJUST 位置不变)"
#property description "v2.02 修复 HIDE 后切周期 ADJUST/SIGNAL 按钮看不见的 bug: 根因是 RefreshAll 早退分支 (g_hidden=true) 不调 UpdateAdjustButton/UpdateSignalButtonPosition, CreateObjects 创建的 ADJUST/SIGNAL 停在默认 (0,0), 即使 ApplyHidden (v2.01) 跳过了它们, 也仍被其他 UI 遮挡看不见 — 用户报告 '点 HIDE 后切周期, ADJUST 看不见, 即使切回也看不见'。修复方案在早退分支 ApplyHidden() 之前补两行 UpdateAdjustButton() 和 UpdateSignalButtonPosition(), 显式重定位到正常位置。g_hidden 跨周期保留机制未在 SaveFibPositions 中显式实现 (仅 p1/p0/p79/p49 通过 GlobalVariable 持久化), 但 MQL5 全局变量在某些 MT5 切周期流程中可能保留, 这个修复是无害的冗余保护 — g_hidden=false 走显示分支时这两行不会被执行 (在 if 块内); 顺手也修了 SIGNAL 按钮 (同样靠 UpdateSignalButtonPosition 重定位)"
#property description "v2.03 修复 v2.02 残留 bug: 点 HIDE 后切周期, 用户报告 'HIDE 按钮不见了, 在左上角好像有个 FVG 按钮, 不知道 HIDE 是否也挤在一起'。根因更深: v2.02 只补了 ADJUST/SIGNAL 的位置, 但 HIDE/FVG/RISK 三个底部按钮的位置是由 UpdateBottomButtons() 设置的, 而 UpdateHideButton/UpdateFVGButton/UpdateRiskButton 只更新文字/sticky 不改位置。早退分支 (g_hidden=true) 不调 UpdateBottomButtons → CreateObjects 重建后三个按钮挤在 (0,0) 重叠, FVG 露出半截, HIDE 被完全遮挡。第二个问题: ApplyHidden 的 skip 列表漏了 signalBtn, 切周期时 SIGNAL 按钮被移到屏幕外 (XDISTANCE=-10000), 加上 v2.02 的位置问题变成 '完全看不见'。修复: ① 早退分支补 UpdateBottomButtons() — HIDE/FVG/RISK 位置被强制重设到底部按钮行; ② 早退分支补 UpdateRiskButton() — 文字/sticky 与 HIDE/FVG 一致保持; ③ ApplyHidden skip 列表加 signalBtn — SIGNAL 不被移出屏幕; ④ 保留 v2.02 的 UpdateAdjustButton + 新增 UpdateSignalButtonPosition 显式重定位 (信号位置在右下角 UpdateBottomButtons 不管它); ⑤ 注释明确说明 'HIDE/FVG/RISK 由 UpdateBottomButtons 定位, SIGNAL 由 UpdateSignalButtonPosition 定位, ADJUST 由 UpdateAdjustButton 定位'。改动 6 处: ApplyHidden 1 行声明 + 1 行 skip 条件, RefreshAll 早退分支 4 行新增 (UpdateBottomButtons 1 + UpdateRiskButton 1 + UpdateSignalButtonPosition 1 + 注释)"
#property description "v2.04 修复 FVG 矩形不停闪烁的 bug: 根因是 UpdateFVGDisplay() 在 OnTick 中每 tick 都调用 (独立于 g_dirty), 导致: ① DetectFVG 每 tick 重建 FVGRecord 数组, 状态从 0 开始 (跨调用 'F 锁定' 失效); ② 可见区边界 FVG 在 tick 之间反复进出 Detect 集合, 触发 ObjectCreate/ObjectDelete → 视觉闪烁; ③ ClassifyFVGStatus 扫描的是已收线 K 线 (shift>=1), 输入在 K 线内不变, 每 tick 重做无意义。修复: 把 UpdateFVGDisplay() 从 line 3633 移到 if(g_dirty) 块内 (与 RefreshAll 并列), 仅在新柱收线或图表缩放/拖动时触发, 行为不变但消除闪烁。AdvanceFVGState (按钮切换 3 态) 仍然立即重绘; OnInit 启动时仍然重绘一次; 正常运行时只在 g_dirty 时重绘。改动 1 行 (UpdateFVGDisplay 从独立调用移到 g_dirty 块内)"
#property description "v2.05 修复 SIGNAL/HIDE 按钮跨周期被重置的 bug: 用户报告 '我在日周期设置好提醒后, 切换其他周期又切换回来, 提醒按钮复原了'。根因: SaveFibPositions() 只保存 p1/p0/p79/p49 四个价位, 没有保存 g_signalAlert 和 g_hidden; 切周期时 OnDeinit(reason=REASON_CHARTCHANGE) 调 SaveFibPositions → OnInit 在 LoadFibPositions 后被 InpSignalAlert 默认 false 覆盖 → 按钮复原为 OFF (同理 g_hidden 跨周期也丢状态, 用户可能还没注意到)。修复: 扩展 SaveFibPositions/LoadFibPositions 函数体, 把 g_hidden 和 g_signalAlert 用 GlobalVariableTemp + GlobalVariableSet 持久化 (按 g_prefix 区分, 与 fib 端点同样的会话内临时全局变量机制, 客户端重启自动清空); OnInit 中 LoadFibPositions 会覆盖 InpSignalAlert 默认值, 之后 CreateObjects + RefreshAll → UpdateHideButton/UpdateSignalButton 同步按钮视觉。布尔用 0.0/1.0 编码 double (GlobalVariable 只支持 double)。状态机变量 (g_pullbackFired/g_breakUpFired/g_breakDownFired/g_prevSamplePrice) 不持久化 — 切周期后重置是合理的 (重新等首次穿越)。改动 2 处: SaveFibPositions 末尾 2 行, LoadFibPositions 末尾 2 行"
#property description "v2.06 SIGNAL 三类报警新增手机推送: 用户报告 'PC 端配置正常, 测试消息可发, alert/experts 日志正常, 但 journal 里没看到 notification 相关消息, 手机收不到推送'。根因: SIGNAL 触发的三类报警 (0.49 回调 / 突破上界 g_p0 / 突破下界 g_p1) 只用 Alert() + Print(), 从未调用 SendNotification() — 整个 EA 只有 CheckPnLReport (盈亏播报, 整 15 分钟 + 有持仓时) 推过一次, 这就是 journal 里看不到 notification 的原因。修复: 在三类报警的 Alert+Print 之后追加 SendNotification(msg), 失败时 Print 错误提示 (PC 端默认 MetaQuotes ID, 与测试消息同 ID, 所以推送通道本身没问题 — 是代码根本没调)。防重复推送沿用 fired 锁 (g_pullbackFired/g_breakUpFired/g_breakDownFired) — Alert/Print/SendNotification 三通道在同一 if 分支内, fired 一锁全锁, 不需要新增独立的 sent 锁 (避免过度设计)。MT5 SendNotification 限制: 同一消息 5 秒内自动去重, 每秒最多 1 条 — 三类报警消息格式不同, 不会冲突。改动 4 处: CheckPullbackSignal ④⑤⑥ 三处报警后追加 SendNotification (各 2 行, 含失败日志); ToggleSignalAlert 注释更新 (fired 已覆盖推送锁); 全局变量注释更新 (fired 同步锁三通道); 版本号 + 描述。无需新增变量, 无需持久化"
#property description "v2.07 SIGNAL 三类报警措辞改为方向中性 (与 LONG/SHORT 无关): 用户报告 '刚刚收到一条推送 价格向上突破上界 g_p0=157.20400 (区间底=157.31500), 为什么上界比区间底还低?'。根因: 三类报警的措辞 '上界 g_p0 / 下界 g_p1 / 区间顶 g_p0 / 区间底 g_p1' 是 LONG 视角写死的 (假设 g_p1<g_p0 即 1.00 在下=low, 0.00 在上=high); 但 SWAP 按钮切换为 SHORT 模式后 g_p1>g_p0 (1.00 在上=high, 0.00 在下=low), 此时消息里的 '上界 g_p0' 实际是下界, '区间底 g_p1' 实际是上界 — 数值反了。v1.99 设计原意就是 '不依赖 Dir, 任何方向都报', 但措辞却用了 LONG 视角的术语, 是 v1.99 留下的措辞漏洞 (v2.06 把同样的错措辞一并推送到了手机)。修复: 把 '上界 g_p0 / 下界 g_p1 / 区间顶 g_p0 / 区间底 g_p1' 统一替换为方向中性的 '0.00 端点 / 1.00 端点 / 对端' 措辞 — 端点名只与 fib 系数绑定, 与 SWAP 后的视觉上下无关。'向上突破/向下突破' 也改为 '向上穿越/向下穿越' (中性描述, 不暗示哪边是上哪边是下)。Range 仍保留 (区间宽度与方向无关)。改动 6 处: 3 处消息文本 (0.49 回调/向上穿越/向下穿越) + 3 处对应注释 (CheckPullbackSignal 函数头注释 + ⑤⑥ 块注释)。无逻辑变化, 无新增变量, 无持久化"
#property description "v2.08 SIGNAL 突破检测阈值改为 max/min(g_p1,g_p0), 措辞改为 '突破区间上沿/下沿': v2.07 修复了措辞 ('端点名' 中性化) 但没改检测阈值 — SHORT 模式下 pxBrk > g_p0 等于 '价格向上穿过下沿' 却报 '向上穿越 0.00 端点', 阈值语义仍与消息措辞矛盾。用户反馈 '描述还是有问题, 不管 long/short, 价格高的为上沿, 价格低的为下沿, 统一为突破区间上沿/下沿'。v2.08 修复: ① 检测阈值从 g_p0/g_p1 改为 highEdge=max(g_p1,g_p0)/lowEdge=min(g_p1,g_p0) — '上沿/下沿' 按当前数值高低动态判定, 不再依赖端点 fib 系数或 SWAP 状态; ② 措辞从 '0.00 端点/1.00 端点' 改为 '区间上沿/区间下沿' (用户指定, 比端点名更直观); ③ '穿越' 改回 '突破' (用户指定, 配合区间沿措辞); ④ 0.49 回调消息也改用 highEdge/lowEdge (虽然 0.49 回调本身没这个问题, 但消息中显示的两个端点信息用 '上沿/下沿' 更一致); ⑤ g_breakUpFired 语义从 '突破 g_p0' 改为 '突破 highEdge', g_breakDownFired 类似。改动 6 处: CheckPullbackSignal 函数头注释 1 处 + 0.49 回调消息 1 处 (新增 highEdge/lowEdge 局部变量) + 向上穿越注释+阈值+消息 3 处 + 向下穿越注释+阈值+消息 3 处。新增 4 个临时 double (highEdge/lowEdge/range 共用, 每个 if 块内声明)"
#property description "v2.09 SIGNAL 三类报警消息加上 _Symbol 标的品种信息: 用户要求 '所有的提醒要带有标的品种信息', 因为多 chart 跑同一 EA 时 (用户可能 EURUSD/XAUUSD 各开一个 chart 各挂一个 EA 实例), 推送无法区分是哪个品种触发的 — v2.06/v2.07/v2.08 消息前缀都是 '[FibLimitAssist]' 无品种信息, 手机端看到推送只能看推送时间推断是哪个 chart 报的, 不直观。修复: 三个 StringFormat 都在 '[FibLimitAssist]' 后加 %s 传 _Symbol, 风格与 v2.00 盈亏播报 ('[FibLimitAssist] %s P&L: ...') 保持一致。0.49 回调消息变成 '[FibLimitAssist] %s %s 价格首次回调...' (第一 %s=_Symbol, 第二 %s=dirStr=long/short); 突破上沿/下沿消息变成 '[FibLimitAssist] %s 突破区间...', 第二参数位加 pxBrk。SendNotification 去重问题: MT5 同一消息 5 秒内自动去重 (每秒最多 1 条), 三类报警的消息格式现在按品种区分 — 不同品种的同类报警不会冲突 (因为 _Symbol 不同); 同品种的同类报警仍按 fired 锁去重, 不会撞 SendNotification 去重。改动 4 处: 0.49 回调 1 行 StringFormat + 向上穿越 1 行 + 向下穿越 1 行 + 函数头注释 1 行 (v2.09 标注)。无逻辑变化, 无新增变量, 无持久化"
#property description "v2.10 盈亏播报消息用 '盈/亏' 替代 '+/-' 符号: 用户要求 '提醒消息 改成 盈 亏 代替 + -'。原因: 推送中纯符号 '+12.50 USD' 手机端无文字语义, 看一眼分不清是盈是亏, 用中文 '盈/亏' 一目了然。修复: CheckPnLReport 中把 `(netPnl >= 0) ? '+' : ''` 改为 `(netPnl >= 0) ? '盈' : '亏'`, 同时用 MathAbs(netPnl) 取绝对值显示金额 (符号已被 '盈/亏' 取代, 不再需要双重符号)。注意: 0 视为 '盈' (与 netPnl >= 0 一致, 0 不亏)。新消息示例: '[FibLimitAssist] EURUSD P&L: 盈 12.50 USD (2 单)' / '[FibLimitAssist] XAUUSD P&L: 亏 5.20 USD (1 单)' / '[FibLimitAssist] EURUSD P&L: 盈 0.00 USD (3 单)'。改动 2 处: CheckPnLReport 中 sign 变量名改 status (语义更准, 不再是 sign) + StringFormat 参数调整 (%s%.2f → %s %.2f 加 MathAbs)。无逻辑变化, 无新增变量, 无持久化"
#property description "v2.11 RISK 按钮循环档位从三档扩展为四档 (新增 0.25%): 用户要求 '比例切换 增加一个0.25%'。原三档 (0.5/1/2) 循环, 新增 0.25 作为最低档 (循环顺序 0.25 → 0.5 → 1 → 2 → 0.25), 方便用户用更小仓位试探行情或长线超轻仓。修复: ① g_riskValues 数组从 [3]={0.5,1.0,2.0} 扩为 [4]={0.25,0.5,1.0,2.0}, CycleRisk 函数用 ArraySize 自动适配, 无需改循环逻辑; ② UpdateRiskButton 三档配色扩为四档: 新增 CLR_RISK_VERYLOW 浅绿 C'180,220,180' (0.25% 用), 保留原 CLR_RISK_LOW/MID/HI (0.5/1/2%) — 视觉梯度: 浅绿(0.25, 极低风险) → 绿(0.5, 低) → 黄(1, 中) → 红(2, 高); ③ UpdateRiskButton 文本格式化精度 1 → 2 (DoubleToString(d, 2)), 因为 0.25 精度 1 显示为 '0.3' 错误; 同时增加去尾 '00' 逻辑, 0.50 → '0.5', 1.00 → '1' (不出现 '0.50'/'1.00' 这种末尾补零); ④ RISK 按钮 tooltip 文字从 '0.5% → 1% → 2% → 0.5%' 改为 '0.25% → 0.5% → 1% → 2% → 0.25%'; ⑤ 注释中 '(0.5/1/2)' 全部改为 '(0.25/0.5/1/2)'; ⑥ v2.11 注释标注。CycleRisk 函数体完全不动 (ArraySize 自适应), CalcLot 函数体不动 (仍是 g_riskPercent/100, 与档位数无关)。无新增变量 (CLR_RISK_VERYLOW 是 #define), 无持久化改动"
#property description "v1.62 EVEN/CHALF/CALL 镜像到底部下方 (y+4 与 STOP 同侧), X 分别对齐 SWAP/ADJUST/CANCEL (stepBox+8/92/176)"
#property description "v1.63 v1.62 位置修正: EVEN/CHALF/CALL 改回 yBtn (最下面线上方) + HIDE/RISK/FVG 同步从底部移到顶部 CANCEL 右侧 (顶部 6 按钮一长链: LONG→ADJUST→CANCEL→HIDE→RISK→FVG)"
#property description "v1.64 撤销 v1.63: 用户验证后改回原方案 — HIDE/RISK/FVG 回到底部左侧 (yBtn), EVEN/CHALF/CALL 恢复右侧 g_btnX 右对齐"
#property description "v1.65 EVEN/CHALF/CALL 移到顶部第二排 (CANCEL 正下方): X 对齐 LONG/ADJUST/CANCEL (stepBox+8/92/176), Y = 第一排 + 按钮高 + 4px 间距 — 形成顶部 3×2 对称矩阵"
#property description "v1.66 修 v1.65 错位: 第二排 CALL X 从 176 改 196 — 因 CHALF 宽 100, 原 stepBox+8/92/176 让 CHALF 右沿(192)与 CALL 左沿(176)重叠 16px; 改为按实际宽度递进 stepBox+8/92/196"
#property description "v1.67 撤回 v1.66 偏移: CHALF 宽 100→80 (与 ADJUST 对齐), CALL 保持 100 (与 CANCEL 对齐); CALL X 回 stepBox+176 — 三对按钮左右边缘完全对齐"
#property description "v1.68 ADJUST 新逻辑: 基于最近 FVG 找高低点 — 复用现有 DetectFVG(仅当前周期) 找最近 FVG, 看涨→强制 LONG (1.00=FVG K2 左侧 Williams 低, 0.00=FVG K2→bar0 max high); 看跌→强制 SHORT (镜像); 找不到 FVG/Williams 分形 回退到原 FindNearestSwing 逻辑"
#property description "v1.69 ADJUST FVG 修复: FindMostRecentFVG_K2 原只取 formTime 最大的单个 FVG, 若它是未成熟(K3=bar0)则直接 return -1; 改为按 formTime 降序逐个尝试, 跳过未成熟的, 用次近的已收线 FVG"
#property description "v1.70 ADJUST 跳过已完全填补 FVG: FindMostRecentFVG_K2 在 K2 已收线后, 调 ClassifyFVGStatus 判 status; 若 status=2 (完全填补) 则 continue 试次近的, 优先选未填补/部分填补的 FVG"

//---------------------------- 输入参数 -----------------------------//
// 注: 单笔风险(%) 由 RISK 按钮循环控制 (0.25/0.5/1/2); 0.79 挂单 v1.84 起拆两半仓 (半仓1 TP=0.19 线, 半仓2 TP=0.79→0.19 距离的2倍), 0.49 挂单=1:1, 市价=1:1
input double InpSL_OffsetPercent = 1.0;        // 止损向外偏移占区间百分比 (%)
input int    InpLotDecimals      = 2;          // 手数截断保留的小数位 (不四舍五入)
input long   InpMagicNumber      = 20260903;   // 订单魔术号
input string InpOrderComment     = "FibLimitAssist"; // 订单注释

// v1.12 新增: 当日盈亏切日时区 (FTMO 用布拉格时间 CE(S)T，其他 broker 可保持 LOCAL)
enum ENUM_DAY_RESET_TZ
  {
   DAY_TZ_LOCAL    = 0,  // 本机时间 00:00 切日 (按 TimeLocal())
   DAY_TZ_CET_AUTO = 1,  // FTMO 规则: CE(S)T 00:00 切日, 自动判断 DST (推荐 FTMO 用户)
   DAY_TZ_CET      = 2,  // 强制 CET (GMT+1, 冬令时)
   DAY_TZ_CEST     = 3,  // 强制 CEST (GMT+2, 夏令时)
  };
input ENUM_DAY_RESET_TZ InpDayResetTimezone = DAY_TZ_CET_AUTO; // 日切时区 (默认 FTMO/布拉格时间)

// v1.13 新增: ADJUST 按钮 - 一键将 1.00/0.00 调整到图表上最近的高低点 (移植 zigzag 3 参数分形识别)
input int InpAdjustDepth     = 12; // [ADJUST] 分形识别窗口 (左右各 N 根 bar, 类比 zigzag ExtDepth)
input int InpAdjustDeviation = 5;   // [ADJUST] 候选与前一同向极值最小偏差 (单位:点, 类比 zigzag ExtDeviation)
input int InpAdjustBackstep  = 3;   // [ADJUST] 候选最小时间距离 (单位:bar, 类比 zigzag ExtBackstep, 用于替换紧挨假信号)

// v1.17 新增: 0.79/0.49 线上 UP/DOWN 按钮 - 单击步长 = swing 区间 × (InpStepPercent)%, 双击 ×10
// v1.72: 1.00/0.00 端点 STEP 改为按 Williams 分形跳转 (上界找高/下界找低), 不再用此百分比; InpStepPercent 仅作用于 0.79/0.49
input double InpStepPercent  = 1.0; // [STEP] 0.79/0.49 单击移动步长占 swing 区间百分比 (%); 双击同按钮 300ms 内 = ×10 (1.00/0.00 端点不受此影响, 改用 Williams 分形)

// v1.38 新增: 默认斐波那契区间基准 — 最近 N 根已收盘 K 线的高低点 (数据驱动, 解决切周期时 ChartGetDouble(CHART_PRICE_MAX/MIN) 返回 0 或过窄导致线条挤死/跑出屏)
input int InpDefaultSpanBars = 60; // [默认区间] 用最近多少根已收盘 bar 的 High/Low 作为默认区间 (0=不用, 恢复旧视图基准)

// v1.27 新增: UI 界面缩放系数 (统一缩放所有按钮/标签的尺寸与间距)
//   Mac/Wine 版或 96DPI 屏幕用 1.0; 远程 Windows 服务器按钮过大时, 调小 (如 0.6~0.8)
//   0 = 自动按平台智能默认 (mac=1.0, Windows=0.6); 其他正数 = 强制使用 (手动覆盖智能默认)
// v1.85: 默认 0 → 1, 强制按原始尺寸显示 (取消平台自动缩小 Windows=0.6 的行为)
// v1.88: 默认 1 → 0, 恢复 v1.27 的平台自动智能默认 (Windows=0.6 自动缩小, Mac/Wine=1.0 原始尺寸)
input double InpUIScale = 0.0;   // [UI] 按钮尺寸缩放系数 (0=按平台自动; 正数=强制值)

// v1.28 新增: 字号独立缩放系数 (与 InpUIScale 解耦, 防止按钮缩小后文字看不清)
//   0 = 自动按平台智能默认 (mac=1.0, Windows=1.0); 其他正数 = 强制值 (如 0.8=字小一些)
input double InpFontScale = 0.0;  // [UI] 字号缩放系数 (0=按平台智能默认; 正数=强制值)

// v1.45 新增: FVG (公允价值缺口) 矩形画图
input bool               InpFVG_ShowUnfilled     = true;    // [FVG] 显示未填补 (绿/红)
input bool               InpFVG_ShowPartial     = true;    // [FVG] 显示部分填补 (蓝/橙)
input bool               InpFVG_ShowFilled       = true;    // [FVG] 显示完全填补 (灰, 默认开 — 主开关; 运行时仍由 FILL 按钮控制, FILL 按钮默认 OFF=隐藏)
input bool               InpFVG_ShowLabel        = false;   // [FVG] 显示 FVG 标签 (U·M15 形式, 默认关 — 默认只画矩形不画文字)
input bool               InpFVG_HigherTF_Enabled = false;  // [FVG] 叠加高级别 FVG
input bool               InpFVG_HigherTF_Auto    = true;    // [FVG] 自动按当前周期选高级别 (Auto=false 时用 InpFVG_HigherTF_Period)
input ENUM_TIMEFRAMES    InpFVG_HigherTF_Period  = PERIOD_H1;// [FVG] 手动指定的高级周期 (Auto=false 时生效)
input int                InpFVG_MinPoints        = 0;         // [FVG] 最小缺口宽度 (points), 0=不过滤

// v1.91 新增: 信号提醒 — 价格首次回调到区间 0.49 位置时弹窗+日志
//   价位计算: g_p1 - 0.49*(g_p1 - g_p0)  (从顶部回撤 49%, 与 g_p1/g_p0 边界联动; 不使用可拖动的 0.49 线)
//   方向: Dir() 判定 (DIR_UP=long 等价格从上方穿越向下; DIR_DOWN=short 等价格从下方穿越向上)
//   首次: 跨价位瞬间报警一次, 之后锁定, 直到 p1/p0 调整或按钮关闭再开重置
//   注意: 按钮可运行时切换 (ToggleSignalAlert), 切换时也会重置已触发状态
input bool InpSignalAlert = false;  // [信号提醒] 启动默认开关 (默认关; MQL5 input 不能运行时改, 切换由运行时变量 g_signalAlert 承担, OnInit 时拷贝此值)

//---------------------------- 固定比例 -----------------------------//
#define RATIO_100 1.00
#define RATIO_079 0.79
#define RATIO_049 0.49
#define RATIO_019 0.19
#define RATIO_073 0.73   // v1.86: 0.73 装饰线 (不可拖动, 仅显示)
#define RATIO_000 0.00

//---------------------------- 颜色定义 -----------------------------//
#define CLR_END      C'90,90,90'     // 端点 1.00 / 0.00 线
// v1.25 删除 CLR_MID：0.79/0.49 线颜色改为随方向动态变化 (DIR_UP→CLR_BUY_BG 绿, DIR_DOWN→CLR_SELL_BG 红, DIR_FLAT→CLR_FLAT_BG 灰), 由 RefreshAll 同步
#define CLR_DECO     C'115,115,115'  // 0.19 装饰线（加深，避免看不清）
#define CLR_DECO_073 C'100,150,200'  // v1.86: 0.73 装饰线 (青色, 与 0.19 灰色 CLR_DECO 区分)
#define CLR_BUY_BG   C'76,175,80'    // 买单按钮底色 (+0.79/0.49 线 long 态)
#define CLR_SELL_BG  C'244,67,54'    // 卖单按钮底色 (+0.79/0.49 线 short 态)
#define CLR_FLAT_BG  C'140,140,140'  // 方向未定义按钮底色 (+0.79/0.49 线未方向态)
// v1.07 新增：HIDE/SHOW 状态色 + RISK 三档色
// v1.25 调整：HIDE 按钮改为浅灰底（与 CANCEL 按钮同色 C'120,120,120'），仅 HIDE 态保留橙黄警示
#define CLR_HIDE_OFF C'120,120,120'  // SHOW 状态：当前显示（浅灰，与 CANCEL 一致）
#define CLR_HIDE_ON  C'200,120,20'   // HIDE 状态：当前隐藏（橙黄警示，仍保留）
#define CLR_RISK_VERYLOW C'180,220,180' // RISK 0.25% 极低风险（浅绿, 比 LOW 更轻; v2.11 新增四档配色）
#define CLR_RISK_LOW C'76,175,80'    // RISK 0.5% 低风险（绿）
#define CLR_RISK_MID C'255,193,7'    // RISK 1%   中风险（黄）
#define CLR_RISK_HI  C'244,67,54'    // RISK 2%   高风险（红）

// v1.34 新增：盈亏比标签三色
//  1.4  = 合计浮盈 / 合计止盈 (正值=已捕获止盈份额, 负值=整体亏损中) — 正绿/负红/零灰
//  3.2  = 合计止盈 / 合计止损 (风险回报比, 永远正)            — 褐色
//  50%  = 1.4 / 3.2 的比值                                    — 中性灰
#define CLR_RATIO_PLUS   C'76,175,80'   // 浮盈占比 正 (绿, 与 CLR_BUY_BG 一致)
#define CLR_RATIO_MINUS  C'244,67,54'   // 浮盈占比 负 (红, 与 CLR_SELL_BG 一致)
#define CLR_RATIO_NEUTRAL C'140,140,140'// 浮盈占比 0 或无持仓 (灰, 与 CLR_FLAT_BG 一致)
#define CLR_RATIO_RR     C'139,90,43'   // 风险回报比 (标准 saddle brown)

// v1.08 新增：P/L 数字标签颜色
#define CLR_PLUS        C'0,150,60'   // 盈利（绿，带 +）
#define CLR_MINUS       C'220,0,0'    // 亏损（红，带 -）
#define CLR_PNL_NEUTRAL C'140,140,140'// 盈亏为零（灰）

// v1.58 新增: FVG 配色 — 简化为 3 色: 上涨(浅绿) / 下跌(浅红) / 完全填补(浅灰)
//   不再区分未填补 vs 部分填补, 只看方向. v1.57 之前的 6 色过于细分, 视觉干扰大.
#define CLR_FVG_BULL    C'210,235,215'        // 看涨 (U/P 都用此色, 浅绿)
#define CLR_FVG_BEAR    C'250,210,208'        // 看跌 (U/P 都用此色, 浅红/粉)
#define CLR_FVG_FILLED  C'225,225,225'        // 完全填补 (浅灰, 默认隐藏)
// FVG 按钮 (与 HIDE 同色组, sticky 行为)
#define CLR_FVG_OFF          C'120,120,120'   // SHOW (浅灰)
#define CLR_FVG_ON           C'200,120,20'    // OFF 状态 (橙黄警示, 与 CLR_HIDE_ON 同)
// v1.83: FILL 状态颜色 — 复用 CLR_FILL_ON (原 v1.81 FILL ON 颜色), 3 态循环用现有色组即可
//   state=0 (FVG)  → CLR_FVG_OFF   浅灰 (默认态, 只显 U/P)
//   state=1 (FILL) → CLR_FILL_ON   青蓝 (显示 U/P + F)
//   state=2 (OFF)  → CLR_FVG_ON    橙黄 (全隐藏)
//   CLR_FILL_OFF (旧浅灰态) 与 CLR_FVG_OFF 重复, v1.83 删除
#define CLR_FILL_ON          C'60,160,200'

// v1.24 新增：STEP 上下调整按钮配色 (浅灰背景 + 黑字, 区别于其他深色操作按钮, 视觉更轻)
#define CLR_STEP_BG     C'200,200,200'// STEP 按钮底色（浅灰）
#define CLR_STEP_TXT    clrBlack      // STEP 按钮文字（黑, ▲▼）

//---------------------------- 方向枚举 -----------------------------//
enum ENUM_DIR { DIR_FLAT = 0, DIR_UP = 1, DIR_DOWN = 2 };

//---------------------------- 全局状态 -----------------------------//
string   g_prefix;             // 本实例对象/全局变量命名前缀
double   g_p1, g_p0;           // 1.00 / 0.00 端点价格
double   g_p79, g_p49;         // 0.79 / 0.49 分割线价格 (可手动偏移)
double   g_lastBalance = -1.0; // 上次刷新时的余额
bool     g_dirty = true;       // 需要刷新标记
int      g_btnX = 0;           // 按钮固定 X 像素位置

// 单笔风险档位 (会话内持久化，MT5 重启默认 1%)
double   g_riskPercent = 1.0;  // 当前风险档位 (%)
double   g_riskValues[4] = {0.25, 0.5, 1.0, 2.0};  // 可选档位 (循环顺序: 1 → 2 → 3 → 4 → 1 → ...; v2.11 加 0.25%)

// HIDE/SHOW 状态 (会话内有效，重启后恢复显示——避免忘记 EA 被隐藏找不到)
bool     g_hidden = false;     // true=隐藏 EA 线条与按钮(HIDE 按钮自身除外)

// v1.28: UI 缩放系数拆成两个 — g_uiScale 缩按钮尺寸, g_fontScale 缩字号
//   默认 1.0/1.0; Windows 服务器上智能默认 0.6/1.0 (按钮缩小但字保持清晰)
//   手动覆盖: InpUIScale / InpFontScale 任一改为非 0 正数时优先用手动值
double   g_uiScale   = 1.0;
double   g_fontScale = 1.0;

// 缩放辅助: 把设计像素乘以 UI 缩放系数 (四舍五入), 用于所有按钮/标签尺寸与固定偏移
int UI(int px)   { return (int)MathRound(px * g_uiScale); }
// v1.28 新增: 字号独立缩放 (与按钮尺寸解耦, 防止按钮缩小后文字看不清)
int Font(int px) { return (int)MathRound(px * g_fontScale); }

// v1.12 新增: 服务器相对 GMT 的偏移小时数 (OnInit 自动探测一次)
//   由 (TimeCurrent() - TimeGMT()) 推断，如 broker 是 GMT+2 则 g_serverGMTOffset = +2
//   仅用于 CE(S)T 切日换算
int      g_serverGMTOffset = 0;

// v1.17 新增: STEP 按钮双击检测 (MQL5 CHARTEVENT_OBJECT_CLICK 不带 shift 状态, 改用双击 = ×10 倍步长)
string   g_lastStepName     = "";
long     g_lastStepTimeMs   = 0;
#define  STEP_DBLCLICK_MS   300

// v1.45 新增: FVG 状态机
//   g_fvgEnabled: FVG 按钮 sticky 状态 (与 HIDE 同步隐藏/显示)
//   g_higherTF:   Auto 模式实际生效的高级周期 (OnInit 时根据 _Period 自动选)
//   g_fvgCache:   缓存上一帧的状态/边界, 减少 ObjectSetInteger 调用
// v1.83: FVG 单按钮 3 状态循环 — 取代 v1.81 的 g_fvgEnabled + g_fillShown 双 bool
//   状态机: 0 (FVG, 只显 U/P) → 1 (FILL, 显 U/P + F) → 2 (OFF, 全隐藏) → 0
//   派生 bool (供 UpdateFVGDisplay 等内部使用):
//     g_fvgEnabled = (state != 2)        // state 0/1 都启用 FVG 绘制
//     g_fillShown  = (state == 1)        // 仅 state 1 显示填补态
//   默认 state=0 (FVG, U/P 可见, F 隐藏) — 等价于 v1.82 的 g_fvgEnabled=true && g_fillShown=false
int               g_fvgState       = 0;

// v1.91 新增: 信号提醒状态
//   g_pullbackLevel: 报警价位 = g_p1 - 0.49*(g_p1 - g_p0), 每次 p1/p0 变化或按钮切换时重算
//   g_prevSamplePrice: 上次 OnTick 采样的价格, 用于检测跨价位 (long: prev>level && now<=level)
//   g_pullbackFired: 本轮 0.49 回调是否已报警 (锁定, 直到 p1/p0 调整或按钮重置) — 同时锁 Alert/Print/SendNotification 三通道
//   g_breakUpFired:   本轮向上突破 p0 (上界) 是否已报警 (锁定) — 同时锁三通道
//   g_breakDownFired: 本轮向下突破 p1 (下界) 是否已报警 (锁定) — 同时锁三通道
//   g_prevP1/g_prevP0: 上次 p1/p0 快照, 1 tick 内差异 > _Point 视为边界被调整 → 重置所有 fired 并重新采样
//   g_signalAlert: 运行时开关 (MQL5 input 是常量, 不能运行时赋值; OnInit 从 InpSignalAlert 拷贝初始化, 按钮切换它)
//   g_lastPnLReportMin: 盈亏播报节流锁 (上次发送的服务器分钟, -1 = 未锁; 非整15分钟时重置为-1, 避免重复发送)
double            g_pullbackLevel    = 0.0;
double            g_prevSamplePrice  = 0.0;
bool              g_pullbackFired    = false;
bool              g_breakUpFired     = false;   // v1.99: 向上突破 p0 锁定
bool              g_breakDownFired   = false;   // v1.99: 向下突破 p1 锁定
double            g_prevP1           = 0.0;
double            g_prevP0           = 0.0;
bool              g_signalAlert      = false;
int               g_lastPnLReportMin = -1;     // v2.00: 盈亏播报节流锁

ENUM_TIMEFRAMES   g_higherTF      = PERIOD_H1;             // 实际生效的高级周期
// FVG 单条记录 (检测 + 状态 紧凑存储)
//   formTime= 形成时间 (中间 K 线时间), top= 上边界, bot= 下边界, status=0/1/2, dir=DIR_UP/DOWN
struct FVGRecord
  {
   datetime formTime;
   double   top;
   double   bot;
   int      status;   // 0=U未填补 / 1=P部分填补 / 2=F已填补 (F 永远不变)
   int      dir;      // DIR_UP 看涨, DIR_DOWN 看跌
   int      tfMin;    // 周期分钟数 (高级别叠加时区分周期显示)
   double   fillLevel; // v1.57: 部分填补时, 价格进入缺口的最深处 (DIR_UP=最低低, DIR_DOWN=最高高); status=0 时无意义
   datetime fillTime;  // v1.60: 完全填补时记录填补那根 K 线的起点时间 (status=2 有效; 其他=0). 用于让 F 矩形止于填补 K 线起点, 不再延伸至最新 K 线
  };
FVGRecord g_fvgCache[];

//---------------------------- 工具函数 -----------------------------//
// v1.39: 移除 kernel32.dll 依赖 — 改用纯路径判断 Wine (EA 不再需要勾选 Allow DLL imports)
//   v1.29 曾用 #import "kernel32.dll" 的 GetLogicalDrives() 探测 Z: 盘, 导致 EA 依赖 DLL,
//   MT5 属性/Dependencies 里提示 kernel32.dll 并需勾选 Allow DLL imports (账户禁用 DLL 时无法加载)
//   纯路径信号(可靠): Wine 官方版(含 mac 打包)是便携模式, 数据目录在 "Program Files" 下;
//                     原生 Windows 标准安装数据目录在 "AppData\Roaming\MetaQuotes\Terminal" 下
bool IsWine()
  {
   string dp = TerminalInfoString(TERMINAL_DATA_PATH);
   if(StringFind(dp, "AppData") >= 0)
      return false;                // 原生 Windows 标准安装
   if(StringFind(dp, "Program Files") >= 0)
      return true;                 // Wine 便携(mac/Linux)
   return false;                   // 无法判断时保守按 Windows (mac 必命中 Program Files, 不会误判)
  }

// 对象命名：按比例生成唯一名称
string HName(double r) { return g_prefix + "H" + StringFormat("%.2f", r); } // 水平线
string BName(double r) { return g_prefix + "B" + StringFormat("%.2f", r); } // 按钮
string LName(double r) { return g_prefix + "L" + StringFormat("%.2f", r); } // 文字标签

// 理论比例价位：price_r = p1 + (1 - r) * (p0 - p1)
// 该公式对上涨( p1<p0 )与下跌( p1>p0 )均成立
double TheoPrice(double r, double p1, double p0) { return p1 + (1.0 - r) * (p0 - p1); }

// 某条分割线的当前价格 (0.79/0.49 取手动值，其余取理论值)
double LevelPrice(double r)
  {
   if(r == RATIO_079) return g_p79;
   if(r == RATIO_049) return g_p49;
   return TheoPrice(r, g_p1, g_p0);
  }

// 某价位在当前区间内的实际比例 (0~1)：r = (p0 - price) / (p0 - p1)
// 上涨/下跌统一成立；区间未定义时返回 0
double ActualRatio(double price)
  {
   double denom = g_p0 - g_p1;
   if(MathAbs(denom) < 1e-12) return 0.0;
   return (g_p0 - price) / denom;
  }

// 方向：由 1.00 与 0.00 端点位置自动判定
int Dir()
  {
   if(g_p1 < g_p0) return DIR_UP;
   if(g_p1 > g_p0) return DIR_DOWN;
   return DIR_FLAT;
  }

// 右侧可见最近 bar 时间 (用于价格→像素换算)
datetime RightAnchor()
  {
   datetime t = iTime(_Symbol, _Period, 1);
   return (t == 0) ? TimeCurrent() : t;
  }

// 左侧可见 bar 偏移 (用于未来扩展)
int LeftShift()
  {
   int first = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR, 0);
   int width = (int)ChartGetInteger(0, CHART_WIDTH_IN_BARS, 0);
   int bars  = Bars(_Symbol, _Period);
   int s = first + width - 2;
   if(s < 0)      s = 0;
   if(s >= bars)  s = bars - 1;
   return s;
  }

//---------------------------- 状态持久化 ---------------------------//
// 使用临时全局变量 (GlobalVariableTemp)：会话内(切换周期/缩放)保留，MT5 重启后自动清空
// v1.15: 移除端点位置记忆 → v1.36 恢复为"按周期记忆"(每个周期独立记忆自己的线条位置)
// v1.36: g_prefix 已含 _Period, 天然按周期隔离, 切走再切回同周期可恢复位置
void SaveRisk()
  {
   GlobalVariableTemp(g_prefix + "risk");   // 临时变量, 重启清空
   GlobalVariableSet(g_prefix + "risk", g_riskPercent);
  }
bool LoadRisk()
  {
   if(!GlobalVariableCheck(g_prefix + "risk")) return false;
   g_riskPercent = GlobalVariableGet(g_prefix + "risk");
   return true;
  }

// v1.36: 端点/挂单线位置按周期记忆 (临时全局变量, 会话内持久, 重启清空)
//   切周期时 OnDeinit 保存 → 重新 OnInit 时恢复; 同周期切回恢复上次调整的位置
void SaveFibPositions()
  {
   GlobalVariableTemp(g_prefix + "p1");   GlobalVariableSet(g_prefix + "p1",  g_p1);
   GlobalVariableTemp(g_prefix + "p0");   GlobalVariableSet(g_prefix + "p0",  g_p0);
   GlobalVariableTemp(g_prefix + "p79");  GlobalVariableSet(g_prefix + "p79", g_p79);
   GlobalVariableTemp(g_prefix + "p49");  GlobalVariableSet(g_prefix + "p49", g_p49);
   // v2.05: HIDE + SIGNAL 跨周期持久化 — 与 fib 端点共用 SaveFibPositions 函数
   //   切周期时 OnDeinit(reason=REASON_CHARTCHANGE) 调 SaveFibPositions 保存所有状态
   //   → OnInit LoadFibPositions 恢复 → RefreshAll → UpdateHideButton/UpdateSignalButton 同步视觉
   //   GlobalVariable 是 double, 用 0.0/1.0 编码 bool
   //   GlobalVariableTemp 标记为临时 (客户端重启自动清理, 不污染 MT5 全局变量列表)
   GlobalVariableTemp(g_prefix + "hide");   GlobalVariableSet(g_prefix + "hide",   g_hidden      ? 1.0 : 0.0);
   GlobalVariableTemp(g_prefix + "signal");  GlobalVariableSet(g_prefix + "signal",  g_signalAlert ? 1.0 : 0.0);
  }
bool LoadFibPositions()
  {
   if(!GlobalVariableCheck(g_prefix + "p1") || !GlobalVariableCheck(g_prefix + "p0"))
      return false;   // 端点缺失 → 视为首次, 走默认初始化
   g_p1 = GlobalVariableGet(g_prefix + "p1");
   g_p0 = GlobalVariableGet(g_prefix + "p0");
   // v1.38: 加强校验 — 端点须为有效正价且跨度足够(≥max(10点, 价格×0.2%)), 否则视为异常残留走默认
   //   目的: 拒绝旧版本 ChartGetDouble 兜底时产生的"挤死"位置(|p1-p0|≈spread 几个点)
   double minSpan = MathMax(10 * _Point, MathMax(g_p1, g_p0) * 0.002);
   if(g_p1 <= 0 || g_p0 <= 0 || MathAbs(g_p1 - g_p0) < minSpan)
      return false;   // 无效值(异常残留) → 走默认初始化
   // 中间线: 有单独记忆则恢复(用户可能拖过偏离理论值), 否则按端点理论值补齐
   if(GlobalVariableCheck(g_prefix + "p79")) g_p79 = GlobalVariableGet(g_prefix + "p79");
   else                                      g_p79 = TheoPrice(RATIO_079, g_p1, g_p0);
   if(GlobalVariableCheck(g_prefix + "p49")) g_p49 = GlobalVariableGet(g_prefix + "p49");
   else                                      g_p49 = TheoPrice(RATIO_049, g_p1, g_p0);
   // v2.05: HIDE + SIGNAL 跨周期持久化恢复 — 与 SaveFibPositions 对称
   //   缺失则保留 OnInit 中 g_signalAlert = InpSignalAlert 默认值 (用户首次运行或 MT5 重启清空)
   //   if 判断内不强制设 false, 让用户能通过 InpSignalAlert 启动默认值控制
   if(GlobalVariableCheck(g_prefix + "hide"))   g_hidden      = (GlobalVariableGet(g_prefix + "hide")   > 0.5);
   if(GlobalVariableCheck(g_prefix + "signal"))  g_signalAlert = (GlobalVariableGet(g_prefix + "signal")  > 0.5);
   return true;
  }

//---------------------------- 对象创建 -----------------------------//
// 横线 (OBJ_HLINE)：横跨整个图表，拖拽时只能上下改价
bool CreateHLine(string name, double price, bool selectable, color clr, int style, int width)
  {
   if(!ObjectCreate(0, name, OBJ_HLINE, 0, 0, price)) return false;
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, selectable);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   return true;
  }
bool CreateButton(string name)
  {
   if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0)) return false;
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, UI(120));   // v1.08：挂单按钮从 200 缩到 120（v1.06 的 60%）; v1.27 UI 缩放
   ObjectSetInteger(0, name, OBJPROP_YSIZE, UI(22));
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, Font(7));
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   return true;
  }
bool CreateLabel(string name, string text, color clr, ENUM_ANCHOR_POINT anchor)
  {
   if(!ObjectCreate(0, name, OBJ_TEXT, 0, 0, 0)) return false;
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, Font(8));
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   return true;
  }
// 右对齐标签 (OBJ_LABEL，像素定位，右边缘与按钮右边缘对齐)
bool CreateLabelRight(string name, string text, color clr)
  {
   if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0)) return false;
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, Font(8));
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   return true;
  }

// 多空切换按钮对象名
string SwapName()          { return g_prefix + "SWAP"; }
// 取消所有挂单按钮对象名
string CancelPendingName() { return g_prefix + "CANCELP"; }
// 清仓按钮对象名
string CloseAllName()      { return g_prefix + "CLOSEALL"; }
// 平仓一半按钮对象名
string CloseHalfName()     { return g_prefix + "CLOSEHALF"; }
// v1.08：入场价平仓按钮对象名
string EvenName()          { return g_prefix + "EVEN"; }
// v1.08：MKT 左侧的实时浮盈标签（账户当前所有持仓的浮盈合计）
string PnLLeftName()       { return g_prefix + "PNLL"; }
// v1.08：MKT 右侧的当日盈亏标签（本地 00:00 起所有已平仓+未平仓盈亏合计）
string PnLRightName()      { return g_prefix + "PNLR"; }
// 风险切换按钮对象名
string RiskName()          { return g_prefix + "RISK"; }
// v1.75: MKT 与 STP 之间的实时点差标签 (形如 "(1.5)")
string SpreadName()        { return g_prefix + "SPREAD"; }
// 市价下单按钮对象名
string MarketName()        { return g_prefix + "MARKET"; }
// v1.31：突破挂单按钮对象名 (BUY STP / SELL STP)
string StopName()          { return g_prefix + "STOP"; }
// v1.34：盈亏比标签 (3 段 OBJ_LABEL: A=含(的浮盈占比, B=含:)的止盈/止损比, C=百分比)
string RatioAName()        { return g_prefix + "RATIO_A"; }
string RatioBName()        { return g_prefix + "RATIO_B"; }
string RatioCName()        { return g_prefix + "RATIO_C"; }
// v1.45: FVG 切换按钮对象名
//   v1.83 起升级为 3 状态循环按钮 (state: 0=FVG, 1=FILL, 2=OFF)
//   MQL5 OBJ_BUTTON 的 STATE 只支持 bool, 但 3 状态通过 OBJPROP_TEXT/BGCOLOR 切换文字+颜色实现 (点 1 次 state++ % 3)
string FVGButtonName()     { return g_prefix + "FVG_BTN"; }
// v1.81: FILL 切换按钮对象名 (sticky: 文字 "FILL"/"OFF", 按下=当前隐藏填补态, 默认 OFF) — v1.83 删除 (合并入 FVGButtonName)
// FVG 矩形对象名前缀 (矩形本体 + 标签 — 都要按此前缀清理)
string FVGPrefix()         { return g_prefix + "FVG_"; }
// 隐藏/显示按钮对象名 (始终显示，不会随 g_hidden 隐藏)
string HideName()          { return g_prefix + "HIDE"; }
// v1.13: 一键调整 1.00/0.00 到最近高低点的按钮对象名
string AdjustName()        { return g_prefix + "ADJUST"; }

// v1.91: 信号提醒开关按钮对象名 (放在原 ADJUST 位置 — LONG 右侧 4px, 与 SWAP/ADJUST/CANCEL 同 Y)
string SignalName()        { return g_prefix + "SIGNAL"; }

// v1.17 新增: 4 条主线的 UP/DOWN 步进按钮对象名 (ratio=100/079/049/000, dir=+1/-1)
string StepName(double ratio, int dir)
  {
   int rint = (int)MathRound(ratio * 100);
   return g_prefix + "STEP_" + (dir > 0 ? "UP_" : "DN_") + IntegerToString(rint);
  }

bool CreateSwapButton()
  {
   string name = SwapName();
   if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0)) return false;
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, UI(80));
   ObjectSetInteger(0, name, OBJPROP_YSIZE, UI(22));
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, Font(7));
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TOOLTIP, "点击对调起点终点，切换多空方向");
   return true;
  }

// v1.13: ADJUST 按钮 (一键调整 1.00/0.00 到最近的高低点)
bool CreateAdjustButton()
  {
   string name = AdjustName();
   if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0)) return false;
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, UI(80));
   ObjectSetInteger(0, name, OBJPROP_YSIZE, UI(22));
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, Font(7));
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'100,100,160');
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, "ADJUST");
   ObjectSetString(0, name, OBJPROP_TOOLTIP,
                   "一键将 1.00/0.00 调整到图表上最近的高低点 (zigzag 3 参数分形识别)\n"
                   "· 1.00 → 最近的高点 (datetime 距今最近)\n"
                   "· 0.00 → 最近的低点 (datetime 距今最近)\n"
                   "· 0.19/0.49/0.79 自动按新 Range 重新计算\n"
                   "参数: Depth=" + IntegerToString(InpAdjustDepth) +
                   ", Deviation=" + IntegerToString(InpAdjustDeviation) +
                   ", Backstep=" + IntegerToString(InpAdjustBackstep));
   return true;
  }

// v1.91: 信号提醒开关按钮 — 2 态切换 SIGNAL/OFF (默认 OFF)
//   位置由 UpdateSignalButtonPosition 设为原 ADJUST 位置 (LONG 右侧 4px, 与 SWAP/ADJUST/CANCEL 同 Y)
//   v1.99 起该按钮为"三类报警"总开关: ①0.49 回调 ②向上突破上界 g_p0 ③向下突破下界 g_p1
bool CreateSignalButton()
  {
   string name = SignalName();
   if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0)) return false;
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, UI(80));
   ObjectSetInteger(0, name, OBJPROP_YSIZE, UI(22));
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, Font(7));
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   // v1.94: 显式设置初始 STATE/BGCOLOR/TEXT, 与 CreateActionButton 一致 — 仅靠 UpdateSignalButton 派生在某些 MT5 启动顺序下会有视觉闪烁
   ObjectSetInteger(0, name, OBJPROP_STATE,   false);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'120,120,120');   // v1.95: OFF 底色与 CANCEL 按钮一致 (灰色)
   ObjectSetString (0, name, OBJPROP_TEXT,    "OFF");
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   // v1.93: 用局部 string 变量承载多行 tooltip, 避免 MetaEditor 对连续字符串字面量的解析报错
   // v1.99: tooltip 描述三类报警 (0.49 回调 + 突破上下界), 共用 g_signalAlert 开关
   string tip = "信号提醒 总开关 (v1.99 共用三类): SIGNAL=开, OFF=关\n"
                "· ① long 价格首次回调 (下跌) 到区间 0.49 位置报警\n"
                "· ② 任何方向 向上突破上界 g_p0 报警\n"
                "· ③ 任何方向 向下突破下界 g_p1 报警\n"
                "· 首次跨价位报警一次后锁定, 直到边界调整或按钮重开";
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tip);
   UpdateSignalButton();   // 同步文字/颜色/STICKY (依据 g_signalAlert 运行时值)
   return true;
  }

// 通用操作按钮（取消挂单 / 清仓）
bool CreateActionButton(string name, int xsize, string text, color bg, string tooltip)
  {
   if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0)) return false;
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, UI(xsize));
   ObjectSetInteger(0, name, OBJPROP_YSIZE, UI(22));
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, Font(7));
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
   return true;
  }
void CreateObjects()
  {
   CreateHLine(HName(RATIO_100), g_p1,  true,  CLR_END,  STYLE_SOLID, 1);   // v1.87: width 2→1, 与 0.79/0.49 中线统一
   CreateHLine(HName(RATIO_000), g_p0,  true,  CLR_END,  STYLE_SOLID, 1);   // v1.87: width 2→1, 与 0.79/0.49 中线统一
   CreateHLine(HName(RATIO_079), g_p79, true,  CLR_FLAT_BG, STYLE_SOLID, 1);
   CreateHLine(HName(RATIO_049), g_p49, true,  CLR_FLAT_BG, STYLE_SOLID, 1);
   CreateHLine(HName(RATIO_019), TheoPrice(RATIO_019, g_p1, g_p0), false, CLR_DECO, STYLE_DASHDOT, 1);
   // v1.86: 0.73 装饰线 (青色虚线, 不可拖动)
   CreateHLine(HName(RATIO_073), TheoPrice(RATIO_073, g_p1, g_p0), false, CLR_DECO_073, STYLE_DASHDOT, 1);

   CreateButton(BName(RATIO_079));
   CreateButton(BName(RATIO_049));
   CreateSwapButton();
   CreateAdjustButton();   // v1.13: ADJUST 按钮 (位置由 UpdateAdjustButton 跟随 SWAP 设置)
   CreateSignalButton();  // v1.91: 信号提醒开关按钮 (位置由 UpdateSignalButtonPosition 设在原 ADJUST 位)
   CreateActionButton(CancelPendingName(), 100, "CANCEL",       C'120,120,120', "取消当前品种全部挂单（含手动单），不影响其他品种");
   CreateActionButton(CloseAllName(),       80, "ALL",           C'120,120,120',  "平掉当前品种全部持仓（不涉及挂单），不影响其他品种");   // v1.98: 文字 "all"→"ALL" (大写)
   CreateActionButton(CloseHalfName(),      80, "HALF",          C'120,120,120',  "按手数砍半平仓当前品种持仓；若砍半后 < 最小手数则全平该仓位");   // v1.98: 文字 "half"→"HALF" (大写)
   CreateActionButton(EvenName(),           80, "EVEN",          C'120,120,120',  "一键入场价（仅当前品种）：盈利仓位SL改到入场；亏损仓位TP改到入场（保本平仓）");   // v1.96: 蓝 → 灰
   CreateActionButton(RiskName(),           80, "",              C'90,90,90',   "点击循环切换单笔风险档位：0.25% → 0.5% → 1% → 2% → 0.25%");
   CreateActionButton(MarketName(),        110, "MARKET",        C'140,140,140',"市价下单（止损 = 1.00 ± Range×1%，盈亏比 1:1）");
   CreateActionButton(StopName(),          110, "STOP",          CLR_FLAT_BG,    "突破挂单: BUY STOP (long) 挂在最新已收线 K 线 High + 1 tick, SELL STOP (short) 挂在最新已收线 K 线 Low - 1 tick (v1.73 与 fib 线条解耦); SL/TP/lot 与 MARKET 共用公式");
   CreateActionButton(HideName(),           80, "HIDE",          CLR_HIDE_OFF,   "隐藏/显示 EA 全部线条与按钮（此按钮自身始终显示）");
   // v1.45: FVG 切换按钮 (在 HIDE 右侧, sticky 行为)
   //   v1.83: 升级为 3 状态循环 (FVG → FILL → OFF → FVG)
   //   文字/颜色由 UpdateFVGButton 根据 g_fvgState 派生:
   //     state=0 (FVG)  → 文字 "FVG",  底色 CLR_FVG_OFF 浅灰
   //     state=1 (FILL) → 文字 "FILL", 底色 CLR_FILL_ON  青蓝
   //     state=2 (OFF)  → 文字 "OFF",  底色 CLR_FVG_ON  橙黄
   //   v1.81 FILL 按钮已合并入本按钮, 不再单独创建
   CreateActionButton(FVGButtonName(),      80, "FVG",           CLR_FVG_OFF,    "FVG 切换 (3 态循环): FVG=只显未/部分填补 (绿/红), FILL=再显完全填补 (灰, 需 InpFVG_ShowFilled=true), OFF=全隐藏");

   // v1.08：MKT 两侧的实时盈亏数字标签（OBJ_LABEL 像素定位）
   CreatePnLLabel(PnLLeftName());
   CreatePnLLabel(PnLRightName());
   // v1.34: 盈亏比标签 — 3 段 (浮盈占比 + 风险回报比 + 百分比), 颜色不同需独立对象
   CreatePnLLabel(RatioAName());
   CreatePnLLabel(RatioBName());
   CreatePnLLabel(RatioCName());
   // v1.75: MKT 与 STP 中间的实时点差标签 (形如 "(1.5)" — 单位 points/10=pips)
   CreateSpreadLabel(SpreadName());

   CreateLabelRight(LName(RATIO_019), "0.19", CLR_DECO);
   // v1.86: 0.73 装饰线标签
   CreateLabelRight(LName(RATIO_073), "0.73", CLR_DECO_073);

   CreateStepButtons();   // v1.17: 1.00/0.79/0.49/0.00 各一对 UP/DOWN 按钮
  }

// v1.08：盈亏数字标签（OBJ_LABEL 像素定位）
bool CreatePnLLabel(string name)
  {
   if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0)) return false;
   ObjectSetString(0, name, OBJPROP_TEXT, "");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, Font(8));
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   return true;
  }
// v1.75: MKT 与 STP 中间的实时点差标签 (形如 "(1.5)") — 居中锚点, 颜色用 PNL_NEUTRAL 灰避免抢眼
bool CreateSpreadLabel(string name)
  {
   if(ObjectFind(0, name) >= 0) return true;
   if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0)) return false;
   ObjectSetString(0, name, OBJPROP_TEXT, "");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, Font(7));
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);  // 居中锚点: (X,Y) 居中, X=gap 中心, Y=按钮中线
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_COLOR, CLR_PNL_NEUTRAL);
   return true;
  }

//---------------------------- 刷新显示 -----------------------------//
void UpdateButtonX()
  {
   // v1.08：g_btnX = 最右边挂单按钮列的右边缘锚点（右边距 8）；v1.97 起仅作挂单列右对齐锚点，CALL 实际宽度 80 不影响
//   历史: v1.08 时 g_btnX = CALL 左 X（CALL 宽 100, 右边距 8）; v1.27 起 UI 缩放右边缘 = w - UI(108)
//   v1.32：STOP 放回中间 slack 区, 不再吃 g_btnX 的位置 (回退到 v1.25 的 X)
   int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   g_btnX = w - UI(108);
   if(g_btnX < 0) g_btnX = 0;
  }
void UpdateButton(string name, double price, string text, int dir)
  {
   if(ObjectFind(0, name) < 0) return;
   int x = 0, y = 0;
   if(ChartTimePriceToXY(0, 0, RightAnchor(), price, x, y))
     {
      // v1.08b：挂单按钮宽 120，右边缘与 CALL/COLUMN 右边缘对齐（w-8），左 X = g_btnX - UI(20)
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, g_btnX - UI(20));
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y - UI(11));
     }
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   color bg = (dir == DIR_UP) ? CLR_BUY_BG : ((dir == DIR_DOWN) ? CLR_SELL_BG : CLR_FLAT_BG);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
  }
// v1.25: 0.79/0.49 挂单线颜色随方向动态 (long=绿, short=红, flat=灰), 与按钮配色统一
void UpdateMidLines(int dir)
  {
   color clr = (dir == DIR_UP) ? CLR_BUY_BG : ((dir == DIR_DOWN) ? CLR_SELL_BG : CLR_FLAT_BG);
   string n79 = HName(RATIO_079);
   string n49 = HName(RATIO_049);
   if(ObjectFind(0, n79) >= 0)
      ObjectSetInteger(0, n79, OBJPROP_COLOR, clr);
   if(ObjectFind(0, n49) >= 0)
      ObjectSetInteger(0, n49, OBJPROP_COLOR, clr);
  }
void UpdateLabel(string name, double price)
  {
   if(ObjectFind(0, name) < 0) return;
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
  }
// 右对齐标签更新：像素定位，右边缘对齐挂单按钮右边缘（w-8 = g_btnX+100）
//  v1.08b：0.19 标签右边缘与 0.79/0.49 按钮、CALL 按钮右边缘对齐
void UpdateLabelRight(string name, double price, string text)
  {
   if(ObjectFind(0, name) < 0) return;
   int x = 0, y = 0;
   if(!ChartTimePriceToXY(0, 0, RightAnchor(), price, x, y)) return;
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, g_btnX + UI(100));  // 右边缘 = w-UI(8)，与按钮列右对齐
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y - UI(2));
   ObjectSetString(0, name, OBJPROP_TEXT, text);
  }

//+------------------------------------------------------------------+
//| v1.17: STEP UP/DOWN 按钮 (1.00/0.00/0.79/0.49 各一对)
//| 单击 = 移动区间比例 InpStepPercent%, 双击 300ms 内 = ×10
//+------------------------------------------------------------------+
// v1.61: STEP 几何宏提前到这里 — 原定义在 UpdateSwapButton/UpdateAdjustButton 之后,
//   但这两个函数 (顶部按钮布局重构后) 也引用了这些宏, MQL5 按文件顺序解析 #define
//   (不像 C 预处理器全单元展开), 前置引用会报 undeclared identifier
#define STEP_BTN_W     22   // 按钮宽度
#define STEP_BTN_H     18   // 按钮高度
#define STEP_BTN_GAP   2    // UP/DOWN 之间的间距
#define STEP_BTN_X     6    // 距图表左边距
#define STEP_BTN_DN_OFFSET (STEP_BTN_W + STEP_BTN_GAP)

void UpdateSwapButton(int dir)
  {
   string name = SwapName();
   if(ObjectFind(0, name) < 0) return;
   string t = (dir == DIR_UP) ? "LONG" : ((dir == DIR_DOWN) ? "SHORT" : "FLAT");
   ObjectSetString(0, name, OBJPROP_TEXT, t);
   color bg = (dir == DIR_UP) ? CLR_BUY_BG : ((dir == DIR_DOWN) ? CLR_SELL_BG : CLR_FLAT_BG);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);

   // v1.61: 顶部按钮布局重构 — 改为左对齐链 (类似底部 HIDE/RISK/FVG 链)
   //   LONG   X = stepBox + 8          (STEP 列右 8px, 类 HIDE 位置)
   //   ADJUST X = xLong  + UI(80) + 4  (类 RISK)
   //   CANCEL X = xAdj  + UI(80) + 4   (类 FVG)
   //   原居中布局 (SWAP = (w-80)/2) 让顶部右侧留白过大, 且与底部左列无视觉对齐
   int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int x = 0, y = 0;
   double topPrice = MathMax(g_p1, g_p0);
   if(!ChartTimePriceToXY(0, 0, RightAnchor(), topPrice, x, y)) return;
   int stepBox = UI(STEP_BTN_X) + (UI(STEP_BTN_W) + UI(STEP_BTN_GAP)) + UI(STEP_BTN_W);
   int xLong   = stepBox + UI(8);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xLong);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y + UI(4));
  }

// v1.13: ADJUST 按钮位置 (在 SWAP 右侧 4px)
// v1.26: Y 改 y+4 (SWAP/ADJUST/CANCEL 三个按钮统一在 topPrice 线下方 4px, 不被线穿过)
// v1.61: 跟随 LONG 右侧 4px (改为左对齐链, xAdjust = xLong + 84)
// v1.91: 改为钉在图表右下角 — 周期切换/缩放/拖动端点线时自动跟随
//   使用 ChartGetInteger(CHART_WIDTH_IN_PIXELS/CHART_HEIGHT_IN_PIXELS) 取当前像素尺寸
//   X = w - UI(80) - UI(4) (按钮宽 80 + 4px 右偏移), Y = h - UI(22) - UI(4) (按钮高 22 + 4px 下偏移)
//   CHARTEVENT_CHART_CHANGE 已设 g_dirty=true → RefreshAll → 本函数 → 自动跟随
void UpdateAdjustButton()
  {
   string name = AdjustName();
   if(ObjectFind(0, name) < 0) return;
   int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   int x = w - UI(80) - UI(4);   // 4px 右偏移
   int y = h - UI(22) - UI(4);   // 4px 下偏移
   if(x < 0) x = 0;
   if(y < 0) y = 0;
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
  }

// v1.91: SIGNAL 按钮文字 + 颜色 + sticky 同步
//   开 (g_signalAlert=true):  文字 "SIGNAL" + 黄色底  + sticky=true  (按下 = 监控中, 黄与 RISK 1% 同色)
//   关 (g_signalAlert=false): 文字 "OFF"    + 灰色底  + sticky=false (弹起 = 已关闭, 灰与 CANCEL 一致)
//   与 HIDE 按钮设计一致 — sticky 表示当前生效状态, 不是点击瞬时态
//   读 g_signalAlert 而非 InpSignalAlert: MQL5 input 是编译期常量, 按钮切换改运行时变量
void UpdateSignalButton()
  {
   string name = SignalName();
   if(ObjectFind(0, name) < 0) return;
   ObjectSetString (0, name, OBJPROP_TEXT,    g_signalAlert ? "SIGNAL" : "OFF");
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, g_signalAlert ? C'255,193,7' : C'120,120,120');   // v1.96: 开=黄(同 RISK 1%), 关=灰(同 CANCEL)
   ObjectSetInteger(0, name, OBJPROP_STATE,   g_signalAlert);
  }

// v1.91: SIGNAL 按钮位置 — 占用原 ADJUST 位置 (LONG 右侧 4px, 与 SWAP/ADJUST/CANCEL 同 Y)
//   Y 由顶线 (topPrice = max(g_p1, g_p0)) 决定, 距线下 4px, 与 SWAP/CANCEL 三个按钮 Y 对齐
void UpdateSignalButtonPosition()
  {
   string name = SignalName();
   if(ObjectFind(0, name) < 0) return;
   int x = 0, y = 0;
   double topPrice = MathMax(g_p1, g_p0);
   if(!ChartTimePriceToXY(0, 0, RightAnchor(), topPrice, x, y)) return;
   int stepBox  = UI(STEP_BTN_X) + (UI(STEP_BTN_W) + UI(STEP_BTN_GAP)) + UI(STEP_BTN_W);
   int xSignal  = stepBox + UI(8) + UI(80) + UI(4);   // = 原 ADJUST X
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xSignal);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y + UI(4));
  }

// v1.91: 切换信号提醒总开关 — OnChartEvent 收到 SIGNAL 按钮点击时调用
//   切换运行时变量 g_signalAlert (input 不能改), 同时重置状态: 三个 fired 全 false, g_prevSamplePrice=0 (下一 tick 重新采样), g_prevP1/P0 重新初始化
//   v2.06: 三个 fired 已覆盖 Alert/Print/SendNotification 三通道, 无需额外推送锁
void ToggleSignalAlert()
  {
   g_signalAlert      = !g_signalAlert;
   g_pullbackFired    = false;
   g_breakUpFired     = false;   // v1.99: 突破上界锁
   g_breakDownFired   = false;   // v1.99: 突破下界锁
   g_prevSamplePrice  = 0.0;    // 强制下一 tick 重新采样, 避免"按钮开瞬间就报警"
   g_prevP1           = g_p1;
   g_prevP0           = g_p0;
   g_pullbackLevel    = (g_p1 > 0 && g_p0 > 0) ? (g_p1 - 0.49 * (g_p1 - g_p0)) : 0.0;
   UpdateSignalButton();
   ChartRedraw(0);   // v1.94: 必须手动重绘 — AdvanceFVGState/ToggleHide 都有 (前者直接调, 后者经 RefreshAll), 这里不调导致 UpdateSignalButton 写入的 TEXT/BGCOLOR/STATE 不立即生效, 第一次点击视觉延迟到第二次才显示
   Print("[信号提醒] ", g_signalAlert ? "已启用 (0.49 回调=" + DoubleToString(g_pullbackLevel, _Digits) + ", 突破上下界共用开关)" : "已关闭");
  }

//+------------------------------------------------------------------+
//| v1.17: STEP UP/DOWN 按钮 (1.00/0.00/0.79/0.49 各一对)
//| 单击 = 移动区间比例 InpStepPercent%, 双击 300ms 内 = ×10
//+------------------------------------------------------------------+
// v1.61: STEP 几何宏已上移到 UpdateSwapButton 之前 (line 600-604), 详见那里的注释

bool CreateStepButton(double ratio, int dir)
  {
   string name = StepName(ratio, dir);
   if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0)) return false;
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, UI(STEP_BTN_W));
   ObjectSetInteger(0, name, OBJPROP_YSIZE, UI(STEP_BTN_H));
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, Font(7));
   ObjectSetInteger(0, name, OBJPROP_COLOR, CLR_STEP_TXT);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, CLR_STEP_BG);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, (dir > 0 ? "▲" : "▼"));
   string rstr = DoubleToString(ratio, 2);
   string dirTxt = (dir > 0 ? "向上" : "向下");
   // v1.72: 1.00/0.00 端点 STEP 提示改为 Williams 分形跳转; 0.79/0.49 仍按百分比
   string tip;
   if(ratio == RATIO_100 || ratio == RATIO_000)
      tip = dirTxt + "跳转到最近 Williams 分形 (上界找高/下界找低, 找不到保持不变)";
   else
      tip = dirTxt + "移动 " + rstr + " 线 (单击=" +
            DoubleToString(InpStepPercent, 1) + "%, 双击=×10 加速)";
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tip);
   return true;
  }

bool CreateStepButtons()
  {
   bool ok = true;
   double ratios[4] = {RATIO_100, RATIO_079, RATIO_049, RATIO_000};
   for(int i = 0; i < 4; i++)
     {
      ok = CreateStepButton(ratios[i], +1) && ok;   // UP
      ok = CreateStepButton(ratios[i], -1) && ok;   // DOWN
     }
   return ok;
  }

// 单个 STEP 按钮位置: UP 在左, DOWN 在右, 水平并排
// v1.22: 按视觉高端/低端判定位置, 不按 1.00/0.00 ratio
//   long 时 1.00 在顶 / 0.00 在底; short 时 1.00 在底 / 0.00 在顶 (SWAP 反转)
//   不论方向: 视觉高端 (顶) 按钮在该线下方 (避开上方 K 线)
//             视觉低端 (底) 按钮在该线上方 (避开 HIDE)
//             中间线 (0.79/0.49) 按钮中心与线对齐
void UpdateStepButton(double ratio, int dir)
  {
   string name = StepName(ratio, dir);
   if(ObjectFind(0, name) < 0) return;
   double price = LevelPrice(ratio);
   int x = 0, y = 0;
   if(!ChartTimePriceToXY(0, 0, RightAnchor(), price, x, y)) return;

   // v1.27: STEP 按钮几何按 UI 缩放 (运行期计算, 因 STEP_BTN_* 是编译期宏)
   int btnW = UI(STEP_BTN_W);
   int btnH = UI(STEP_BTN_H);
   int gap  = UI(STEP_BTN_GAP);
   int x0   = UI(STEP_BTN_X);
   int off  = btnW + gap;

   int xUp   = x0;
   int xDown = x0 + off;
   int btnX  = (dir > 0) ? xUp : xDown;

   double topPrice = MathMax(g_p1, g_p0);
   double botPrice = MathMin(g_p1, g_p0);
   const double eps = _Point * 0.5;

   int btnY;
   if(MathAbs(price - topPrice) < eps)
     {
      // 视觉高端: 按钮位于该线下方 (避开上方 K 线)
      btnY = y + UI(2);
     }
   else if(MathAbs(price - botPrice) < eps)
     {
      // 视觉低端: 按钮位于该线上方 (避开底部 HIDE)
      btnY = y - btnH - UI(2);
     }
   else
     {
      // 中间线 (0.79 / 0.49): 按钮中心与线对齐, 线穿过两按钮中心
      btnY = y - btnH / 2;
     }

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, btnX);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, btnY);
  }

void UpdateStepButtons()
  {
   double ratios[4] = {RATIO_100, RATIO_079, RATIO_049, RATIO_000};
   for(int i = 0; i < 4; i++)
     {
      UpdateStepButton(ratios[i], +1);
      UpdateStepButton(ratios[i], -1);
     }
  }

// 计算给定 ratio 和方向的"目标价格" — 在 fib 顺序约束下
//   1.00 / 0.00 (端点): 完全自由 — 用户主动设的边界, 可以推开挂单线
//   0.79 / 0.49 (挂单线): 不能跨过对方, 也不能跨过顶/底端点
// v1.23: 修复 long 模式下 fib 系数反转问题
//   fib 系数 0.79 永远比 0.49 更靠近 1.00 端点, 因此:
//   - Long 模式 (1.00 在底, 默认插入): 0.79 < 0.49 数值, 0.79 在底部, 0.49 在中部
//   - Short 模式 (1.00 在顶, 按 SWAP): 0.79 > 0.49 数值, 0.79 在顶部, 0.49 在中部
//   旧代码按 ratio 写死 0.79/0.49 的数值关系 (假设 0.79 > 0.49 即 short 模式),
//   long 模式下约束条件几乎永远触发, 导致 0.79 DOWN / 0.49 UP 失灵
//   改用 upperLine/lowerLine 按视觉位置判定 — long/short 都能正常工作
double ClampStepMove(double ratio, int dir, double step)
  {
   double oldPrice = LevelPrice(ratio);
   double newPrice = oldPrice + dir * step;

   double margin    = _Point;            // 留 1 个点的安全 gap, 避免 fib 关系"=="
   double topPrice  = MathMax(g_p1, g_p0);   // 视觉高端 (屏幕顶部)
   double botPrice  = MathMin(g_p1, g_p0);   // 视觉低端 (屏幕底部)

   // 端点 1.00 / 0.00 完全自由 — 用户主动设的边界, 可以推开挂单线
   if(ratio == RATIO_100 || ratio == RATIO_000)
      return newPrice;

   // v1.23: 0.79 / 0.49 互撞按视觉位置自适应 — long/short 都能正常工作
   double upperLine = MathMax(g_p79, g_p49);   // 视觉上更靠近 topPrice 的线 (不论 long/short)
   double lowerLine = MathMin(g_p79, g_p49);   // 视觉上更靠近 botPrice 的线

   if(ratio == RATIO_079 || ratio == RATIO_049)
     {
      // 当前线在视觉上是 upper 还是 lower?
      bool isUpper = (ratio == RATIO_079) ? (g_p79 >= g_p49) : (g_p49 >= g_p79);
      if(isUpper)
        {
         // 上方线 (视觉靠近顶): UP 受限于 topPrice, DOWN 受限于下方线
         if(dir > 0 && newPrice > topPrice - margin)  return oldPrice;
         if(dir < 0 && newPrice < lowerLine + margin) return oldPrice;
        }
      else
        {
         // 下方线 (视觉靠近底): UP 受限于上方线, DOWN 受限于 botPrice
         if(dir > 0 && newPrice > upperLine - margin) return oldPrice;
         if(dir < 0 && newPrice < botPrice + margin)  return oldPrice;
        }
     }

   return newPrice;
  }

// v1.72: 1.00/0.00 端点 STEP — 跳转到最近 Williams 分形
//   上界 (高价线, 视觉上更高的那条) ▲ 按钮: 找最近的 Williams 高分形且 High > 当前上界价
//   上界 (高价线) ▼ 按钮:                              且 High < 当前上界价
//   下界 (低价线, 视觉上更低的那条) ▲ 按钮: 找最近的 Williams 低分形且 Low  > 当前下界价
//   下界 (低价线) ▼ 按钮:                              且 Low  < 当前下界价
//   搜索方向: j=1 (最右已收线) → firstBar (最左可见), 第一个匹配即返回 — 离当前价"最近" = 离 shift=0 时间最近
//   排除 shift=0 未收线 bar (Williams 定义需要 j+1 < total, j 至少 1)
//   搜索范围: 图表可见区 (firstBar)
//   找不到分形 → Alert 提示, 端点保持不变
//   移动端点后 0.79/0.49 按理论比例回归 (复用 ApplyStepDrag 行为)
// 前向声明: IsWilliamsLow/IsWilliamsHigh 在文件靠后定义 (line ~2657), 这里提前引用需要先声明
bool IsWilliamsLow (int j);
bool IsWilliamsHigh(int j);
bool ApplyStepToFractal(double ratio, int dir)
  {
   double curPrice = LevelPrice(ratio);
   double topPrice = MathMax(g_p1, g_p0);
   double botPrice = MathMin(g_p1, g_p0);
   const double eps = _Point * 0.5;
   bool isUpper = (MathAbs(curPrice - topPrice) < eps);
   bool isLower = (MathAbs(curPrice - botPrice) < eps);
   if(!isUpper && !isLower)
     {
      Alert("[FibLimitAssist] STEP ", DoubleToString(ratio, 2),
            ": fib 区间未定义 (1.00 == 0.00), 端点保持不变");
      return false;
     }

   // 可见区范围 (排除 shift=0 未收线)
   int firstBar = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR, 0);
   if(firstBar < 1) firstBar = 1;
   int totalBars = Bars(_Symbol, _Period);
   int maxJ = MathMin(firstBar, totalBars - 2);   // j+1 < totalBars 才能 IsWilliams* 不越界
   if(maxJ < 1)
     {
      Alert("[FibLimitAssist] STEP ", DoubleToString(ratio, 2),
            ": 可见区数据不足, 端点保持不变");
      return false;
     }

   bool        isUpBtn  = (dir > 0);
   string      lineRole = isUpper ? "上界" : "下界";
   string      dirSign  = isUpBtn ? "▲" : "▼";
   string      target   = isUpBtn ? "更高" : "更低";
   double      foundPrice = 0;
   int         foundBar   = -1;

   if(isUpper)
     {
      // 上界 → 找 Williams 高分形
      for(int j = 1; j <= maxJ; j++)
        {
         if(!IsWilliamsHigh(j)) continue;
         double h = iHigh(_Symbol, _Period, j);
         if(h <= 0) continue;
         bool match = isUpBtn ? (h > curPrice) : (h < curPrice);
         if(match) { foundPrice = h; foundBar = j; break; }
        }
      if(foundBar < 0)
        {
         Alert("[FibLimitAssist] STEP ", DoubleToString(ratio, 2),
               " (", lineRole, ") ", dirSign, ": 可见区找不到",
               target, " 的 Williams 高分形, 端点保持不变");
         return false;
        }
     }
   else  // isLower
     {
      // 下界 → 找 Williams 低分形
      for(int j = 1; j <= maxJ; j++)
        {
         if(!IsWilliamsLow(j)) continue;
         double l = iLow(_Symbol, _Period, j);
         if(l <= 0) continue;
         bool match = isUpBtn ? (l > curPrice) : (l < curPrice);
         if(match) { foundPrice = l; foundBar = j; break; }
        }
      if(foundBar < 0)
        {
         Alert("[FibLimitAssist] STEP ", DoubleToString(ratio, 2),
               " (", lineRole, ") ", dirSign, ": 可见区找不到",
               target, " 的 Williams 低分形, 端点保持不变");
         return false;
        }
     }

   Print("[STEP-FRACTAL] ", DoubleToString(ratio, 2),
         " (", lineRole, ") ", dirSign, " → 跳转到", target, " Williams ",
         isUpper ? "高" : "低", "分形",
         " old=", DoubleToString(curPrice, _Digits),
         " new=", DoubleToString(foundPrice, _Digits),
         " srcBar=", foundBar,
         " srcTime=", TimeToString(iTime(_Symbol, _Period, foundBar)));
   ApplyStepDrag(ratio, foundPrice);  // 0.79/0.49 自动按理论比例回归
   return true;
  }

// 处理 STEP 按钮点击: 解析 name → (ratio, dir), 分支处理
// v1.72: 1.00/0.00 端点 → 跳转到最近 Williams 分形 (ApplyStepToFractal)
//        0.79/0.49       → 保持原 InpStepPercent 百分比 + 双击 ×10 行为
void ApplyStepButton(string name)
  {
   string sfx = StringSubstr(name, StringLen(g_prefix));
   int dir = 0;
   int rint = -1;
   if(StringFind(sfx, "STEP_UP_") == 0)
     {
      dir  = +1;
      rint = (int)StringToInteger(StringSubstr(sfx, 8));
     }
   else if(StringFind(sfx, "STEP_DN_") == 0)
     {
      dir  = -1;
      rint = (int)StringToInteger(StringSubstr(sfx, 8));
     }
   else return;
   if(rint != 0 && rint != 49 && rint != 79 && rint != 100) return;
   double ratio = rint / 100.0;

   // 释放按钮视觉
   ObjectSetInteger(0, name, OBJPROP_STATE, false);

   // v1.72: 1.00/0.00 端点 STEP 改走 Williams 分形跳转 (不再用百分比步长, 单/双击行为一致)
   if(ratio == RATIO_100 || ratio == RATIO_000)
     {
      g_lastStepName   = name;
      g_lastStepTimeMs = GetTickCount();   // 仍记录, 避免与 0.79/0.49 的双击状态串台
      ApplyStepToFractal(ratio, dir);
      return;
     }

   // v1.17: 0.79/0.49 保持原 InpStepPercent 百分比行为 (双击 ×10)
   // 双击检测: 300ms 内同按钮再点 → ×10 倍步长
   long nowMs = GetTickCount();
   int  mult  = 1;
   if(g_lastStepName == name && (nowMs - g_lastStepTimeMs) <= STEP_DBLCLICK_MS)
      mult = 10;
   g_lastStepName   = name;
   g_lastStepTimeMs = nowMs;

   double range = MathAbs(g_p1 - g_p0);
   if(range <= 0)
     {
      Print("[STEP] 区间未定义, 忽略 ", sfx);
      return;
     }
   double step = range * InpStepPercent / 100.0 * (double)mult;
   if(step < _Point) step = _Point;

   double newPrice = ClampStepMove(ratio, dir, step);
   double oldPrice = LevelPrice(ratio);
   if(MathAbs(newPrice - oldPrice) < _Point * 0.5)
     {
      Print("[STEP] ", sfx, " 已被 fib 边界约束, 不移动 (old=", DoubleToString(oldPrice, _Digits), ")");
      return;
     }

   Print("[STEP] ", sfx,
         " mult=×", mult,
         " step=", DoubleToString(step, _Digits),
         " old=", DoubleToString(oldPrice, _Digits),
         " new=", DoubleToString(newPrice, _Digits),
         mult > 1 ? " (双击)" : "");
   // v1.19: 用 ApplyStepDrag 而不是 ApplyDrag — 端点变化时不要重置 0.79/0.49
   //   避免点击 1.00/0.00 时把用户手调的 0.79/0.49 突然重置到理论位置 (跳动/消失)
   ApplyStepDrag(ratio, newPrice);
  }

// v1.30: STEP 按钮移动端点 (1.00/0.00) → 同步重置 0.79/0.49 到理论值 (与拖动端点行为一致),
//   让中间线成比例跟随. 命中 0.79/0.49 本身仍只动单条线, 不互相打扰 (与拖动行为一致).
// 历史: v1.19 为避免按钮跳动改成"端点 STEP 也不重置", v1.30 用户反馈应与鼠标拖动行为对齐.
void ApplyStepDrag(double r, double price)
  {
   if(r == RATIO_100)
     {
      g_p1 = price;
      // v1.30: 端点 STEP 与 ApplyDrag 行为对齐 — 中间线成比例回归
      g_p79 = TheoPrice(RATIO_079, g_p1, g_p0);
      g_p49 = TheoPrice(RATIO_049, g_p1, g_p0);
     }
   else if(r == RATIO_000)
     {
      g_p0 = price;
      g_p79 = TheoPrice(RATIO_079, g_p1, g_p0);
      g_p49 = TheoPrice(RATIO_049, g_p1, g_p0);
     }
   else if(r == RATIO_079) g_p79 = price;
   else if(r == RATIO_049) g_p49 = price;
   else return;
   // v1.15: 端点/挂单线位置不再记忆, 无需保存
   RefreshAll();
  }

// 顶部按钮 — v1.61: 改为左对齐链 (LONG → ADJUST → CANCEL), LONG/ADJUST 由各自函数定位, 这里只设 CANCEL
// v1.26: 改到线下方 (y+4), 与 SWAP/ADJUST 三个按钮统一在 topPrice 线下方 4px, 不被线穿过
// v1.65: 新增第二排 — EVEN / CHALF / CALL 放在 CANCEL 正下方, X 对齐顶部 LONG/ADJUST/CANCEL (stepBox+8/92/176)
// v1.97: 三按钮宽统一 80, CALL X 仍按 UI(80) 算 (stepBox+176) — 实际右沿 stepBox+256, 比 v1.96 (宽 100) 缩进 20px, 不影响挂单列右对齐 (挂单列右边缘 = g_btnX+UI(100) = w-8, 与 CALL 实际宽度解耦)
void UpdateTopButtons()
  {
   double topPrice = MathMax(g_p1, g_p0);
   int x = 0, y = 0;
   if(!ChartTimePriceToXY(0, 0, RightAnchor(), topPrice, x, y)) return;
   int yBtn = y + UI(4);

   // v1.61: CANCEL X = stepBox + 8 + 80 + 4 + 80 + 4 = stepBox + 176 (ADJUST 右侧相邻 4px)
   //   原右对齐 (g_btnX) 已废弃 — 顶部按钮全部左对齐
   // v1.64: 撤销 v1.63 — HIDE/RISK/FVG 恢复到底部左侧 (UpdateBottomButtons), 顶部按钮链回到 LONG→ADJUST→CANCEL 3 个
   int stepBox = UI(STEP_BTN_X) + (UI(STEP_BTN_W) + UI(STEP_BTN_GAP)) + UI(STEP_BTN_W);
   int xCancel = stepBox + UI(8) + UI(80) + UI(4) + UI(80) + UI(4);
   string cancelName = CancelPendingName();
   if(ObjectFind(0, cancelName) >= 0)
     {
      ObjectSetInteger(0, cancelName, OBJPROP_XDISTANCE, xCancel);
      ObjectSetInteger(0, cancelName, OBJPROP_YDISTANCE, yBtn);
     }

   // v1.82: EVEN / CHALF / CALL 移到 0.49 挂单线, 让 0.49 挂单线从三个按钮中间穿过
   //   v1.66 顶部第二排 → v1.82 改为中段: X 保持原位置 (stepBox+8/92/196), 仅调整 Y
   //   buttonY = screenY(0.49 线) - UI(11), UI(11)=按钮高 UI(22)/2, 让按钮几何中心对齐 0.49 线
   //   0.49 线用 g_p49 (LevelPrice 内部: 用户拖动过的取 g_p49, 否则取理论值)
   double midPrice = LevelPrice(RATIO_049);
   int mx = 0, my = 0;
   if(ChartTimePriceToXY(0, 0, RightAnchor(), midPrice, mx, my))
     {
      int yBtn49 = my - UI(11);   // 按钮顶部 Y, 让按钮中心 = my (0.49 线屏幕 Y)
      if(yBtn49 < 0) yBtn49 = 0;
      if(ObjectFind(0, EvenName()) >= 0)
        {
         ObjectSetInteger(0, EvenName(), OBJPROP_XDISTANCE, stepBox + UI(8));
         ObjectSetInteger(0, EvenName(), OBJPROP_YDISTANCE, yBtn49);
        }
      if(ObjectFind(0, CloseHalfName()) >= 0)
        {
         ObjectSetInteger(0, CloseHalfName(), OBJPROP_XDISTANCE, stepBox + UI(8) + UI(80) + UI(4));
         ObjectSetInteger(0, CloseHalfName(), OBJPROP_YDISTANCE, yBtn49);
        }
      if(ObjectFind(0, CloseAllName()) >= 0)
        {
         ObjectSetInteger(0, CloseAllName(), OBJPROP_XDISTANCE, stepBox + UI(8) + UI(80) + UI(4) + UI(80) + UI(4));
         ObjectSetInteger(0, CloseAllName(), OBJPROP_YDISTANCE, yBtn49);
        }
     }
  }

// 最下面那根线的全部按钮 (v1.08)：
//  左侧：HIDE(80) | RISK(80) | FVG(80) | ... | MARKET(110) + STOP(110) 横向居中 | ...
//  右侧仓位按钮 (EVEN/CHALF/CALL) 已在 v1.65 移到顶部第二排 (UpdateTopButtons)
// v1.74: MARKET + STOP 改为横向相邻 (4px 间隔), 一对整体居中
//   v1.32-v1.73 是 MARKET 居中 + STOP 在 MARKET 正下方 (上下排)
//   现在 MKT 和 STP 同 Y (yBtn), STP 在 MKT 右边 4px, 整体 (224px) 关于图表中心左右对称
//   LONG/SHORT 模式统一: STP 永远在 MKT 右边 (用户对两种方向要求一致)
// v1.77: 中间新增实时点差标签 (形如 "(1.5)"), 因此 gap 从 UI(4) 扩大到 UI(56) 容纳 ~40px 标签宽度 + 余量
//   整体宽度 110+56+110=276 关于图表中心 w/2 左右对称; spread 标签用 ANCHOR_CENTER 居中到 gap 几何中心
//   (gap 扩大的取舍: 与 v1.74 的 "4px" 紧贴布局冲突, 但 4px 无法容纳可读文字, 用户的 "在中间加数字" 优先)
void UpdateBottomButtons()
  {
   double botPrice = MathMin(g_p1, g_p0);
   int x = 0, y = 0;
   if(!ChartTimePriceToXY(0, 0, RightAnchor(), botPrice, x, y)) return;
   int yBtn = y - UI(26); if(yBtn < 0) yBtn = 0;
   int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);

   // v1.77: MKT(110) + 56px 间隔(放点差标签) + STP(110) = 276 整体, 关于 w/2 左右对称
   //   v1.75 gap=UI(40) → v1.76 → v1.77 gap=UI(56): 用户反馈 v1.75-v1.76 的 40px 装不下 "(15.0)" 文字
   //   字号 Font(7) 的 5 字符文字宽度约 35-45px, 40px 时括号刚好压在两侧按钮边缘
   //   56px 给文字每侧 ~8-10px 余量, 视觉清晰不重叠
   int marketW  = UI(110);
   int gapW     = UI(56);
   int pairW    = marketW + gapW + marketW;
   int pairLeft = (w - pairW) / 2;
   int marketX  = pairLeft;
   int stopX    = pairLeft + marketW + gapW;
   int spreadX  = pairLeft + marketW + gapW / 2;   // gap 几何中心, ANCHOR_CENTER 居中

   // 左侧 HIDE / RISK
   // v1.22: HIDE / RISK 右移到 STEP 按钮 (X=[6, 52]) 右侧, 避免 long 模式
   //   0.00 在底部时与 0.00 STEP 按钮 Y 重叠
   //   STEP 按钮范围 X=[STEP_BTN_X, STEP_BTN_X + STEP_BTN_DN_OFFSET + STEP_BTN_W]
   // v1.27: 全部按 UI 缩放
   // v1.64: 从顶部撤回 (v1.63 移到顶部 CANCEL 右侧, 验证后用户改回原方案) — 恢复到底部左侧
   int stepBox = UI(STEP_BTN_X) + (UI(STEP_BTN_W) + UI(STEP_BTN_GAP)) + UI(STEP_BTN_W); // 缩放后的 STEP 列右边缘
   int xHide   = stepBox + UI(8);                                 // HIDE 左 X
   int xFVG    = xHide + UI(80) + UI(4);                          // v1.83: FVG 左 X (对调前是 RISK 位)
   int xRisk   = xFVG  + UI(80) + UI(4);                          // v1.83: RISK 左 X (对调到最右, FVG 之后)
   if(ObjectFind(0, HideName()) >= 0)
     {
      ObjectSetInteger(0, HideName(), OBJPROP_XDISTANCE, xHide);
      ObjectSetInteger(0, HideName(), OBJPROP_YDISTANCE, yBtn);
     }
   // v1.83: FVG/RISK 位置对调 — FVG 移到原 RISK 位 (紧贴 HIDE 右侧), RISK 移到 FVG 原位 (最右)
   if(ObjectFind(0, FVGButtonName()) >= 0)
     {
      ObjectSetInteger(0, FVGButtonName(), OBJPROP_XDISTANCE, xFVG);
      ObjectSetInteger(0, FVGButtonName(), OBJPROP_YDISTANCE, yBtn);
     }
   if(ObjectFind(0, RiskName()) >= 0)
     {
      ObjectSetInteger(0, RiskName(), OBJPROP_XDISTANCE, xRisk);
      ObjectSetInteger(0, RiskName(), OBJPROP_YDISTANCE, yBtn);
     }

   // 中间 MKT
   if(ObjectFind(0, MarketName()) >= 0)
     {
      ObjectSetInteger(0, MarketName(), OBJPROP_XDISTANCE, marketX);
      ObjectSetInteger(0, MarketName(), OBJPROP_YDISTANCE, yBtn);
     }

   // v1.08：MKT 两侧 P/L 标签（OBJ_LABEL 像素定位）
   // v1.74: P/L 标签改为对应到"MKT+STP 整对"的左右两侧 (整体宽度 224)
   //   PL_LEFT:  整对左 4px 处 (即 pairLeft - 6, 文字右对齐)
   //   PL_RIGHT: 整对右 4px 处 (即 stopX + marketW + 6, 文字左对齐)
   if(ObjectFind(0, PnLLeftName()) >= 0)
     {
      ObjectSetInteger(0, PnLLeftName(), OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
      ObjectSetInteger(0, PnLLeftName(), OBJPROP_XDISTANCE, pairLeft - UI(6));
      ObjectSetInteger(0, PnLLeftName(), OBJPROP_YDISTANCE, yBtn + UI(4));
     }
   if(ObjectFind(0, PnLRightName()) >= 0)
     {
      ObjectSetInteger(0, PnLRightName(), OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, PnLRightName(), OBJPROP_XDISTANCE, stopX + marketW + UI(6));
      ObjectSetInteger(0, PnLRightName(), OBJPROP_YDISTANCE, yBtn + UI(4));
     }

   // v1.65: 右侧 EVEN / CHALF / CALL 已移到顶部第二排 (UpdateTopButtons), 这里不再设置
   //   历史: v1.61 右侧 g_btnX 右对齐 → v1.62/v1.63 镜像到底部/顶部对齐 → v1.64 撤回 → v1.65 最终方案: 顶部第二排

   // v1.74: STOP 与 MKT 横向相邻 (右边 4px), 同 Y (yBtn) — 不再上下排
   //   v1.32-v1.73 是在 MARKET 正下方 y + UI(4); 现在统一到 yBtn (与 MKT 同高)
   // v1.75: gap 从 4px 扩到 40px (见函数头注释), STP 仍在 MKT 右边, 整体居中
   if(ObjectFind(0, StopName()) >= 0)
     {
      ObjectSetInteger(0, StopName(), OBJPROP_XDISTANCE, stopX);
      ObjectSetInteger(0, StopName(), OBJPROP_YDISTANCE, yBtn);
     }

   // v1.77: 点差标签 — gap 几何中心, ANCHOR_CENTER 居中 (Y=yBtn+UI(9) 让文字在 22px 按钮中视觉居中)
   if(ObjectFind(0, SpreadName()) >= 0)
     {
      ObjectSetInteger(0, SpreadName(), OBJPROP_XDISTANCE, spreadX);
      ObjectSetInteger(0, SpreadName(), OBJPROP_YDISTANCE, yBtn + UI(9));
     }
  }

// 0.79/0.49 挂单按钮文字：保留比例与手数，去掉中间的 BL/SL（颜色已区分方向）
string BuildButtonText(double r, double lot)
  {
   return StringFormat("%.2f (%.*f)", r, InpLotDecimals, lot);
  }

// HIDE/SHOW 按钮文字 + 颜色 + sticky 状态（v1.07）
//  · 显示态（g_hidden=false）：文字 HIDE，底色深灰，按钮弹起
//  · 隐藏态（g_hidden=true）：文字 SHOW，底色橙黄，按钮按下
void UpdateHideButton()
  {
   string name = HideName();
   if(ObjectFind(0, name) < 0) return;
   ObjectSetString(0, name, OBJPROP_TEXT, g_hidden ? "SHOW" : "HIDE");
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, g_hidden ? CLR_HIDE_ON : CLR_HIDE_OFF);
   ObjectSetInteger(0, name, OBJPROP_STATE, g_hidden);   // sticky：按下表示当前隐藏中
  }

// 风险按钮文字 + 颜色（v1.07 三档 → v2.11 四档：循环档位 0.25 → 0.5 → 1 → 2 → 0.25；底色按档位变化，比例越高越醒目）
void UpdateRiskButton()
  {
   string name = RiskName();
   if(ObjectFind(0, name) < 0) return;
   string s = DoubleToString(g_riskPercent, 2);   // v2.11: 精度 1 → 2 (支持 0.25 显示, 0.5/1.0/2.0 末尾 .0 由后续去尾处理)
   int dot = StringFind(s, ".");
   if(dot >= 0 && StringSubstr(s, dot + 1) == "0")   // 去掉末尾 ".0"，如 1.0 → 1 (但 0.25 不能去掉末尾的 0, 否则变 0.2 — 实际 0.25 末尾是 "25", 不触发)
      s = StringSubstr(s, 0, dot);
   if(dot >= 0 && StringSubstr(s, dot + 1) == "00")  // v2.11: 多去掉末尾 "00" — 如 0.50 → 0.5 (0.25 显示为 "0.25", 0.5 显示为 "0.5", 1.0 → "1", 2.0 → "2")
      s = StringSubstr(s, 0, dot + 1) + StringSubstr(s, dot + 3);
   ObjectSetString(0, name, OBJPROP_TEXT, s + "%");

   // 四档配色：极低风险浅绿 / 低风险绿 / 中风险黄 / 高风险红
   color bg = CLR_RISK_MID;
   if(MathAbs(g_riskPercent - 0.25) < 1e-9)      bg = CLR_RISK_VERYLOW;
   else if(MathAbs(g_riskPercent - 0.5) < 1e-9)  bg = CLR_RISK_LOW;
   else if(MathAbs(g_riskPercent - 1.0) < 1e-9)  bg = CLR_RISK_MID;
   else if(MathAbs(g_riskPercent - 2.0) < 1e-9)  bg = CLR_RISK_HI;
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
  }

// 市价按钮文字与颜色：按当前方向显示 BUY MKT / SELL MKT，FLAT 时显示 --
void UpdateMarketButton(int dir)
  {
   string name = MarketName();
   if(ObjectFind(0, name) < 0) return;
   string t = (dir == DIR_UP) ? "BUY MKT" : ((dir == DIR_DOWN) ? "SELL MKT" : "--");
   color bg = (dir == DIR_UP) ? CLR_BUY_BG : ((dir == DIR_DOWN) ? CLR_SELL_BG : CLR_FLAT_BG);
   ObjectSetString(0, name, OBJPROP_TEXT, t);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
  }

// v1.31: 突破挂单按钮文字与颜色 — 按方向显示 BUY STOP / SELL STOP / --
void UpdateStopButton(int dir)
  {
   string name = StopName();
   if(ObjectFind(0, name) < 0) return;
   string t = (dir == DIR_UP) ? "BUY STP" : ((dir == DIR_DOWN) ? "SELL STP" : "--");
   color bg = (dir == DIR_UP) ? CLR_BUY_BG : ((dir == DIR_DOWN) ? CLR_SELL_BG : CLR_FLAT_BG);
   ObjectSetString(0, name, OBJPROP_TEXT, t);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
  }

// v1.45: FVG 切换按钮文字/颜色/sticky 同步
// v1.83: 升级为 3 状态循环 — 文字 + 颜色 + sticky 都由 g_fvgState 派生
//   state=0 (FVG)  → "FVG"  文字, CLR_FVG_OFF 浅灰, sticky=false (不按下, 表示当前启用)
//   state=1 (FILL) → "FILL" 文字, CLR_FILL_ON  青蓝, sticky=false
//   state=2 (OFF)  → "OFF"  文字, CLR_FVG_ON  橙黄, sticky=true  (按下, 表示当前关闭)
// MQL5 OBJ_BUTTON 的 STATE 只支持 bool (按下/不按下), 这里 STATE 用作 "state=2 时高亮提示" 信号
void UpdateFVGButton()
  {
   string name = FVGButtonName();
   if(ObjectFind(0, name) < 0)
     {
      CreateActionButton(name, 80, "FVG", CLR_FVG_OFF,
                         "FVG 切换 (3 态循环): FVG=只显未/部分填补 (绿/红), FILL=再显完全填补 (灰, 需 InpFVG_ShowFilled=true), OFF=全隐藏");
      if(ObjectFind(0, name) < 0) return;
     }
   string text;
   color  bg;
   bool   sticky;
   if(g_fvgState == 0)      { text = "FVG";  bg = CLR_FVG_OFF;   sticky = false; }
   else if(g_fvgState == 1) { text = "FILL"; bg = CLR_FILL_ON;   sticky = false; }
   else                     { text = "OFF";  bg = CLR_FVG_ON;    sticky = true;  }
   ObjectSetString (0, name, OBJPROP_TEXT,    text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_STATE,   sticky);
   // v1.59: FVG 按钮完全独立于 HIDE — 不再跟随 g_hidden 切换 OBJPROP_HIDDEN
   //   (由 ApplyHidden 跳过 FVG 按钮保证 — HIDE 时按钮位置/可见性不变)
  }

// v1.83: 状态机前进 — 点击 FVG 按钮时调用, state = (state + 1) % 3
//   v1.81 双 bool 时代的翻转逻辑 (g_fvgEnabled = !g_fvgEnabled; g_fillShown = !g_fillShown) 替换为单状态机循环
void AdvanceFVGState()
  {
   g_fvgState = (g_fvgState + 1) % 3;
   UpdateFVGButton();       // 同步按钮文字/颜色/sticky
   UpdateFVGDisplay();      // 立即重绘: OFF 时清空矩形, FVG/FILL 时绘制
   ChartRedraw(0);
  }

// v1.45: ENUM_TIMEFRAMES → 分钟数 (用于 FVG 标签时间显示, 不支持范围返回 0)
int TFToMinutes(ENUM_TIMEFRAMES tf)
  {
   switch(tf)
     {
      case PERIOD_M1:  return 1;
      case PERIOD_M2:  return 2;
      case PERIOD_M3:  return 3;
      case PERIOD_M4:  return 4;
      case PERIOD_M5:  return 5;
      case PERIOD_M6:  return 6;
      case PERIOD_M10: return 10;
      case PERIOD_M12: return 12;
      case PERIOD_M15: return 15;
      case PERIOD_M20: return 20;
      case PERIOD_M30: return 30;
      case PERIOD_H1:  return 60;
      case PERIOD_H2:  return 120;
      case PERIOD_H3:  return 180;
      case PERIOD_H4:  return 240;
      case PERIOD_H6:  return 360;
      case PERIOD_H8:  return 480;
      case PERIOD_H12: return 720;
      case PERIOD_D1:  return 1440;
      case PERIOD_W1:  return 10080;
      case PERIOD_MN1: return 43200;
      default:         return 0;
     }
  }

// v1.45: 按当前图表周期推荐默认高级别
//   M1/M2→M5, M3→M15, M5→H1, M15/M30/H1→H4, H4→D1
ENUM_TIMEFRAMES PickDefaultHigherTF(ENUM_TIMEFRAMES current)
  {
   switch(current)
     {
      case PERIOD_M1:
      case PERIOD_M2:  return PERIOD_M5;
      case PERIOD_M3:  return PERIOD_M15;
      case PERIOD_M5:  return PERIOD_H1;
      case PERIOD_M15:
      case PERIOD_M30:
      case PERIOD_H1:  return PERIOD_H4;
      case PERIOD_H4:  return PERIOD_D1;
      default:         return PERIOD_H1;   // 其他 (D1/W1/MN1) 兜底
     }
  }

// v1.58: FVG 状态颜色 — 简化为方向二选一 + 填补灰
//   OBJ_RECTANGLE 的填充色由 OBJPROP_COLOR 控制 (OBJPROP_BGCOLOR 对矩形无效)
color FVGStatusColor(int status, int dir)
  {
   if(status == 2) return CLR_FVG_FILLED;
   if(dir == DIR_UP)   return CLR_FVG_BULL;
   return CLR_FVG_BEAR;
  }

// v1.45: 状态字符 (U/P/F)
string FVGStatusChar(int status)
  {
   if(status == 0) return "U";
   if(status == 1) return "P";
   return "F";
  }

// v1.48: 检测单个周期在 [firstBar, lastBar] 范围内的 FVG
//   经典 ICT 定义 (用户确认): 按时间顺序 3 根 K 线
//     C1 = 中间 K 线左侧 1 根 (shift=i+1)
//     Mid = 中间 K 线 (shift=i)
//     C3 = 中间 K 线右侧 1 根 (shift=i-1, 必须已收线)
//   看涨 FVG: C1.high < C3.low  → 区间 [C1.high, C3.low], 方向 DIR_UP (价格上跳)
//   看跌 FVG: C1.low  > C3.high → 区间 [C3.high, C1.low], 方向 DIR_DOWN
//   formTime = C3 开始时间 (iTime(i-1)) = FVG 在 C3 收线后被确认
void DetectFVG(ENUM_TIMEFRAMES tf, int firstBarShift, int lastBarShift, FVGRecord &arr[])
  {
   ArrayResize(arr, 0);
   if(firstBarShift < lastBarShift + 2) return;   // 至少需要 3 根 (i+1, i, i-1, 必须 i-1 >= 1 已收线)
   int total = Bars(_Symbol, tf);
   if(total < 3) return;
   for(int i = lastBarShift + 1; i <= firstBarShift - 1; i++)   // i = 中间 K 线
     {
      // C1 (左侧更早) | Mid | C3 (右侧更近)
      double c1High  = iHigh(_Symbol, tf, i + 1);
      double c1Low   = iLow (_Symbol, tf, i + 1);
      double midHigh = iHigh(_Symbol, tf, i);
      double midLow  = iLow (_Symbol, tf, i);
      double c3High  = iHigh(_Symbol, tf, i - 1);
      double c3Low   = iLow (_Symbol, tf, i - 1);
      if(c1High <= 0 || c1Low <= 0 || midHigh <= 0 || midLow <= 0 || c3High <= 0 || c3Low <= 0)
         continue;
      datetime c1Time = iTime(_Symbol, tf, i + 1);
      datetime midTime = iTime(_Symbol, tf, i);
      datetime c3Time = iTime(_Symbol, tf, i - 1);
      if(c1Time == 0 || midTime == 0 || c3Time == 0) continue;
      // 看涨: C1.high < C3.low (左侧 K 线高点 < 右侧 K 线低点 → 价格跳空)
      // 看跌: C1.low > C3.high
      int idx = -1;
      double top = 0, bot = 0;
      int    dir = DIR_FLAT;
      if(c1High < c3Low)
        {
         top = c1High;
         bot = c3Low;
         if(InpFVG_MinPoints > 0 && (bot - top) / _Point < InpFVG_MinPoints) continue;
         dir = DIR_UP;
         idx = ArraySize(arr);
         ArrayResize(arr, idx + 1);
        }
      else if(c1Low > c3High)
        {
         top = c3High;
         bot = c1Low;
         if(InpFVG_MinPoints > 0 && (bot - top) / _Point < InpFVG_MinPoints) continue;
         dir = DIR_DOWN;
         idx = ArraySize(arr);
         ArrayResize(arr, idx + 1);
        }
      if(idx < 0) continue;
      arr[idx].formTime = c3Time;  // FVG 在 C3 收线时确认
      arr[idx].top      = top;
      arr[idx].bot      = bot;
      arr[idx].status   = 0;       // 初始未填补, ClassifyFVGStatus 会修正
      arr[idx].dir      = dir;
      arr[idx].tfMin    = TFToMinutes(tf);
      arr[idx].fillLevel = 0.0;    // v1.57: 部分填补时记录最深入位置
      arr[idx].fillTime  = 0;      // v1.60: F 状态时记录填补 K 线起点; 初始=0 (未填补/部分填补时无意义)
     }
  }

// v1.45: 判定单个 FVG 的填补状态 (按 high/low 越过即触发)
//   从 FVG 形成时间往后扫所有已收线 K 线 (跳过形成时间之前, 避免回看)
//   F (status=2) 永远不变 — 第一次完全填补就锁定
void ClassifyFVGStatus(FVGRecord &rec, ENUM_TIMEFRAMES tf)
  {
   if(rec.status == 2) return;   // 已锁定 F, 不再判定
   int total = Bars(_Symbol, tf);
   if(total <= 1) return;
   // 从形成时间的下一根 K 线 (shift=0 当前未收, 从 shift=1 开始扫已收线)
   // 但形成时间就是中间 K 线时间 — shift of midTime: FVG 形成时, 中间 K 线是当时最新已收线 (shift=1)
   int midShift = iBarShift(_Symbol, tf, rec.formTime);
   if(midShift < 0) return;
   // 从 midShift-1 (中间 K 线的下一根) 开始扫 (i.e. shift=midShift-1 已收线)
   for(int i = midShift - 1; i >= 1; i--)
     {
      double h = iHigh(_Symbol, tf, i);
      double l = iLow (_Symbol, tf, i);
      if(h <= 0 || l <= 0) continue;
      // 注意: DetectFVG 赋值时 top=下沿(低价), bot=上沿(高价) — 即 top < bot
      // 完全填补: 价格穿越了整个缺口区间 — 方向相关!
      //   看涨 FVG (DIR_UP): 回落填补, 价格从上往下穿 → 只要 low 触及/跌破下沿(top) 即完全填补
      //   看跌 FVG (DIR_DOWN): 反弹填补, 价格从下往上穿 → 只要 high 触及/突破上沿(bot) 即完全填补
      if(rec.dir == DIR_UP && l <= rec.top)
        {
         rec.status  = 2;
         rec.fillTime = iTime(_Symbol, tf, i);   // v1.60: 记录填补那根 K 线的起点 — 矩形止于此
         return;
        }
      if(rec.dir == DIR_DOWN && h >= rec.bot)
        {
         rec.status  = 2;
         rec.fillTime = iTime(_Symbol, tf, i);   // v1.60
         return;
        }
      // 部分填补: K 线与区间有重叠 (方向无关, high>=下沿 且 low<=上沿)
      if(h >= rec.top && l <= rec.bot)
        {
         rec.status = 1;
         // v1.57: 跟踪价格进入缺口的最深处 (用于画"剩余未填补"部分)
         //   DIR_UP (看涨): 价格从上方跌入 → 最低 low 即为最深处 (向下为深)
         //   DIR_DOWN (看跌): 价格从下方涨入 → 最高 high 即为最深处 (向上为深)
         if(rec.dir == DIR_UP)
           {
            if(rec.fillLevel == 0.0 || l < rec.fillLevel)
               rec.fillLevel = MathMax(l, rec.top);   // 不超过下沿
           }
         else if(rec.dir == DIR_DOWN)
           {
            if(rec.fillLevel == 0.0 || h > rec.fillLevel)
               rec.fillLevel = MathMin(h, rec.bot);   // 不超过上沿
           }
        }
     }
  }

// v1.45: 周期时间 → 简短字符串 (用于标签显示)
string TFShortStr(int minutes)
  {
   if(minutes <= 0)     return "?";
   if(minutes < 60)     return IntegerToString(minutes) + "m";
   if(minutes < 1440)   return IntegerToString(minutes / 60) + "h";
   if(minutes < 10080)  return IntegerToString(minutes / 1440) + "d";
   return IntegerToString(minutes / 10080) + "w";
  }

// v1.45: FVG 矩形名 (按 formTime 唯一标识 — 同一时间点只可能有一个 FVG)
string FVGObjName(datetime formTime, int tfMin)
  {
   return g_prefix + "FVG_R_" + IntegerToString((long)formTime) + "_" + IntegerToString(tfMin);
  }

// v1.45: FVG 状态标签名 (右上角 OBJ_LABEL, 与矩形对齐)
string FVGLblName(datetime formTime, int tfMin)
  {
   return g_prefix + "FVG_L_" + IntegerToString((long)formTime) + "_" + IntegerToString(tfMin);
  }

// v1.91: 信号提醒主入口 — OnTick 每 tick 调用
//   三类报警, 共享总开关 g_signalAlert, 三类相互独立的锁定:
//     ① 0.49 回调报警 (Dir 驱动 long/short)
//     ② 突破区间上沿 (highEdge=max(p1,p0)) — 价格从 ≤highEdge 跳到 >highEdge 时报
//     ③ 突破区间下沿 (lowEdge =min(p1,p0)) — 价格从 ≥lowEdge  跳到 <lowEdge  时报
//   0.49 报警价位 = g_p1 - 0.49*(g_p1 - g_p0)  (从顶部回撤 49%, 与可拖动的 0.49 线无关)
//   v2.08: 突破阈值从 g_p0/g_p1 改为 highEdge/lowEdge — 旧阈值在 SHORT 模式下 pxBrk>g_p0 等于 "价格向上穿过下沿" 却报 "突破上界", 与消息措辞矛盾
//   v2.08: 措辞 "上沿/下沿" 按 max/min 动态判定 (价格高的为上沿, 低的为下沿) — 不再依赖端点 fib 系数或 SWAP 状态
//   v2.09: 三类报警消息都加 _Symbol 前缀 (用户要求, 多 chart 区分品种用; 格式与 v2.00 盈亏播报一致 '[FibLimitAssist] %s ...')
//   "首次" = 跨价位那一 tick (prev 在异侧, 当前在同侧), 报警一次后该锁永久, 直到:
//     - p1/p0 调整 (>_Point) → 三个 fired 全重置
//     - 按钮切换 (ToggleSignalAlert 重置状态)
//   边界变化检测: 与上次记录的 g_prevP1/g_prevP0 比较, 超过 _Point 视为用户拖动了 1.00/0.00 线
//   报价选择: 0.49 回调沿用 DIR 驱动 BID/ASK (与原 v1.91 一致); 突破用 BID (保守报价)
void CheckPullbackSignal()
  {
   if(!g_signalAlert)            return;   // 总开关关闭 → 零开销
   if(g_p1 <= 0 || g_p0 <= 0)     return;   // 边界未初始化
   if(MathAbs(g_p1 - g_p0) < _Point) return; // 区间过窄 (DIR_FLAT 等价)

   // ① 边界变化检测 → 重置全部三个 fired
   bool p1Changed = (MathAbs(g_p1 - g_prevP1) > _Point);
   bool p0Changed = (MathAbs(g_p0 - g_prevP0) > _Point);
   if(p1Changed || p0Changed)
     {
      g_pullbackFired    = false;
      g_breakUpFired     = false;   // v1.99
      g_breakDownFired   = false;   // v1.99
      g_prevSamplePrice  = 0.0;     // 强制下一 tick 重新采样, 避免"边界刚改完就立刻报警"
      g_prevP1           = g_p1;
      g_prevP0           = g_p0;
      g_pullbackLevel    = g_p1 - 0.49 * (g_p1 - g_p0);
      if(g_signalAlert) PrintFormat("[信号提醒] 边界调整 — 重置状态: p1=%.5f p0=%.5f level=%.5f", g_p1, g_p0, g_pullbackLevel);
      return;
     }

   // ② 计算当前采样价 (突破用 BID, 回调按 DIR 取 BID/ASK — 与原 v1.91 一致)
   int    dir   = Dir();
   double level = g_p1 - 0.49 * (g_p1 - g_p0);
   g_pullbackLevel = level;

   double pxAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double pxBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(pxBid <= 0 || pxAsk <= 0) return;

   // 突破检测价 = BID (保守: BID 突破上界等价于市价已超过, BID 突破下界等价于市价已跌破)
   double pxBrk = pxBid;

   // ③ 首 tick 采样 (不评估, 避免"开关刚开就报警")
   if(g_prevSamplePrice == 0.0)
     {
      g_prevSamplePrice = pxBrk;
      return;
     }

   // ④ 0.49 回调报警 (按 DIR 选择 BID/ASK, 与原 v1.91 完全一致)
   if(!g_pullbackFired)
     {
      double pxDir = (dir == DIR_UP) ? pxBid : pxAsk;
      bool crossDown = (g_prevSamplePrice > level) && (pxDir <= level);   // long
      bool crossUp   = (g_prevSamplePrice < level) && (pxDir >= level);   // short
      bool crossed   = (dir == DIR_UP) ? crossDown :
                       (dir == DIR_DOWN) ? crossUp : false;
      if(crossed)
        {
         string dirStr   = (dir == DIR_UP) ? "long" : "short";
         // v2.08: 消息中端点信息改用 highEdge/lowEdge (动态按 max/min, 与 LONG/SHORT 无关)
         double highEdge = MathMax(g_p1, g_p0);
         double lowEdge  = MathMin(g_p1, g_p0);
         double range    = MathAbs(g_p1 - g_p0);
         g_pullbackFired = true;
         string msg      = StringFormat("[FibLimitAssist] %s %s 价格首次回调到区间 0.49 位置: %.5f (区间上沿=%.5f, 下沿=%.5f, Range=%.5f)",
                                        _Symbol, dirStr, level, highEdge, lowEdge, range);
         Alert(msg);
         Print("[信号提醒] ", msg);
         // v2.06: 推送到手机 — 与 Alert/Print 同分支, fired 锁防重复推送 (同 tick 不会再次进入此 if)
         //   需在 MT5 工具→选项→通知 中配置 MetaQuotes ID (PC 端默认 ID); 测试消息可发但 SIGNAL 不推 = 没调 SendNotification
         if(!SendNotification(msg))
            Print("[信号提醒] 推送未送达 (需在 MT5 工具→选项→通知 中配置 MetaQuotes ID): ", msg);
        }
     }

   // ⑤ v1.99: 突破区间上沿 (highEdge=max(p1,p0)) — 任何 tick BID 从 ≤highEdge 跳到 >highEdge 时报警
   //   v2.08: 阈值从 g_p0 改为 highEdge — 旧阈值 SHORT 模式下 pxBrk>g_p0 等于 "穿过下沿", 与消息措辞矛盾
   //   v2.08: 措辞 "穿越 0.00 端点" → "突破区间上沿" (按 max 动态判定, 不依赖 fib 系数/SWAP)
   double highEdge = MathMax(g_p1, g_p0);
   double lowEdge  = MathMin(g_p1, g_p0);
   double range    = MathAbs(g_p1 - g_p0);
   if(!g_breakUpFired && (g_prevSamplePrice <= highEdge) && (pxBrk > highEdge))
     {
      g_breakUpFired = true;
      string msg = StringFormat("[FibLimitAssist] %s 突破区间上沿, 价格: %.5f (下沿=%.5f, Range=%.5f)",
                                _Symbol, pxBrk, lowEdge, range);
      Alert(msg);
      Print("[信号提醒] ", msg);
      // v2.06: 推送到手机 — 注释同 ④
      if(!SendNotification(msg))
         Print("[信号提醒] 推送未送达 (需在 MT5 工具→选项→通知 中配置 MetaQuotes ID): ", msg);
     }

   // ⑥ v1.99: 突破区间下沿 (lowEdge=min(p1,p0)) — 任何 tick BID 从 ≥lowEdge 跳到 <lowEdge 时报警
   //   v2.08: 阈值从 g_p1 改为 lowEdge — 旧阈值 SHORT 模式下 pxBrk<g_p1 等于 "穿过上沿", 与消息措辞矛盾
   //   v2.08: 措辞 "穿越 1.00 端点" → "突破区间下沿" (按 min 动态判定, 不依赖 fib 系数/SWAP)
   //   highEdge/lowEdge/range 在 ⑤ 块已声明 (函数体作用域), 直接复用
   if(!g_breakDownFired && (g_prevSamplePrice >= lowEdge) && (pxBrk < lowEdge))
     {
      g_breakDownFired = true;
      string msg = StringFormat("[FibLimitAssist] %s 突破区间下沿, 价格: %.5f (上沿=%.5f, Range=%.5f)",
                                _Symbol, pxBrk, highEdge, range);
      Alert(msg);
      Print("[信号提醒] ", msg);
      // v2.06: 推送到手机 — 注释同 ④
      if(!SendNotification(msg))
         Print("[信号提醒] 推送未送达 (需在 MT5 工具→选项→通知 中配置 MetaQuotes ID): ", msg);
     }

   g_prevSamplePrice = pxBrk;
  }

// v2.00: 盈亏播报 — 共用 g_signalAlert 总开关
//   触发条件: 服务器时间分钟 % 15 == 0 (即 00/15/30/45) 且当前 chart 品种有持仓
//   节流: g_lastPnLReportMin 锁, 同一分钟内多次 OnTick 只发一次
//   重置锁: 分钟 % 15 != 0 时清空锁, 等下一个 15 分钟边界重新触发
//   发送渠道: SendNotification (MT5 推送 → 手机) + Print 日志; 不弹 Alert 避免每 15 分钟打断用户
//   消息格式: "[FibLimitAssist] SYMBOL P&L: ±X.XX USD (N 单)" — 简洁, 一眼可读
//   盈亏计算: profit + swap (持仓期间累计换仓费), 佣金在开仓时已扣, 不重复计入
//   多品种支持: 每个 chart 跑一个 EA 实例, 仅播报当前 chart 品种 (POSITION_SYMBOL == _Symbol); 不同 chart 自动播报不同品种
void CheckPnLReport()
  {
   if(!g_signalAlert)            return;   // 共用总开关
   MqlDateTime tm;
   if(!TimeCurrent(tm))          return;
   int m = tm.min;

   // 非整 15 分 → 重置锁, 等下一个边界 (00/15/30/45)
   if(m % 15 != 0)
     {
      g_lastPnLReportMin = -1;
      return;
     }
   if(m == g_lastPnLReportMin)    return;   // 本分钟已发
   g_lastPnLReportMin = m;

   // 遍历当前品种持仓, 累加 profit + swap
   int    total   = PositionsTotal();
   if(total <= 0)                 return;   // 无任何持仓 → 跳过 (即使关闭其他品种也只关注自己)
   double netPnl  = 0.0;
   int    cnt     = 0;
   for(int i = 0; i < total; i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)             continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;   // 仅当前 chart 品种
      double p = PositionGetDouble(POSITION_PROFIT);
      double s = PositionGetDouble(POSITION_SWAP);
      netPnl += p + s;
      cnt++;
     }
   if(cnt <= 0)                   return;   // 当前 chart 品种无持仓

   string status = (netPnl >= 0) ? "盈" : "亏";
   string msg    = StringFormat("[FibLimitAssist] %s P&L: %s %.2f USD (%d 单)",
                                _Symbol, status, MathAbs(netPnl), cnt);
   if(!SendNotification(msg))     Print("[盈亏播报] 推送未送达 (需在 MT5 工具→选项→通知 中配置 MetaQuotes ID): ", msg);
   Print("[盈亏播报] ", msg);
  }

// v1.45: 主入口 — 检测 + 分类 + 绘制 FVG 矩形
//   扫描范围: 图表可见区 (ChartGetInteger(CHART_FIRST_VISIBLE_BAR) + CHART_WIDTH_IN_BARS)
//   多周期: 当前周期必扫; 启用 InpFVG_HigherTF_Enabled 时额外扫 g_higherTF
//   每 tick 调用, 实时重判状态 (U/P/F)
//   未成熟 FVG: 中间 K 线 = shift 0 (当前未收线), formTime 用最近已收线 K 线 + 1 个 TF 周期估算
void UpdateFVGDisplay()
  {
   // v1.83: 仅由 g_fvgState 控制 — state=2 (OFF) 时清空矩形, state 0/1 渲染
   //   v1.59 旧逻辑 "仅由 g_fvgEnabled 控制" 已替换为状态机: g_fvgEnabled = (state != 2)
   //   仍不受 g_hidden 影响 — HIDE 隐藏主 fib UI, 但 FVG 仍显示
   if(g_fvgState == 2)
     {
      // v1.48: 关闭 → 仅清掉 FVG 矩形 (FVG_R_*) + 状态标签 (FVG_L_*)
      //   不能用 FVG_ 前缀过滤, 因为 FVG_BTN 按钮也是 FVG_ 前缀, 误删按钮 → "点一次消失" bug
      //   必须精确匹配 FVG_R_ / FVG_L_
      int total = ObjectsTotal(0, -1, -1);
      for(int i = total - 1; i >= 0; i--)
        {
         string nm = ObjectName(0, i, -1, -1);
         if(StringFind(nm, FVGPrefix() + "R_") == 0
         || StringFind(nm, FVGPrefix() + "L_") == 0)
            ObjectDelete(0, nm);
        }
      return;
     }

   // 图表可见区 → K 线 shift 范围
   // v1.51 修复: shift 编号从右到左, CHART_FIRST_VISIBLE_BAR 已是最左(最大 shift)
   //   原代码 lastBar = firstBar + widthBars + 5 导致 lastBar > firstBar,
   //   DetectFVG 的 guard (firstBarShift < lastBarShift + 2) 直接 return, 所以一个 FVG 都检测不到
   int firstBar = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR, 0);   // 最左可见 K 线 shift (最大)
   int widthBars = (int)ChartGetInteger(0, CHART_WIDTH_IN_BARS, 0);      // 可见区宽度
   if(firstBar < 0) firstBar = 0;
   if(widthBars < 3) widthBars = 3;
   int lastBar = MathMax(0, firstBar - widthBars + 1);                   // 最右端 shift (靠近当前 K 线, 最小)
   lastBar = MathMax(0, lastBar - 5);                                    // 向右多扩 5 根, 避免边界抖动

   // 收集当前周期 + 可选高级别的 FVG
   FVGRecord all[];
   ArrayResize(all, 0);

   // 当前周期 (firstBar=最左大shift, lastBar=最右小shift — 顺序须与 DetectFVG 签名一致)
   FVGRecord cur[];
   DetectFVG(_Period, firstBar, lastBar, cur);
   int sz = ArraySize(cur);
   for(int i = 0; i < sz; i++) { int n = ArraySize(all); ArrayResize(all, n + 1); all[n] = cur[i]; }

   // 高级别叠加 (可选)
   if(InpFVG_HigherTF_Enabled && g_higherTF > 0 && g_higherTF != _Period)
     {
      FVGRecord hi[];
      DetectFVG(g_higherTF, firstBar, lastBar, hi);
      sz = ArraySize(hi);
      for(int i = 0; i < sz; i++) { int n = ArraySize(all); ArrayResize(all, n + 1); all[n] = hi[i]; }
     }

   // 分类状态 (F 永远不变)
   int allN = ArraySize(all);
   for(int i = 0; i < allN; i++)
     {
      // 根据 formTime 对应周期判断, 优先用 formTime 所在周期 (优先 _Period, 再 g_higherTF)
      ENUM_TIMEFRAMES tf = (all[i].tfMin == TFToMinutes(_Period)) ? _Period : g_higherTF;
      ClassifyFVGStatus(all[i], tf);
     }

   // 收集所有 FVG 矩形名 (用于清理过期)
   string existing[];
   int existingTotal = ObjectsTotal(0, -1, -1);
   for(int i = 0; i < existingTotal; i++)
     {
      string nm = ObjectName(0, i, -1, -1);
      if(StringFind(nm, FVGPrefix() + "R_") == 0 || StringFind(nm, FVGPrefix() + "L_") == 0)
       { int eN = ArraySize(existing); ArrayResize(existing, eN + 1); existing[eN] = nm; }
     }

   // 最新 K 线起点 (X2 右边界)
   // v1.71: 改用 shift=0 (当前正在形成 K 线的起点), 避免 C3=shift1 时 formTime==lastBarTime 导致零宽矩形
   //   原 iTime(_Period,1) 在 C3 刚收线的瞬间与 formTime 相等, FVG 矩形 X1==X2 不可见, 要等下一根 K 线收线后才出现
   datetime lastBarTime = iTime(_Symbol, _Period, 0);
   if(lastBarTime == 0) lastBarTime = iTime(_Symbol, _Period, 1);

   // 绘制 / 更新
   for(int i = 0; i < allN; i++)
     {
      // v1.83: status=2 (完全填补) 同时受 InpFVG_ShowFilled 和 g_fvgState==1 (FILL 按钮 FILL 态) 控制 — AND 关系
      //   旧 v1.81 用 g_fillShown bool, v1.83 改用 g_fvgState==1 (FILL 态) 等价表达
      bool show = (all[i].status == 0 && InpFVG_ShowUnfilled)
                || (all[i].status == 1 && InpFVG_ShowPartial)
                || (all[i].status == 2 && InpFVG_ShowFilled && (g_fvgState == 1));
      string rectName = FVGObjName(all[i].formTime, all[i].tfMin);
      string lblName  = FVGLblName (all[i].formTime, all[i].tfMin);

      // v1.60/v1.71: 矩形右边界按状态分支
      //   U (未填补) / P (部分填补) → X2 = lastBarTime (延伸至当前正在形成 K 线起点, 缺口当前仍存在)
      //   F (完全填补)               → X2 = fillTime  (止于填补那根 K 线起点, 不再延伸)
      //   fillTime 为 0 时 (极端) fallback 到 lastBarTime
      // v1.71: lastBarTime 改用 iTime(0), U/P 矩形从 C3 收线起就有正常宽度, 不再延迟一根 K 线
      //   提到循环顶部声明, 供下方 show 分支 (矩形绘制) 与 showLbl 分支 (标签 X 锚点) 共用
      datetime rectEndTime = (all[i].status == 2 && all[i].fillTime > 0)
                             ? all[i].fillTime
                             : lastBarTime;

      // 矩形
      if(show)
        {
         if(ObjectFind(0, rectName) < 0)
           {
            ObjectCreate(0, rectName, OBJ_RECTANGLE, 0, all[i].formTime, all[i].top, rectEndTime, all[i].bot);
            ObjectSetInteger(0, rectName, OBJPROP_BACK, true);     // 背景层, 不挡价格线
            ObjectSetInteger(0, rectName, OBJPROP_FILL, true);     // 填充
            ObjectSetInteger(0, rectName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, rectName, OBJPROP_HIDDEN, false);
            // 虚线用于"未成熟" (中间 K 线 shift=0): formTime 严格等于 iTime(_,_,0) — 但 DetectFVG 已排除 shift<0, 不存在
            // 此处全部用实线 (未成熟 K 线不可能形成有效 FVG, 因为 iHigh/iLow 返回当前实时值不稳定)
           }
         // v1.47: OBJ_RECTANGLE 坐标修改必须用 ObjectMove(角点索引), 不能用 OBJPROP_TIME1/2
         //   这两个 OBJPROP_TIME1/2/PRICE1/2 在当前 MT5 build 下 ObjectSetDouble 报 undeclared identifier
         //   ObjectMove(0, name, 0, t, p) 改角点 0 (左上); (0, name, 1, t, p) 改角点 1 (右下)
         // v1.57: 部分填补只画"剩余未填补"部分
         //   DIR_UP (看涨): 价格从上往下填, 剩余未填补 = [top, fillLevel]
         //   DIR_DOWN (看跌): 价格从下往上填, 剩余未填补 = [fillLevel, bot]
         double drawTop = all[i].top;
         double drawBot = all[i].bot;
         if(all[i].status == 1 && all[i].fillLevel > 0)
           {
            if(all[i].dir == DIR_UP)
               drawBot = all[i].fillLevel;    // 底边抬到 fillLevel, 上方为未填补
            else if(all[i].dir == DIR_DOWN)
               drawTop = all[i].fillLevel;    // 顶边压到 fillLevel, 下方为未填补
           }
         ObjectMove(0, rectName, 0, all[i].formTime, drawTop);   // 角点 0: FVG 形成时刻 + 顶
         ObjectMove(0, rectName, 1, rectEndTime,    drawBot);   // 角点 1: 状态相关终点 (U/P=lastBarTime; F=fillTime) + 底
         ObjectSetInteger(0, rectName, OBJPROP_COLOR,   FVGStatusColor     (all[i].status, all[i].dir));
         ObjectSetInteger(0, rectName, OBJPROP_HIDDEN, false);
        }
      else if(ObjectFind(0, rectName) >= 0)
         ObjectDelete(0, rectName);

      // v1.47: 右上角小标签 — OBJ_LABEL 在 MQL5 中是屏幕坐标对象, OBJPROP_TIME/PRICE 不适用
      //   必须先用 ChartTimePriceToXY 把时间/价格转屏幕坐标, 再用 OBJPROP_XDISTANCE/YDISTANCE 设置
      //   锚点 ANCHOR_RIGHT_UPPER: 标签右上角对齐到 (x, y), 即标签正好显示在矩形顶边的右上侧
      // v1.78: 标签显隐由 InpFVG_ShowLabel 控制 (默认 false — 只画矩形不画文字)
      //   同时保留 width>200 兜底: 小窗口标签会遮挡 K 线
      bool showLbl = show && InpFVG_ShowLabel && (ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0) > 200);
      if(showLbl)
        {
         string tfStr = TFShortStr(all[i].tfMin);
         string lblText = FVGStatusChar(all[i].status) + "·" + tfStr;
         if(ObjectFind(0, lblName) < 0)
           {
            ObjectCreate(0, lblName, OBJ_LABEL, 0, 0, 0);  // 创建时第 4-5 参数(time, price)对 OBJ_LABEL 实际无效
            ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, lblName, OBJPROP_HIDDEN, false);
            ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, Font(7));
            ObjectSetInteger(0, lblName, OBJPROP_ANCHOR,    ANCHOR_RIGHT_UPPER);
            ObjectSetInteger(0, lblName, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
           }
         // 计算标签目标屏幕位置: 跟随 FVG 顶边的"矩形右边界"时间
         // v1.60/v1.71: 改用 rectEndTime — U/P 状态 = iTime(0) 当前正在形成 K 线起点 (与矩形右边界对齐), F 状态 = fillTime (矩形右边界已止于填补 K 线起点)
         int px = 0, py = 0;
         if(ChartTimePriceToXY(0, 0, rectEndTime, all[i].top, px, py))
           {
            // 标签宽约 36 px (字符宽 7 × 5 字符), 右上对齐后让标签左边缘紧贴矩形右上角
            int tagW = 36;
            ObjectSetInteger(0, lblName, OBJPROP_XDISTANCE, px - tagW);
            ObjectSetInteger(0, lblName, OBJPROP_YDISTANCE, py - 2);
           }
         ObjectSetString (0, lblName, OBJPROP_TEXT, lblText);
         ObjectSetInteger(0, lblName, OBJPROP_COLOR, FVGStatusColor(all[i].status, all[i].dir));
         ObjectSetInteger(0, lblName, OBJPROP_HIDDEN, false);
        }
      else if(ObjectFind(0, lblName) >= 0)
         ObjectDelete(0, lblName);

      // 从 existing 中移除已处理的
      for(int j = ArraySize(existing) - 1; j >= 0; j--)
         if(existing[j] == rectName || existing[j] == lblName)
            ArrayRemove(existing, j, 1);
     }

   // 清理未使用的 (FVG 移出可见区 / 状态变化隐藏 等)
   for(int i = 0; i < ArraySize(existing); i++)
      ObjectDelete(0, existing[i]);

   // v1.48: 调试输出 — 每个新柱打印一次 (避免每 tick 噪音)
   static datetime s_lastFvgDebugBar = 0;
   datetime curBar = iTime(_Symbol, _Period, 0);
   if(curBar != s_lastFvgDebugBar && curBar > 0)
     {
      s_lastFvgDebugBar = curBar;
      int nU = 0, nP = 0, nF = 0;
      for(int i = 0; i < ArraySize(all); i++)
        {
         if(all[i].status == 0) nU++;
         else if(all[i].status == 1) nP++;
         else                     nF++;
        }
      bool showUnfilled = InpFVG_ShowUnfilled, showPartial = InpFVG_ShowPartial, showFilled = InpFVG_ShowFilled;
      PrintFormat("FVG[%s]: total=%d (U=%d%s P=%d%s F=%d%s) Bars=%d range=[%d..%d]",
                  TimeToString(curBar, TIME_DATE|TIME_MINUTES),
                  ArraySize(all),
                  nU, (showUnfilled ? "✓" : "✗"),
                  nP, (showPartial  ? "✓" : "✗"),
                  nF, (showFilled   ? "✓" : "✗"),
                  Bars(_Symbol, _Period), lastBar, firstBar);
     }
  }

// 应用隐藏/显示状态：遍历所有 EA 对象，HIDE 按钮自身除外
// v1.07 改进：
//  · 按钮：OBJPROP_HIDDEN 无效，移出屏幕 (XDISTANCE = -10000)
//  · 水平线：OBJPROP_HIDDEN 在部分 MT5 版本对 HLINE 不生效，改为把价格改到 1e20（屏幕外）
//          显示时由 UpdateLabel 改回 g_p1/g_p0/g_p79/g_p49（UpdateLabel 自身在 g_hidden 时跳过）
//  · 标签：OBJPROP_HIDDEN 对 OBJ_LABEL 有效，继续用 HIDDEN
void ApplyHidden()
  {
   int total = ObjectsTotal(0, -1, -1);
   string hideObj   = HideName();
   string fvgBtn    = FVGButtonName();
   string adjBtn    = AdjustName();      // v2.01: ADJUST 按钮独立于 HIDE
   string signalBtn = SignalName();      // v2.03: SIGNAL 按钮独立于 HIDE — 与 ADJUST 同列的快捷键, HIDE 时仍需可见
   // v1.83: 删除 FillButtonName() — FILL 按钮已合并入 FVG 按钮, 不再独立
   for(int i = 0; i < total; i++)
     {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, g_prefix) != 0) continue;   // 仅本实例对象
      // v1.59: FVG 系列 (按钮 + 矩形 + 标签) 完全独立于 HIDE — HIDE 不动它
      // v1.81: FILL 按钮同样独立于 HIDE — FVG 按钮的辅助开关, HIDE 不应影响
      // v1.83: FILL 按钮已合并入 FVG 按钮, 这里只跳过 fvgBtn 一个
      // v2.01: ADJUST 按钮 (钉在右下角) 同样独立于 HIDE — 用户随时调整 1.00/0.00 的快捷键
      // v2.03: SIGNAL 按钮 (右下角) 同样独立于 HIDE — 报警开关, 隐藏时仍需可见
      if(name == fvgBtn
      || name == adjBtn
      || name == signalBtn
      || StringFind(name, g_prefix + "FVG_R_") == 0
      || StringFind(name, g_prefix + "FVG_L_") == 0)
         continue;
      bool hide = g_hidden && (name != hideObj);       // HIDE 按钮自身永远显示
      int type = (int)ObjectGetInteger(0, name, OBJPROP_TYPE, 0);
      if(type == OBJ_BUTTON)
        {
         if(hide) ObjectSetInteger(0, name, OBJPROP_XDISTANCE, -10000);  // 移出屏幕
         // 显示状态不处理：位置由 RefreshAll 中的定位函数重新设置
        }
      else if(type == OBJ_HLINE)
        {
         if(hide) ObjectSetDouble(0, name, OBJPROP_PRICE, 1e20);  // 移到屏幕上方之外
         // 显示状态：UpdateLabel 会把 g_p1/g_p0/g_p79/g_p49 写回
        }
      else  // OBJ_LABEL / OBJ_TEXT 等
        {
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, hide);
        }
     }
  }

void RefreshAll()
  {
   // v1.42: 隐藏态早退 — 隐藏时跳过所有"写回可见位置"的定位函数, 避免"显示→隐藏"往返造成线条闪现
   //   (v1.07 注释声称 UpdateLabel 会在 g_hidden 时跳过, 但实际从未实现该判断, 导致每次 RefreshAll
   //    先把隐藏的 HLINE/按钮写回正常位置, 再由 ApplyHidden 移走, MQL5 即时生效 → 肉眼闪烁)
   if(g_hidden)
     {
      UpdateHideButton();   // 保持 SHOW 文字 + sticky 状态
      UpdateFVGButton();    // v1.45: FVG 按钮也保持文字/颜色/sticky 状态 (不依赖 EA 主线逻辑)
      UpdateRiskButton();   // v2.03: RISK 按钮文字/sticky 也保持 (与 HIDE/FVG 一致)
      UpdateBottomButtons();   // v2.03: 修复 HIDE 切周期后 HIDE/FVG/RISK 按钮挤在 (0,0) 的 bug
                              //   早退分支原本只调 UpdateHideButton/UpdateFVGButton (只改文字颜色, 不改位置)
                              //   CreateObjects 重建按钮在默认 (0,0), 显示分支的 UpdateBottomButtons 不被调
                              //   → 三个按钮挤在左上角重叠, HIDE 看不见, FVG 露出来。补 UpdateBottomButtons 后
                              //   HIDE/FVG/RISK 位置被重新设置到底部按钮行, 不依赖显示分支。
      // v2.02: 早退分支补 UpdateAdjustButton — 切周期后 g_hidden 若仍为 true
      //   CreateObjects 创建的 ADJUST 仍在 (0,0), 即使 ApplyHidden 跳过它 (v2.01) 也会被其他按钮遮挡看不见。
      // v2.03: 早退分支补 UpdateSignalButtonPosition — 与 ADJUST 同理, CreateObjects 创建的 SIGNAL 停在 (0,0)
      //   即使 ApplyHidden 新加入 signalBtn 到 skip 列表 (v2.03), 仍会被其他按钮遮挡看不见
      UpdateAdjustButton();
      UpdateSignalButtonPosition();
      ApplyHidden();        // 确保所有对象处于隐藏 (幂等); skip 列表含 hideObj/fvgBtn/adjBtn/signalBtn/FVG_R/FVG_L, 不会动它们
      ChartRedraw(0);
      return;
     }

   UpdateButtonX();

   UpdateLabel(HName(RATIO_100), g_p1);
   UpdateLabel(HName(RATIO_000), g_p0);
   UpdateLabel(HName(RATIO_079), g_p79);
   UpdateLabel(HName(RATIO_049), g_p49);
   UpdateLabel(HName(RATIO_019), TheoPrice(RATIO_019, g_p1, g_p0));
   // v1.86: 0.73 装饰线跟随 1.00 重定位
   UpdateLabel(HName(RATIO_073), TheoPrice(RATIO_073, g_p1, g_p0));

   int dir = Dir();
   double price79 = LevelPrice(RATIO_079);
   double price49 = LevelPrice(RATIO_049);
   double lot79 = CalcLotFor(price79, dir);
   double lot49 = CalcLotFor(price49, dir);

   UpdateButton(BName(RATIO_079), price79, BuildButtonText(ActualRatio(price79), lot79), dir);
   UpdateButton(BName(RATIO_049), price49, BuildButtonText(ActualRatio(price49), lot49), dir);
   UpdateMidLines(dir);   // v1.25: 0.79/0.49 线颜色随方向 (与按钮配色统一)

   UpdateSwapButton(dir);
   UpdateAdjustButton();   // v1.13: ADJUST 按钮位置 (跟随 SWAP) — v1.91: 改为钉在右下角
   UpdateSignalButtonPosition();   // v1.91: SIGNAL 按钮位置 (原 ADJUST 位 — LONG 右侧 4px)
   UpdateStepButtons();   // v1.17: 4 条主线的 UP/DOWN 按钮 (跟随线移动)
   UpdateMarketButton(dir);
   UpdateStopButton(dir);   // v1.31: 突破挂单按钮文字与配色跟随方向
   UpdateRiskButton();
   UpdateHideButton();
   UpdateFVGButton();       // v1.83: 单按钮 3 态循环 (FVG→FILL→OFF), 替代 v1.81 独立的 UpdateFillButton
   UpdateTopButtons();
   UpdateBottomButtons();
   UpdatePnLDisplay();   // v1.08：MKT 两侧的实时盈亏数字
   UpdateRatioLabels();  // v1.34：底线下方的盈亏比三指标 (浮盈占比/风险回报比/百分比)
   UpdateSpreadDisplay(); // v1.75：MKT 与 STP 中间的实时点差标签 "(1.5)"

   UpdateLabelRight(LName(RATIO_019), TheoPrice(RATIO_019, g_p1, g_p0), "0.19");  // v1.07：仅保留 0.19 标签
   // v1.86: 0.73 装饰线标签跟随
   UpdateLabelRight(LName(RATIO_073), TheoPrice(RATIO_073, g_p1, g_p0), "0.73");

   ApplyHidden();
   ChartRedraw(0);
  }

//---------------------------- 手数计算 -----------------------------//
// 单笔最大亏损金额 = Balance × g_riskPercent / 100
// g_riskPercent 由 RISK 按钮循环控制 (0.25/0.5/1/2%)，会话内持久化
double CalcLot(double entry, double sl)
  {
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * g_riskPercent / 100.0;
   double dist = MathAbs(entry - sl);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(dist <= 0 || tickSize <= 0 || tickValue <= 0) return 0.0;

   double raw = riskMoney * tickSize / (dist * tickValue);
   // 截断保留 N 位小数，不四舍五入
   double lot = MathFloor(raw * MathPow(10, InpLotDecimals) + 1e-9) / MathPow(10, InpLotDecimals);
   // 向下对齐到品种手数步长
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step > 0) lot = MathFloor(lot / step + 1e-9) * step;
   if(lot < 0) lot = 0;
   return lot;
  }

double CalcLotFor(double entry, int dir)
  {
   double range = MathAbs(g_p0 - g_p1);
   if(dir == DIR_FLAT || range <= 0) return 0.0;
   double sl = (dir == DIR_UP) ? (g_p1 - range * InpSL_OffsetPercent / 100.0)
                               : (g_p1 + range * InpSL_OffsetPercent / 100.0);
   return CalcLot(entry, sl);
  }

//---------------------------- 实时盈亏（v1.08）-------------------//
// 当前所有持仓的浮盈合计（含账户内全部品种、全部魔术号）
double CalcFloatPnL()
  {
   double total = 0.0;
   int n = PositionsTotal();
   for(int i = 0; i < n; i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      total += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }
   return total;
  }

//---------------------------- 时区与切日 -----------------------------//
// v1.12: 用于把 CalcDayPnL 的"今天"起点切换到 FTMO 规则的 CE(S)T
//        (布拉格时间 00:00 切日)，自动判断夏令时/冬令时

// OnInit 调用一次: 自动探测服务器相对 GMT 的偏移 (小时)
void DetectTimezone()
  {
   g_serverGMTOffset = (int)MathRound((double)(TimeCurrent() - TimeGMT()) / 3600.0);
   PrintFormat("[FibLimitAssist] 时区探测: ServerGMT=%+d, DayResetMode=%d (%s)",
               g_serverGMTOffset,
               (int)InpDayResetTimezone,
               (InpDayResetTimezone == DAY_TZ_LOCAL) ? "LOCAL" :
               (InpDayResetTimezone == DAY_TZ_CET_AUTO) ? "CET_AUTO(FTMO)" :
               (InpDayResetTimezone == DAY_TZ_CET) ? "CET" : "CEST");
  }

// 工具: 构造"服务器视角下的 yyyy.mm.dd hh:mm:ss"字符串 (供 StringToTime 解析)
string FmtDateTime(int year, int mon, int day, int hour=0, int min=0, int sec=0)
  {
   return IntegerToString(year) + "." +
          (mon < 10 ? "0" : "") + IntegerToString(mon) + "." +
          (day < 10 ? "0" : "") + IntegerToString(day) + " " +
          (hour < 10 ? "0" : "") + IntegerToString(hour) + ":" +
          (min < 10 ? "0" : "") + IntegerToString(min) + ":" +
          (sec < 10 ? "0" : "") + IntegerToString(sec);
  }

// 工具: 找某年某月最后一个周日的"日" (欧洲 DST 切换依据)
int LastSundayOfMonth(int year, int mon)
  {
   int lastDay = 31;
   if(mon == 4 || mon == 6 || mon == 9 || mon == 11) lastDay = 30;
   else if(mon == 2)
     {
      bool leap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      lastDay = leap ? 29 : 28;
     }
   for(int d = lastDay; d > lastDay - 7 && d >= 1; d--)
     {
      datetime t = StringToTime(FmtDateTime(year, mon, d, 12, 0, 0));
      MqlDateTime st;
      TimeToStruct(t, st);
      if(st.day_of_week == 0) return d;   // 0 = Sunday
     }
   return lastDay;
  }

// 判断 GMT timestamp 是否在欧洲夏令时 (CEST, GMT+2)
// 规则: 3 月最后一个周日 01:00 UTC ~ 10 月最后一个周日 01:00 UTC
// 输入 gmtTime 是真实 Unix UTC timestamp (TimeGMT() 风格)
bool IsEuropeanDST(datetime gmtTime)
  {
   // 把 gmtTime 调整为"本机时区视角下的同一瞬间"，这样 TimeToStruct 拆出的 y/m/d 对应 GMT 视角
   int localGMTBias = (int)MathRound((double)(TimeLocal() - TimeGMT()) / 3600.0);
   datetime localView = gmtTime + localGMTBias * 3600;
   MqlDateTime dt;
   TimeToStruct(localView, dt);   // dt 字段对应 GMT 视角下的 y/m/d/h/m/s
   int year  = dt.year;
   int month = dt.mon;
   int day   = dt.day;

   // 简单月份判断: 1/2/11/12 → CET; 4-9 → CEST
   if(month == 1 || month == 2 || month == 11 || month == 12) return false;
   if(month >= 4 && month <= 9) return true;

   // 3 月 / 10 月: 精确判断
   int lastSun = LastSundayOfMonth(year, month);
   // GMT 视角下"周日 01:00 UTC"的 timestamp
   // 构造服务器视角字符串 (服务器时刻 = GMT + serverGMTBias, 所以要写 GMT 01:00 = server (1+serverGMTBias) 点)
   // 注意: 假设 serverGMTBias < 23 (FTMO broker 永远成立, 即 < 24)
   int srvHour = 1 + g_serverGMTOffset;
   int srvDay  = day;   // 先假设不跨日
   int srvMon  = month;
   int srvYear = year;
   if(srvHour >= 24)
     {
      srvHour -= 24;
      // 日+1, 月可能要进位
      srvDay++;
      // 简化: 用 StringToTime 构造"服务器下个月初"再减 1 秒? 这里直接处理跨日边界
      int monthDays = 31;
      if(srvMon == 4 || srvMon == 6 || srvMon == 9 || srvMon == 11) monthDays = 30;
      else if(srvMon == 2)
        {
         bool leap = (srvYear % 4 == 0 && srvYear % 100 != 0) || (srvYear % 400 == 0);
         monthDays = leap ? 29 : 28;
        }
      if(srvDay > monthDays) { srvDay = 1; srvMon++; if(srvMon > 12) { srvMon = 1; srvYear++; } }
     }
   datetime boundary = StringToTime(FmtDateTime(srvYear, srvMon, srvDay, srvHour, 0, 0));
   // 服务器视角 timestamp → GMT 视角 timestamp
   boundary -= g_serverGMTOffset * 3600;

   if(month == 3)  return (gmtTime >= boundary);   // 3 月周日 01:00 GMT 之后是 CEST
   if(month == 10) return (gmtTime <  boundary);   // 10 月周日 01:00 GMT 之前是 CEST
   return false;
  }

// 给定服务器时间戳 srvNow, 返回 "CE(S)T 视角下今天 00:00" 对应的服务器 timestamp
// cetOffsetHours = 1 (CET) 或 2 (CEST)
//
// 推导:
//   brokerMidnight = broker 视角下"今天 00:00"的 timestamp
//   CET today 可能 != broker today, 取决于 CET hour 是否越界:
//     CET hour = broker hour - serverGMTBias + cetOffset
//     cetHour < 0       → CET today = broker today - 1
//     0 <= cetHour < 24 → CET today = broker today
//     cetHour >= 24     → CET today = broker today + 1
//   result = brokerMidnight + dayDelta*86400 + (serverGMTBias - cetOffset)*3600
//   datetime 加减是直接长整数运算, 跨日/跨月自动处理
datetime CESTMidnightServerTime(datetime srvNow, int cetOffsetHours)
  {
   MqlDateTime dt;
   TimeToStruct(srvNow, dt);
   int cetHour  = dt.hour - g_serverGMTOffset + cetOffsetHours;
   int dayDelta = 0;
   if(cetHour < 0)       dayDelta = -1;
   else if(cetHour >= 24) dayDelta = 1;
   datetime brokerMidnight = StringToTime(FmtDateTime(dt.year, dt.mon, dt.day, 0, 0, 0));
   return brokerMidnight + dayDelta * 86400 + (g_serverGMTOffset - cetOffsetHours) * 3600;
  }

// 按 InpDayResetTimezone 返回"今天 00:00"对应的服务器 timestamp
datetime DayStartForPnL(datetime srvNow)
  {
   switch(InpDayResetTimezone)
     {
      case DAY_TZ_LOCAL:
         return StringToTime(TimeToString(TimeLocal(), TIME_DATE));   // 原行为
      case DAY_TZ_CET:
         return CESTMidnightServerTime(srvNow, 1);   // 强制 CET
      case DAY_TZ_CEST:
         return CESTMidnightServerTime(srvNow, 2);   // 强制 CEST
      case DAY_TZ_CET_AUTO:
      default:
        {
           // 自动判断当前是否在欧洲 DST
           datetime gmtNow = srvNow - g_serverGMTOffset * 3600;
           int cetOffset = IsEuropeanDST(gmtNow) ? 2 : 1;
           return CESTMidnightServerTime(srvNow, cetOffset);
        }
     }
  }

// 当日（按 InpDayResetTimezone 决定的 00:00 起）所有 deals 的盈亏合计（含已平仓 + 未平仓）
// 已平仓：遍历历史 deals，取 profit + swap + commission
// 未平仓部分由 CalcFloatPnL 叠加，避免重复计算
double CalcDayPnL()
  {
   // 按 InpDayResetTimezone 决定"今天 00:00"对应的服务器时间戳
   datetime dayStart = DayStartForPnL(TimeCurrent());
   double closed = 0.0;

   // 拉取从 dayStart 到现在的历史
   if(HistorySelect(dayStart, TimeCurrent()))
     {
      int deals = HistoryDealsTotal();
      for(int i = 0; i < deals; i++)
        {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0) continue;
         // 排除余额存取 (DEAL_TYPE_BALANCE)
         long type = HistoryDealGetInteger(ticket, DEAL_TYPE);
         if(type == DEAL_TYPE_BALANCE) continue;
         closed += HistoryDealGetDouble(ticket, DEAL_PROFIT)
                 + HistoryDealGetDouble(ticket, DEAL_SWAP)
                 + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
        }
     }
   // 已平仓部分 + 当前未平仓的浮盈
   return closed + CalcFloatPnL();
  }

// 把金额格式化为 "(+1234)" / "(-5678)" 字符串
string FormatPnL(double v)
  {
   if(MathAbs(v) < 0.5) return "(0)";
   string s;
   if(v > 0) s = "(+" + IntegerToString((int)MathRound(v)) + ")";
   else       s = "(" + IntegerToString((int)MathRound(v)) + ")";   // 负数自带负号
   return s;
  }

// 根据正负返回颜色
color PnLColor(double v)
  {
   if(MathAbs(v) < 0.5) return CLR_PNL_NEUTRAL;
   return (v > 0) ? CLR_PLUS : CLR_MINUS;
  }

// v1.08：MKT 两侧的实时盈亏标签刷新
void UpdatePnLDisplay()
  {
   double f = CalcFloatPnL();
   double d = CalcDayPnL();

   if(ObjectFind(0, PnLLeftName()) >= 0)
     {
      ObjectSetString(0, PnLLeftName(), OBJPROP_TEXT, FormatPnL(f));
      ObjectSetInteger(0, PnLLeftName(), OBJPROP_COLOR, PnLColor(f));
     }
   if(ObjectFind(0, PnLRightName()) >= 0)
     {
      ObjectSetString(0, PnLRightName(), OBJPROP_TEXT, FormatPnL(d));
      ObjectSetInteger(0, PnLRightName(), OBJPROP_COLOR, PnLColor(d));
     }

  }

// v1.75: MKT 与 STP 之间的实时点差标签 (形如 "(1.5)") — 单位 points/10 = pips
//   SYMBOL_SPREAD 返回当前品种点差 (单位: points), 除以 10 得 pips, 1 位小数
//   BTCUSD 150 pts → 15.0 pips → "(15.0)"; 用户示例 "(1.5)" 暗示 pips 格式, 但 BTCUSD 通常 > 10 pips
//   若用户反馈单位不对 (比如想要 points 形式), 再调整为 /1.0
void UpdateSpreadDisplay()
  {
   long spreadPts = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spreadPts < 0) spreadPts = 0;
   double spreadPips = spreadPts / 10.0;
   string txt = "(" + DoubleToString(spreadPips, 1) + ")";
   if(ObjectFind(0, SpreadName()) >= 0)
      ObjectSetString(0, SpreadName(), OBJPROP_TEXT, txt);
  }

// v1.34: 盈亏比三指标 — 浮盈占比 / 风险回报比 / 百分比
//   valA = ∑浮盈 / ∑止盈金额   (可正可负, 0 表示无仓位或无 TP 设置)
//   valB = ∑止盈金额 / ∑止损金额 (恒正, 0 表示无 TP/SL 设置)
//   pct  = valA/valB * 100, 四舍五入 (valB=0 时取 0)
void CalcRatioMetrics(double &valA, double &valB, double &pct)
  {
   valA = 0; valB = 0; pct = 0;

   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0) return;   // 防止除零

   double totalPL = 0, totalTP = 0, totalSL = 0;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double tp    = PositionGetDouble(POSITION_TP);
      double sl    = PositionGetDouble(POSITION_SL);
      double lots  = PositionGetDouble(POSITION_VOLUME);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      totalPL += PositionGetDouble(POSITION_PROFIT);  // 已含手续费/库存费

      if(tp > 0)
        {
         double dist = (type == POSITION_TYPE_BUY) ? (tp - entry) : (entry - tp);
         if(dist > 0) totalTP += (dist / tickSize) * tickValue * lots;
        }
      if(sl > 0)
        {
         double dist = (type == POSITION_TYPE_BUY) ? (entry - sl) : (sl - entry);
         if(dist > 0) totalSL += (dist / tickSize) * tickValue * lots;
        }
     }

   if(totalTP > 0) valA = totalPL / totalTP;
   if(totalSL > 0) valB = totalTP / totalSL;
   if(valB  > 0) pct = valA / valB * 100.0;
  }

// v1.34: 盈亏比标签刷新 — 3 段 OBJ_LABEL, 右对齐到 CALL 右边缘 (g_btnX + UI(100))
//   Y = botPrice + UI(4), 与 CALL (botPrice 上方 UI(26)) 关于底线下上镜像
void UpdateRatioLabels()
  {
   double botPrice = MathMin(g_p1, g_p0);
   int x = 0, y = 0;
   if(!ChartTimePriceToXY(0, 0, RightAnchor(), botPrice, x, y)) return;

   double valA = 0, valB = 0, pct = 0;
   CalcRatioMetrics(valA, valB, pct);

   // 文本与配色
   string txtA = (valA >= 0)
                 ? StringFormat("(%+.1f",  valA)   // (+1.4
                 : StringFormat("(%+.1f",  valA);   // (-0.5, + 已带负号
   string txtB = StringFormat(":%+.1f)", valB);    // (:3.2)  valB 恒正
   string txtC = StringFormat(" %d%%",   (int)MathRound(pct));

   color clrA = (valA >  0) ? CLR_RATIO_PLUS
                :((valA < 0) ? CLR_RATIO_MINUS : CLR_RATIO_NEUTRAL);
   color clrB = (valB >  0) ? CLR_RATIO_RR    : CLR_RATIO_NEUTRAL;
   color clrC = CLR_RATIO_NEUTRAL;

   string nameA = RatioAName(), nameB = RatioBName(), nameC = RatioCName();

   // 先写文本/颜色, 渲染一次让 XSIZE 反映真实宽度
   if(ObjectFind(0, nameA) >= 0)
     {
      ObjectSetString(0, nameA, OBJPROP_TEXT, txtA);
      ObjectSetInteger(0, nameA, OBJPROP_COLOR, clrA);
     }
   if(ObjectFind(0, nameB) >= 0)
     {
      ObjectSetString(0, nameB, OBJPROP_TEXT, txtB);
      ObjectSetInteger(0, nameB, OBJPROP_COLOR, clrB);
     }
   if(ObjectFind(0, nameC) >= 0)
     {
      ObjectSetString(0, nameC, OBJPROP_TEXT, txtC);
      ObjectSetInteger(0, nameC, OBJPROP_COLOR, clrC);
     }

   // 测宽度, 失败时按字长估算
   int wC = (int)ObjectGetInteger(0, nameC, OBJPROP_XSIZE);
   int wB = (int)ObjectGetInteger(0, nameB, OBJPROP_XSIZE);
   int wA = (int)ObjectGetInteger(0, nameA, OBJPROP_XSIZE);
   if(wC == 0) wC = StringLen(txtC) * UI(6);
   if(wB == 0) wB = StringLen(txtB) * UI(6);
   if(wA == 0) wA = StringLen(txtA) * UI(6);

   int rightEdge = g_btnX + UI(100);
   int yBtn = y + UI(4);   // 底线下 4px (CALL 在 y - 26 = 上方 26px, 关于底线上 4px 镜像)

   // C 最右, B 贴 C 左, A 贴 B 左 (三段共用顶 Y)
   if(ObjectFind(0, nameC) >= 0)
     {
      ObjectSetInteger(0, nameC, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, nameC, OBJPROP_XDISTANCE, rightEdge - wC);
      ObjectSetInteger(0, nameC, OBJPROP_YDISTANCE, yBtn);
     }
   if(ObjectFind(0, nameB) >= 0)
     {
      ObjectSetInteger(0, nameB, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, nameB, OBJPROP_XDISTANCE, rightEdge - wC - wB);
      ObjectSetInteger(0, nameB, OBJPROP_YDISTANCE, yBtn);
     }
   if(ObjectFind(0, nameA) >= 0)
     {
      ObjectSetInteger(0, nameA, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, nameA, OBJPROP_XDISTANCE, rightEdge - wC - wB - wA);
      ObjectSetInteger(0, nameA, OBJPROP_YDISTANCE, yBtn);
     }
  }

//---------------------------- 下单 -----------------------------//
ENUM_ORDER_TYPE_FILLING GetFillModeFor(string sym)
  {
   long mode = SymbolInfoInteger(sym, SYMBOL_FILLING_MODE);
   if((mode & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if((mode & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
  }
ENUM_ORDER_TYPE_FILLING GetFillMode() { return GetFillModeFor(_Symbol); }

void SendLimitOrder(int dir, double price, double sl, double tp, double lot)
  {
   SendLimitOrderEx(dir, price, sl, tp, lot, InpOrderComment);
  }

// v1.84: SendLimitOrder 扩展版 — 支持自定义订单注释 (用于 0.79 拆单区分 1/2 2/2)
//   复用 SendLimitOrder 的逻辑, 仅把注释改为传入参数
void SendLimitOrderEx(int dir, double price, double sl, double tp, double lot, string comment)
  {
   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action      = TRADE_ACTION_PENDING;
   req.symbol      = _Symbol;
   req.magic       = InpMagicNumber;
   req.volume      = lot;
   req.price       = NormalizeDouble(price, _Digits);
   req.sl          = NormalizeDouble(sl, _Digits);
   req.tp          = NormalizeDouble(tp, _Digits);
   req.deviation   = 10;
   req.type        = (dir == DIR_UP) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
   req.type_filling = GetFillMode();
   req.type_time   = ORDER_TIME_GTC;   // 无过期时间
   req.comment     = comment;

   if(!OrderSend(req, res))
     {
      Alert("[FibLimitAssist] 下单失败 retcode=", res.retcode, " ", res.comment);
      return;
     }
   Print("[FibLimitAssist] 挂单成功 ticket=", res.order, " ",
         (dir == DIR_UP ? "BUY" : "SELL"), " LIMIT vol=", DoubleToString(lot, InpLotDecimals),
         " comment=", comment);
  }

void PlaceOrderWithRR(double r, double rr)
  {
   int dir = Dir();
   if(dir == DIR_FLAT)
     {
      Alert("[FibLimitAssist] 区间未定义：1.00 与 0.00 重合，无法下单");
      return;
     }

   double entry = LevelPrice(r);
   double range = MathAbs(g_p0 - g_p1);
   double sl, tp;

   if(dir == DIR_UP)
     {
      if(entry > g_p0) { Alert("[FibLimitAssist] 买单入场价高于 0.00 高点，拒绝下单"); return; }
      sl = g_p1 - range * InpSL_OffsetPercent / 100.0;
      if(sl >= entry) { Alert("[FibLimitAssist] 买单止损价不低于入场价，拒绝下单"); return; }
      tp = entry + (entry - sl) * rr;
     }
   else
     {
      if(entry < g_p0) { Alert("[FibLimitAssist] 卖单入场价低于 0.00 低点，拒绝下单"); return; }
      sl = g_p1 + range * InpSL_OffsetPercent / 100.0;
      if(sl <= entry) { Alert("[FibLimitAssist] 卖单止损价不高于入场价，拒绝下单"); return; }
      tp = entry - (sl - entry) * rr;
     }

   double lot = CalcLot(entry, sl);
   double volMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(lot < volMin)
     {
      Alert("[FibLimitAssist] 计算手数 ", DoubleToString(lot, InpLotDecimals),
            " 小于品种最小手数 ", DoubleToString(volMin, InpLotDecimals), "，拒绝下单");
      return;
     }

   SendLimitOrder(dir, entry, sl, tp, lot);
  }

// v1.80: 0.79 挂单 TP 改为 0.19 装饰线位置 (RATIO_019); 0.49 保持 1:1 RR
// v1.84: 0.79 挂单拆成两半仓 — 半仓 1 TP=0.19 线 (v1.80 逻辑), 半仓 2 TP=0.79→0.19 距离的 2 倍
//   历史: v1.06 起 0.79 → RR=3.0 (TP 距离 = 3 × SL 距离); v1.80 起 0.79 → TP = TheoPrice(0.19); v1.84 起 0.79 → 拆两半仓
//   0.19 线位于 1.00/0.00 区间的另一端 (相对 0.79 远离 1.00), 因此:
//   - LONG (1.00 在底): 0.79 入场 ≈ 下部, 0.19 在上部 → TP > entry ✓
//   - SHORT (1.00 在顶): 0.79 入场 ≈ 上部, 0.19 在下部 → TP < entry ✓
void PlaceOrder(double r)
  {
   if(r == RATIO_079)
     {
      PlaceOrder079Split();
      return;
     }
   PlaceOrderWithRR(r, 1.0);
  }

// v1.84: 0.79 挂单拆成两半仓
//   - 两笔独立挂单, 同一 entry + 同一 SL, 不同 TP, lot 各半 (总风险 = 原来一次挂单的风险)
//   - 半仓 1 TP = TheoPrice(RATIO_019, g_p1, g_p0)        = 0.19 装饰线位置
//   - 半仓 2 TP = 2 * tp019 - entry                       = 0.79→0.19 距离沿同方向再延伸等距
//   - 几何: 半仓 2 TP 远超 1.00/0.00 区间外, 让利润奔跑
//     · LONG (g_p0>g_p1): tp2 > g_p0 (0.00 上方), 趋势延续时捕捉大波段
//     · SHORT(g_p0<g_p1): tp2 < g_p0 (0.00 下方), 趋势延续时捕捉大波段
//   - 注释后缀 " (1/2)" / " (2/2)" 区分两笔
void PlaceOrder079Split()
  {
   int dir = Dir();
   if(dir == DIR_FLAT)
     {
      Alert("[FibLimitAssist] 区间未定义：1.00 与 0.00 重合，无法下单");
      return;
     }

   double entry = LevelPrice(RATIO_079);
   double tp019 = TheoPrice(RATIO_019, g_p1, g_p0);
   double tp2   = 2.0 * tp019 - entry;   // 半仓 2 TP: 0.79→0.19 距离的 2 倍 (沿 0.79→0.19 方向延伸)
   double range = MathAbs(g_p0 - g_p1);
   double sl;

   if(dir == DIR_UP)
     {
      if(entry > g_p0) { Alert("[FibLimitAssist] 买单入场价高于 0.00 高点，拒绝下单"); return; }
      sl = g_p1 - range * InpSL_OffsetPercent / 100.0;
      if(sl >= entry) { Alert("[FibLimitAssist] 买单止损价不低于入场价，拒绝下单"); return; }
     }
   else
     {
      if(entry < g_p0) { Alert("[FibLimitAssist] 卖单入场价低于 0.00 低点，拒绝下单"); return; }
      sl = g_p1 + range * InpSL_OffsetPercent / 100.0;
      if(sl <= entry) { Alert("[FibLimitAssist] 卖单止损价不高于入场价，拒绝下单"); return; }
     }

   // v1.84: TP 方向校验 — 两个半仓 TP 都必须在 entry 的盈利侧
   //   极端情况: 用户把 0.79 拖到 0.19 之外 → tp019 不在盈利侧, tp2 也不在
   if(dir == DIR_UP)
     {
      if(tp019 <= entry) { Alert("[FibLimitAssist] 买单半仓 1 TP=0.19 不高于入场价, 拒绝下单"); return; }
      if(tp2   <= entry) { Alert("[FibLimitAssist] 买单半仓 2 TP=2× 距离不高于入场价, 拒绝下单"); return; }
     }
   else
     {
      if(tp019 >= entry) { Alert("[FibLimitAssist] 卖单半仓 1 TP=0.19 不低于入场价, 拒绝下单"); return; }
      if(tp2   >= entry) { Alert("[FibLimitAssist] 卖单半仓 2 TP=2× 距离不低于入场价, 拒绝下单"); return; }
     }

   // 总 lot = 单仓 lot (按 risk% 计算) — 总风险保持不变, 然后拆两半
   double volMin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double volStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double totalLot = CalcLot(entry, sl);
   if(totalLot < 2.0 * volMin - 1e-9)
     {
      // 半仓 lot < volMin 时无法安全拆单 (会触发券商最小手数校验)
      Alert("[FibLimitAssist] 计算手数 ", DoubleToString(totalLot, InpLotDecimals),
            " 不足以拆两半仓 (至少需要 ", DoubleToString(2.0 * volMin, InpLotDecimals), "), 拒绝下单");
      return;
     }

   // 各半 lot — 向下对齐到 volStep, 至少 1 个 volMin
   double halfLot = MathFloor(totalLot / 2.0 / volStep + 1e-9) * volStep;
   if(halfLot < volMin) halfLot = volMin;
   // 兜底: floor 后若单边仍 < volMin, 调整另一边 (通常不会触发, totalLot 校验已挡住)

   // 两笔独立挂单, 同 entry + SL, 不同 TP, lot 各半, 注释后缀区分
   //   注释 InpOrderComment = "FibLimitAssist" (14) + " (2/2)" (6) = 20 字符 < 31 上限, 安全
   string c1 = InpOrderComment + " (1/2)";
   string c2 = InpOrderComment + " (2/2)";
   SendLimitOrderEx(dir, entry, sl, tp019, halfLot, c1);
   SendLimitOrderEx(dir, entry, sl, tp2,   halfLot, c2);

   Print("[FibLimitAssist] 0.79 拆单完成 vol=", DoubleToString(totalLot, InpLotDecimals),
         " (各半 ", DoubleToString(halfLot, InpLotDecimals), ") | ",
         "半仓1 TP=0.19=", DoubleToString(tp019, _Digits),
         " 半仓2 TP=2×=",  DoubleToString(tp2,   _Digits));
  }

//---------------------------- 市价下单 -----------------------------//
void SendMarketOrder(int dir, double sl, double tp, double lot)
  {
   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action       = TRADE_ACTION_DEAL;
   req.symbol       = _Symbol;
   req.magic        = InpMagicNumber;
   req.volume       = lot;
   req.sl           = NormalizeDouble(sl, _Digits);
   req.tp           = NormalizeDouble(tp, _Digits);
   req.deviation    = 10;
   req.type         = (dir == DIR_UP) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   req.type_filling = GetFillMode();
   req.type_time    = ORDER_TIME_GTC;
   req.comment      = InpOrderComment;
   req.price        = (dir == DIR_UP) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(!OrderSend(req, res))
     {
      Alert("[FibLimitAssist] 市价下单失败 retcode=", res.retcode, " ", res.comment);
      return;
     }
   Print("[FibLimitAssist] 市价成交 ticket=", res.order, " ",
         (dir == DIR_UP ? "BUY" : "SELL"), " vol=", DoubleToString(lot, InpLotDecimals));
  }

// 市价下单：SL = g_p1 ± Range×1%，TP 距离 = SL 距离 (1:1)
void PlaceMarketOrder()
  {
   int dir = Dir();
   if(dir == DIR_FLAT)
     {
      Alert("[FibLimitAssist] 区间未定义：1.00 与 0.00 重合，无法市价下单");
      return;
     }

   double entry = (dir == DIR_UP) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double range = MathAbs(g_p0 - g_p1);
   double sl = (dir == DIR_UP) ? (g_p1 - range * InpSL_OffsetPercent / 100.0)
                               : (g_p1 + range * InpSL_OffsetPercent / 100.0);
   // 校验 SL 方向
   if(dir == DIR_UP  && sl >= entry) { Alert("[FibLimitAssist] 买单止损价不低于当前 ASK，拒绝市价下单"); return; }
   if(dir == DIR_DOWN && sl <= entry) { Alert("[FibLimitAssist] 卖单止损价不高于当前 BID，拒绝市价下单"); return; }

   double tp = (dir == DIR_UP) ? entry + (entry - sl)   // TP 距离 = SL 距离 (1:1)
                               : entry - (sl - entry);

   double lot = CalcLot(entry, sl);
   double volMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(lot < volMin)
     {
      Alert("[FibLimitAssist] 计算手数 ", DoubleToString(lot, InpLotDecimals),
            " 小于品种最小手数 ", DoubleToString(volMin, InpLotDecimals), "，拒绝市价下单");
      return;
     }

   SendMarketOrder(dir, sl, tp, lot);
  }

// v1.31: 突破挂单发送 (BUY STOP / SELL STOP pending order)
void SendStopOrder(int dir, double price, double sl, double tp, double lot)
  {
   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action       = TRADE_ACTION_PENDING;
   req.symbol       = _Symbol;
   req.magic        = InpMagicNumber;
   req.volume       = lot;
   req.price        = NormalizeDouble(price, _Digits);
   req.sl           = NormalizeDouble(sl, _Digits);
   req.tp           = NormalizeDouble(tp, _Digits);
   req.deviation    = 10;
   req.type         = (dir == DIR_UP) ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP;
   req.type_filling = GetFillMode();
   req.type_time    = ORDER_TIME_GTC;   // 无过期时间
   req.comment      = InpOrderComment;

   if(!OrderSend(req, res))
     {
      Alert("[FibLimitAssist] 突破单挂失败 retcode=", res.retcode, " ", res.comment);
      return;
     }
   Print("[FibLimitAssist] 突破单挂成功 ticket=", res.order, " ",
         (dir == DIR_UP ? "BUY" : "SELL"), " STOP vol=", DoubleToString(lot, InpLotDecimals),
         " entry=", DoubleToString(price, _Digits),
         " SL=",   DoubleToString(sl,    _Digits),
         " TP=",   DoubleToString(tp,    _Digits));
  }

// v1.31: 突破挂单 — SL/TP/lot 与市价按钮完全一致 (复用 PlaceMarketOrder 的公式)
// v1.73: 入场价改为"最新已收线 K 线 High/Low ± 1 tick", 不再参考 fib 1.00/0.00 端点
//   LONG → BUY STOP  entry = iHigh(1) + _Point   (最新已收线 K 线最高价上方 1 tick)
//   SHORT → SELL STOP entry = iLow(1)  - _Point   (最新已收线 K 线最低价下方 1 tick)
//   "最新已收线" = shift=1 的 K 线 (排除当前正在形成的 shift=0)
//   SL 公式仍锚 g_p1 (与 MKT 共用); TP = 1:1 盈亏比 (与 MKT 共用); lot = CalcLot (与 MKT 共用)
void PlaceStopOrder()
  {
   int dir = Dir();
   if(dir == DIR_FLAT)
     {
      Alert("[FibLimitAssist] 区间未定义：1.00 与 0.00 重合，无法下突破单");
      return;
     }

   // v1.73: 入场 = 最新已收线 K 线的 High (LONG) / Low (SHORT) ± 1 tick
   double lastHigh = iHigh(_Symbol, _Period, 1);
   double lastLow  = iLow (_Symbol, _Period, 1);
   if(lastHigh <= 0 || lastLow <= 0)
     {
      Alert("[FibLimitAssist] 最新已收线 K 线数据无效 (H=", DoubleToString(lastHigh, _Digits),
            " L=", DoubleToString(lastLow, _Digits), "), 拒绝突破单");
      return;
     }
   double entry = (dir == DIR_UP) ? NormalizeDouble(lastHigh + _Point, _Digits)
                                  : NormalizeDouble(lastLow  - _Point, _Digits);
   double range = MathAbs(g_p0 - g_p1);

   // SL 公式与市价按钮一致: g_p1 ± range * InpSL_OffsetPercent/100 (BUY 在 1.00 下方, SELL 在 1.00 上方)
   double sl = (dir == DIR_UP) ? (g_p1 - range * InpSL_OffsetPercent / 100.0)
                               : (g_p1 + range * InpSL_OffsetPercent / 100.0);

   // 方向校验
   if(dir == DIR_UP  && sl >= entry) { Alert("[FibLimitAssist] BUY STOP SL 不低于 entry, 拒绝挂单"); return; }
   if(dir == DIR_DOWN && sl <= entry) { Alert("[FibLimitAssist] SELL STOP SL 不高于 entry, 拒绝挂单"); return; }

   // TP 距离 = SL 距离 (与 MKT 一致 1:1)
   double tp = (dir == DIR_UP) ? entry + (entry - sl)
                               : entry - (sl - entry);

   double lot    = CalcLot(entry, sl);
   double volMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(lot < volMin)
     {
      Alert("[FibLimitAssist] 计算手数 ", DoubleToString(lot, InpLotDecimals),
            " 小于品种最小手数 ", DoubleToString(volMin, InpLotDecimals), ", 拒绝突破单");
      return;
     }

   SendStopOrder(dir, entry, sl, tp, lot);
  }

//---------------------------- 一键清场 -----------------------------//
// 取消账户内全部挂单（不限魔术号，含手动单）
void CancelAllPending()
  {
   int cancelled = 0, failed = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      long type = OrderGetInteger(ORDER_TYPE);
      if(type != ORDER_TYPE_BUY_LIMIT && type != ORDER_TYPE_SELL_LIMIT &&
         type != ORDER_TYPE_BUY_STOP && type != ORDER_TYPE_SELL_STOP &&
         type != ORDER_TYPE_BUY_STOP_LIMIT && type != ORDER_TYPE_SELL_STOP_LIMIT)
        continue;

      // 仅作用于当前图表品种，不影响其他品种的挂单
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;

      MqlTradeRequest req;
      MqlTradeResult  res;
      ZeroMemory(req); ZeroMemory(res);
      req.action = TRADE_ACTION_REMOVE;
      req.order  = ticket;
      if(OrderSend(req, res))
         cancelled++;
      else
        {
         failed++;
         Print("[FibLimitAssist] 取消挂单失败 ticket=", ticket, " retcode=", res.retcode, " ", res.comment);
        }
     }
   Print("[FibLimitAssist] 当前品种(", _Symbol, ")挂单清除完成：成功=", cancelled, " 失败=", failed);
   Alert("[FibLimitAssist] 当前品种(", _Symbol, ")挂单清除：成功 ", cancelled, " 张", (failed > 0 ? "，失败 " + IntegerToString(failed) + " 张" : ""));
  }

// 平掉账户内全部持仓（不涉及挂单）
void CloseAllPositions()
  {
   int closed = 0, failed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      string sym   = PositionGetString(POSITION_SYMBOL);

      // 仅作用于当前图表品种，不影响其他品种的持仓
      if(sym != _Symbol) continue;

      long   ptype = PositionGetInteger(POSITION_TYPE);
      double vol   = PositionGetDouble(POSITION_VOLUME);

      MqlTradeRequest req;
      MqlTradeResult  res;
      ZeroMemory(req); ZeroMemory(res);
      req.action       = TRADE_ACTION_DEAL;
      req.symbol       = sym;
      req.volume       = vol;
      req.position     = ticket;
      req.magic        = PositionGetInteger(POSITION_MAGIC);
      req.deviation    = 10;
      req.type_filling = GetFillModeFor(sym);
      if(ptype == POSITION_TYPE_BUY)
        {
         req.type  = ORDER_TYPE_SELL;
         req.price = SymbolInfoDouble(sym, SYMBOL_BID);
        }
      else
        {
         req.type  = ORDER_TYPE_BUY;
         req.price = SymbolInfoDouble(sym, SYMBOL_ASK);
        }

      if(OrderSend(req, res))
         closed++;
      else
        {
         failed++;
         Print("[FibLimitAssist] 平仓失败 ticket=", ticket, " retcode=", res.retcode, " ", res.comment);
        }
     }
   Print("[FibLimitAssist] 当前品种(", _Symbol, ")清仓完成：成功=", closed, " 失败=", failed);
   Alert("[FibLimitAssist] 当前品种(", _Symbol, ")清仓：成功 ", closed, " 笔", (failed > 0 ? "，失败 " + IntegerToString(failed) + " 笔" : ""));
  }

// 平掉账户全部持仓的 50%（按手数砍半，向下对齐到步长）
// 若砍半后手数 < 品种最小手数 → 直接全平该仓位
void CloseHalfPositions()
  {
   int halfClosed = 0, fullClosed = 0, failed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      string sym   = PositionGetString(POSITION_SYMBOL);

      // 仅作用于当前图表品种，不影响其他品种的持仓
      if(sym != _Symbol) continue;

      long   ptype = PositionGetInteger(POSITION_TYPE);
      double vol   = PositionGetDouble(POSITION_VOLUME);
      long   magic = PositionGetInteger(POSITION_MAGIC);

      double step  = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
      double vmin  = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
      if(step <= 0) step = 0.01;

      // 砍半后向下对齐到步长
      double half = MathFloor((vol / 2.0) / step + 1e-9) * step;
      // 砍半后 < 最小手数 → 全平
      bool fullClose = (half < vmin);

      MqlTradeRequest req;
      MqlTradeResult  res;
      ZeroMemory(req); ZeroMemory(res);
      req.action       = TRADE_ACTION_DEAL;
      req.symbol       = sym;
      req.position     = ticket;
      req.magic        = magic;
      req.deviation    = 10;
      req.type_filling = GetFillModeFor(sym);
      if(fullClose)
        {
         req.volume = vol;
        }
      else
        {
         req.volume = half;
        }
      if(ptype == POSITION_TYPE_BUY)
        {
         req.type  = ORDER_TYPE_SELL;
         req.price = SymbolInfoDouble(sym, SYMBOL_BID);
        }
      else
        {
         req.type  = ORDER_TYPE_BUY;
         req.price = SymbolInfoDouble(sym, SYMBOL_ASK);
        }

      if(OrderSend(req, res))
        {
         if(fullClose) fullClosed++;
         else           halfClosed++;
        }
      else
        {
         failed++;
         Print("[FibLimitAssist] 平一半失败 ticket=", ticket, " retcode=", res.retcode, " ", res.comment);
        }
     }
   Print("[FibLimitAssist] 当前品种(", _Symbol, ")平一半完成：半平=", halfClosed, " 全平=", fullClosed, " 失败=", failed);
   Alert("[FibLimitAssist] 当前品种(", _Symbol, ")平一半：半平 ", halfClosed, " 笔，全平 ", fullClosed, " 笔",
         (failed > 0 ? "，失败 " + IntegerToString(failed) + " 笔" : ""));
  }

//---------------------------- EVEN 一键入场价 (v1.08) -----------------//
//  · 盈利仓位：把 SL 改到入场价（标准 breakeven）
//  · 亏损仓位：把 TP 改到入场价（价格回到入场即保本离场）
//  目标统一：任意持仓「价格回到入场价即平仓」→ 既保本锁利，也避免继续亏损
void DoEven()
  {
   int modified = 0, failed = 0, skipped = 0;
   int n = PositionsTotal();
   for(int i = 0; i < n; i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      string sym    = PositionGetString(POSITION_SYMBOL);

      // 仅作用于当前图表品种，不影响其他品种的持仓
      if(sym != _Symbol) continue;

      long   ptype  = PositionGetInteger(POSITION_TYPE);
      double entry  = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL  = PositionGetDouble(POSITION_SL);
      double curTP  = PositionGetDouble(POSITION_TP);
      double cur    = (ptype == POSITION_TYPE_BUY)
                      ? SymbolInfoDouble(sym, SYMBOL_BID)
                      : SymbolInfoDouble(sym, SYMBOL_ASK);

      bool profitable;
      if(ptype == POSITION_TYPE_BUY)  profitable = (cur > entry);
      else                            profitable = (cur < entry);

      double newSL = curSL, newTP = curTP;
      if(profitable)
        {
         if(MathAbs(curSL - entry) < _Point / 2.0) { skipped++; continue; }   // 已是 breakeven
         newSL = entry;
        }
      else
        {
         if(curTP > 0 && MathAbs(curTP - entry) < _Point / 2.0) { skipped++; continue; }
         newTP = entry;
        }

      // normalize 到品种最小价位
      double nd = _Digits;
      if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "XAG") >= 0) nd = 2;   // 金属保留 2 位
      newSL = NormalizeDouble(newSL, (int)nd);
      newTP = NormalizeDouble(newTP, (int)nd);

      MqlTradeRequest req;
      MqlTradeResult  res;
      ZeroMemory(req); ZeroMemory(res);
      req.action   = TRADE_ACTION_SLTP;
      req.symbol   = sym;
      req.position = ticket;
      req.magic    = PositionGetInteger(POSITION_MAGIC);
      req.sl       = newSL;
      req.tp       = newTP;

      if(OrderSend(req, res))
         modified++;
      else
        {
         failed++;
         Print("[FibLimitAssist] EVEN 修改失败 ticket=", ticket, " retcode=", res.retcode, " ", res.comment);
        }
     }
   Print("[FibLimitAssist] 当前品种(", _Symbol, ")EVEN 完成：修改=", modified, " 跳过=", skipped, " 失败=", failed);
   Alert("[FibLimitAssist] 当前品种(", _Symbol, ")EVEN：修改 ", modified, " 笔", (skipped > 0 ? "，跳过 " + IntegerToString(skipped) + " 笔已入场价" : ""),
         (failed > 0 ? "，失败 " + IntegerToString(failed) + " 笔" : ""));
  }

//+------------------------------------------------------------------+
//| v1.13: ADJUST 按钮核心 - 识别最近的高低点                           |
//+------------------------------------------------------------------+

// 在指定窗口内识别分形点 (标准 Williams Fractals: 两侧各 D 根 bar 内为极值)
// deviation: 与前一同向候选最小价格偏差 (点)
// backstep:  与前一同向候选最小时间距离 (bar 数量, 用于替换紧挨的假信号)
// 返回所有候选分形点, 时间从新到旧 (out[0] 是最近的)
void BuildSwingCandidates(const double &prices[], const datetime &times[], int dir,
                          datetime &outTimes[], double &outPrices[])
  {
   ArrayResize(outTimes,  0);
   ArrayResize(outPrices, 0);

   double devia = InpAdjustDeviation * _Point;
   int    barSec = PeriodSeconds(_Period);
   if(barSec <= 0) barSec = 60;   // 兜底

   int arrTotal = ArraySize(prices);
   for(int i = InpAdjustDepth; i < arrTotal - InpAdjustDepth; i++)
     {
      double v = prices[i];

      // 左右窗口内为本方向极值
      bool isSwing = true;
      for(int k = 1; k <= InpAdjustDepth; k++)
        {
         if((dir == DIR_UP   && prices[i - k] > v) ||
            (dir == DIR_DOWN && prices[i - k] < v))
           { isSwing = false; break; }
        }
      if(!isSwing) continue;
      for(int k = 1; k <= InpAdjustDepth; k++)
        {
         if((dir == DIR_UP   && prices[i + k] > v) ||
            (dir == DIR_DOWN && prices[i + k] < v))
           { isSwing = false; break; }
        }
      if(!isSwing) continue;

      // deviation: 与最新候选价格偏差
      int n = ArraySize(outPrices);
      if(n > 0 && MathAbs(v - outPrices[n - 1]) < devia)
         continue;
      // backstep: 与最新候选时间距离 (用 bar 数 * PeriodSeconds 计算)
      if(n > 0)
        {
         long distSec = (long)times[i] - (long)outTimes[n - 1];
         // distSec 可能为负 (outTimes[n-1] 是更近的, 但扫描时 i 越大越旧, 不应该为负)
         // 实际场景: outTimes 按扫描顺序, [n-1] 是最近加入的 (i 更小), 所以 distSec >= 0
         long backstepSec = (long)InpAdjustBackstep * barSec;
         if(distSec < backstepSec)
           {
            // 时间太近, 用极值更强者替换 (高点取更高, 低点取更低)
            if((dir == DIR_UP   && v > outPrices[n - 1]) ||
               (dir == DIR_DOWN && v < outPrices[n - 1]))
              {
               outPrices[n - 1] = v;
               outTimes[n - 1]  = times[i];
              }
            continue;
           }
        }

      // 加入候选
      int sz = ArraySize(outPrices);
      ArrayResize(outPrices, sz + 1);
      ArrayResize(outTimes,  sz + 1);
      outPrices[sz] = v;
      outTimes[sz]  = times[i];
     }
  }

// 找最近一个候选分形点 (按 datetime 最近)
// dir = DIR_UP 找高点, DIR_DOWN 找低点
// 失败返回 false
bool FindNearestSwing(int dir, datetime &outTime, double &outPrice)
  {
   int totalBars = Bars(_Symbol, _Period);
   int minRequired = InpAdjustDepth * 2 + 5;
   if(totalBars < minRequired)
     {
      Print("[ADJUST] 错误: K线数据不足 (需要 ", minRequired, " 根, 实际 ", totalBars, " 根)");
      return false;
     }

   // 查找范围 = 图表可见 bar 数 (用户偏好), 兜底 500
   int visibleBars = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
   int lookback = (visibleBars > 0) ? visibleBars : 500;
   lookback = MathMin(lookback, totalBars);
   if(lookback < minRequired) lookback = MathMin(minRequired, totalBars);

   // 复制数据 (ArraySetAsSeries: arr[0] 是最新 bar)
   double highs[], lows[];
   datetime times[];
   ArrayResize(highs,  lookback);
   ArrayResize(lows,   lookback);
   ArrayResize(times,  lookback);
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows,  true);
   ArraySetAsSeries(times, true);
   if(CopyHigh(_Symbol, _Period, 0, lookback, highs) < lookback) { Print("[ADJUST] 错误: CopyHigh 失败"); return false; }
   if(CopyLow (_Symbol, _Period, 0, lookback, lows)  < lookback) { Print("[ADJUST] 错误: CopyLow 失败");  return false; }
   if(CopyTime(_Symbol, _Period, 0, lookback, times) < lookback) { Print("[ADJUST] 错误: CopyTime 失败"); return false; }

   // 收集候选分形点 (datetime 按新到旧排列)
   datetime candTimes[];
   double   candPrices[];

   if(dir == DIR_UP)
      BuildSwingCandidates(highs, times, dir, candTimes, candPrices);
   else
      BuildSwingCandidates(lows,  times, dir, candTimes, candPrices);

   if(ArraySize(candPrices) == 0)
     {
      Print("[ADJUST] 错误: 未识别到有效的", (dir == DIR_UP ? "高点" : "低点"),
            "候选 (InpAdjustDepth=", InpAdjustDepth,
            ", InpAdjustDeviation=", InpAdjustDeviation,
            ", InpAdjustBackstep=", InpAdjustBackstep, ")");
      return false;
     }

   // candTimes 已经是按扫描顺序 (新→旧), candTimes[0] 是最近候选
   outTime  = candTimes[0];
   outPrice = candPrices[0];
   return true;
  }

//+------------------------------------------------------------------+
//| v1.68: ADJUST 新逻辑 - 基于最近 FVG 找高低点                       |
//+------------------------------------------------------------------+

// 简单 3-bar Williams 低分形: K[j].Low < K[j-1].Low 且 K[j].Low < K[j+1].Low
//   j 必须 > 0 (左侧邻居存在) 且 < totalBars-1 (右侧邻居存在)
bool IsWilliamsLow(int j)
  {
   int total = Bars(_Symbol, _Period);
   if(j <= 0 || j >= total - 1) return false;
   double L  = iLow (_Symbol, _Period, j);
   double LL = iLow (_Symbol, _Period, j - 1);
   double LR = iLow (_Symbol, _Period, j + 1);
   if(L <= 0 || LL <= 0 || LR <= 0) return false;
   return (L < LL) && (L < LR);
  }

// 简单 3-bar Williams 高分形: K[j].High > K[j-1].High 且 K[j].High > K[j+1].High
bool IsWilliamsHigh(int j)
  {
   int total = Bars(_Symbol, _Period);
   if(j <= 0 || j >= total - 1) return false;
   double H  = iHigh(_Symbol, _Period, j);
   double HL = iHigh(_Symbol, _Period, j - 1);
   double HR = iHigh(_Symbol, _Period, j + 1);
   if(H <= 0 || HL <= 0 || HR <= 0) return false;
   return (H > HL) && (H > HR);
  }

// v1.68: 找最近一个 FVG (按 formTime 最大), 返回其 K2 (中间 K 线) 的 bar index
//   fvgDir 输出 DIR_UP / DIR_DOWN
//   返回 -1 表示未找到或 K2 不满足已收线要求
//   范围限定为图表可见区 (与现有 FVG 矩形绘制同源, 但仅用当前周期, 不混 higherTF 避免跨周期混乱)
// v1.70: 跳过 status=2 (完全填补) 的 FVG — 按 formTime 降序逐个尝试, 第一个未填补/部分填补的即返回
int FindMostRecentFVG_K2(int &fvgDir)
  {
   int firstBar = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR, 0);
   if(firstBar < 0) firstBar = 0;
   int widthBars = (int)ChartGetInteger(0, CHART_WIDTH_IN_BARS, 0);
   if(widthBars < 3) widthBars = 3;
   int lastBar = MathMax(0, firstBar - widthBars + 1);
   lastBar = MathMax(0, lastBar - 5);

   FVGRecord arr[];
   ArrayResize(arr, 0);
   DetectFVG(_Period, firstBar, lastBar, arr);
   if(ArraySize(arr) == 0) return -1;

   // v1.69: 按 formTime 降序逐个尝试, 跳过 K3 未收线 (bar 0) 的未成熟 FVG
   //   原逻辑只取 formTime 最大的一个, 若它是未成熟则直接 return -1
   //   但图表上往左还有已收线的成熟 FVG, 应该用那些
   bool tried[];
   ArrayResize(tried, ArraySize(arr));
   ArrayInitialize(tried, false);

   for(int pass = 0; pass < ArraySize(arr); pass++)
     {
      int best = -1;
      for(int i = 0; i < ArraySize(arr); i++)
        {
         if(tried[i]) continue;
         if(best < 0 || arr[i].formTime > arr[best].formTime) best = i;
        }
      if(best < 0) break;
      tried[best] = true;

      // DetectFVG: formTime = c3Time (K3 收线时间). K2 在 K3 前 1 根 (索引 +1).
      int k3Shift = iBarShift(_Symbol, _Period, arr[best].formTime);
      if(k3Shift < 1) continue;  // K3 未收线 (bar 0), 跳过试次近的
      int k2Shift = k3Shift + 1;
      if(k2Shift < 1) continue;  // K2 必须已收线
      // v1.70: 跳过已完全填补 (status=2) 的 FVG, 试次近的 (U=0, P=1 可用)
      ClassifyFVGStatus(arr[best], _Period);
      if(arr[best].status == 2) continue;
      fvgDir = arr[best].dir;
      return k2Shift;
     }

   return -1;
  }

// v1.68: ADJUST 新逻辑 — 基于最近 FVG 找高低点
//   看涨 FVG → 强制 LONG: g_p1 (1.00) = FVG K2 左侧最近 Williams 低, g_p0 (0.00) = K2→bar0 max high
//   看跌 FVG → 强制 SHORT: g_p1 (1.00) = FVG K2 左侧最近 Williams 高, g_p0 (0.00) = K2→bar0 min low
//   返回 true 成功; false 失败 (调用方回退到原 Williams Fractal 逻辑)
bool DoAdjustFVG()
  {
   int fvgDir = DIR_FLAT;
   int fvgK2 = FindMostRecentFVG_K2(fvgDir);
   if(fvgK2 < 0)
     {
      Alert("[FibLimitAssist] ADJUST: 未找到有效 FVG, 回退到 Williams Fractal 逻辑");
      return false;
     }

   int firstBar = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR, 0);
   if(firstBar < 0) firstBar = 0;
   int totalBars = Bars(_Symbol, _Period);
   int maxScanIdx = MathMin(firstBar, totalBars - 2);  // j+1 < totalBars 需满足

   double pH = 0, pL = 0;
   datetime tH = 0, tL = 0;
   int srcHBar = 0, srcLBar = 0;

   if(fvgDir == DIR_UP)  // 看涨 FVG → LONG (1.00 下方, 0.00 上方)
     {
      // 高点 (0.00) = FVG K2 → bar 0 的 max high (含实时 K 线)
      pH = iHigh(_Symbol, _Period, fvgK2);
      srcHBar = fvgK2;
      for(int i = fvgK2 - 1; i >= 0; i--)
        {
         double h = iHigh(_Symbol, _Period, i);
         if(h > pH) { pH = h; srcHBar = i; }
        }
      tH = iTime(_Symbol, _Period, srcHBar);

      // 低点 (1.00) = FVG K2 左侧最近 Williams 低 (向左扫, 第一个匹配即返回)
      int foundL = -1;
      for(int j = fvgK2 + 1; j <= maxScanIdx; j++)
        {
         if(IsWilliamsLow(j)) { foundL = j; break; }
        }
      if(foundL < 0)
        {
         Alert("[FibLimitAssist] ADJUST 失败: 找到看涨 FVG (K2=bar ", fvgK2,
               "), 但左侧无 Williams 低点, 拒绝调整");
         return false;
        }
      pL = iLow(_Symbol, _Period, foundL);
      srcLBar = foundL;
      tL = iTime(_Symbol, _Period, srcLBar);
     }
   else if(fvgDir == DIR_DOWN)  // 看跌 FVG → SHORT (1.00 上方, 0.00 下方) — 镜像
     {
      // 高点 (1.00) = FVG K2 左侧最近 Williams 高
      int foundH = -1;
      for(int j = fvgK2 + 1; j <= maxScanIdx; j++)
        {
         if(IsWilliamsHigh(j)) { foundH = j; break; }
        }
      if(foundH < 0)
       {
         Alert("[FibLimitAssist] ADJUST 失败: 找到看跌 FVG (K2=bar ", fvgK2,
               "), 但左侧无 Williams 高点, 拒绝调整");
         return false;
        }
      pH = iHigh(_Symbol, _Period, foundH);
      srcHBar = foundH;
      tH = iTime(_Symbol, _Period, srcHBar);

      // 低点 (0.00) = FVG K2 → bar 0 的 min low (含实时 K 线)
      pL = iLow(_Symbol, _Period, fvgK2);
      srcLBar = fvgK2;
      for(int i = fvgK2 - 1; i >= 0; i--)
        {
         double l = iLow(_Symbol, _Period, i);
         if(l < pL) { pL = l; srcLBar = i; }
        }
      tL = iTime(_Symbol, _Period, srcLBar);
     }
   else
     {
      Alert("[FibLimitAssist] ADJUST: 未知 FVG 方向, 回退");
      return false;
     }

   // 异常检查
   if(MathAbs(pH - pL) < _Point * InpAdjustDeviation)
     {
      Alert("[FibLimitAssist] ADJUST 失败: 识别的高低点距离过近 (",
            DoubleToString(MathAbs(pH - pL) / _Point, 1), " points < ", InpAdjustDeviation, "), 拒绝");
      return false;
     }
   if(pH <= pL)
     {
      Alert("[FibLimitAssist] ADJUST 失败: 高点(", DoubleToString(pH, _Digits), ") <= 低点(",
            DoubleToString(pL, _Digits), "), 数据异常, 拒绝");
      return false;
     }
   if(tH > TimeCurrent() || tL > TimeCurrent())
     {
      Alert("[FibLimitAssist] ADJUST 失败: 时间在未来 (H=", TimeToString(tH),
            ", L=", TimeToString(tL), "), 数据异常, 拒绝");
      return false;
     }

   // 赋值 — 按 fvgDir 直接设置 LONG/SHORT 语义 (无需 SWAP)
   //   看涨 (LONG):  g_p1 (1.00) = pL (低, 下方) | g_p0 (0.00) = pH (高, 上方)
   //   看跌 (SHORT): g_p1 (1.00) = pH (高, 上方) | g_p0 (0.00) = pL (低, 下方)
   if(fvgDir == DIR_UP)
     {
      g_p1 = NormalizeDouble(pL, _Digits);
      g_p0 = NormalizeDouble(pH, _Digits);
     }
   else  // DIR_DOWN
     {
      g_p1 = NormalizeDouble(pH, _Digits);
      g_p0 = NormalizeDouble(pL, _Digits);
     }

   // 0.79/0.49 回归理论
   g_p79 = TheoPrice(RATIO_079, g_p1, g_p0);
   g_p49 = TheoPrice(RATIO_049, g_p1, g_p0);

   // 重画
   RefreshAll();

   // 反馈
   int dir = Dir();
   string dirText  = (dir == DIR_UP)   ? "做多" : ((dir == DIR_DOWN) ? "做空" : "FLAT");
   string fvgText  = (fvgDir == DIR_UP) ? "看涨" : "看跌";
   double rangePts = MathAbs(pH - pL) / _Point;

   Print("[ADJUST v1.68] FVG=", fvgText, "  K2=bar ", fvgK2,
         "  time=", TimeToString(iTime(_Symbol, _Period, fvgK2), TIME_DATE|TIME_MINUTES));
   Print("[ADJUST v1.68] High (1.00): ", DoubleToString(pH, _Digits),
         "  time=", TimeToString(tH, TIME_DATE|TIME_MINUTES), "  bar=", srcHBar);
   Print("[ADJUST v1.68] Low  (0.00): ", DoubleToString(pL, _Digits),
         "  time=", TimeToString(tL, TIME_DATE|TIME_MINUTES), "  bar=", srcLBar);
   Print("[ADJUST v1.68] Range:       ", DoubleToString(rangePts, 1), " points");
   Print("[ADJUST v1.68] Direction:   ", dirText);
   Print("[ADJUST v1.68] 0.79 = ", DoubleToString(TheoPrice(RATIO_079, g_p1, g_p0), _Digits));
   Print("[ADJUST v1.68] 0.49 = ", DoubleToString(TheoPrice(RATIO_049, g_p1, g_p0), _Digits));

   Alert("[FibLimitAssist] ADJUST 完成 (", _Symbol, ", ", fvgText, " FVG): ",
         "1.00=", DoubleToString(pH, _Digits), " (", TimeToString(tH, TIME_DATE|TIME_MINUTES), "), ",
         "0.00=", DoubleToString(pL, _Digits), " (", TimeToString(tL, TIME_DATE|TIME_MINUTES), "), ",
         "Range=", DoubleToString(rangePts, 1), " points, 方向=", dirText);

   return true;
  }

//+------------------------------------------------------------------+
//| v1.13: ADJUST 入口 - 点击按钮后调用                                |
//| v1.68: 改为先试 FVG 新逻辑, 失败回退到原 Williams Fractal 逻辑       |
//+------------------------------------------------------------------+
void DoAdjust()
  {
   // 1. v1.68 先试 FVG 新逻辑
   if(DoAdjustFVG()) return;

   // 2. 回退: 原 Williams Fractal 逻辑 (v1.13-v1.67)
   //    1) 找最近高点 (1.00)
   datetime tH = 0; double pH = 0;
   if(!FindNearestSwing(DIR_UP, tH, pH))
     {
      Alert("[FibLimitAssist] ADJUST 失败: 未识别到有效高点 (请放大图表或调整 Depth/Deviation/Backstep 参数)");
      return;
     }

   //    2) 找最近低点 (0.00)
   datetime tL = 0; double pL = 0;
   if(!FindNearestSwing(DIR_DOWN, tL, pL))
     {
      Alert("[FibLimitAssist] ADJUST 失败: 未识别到有效低点 (请放大图表或调整 Depth/Deviation/Backstep 参数)");
      return;
     }

   //    3) 异常检查
   if(MathAbs(pH - pL) < _Point * InpAdjustDeviation)
     {
      Alert("[FibLimitAssist] ADJUST 失败: 识别的高低点距离过近 (",
            DoubleToString(MathAbs(pH - pL) / _Point, 1), " points < ", InpAdjustDeviation, " points 阈值), 不调整");
      return;
     }
   if(pH <= pL)
     {
      Alert("[FibLimitAssist] ADJUST 失败: 最近高点 (", DoubleToString(pH, _Digits), ") <= 最近低点 (",
            DoubleToString(pL, _Digits), "), 数据异常, 不调整");
      return;
     }
   if(tH > TimeCurrent() || tL > TimeCurrent())
     {
      Alert("[FibLimitAssist] ADJUST 失败: 识别出的时间戳在未来 (高点时间=", TimeToString(tH),
            ", 低点时间=", TimeToString(tL), "), 数据异常, 不调整");
      return;
     }

   //    4) 改全局变量: 1.00 / 0.00 按新高低点 (原逻辑固定 1.00=高, 0.00=低, 默认 SHORT 方向)
   g_p1 = NormalizeDouble(pH, _Digits);   // 1.00 = 最近高点
   g_p0 = NormalizeDouble(pL, _Digits);   // 0.00 = 最近低点

   //    5) 端点变了 → 0.49 / 0.79 立即回归理论值 (与 ApplyDrag 拖动端点行为一致).
   g_p79 = TheoPrice(RATIO_079, g_p1, g_p0);
   g_p49 = TheoPrice(RATIO_049, g_p1, g_p0);

   //    6) 重画
   RefreshAll();

   //    7) 反馈 (Print + Alert)
   double rangePoints = (pH - pL) / _Point;
   int dir = Dir();
   string dirText = (dir == DIR_UP) ? "做多" : ((dir == DIR_DOWN) ? "做空" : "FLAT");

   Print("[ADJUST] (回退) High (1.00): ", DoubleToString(pH, _Digits),
         "  time=", TimeToString(tH, TIME_DATE|TIME_MINUTES));
   Print("[ADJUST] (回退) Low  (0.00): ", DoubleToString(pL, _Digits),
         "  time=", TimeToString(tL, TIME_DATE|TIME_MINUTES));
   Print("[ADJUST] (回退) Range:       ", DoubleToString(rangePoints, 1), " points (", DoubleToString(pH - pL, _Digits), ")");
   Print("[ADJUST] (回退) Direction:   ", dirText);
   Print("[ADJUST] (回退) 0.79 = ", DoubleToString(TheoPrice(RATIO_079, g_p1, g_p0), _Digits));
   Print("[ADJUST] (回退) 0.49 = ", DoubleToString(TheoPrice(RATIO_049, g_p1, g_p0), _Digits));
   Print("[ADJUST] (回退) 0.19 = ", DoubleToString(TheoPrice(RATIO_019, g_p1, g_p0), _Digits));

   Alert("[FibLimitAssist] ADJUST 完成 (", _Symbol, "): ",
         "1.00=", DoubleToString(pH, _Digits), " (高点, ", TimeToString(tH, TIME_DATE|TIME_MINUTES), "), ",
         "0.00=", DoubleToString(pL, _Digits), " (低点, ", TimeToString(tL, TIME_DATE|TIME_MINUTES), "), ",
         "Range=", DoubleToString(rangePoints, 1), " points, 方向=", dirText);
  }

//---------------------------- 风险/隐藏/市价 业务处理 --------------//
// 风险档位循环：1% → 2% → 3% → 1% (即 0.5 → 1 → 2 → 0.5)
void CycleRisk()
  {
   int idx = 0;
   for(int i = 0; i < ArraySize(g_riskValues); i++)
     {
      if(MathAbs(g_riskValues[i] - g_riskPercent) < 1e-9) { idx = i; break; }
     }
   idx = (idx + 1) % ArraySize(g_riskValues);
   g_riskPercent = g_riskValues[idx];
   SaveRisk();
   Print("[FibLimitAssist] 风险档位切换为 ", DoubleToString(g_riskPercent, 1), "%");
   RefreshAll();   // v1.07：刷新按钮文字 + 配色（v2.11: 三档→四档）
  }

// 切换隐藏/显示
void ToggleHide()
  {
   g_hidden = !g_hidden;
   RefreshAll();   // 重新定位 + 更新 HIDE/SHOW 文字 + 应用隐藏
   Print("[FibLimitAssist] 隐藏状态切换为 ", g_hidden ? "HIDE" : "SHOW");
  }

//---------------------------- 拖拽处理 -----------------------------//
double RatioOfHLine(string name)
  {
   if(name == HName(RATIO_100)) return RATIO_100;
   if(name == HName(RATIO_079)) return RATIO_079;
   if(name == HName(RATIO_049)) return RATIO_049;
   if(name == HName(RATIO_000)) return RATIO_000;
   return -1.0;   // 0.19 不可拖拽，忽略
  }
double RatioOfButton(string name)
  {
   if(name == BName(RATIO_079)) return RATIO_079;
   if(name == BName(RATIO_049)) return RATIO_049;
   return -1.0;
  }

void ApplyDrag(double r, double price)
  {
   if(r == RATIO_100)
     {
      g_p1 = price;
      // 拖动端点：0.79 / 0.49 强制回归理论比例，丢弃手动偏移
      g_p79 = TheoPrice(RATIO_079, g_p1, g_p0);
      g_p49 = TheoPrice(RATIO_049, g_p1, g_p0);
     }
   else if(r == RATIO_000)
     {
      g_p0 = price;
      g_p79 = TheoPrice(RATIO_079, g_p1, g_p0);
      g_p49 = TheoPrice(RATIO_049, g_p1, g_p0);
     }
   else if(r == RATIO_079) g_p79 = price;
   else if(r == RATIO_049) g_p49 = price;
   else return;

   // v1.15: 端点/挂单线位置不再记忆, 无需保存
   RefreshAll();
  }

// 多空切换：对调起点(1.00)与终点(0.00)，方向自动翻转；0.79/0.49 回归理论比例
void DoSwap()
  {
   double t = g_p1;
   g_p1 = g_p0;
   g_p0 = t;
   g_p79 = TheoPrice(RATIO_079, g_p1, g_p0);
   g_p49 = TheoPrice(RATIO_049, g_p1, g_p0);
   // v1.15: 端点位置不再记忆, 无需保存
   RefreshAll();
  }

//---------------------------- 生命周期 -----------------------------//
int OnInit()
  {
   // v1.15: prefix 增加 _Period, 减少 MT5 ChartID 复用导致的跨周期状态串扰
   g_prefix = "FLA_" + IntegerToString(ChartID()) + "_" + _Symbol + "_" + EnumToString(_Period) + "_";

   // v1.29: 计算 UI/字号缩放系数 — 手动值优先, 0 则按平台智能默认
   //   v1.89: UI 缩放取消平台区分 — Windows 和 Wine/mac 一律 defaultUIScale=1.0
   //         (历史: v1.27 引入时 Windows=0.6 自动缩小挡图, v1.85 默认改 1.0, v1.88 改回 0.6, v1.89 改为统一 1.0)
   //   字号仍保持 defaultFontScale=1.0 (按钮缩小但字保持可读, 与缩放系数解耦)
   double defaultUIScale   = 1.0;   // v1.89: 取消 Windows=0.6 的平台默认, 所有平台统一 1.0
   double defaultFontScale = 1.0;   // 默认字号不变 (按钮缩小但字保持可读)
   g_uiScale   = (InpUIScale   > 0.01) ? InpUIScale   : defaultUIScale;
   g_fontScale = (InpFontScale > 0.01) ? InpFontScale : defaultFontScale;
   if(g_uiScale   < 0.2) g_uiScale   = 0.2;   // 下限保护
   if(g_uiScale   > 3.0) g_uiScale   = 3.0;   // 上限保护
   if(g_fontScale < 0.2) g_fontScale = 0.2;   // 下限保护
   if(g_fontScale > 3.0) g_fontScale = 3.0;   // 上限保护

   // v1.91: 运行时变量从 input 拷贝初始值 (MQL5 input 是编译期常量, 不能运行时赋值)
   g_signalAlert   = InpSignalAlert;
   g_pullbackLevel = (g_p1 > 0 && g_p0 > 0) ? (g_p1 - 0.49 * (g_p1 - g_p0)) : 0.0;
   g_prevP1        = g_p1;
   g_prevP0        = g_p0;

   // v1.12: 自动探测服务器时区 (用于 CE(S)T 切日换算)
   DetectTimezone();

   // v1.36: 端点位置按周期记忆 — 先尝试恢复上次位置, 无记忆才用数据驱动的默认区间
   if(!LoadFibPositions())
     {
      // v1.38: 首次(或重启后清空): 用最近 N 根已收盘 bar 的 High/Low 作为默认区间
      //   不再用 ChartGetDouble(CHART_PRICE_MAX/MIN) — 那是"视图窗口"属性, 切换周期瞬间
      //   可能返回 0/0 (D1 挤死) 或过窄/错位区间 (M30/M15/M5/M1 跑出屏幕), 均不可靠
      double hi = 0.0, lo = 0.0;
      int bars = MathMax(1, InpDefaultSpanBars);
      int total = Bars(_Symbol, _Period);
      if(total > 0)
        {
         int avail = MathMin(bars, total - 1);   // 留最后 1 根(当前未收盘)不计入, 从 shift=1 扫
         for(int i = 1; i <= avail; i++)
           {
            double h = iHigh(_Symbol, _Period, i);
            double l = iLow(_Symbol, _Period, i);
            if(h <= 0 || l <= 0) continue;          // 忽略缺失数据(历史未载入)
            if(hi == 0.0 || h > hi) hi = h;
            if(lo == 0.0 || l < lo) lo = l;
           }
        }

      // 兜底: 若拿不到有效高低点(数据不足/异常), 退化为当前价 ±2% 对称区间
      if(hi <= 0 || lo <= 0 || hi <= lo)
        {
         double mid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(mid <= 0) mid = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double half = mid * 0.02;
         if(mid <= 0) { mid = 1.0; half = 1.0; }   // 极端情况保护, 绝不 0 价
         lo = mid - half;
         hi = mid + half;
        }

      double span = hi - lo;
      if(span < 10 * _Point) span = 10 * _Point;    // 最小 span 保护(10 点), 防挤死
      g_p1  = lo + span * 0.1;
      g_p0  = hi - span * 0.1;
      g_p79 = TheoPrice(RATIO_079, g_p1, g_p0);
      g_p49 = TheoPrice(RATIO_049, g_p1, g_p0);
     }

   // 风险档位会话内持久
   LoadRisk();

   // v1.45: FVG 默认高级别周期 — Auto 模式按当前周期映射, 否则用 InpFVG_HigherTF_Period
   g_higherTF = InpFVG_HigherTF_Auto ? PickDefaultHigherTF(_Period) : InpFVG_HigherTF_Period;

   CreateObjects();
   g_lastBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   RefreshAll();
   g_dirty = false;
   UpdateFVGDisplay();   // v1.50: OnInit 即调一次, 周末/非交易时段加载 EA 也能立即看到 FVG (原仅 OnTick 触发, 收市无新 tick 一直空白)
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   // v1.36: 切周期/移除前保存位置 (临时全局变量, 会话内持久, 重启自动清空)
   SaveFibPositions();
   // 仅清除本实例图表对象；服务器挂单保留不动
   ObjectsDeleteAll(0, g_prefix, -1, -1);
   ChartRedraw(0);
  }

void OnTick()
  {
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(MathAbs(bal - g_lastBalance) > DBL_EPSILON) { g_lastBalance = bal; g_dirty = true; }

   static datetime lastBarTime = 0;
   datetime bt = iTime(_Symbol, _Period, 0);
   if(bt != lastBarTime) { lastBarTime = bt; g_dirty = true; }

   if(g_dirty) { RefreshAll(); g_dirty = false; UpdateFVGDisplay(); }   // v2.04: UpdateFVGDisplay 移到 g_dirty 块内
                                                                                    //   原每 tick 调用导致 FVG 矩形闪烁:
                                                                                    //   - DetectFVG 每 tick 重建 FVGRecord 数组, 状态从 0 开始
                                                                                    //   - 可见区边界 FVG 在 tick 之间反复进出集合, 触发 create/delete → 视觉闪烁
                                                                                    //   - ClassifyFVGStatus 的 if(status==2)return 仅在单次调用内有效, 跨调用 F 状态会重置
                                                                                    //   - ClassifyFVGStatus 扫描的是已收线 K 线 (shift>=1), 与实时 tick 无关
                                                                                    //   → FVG 检测/分类的输入在 K 线内不变, 每 tick 重做无意义
                                                                                    //   移到 g_dirty 块 (新柱收线 + 图表缩放/拖动) 触发即可, 行为不变但消除闪烁
   else        { UpdatePnLDisplay(); UpdateRatioLabels(); UpdateSpreadDisplay(); ChartRedraw(0); }   // v1.08 PnL + v1.35 盈亏比 + v1.75 点差 — 每个 tick 都刷新, 不等新柱

   // v1.91: 信号提醒 — 价格首次回调到区间 0.49 位置时弹窗+日志 (内部判断 g_signalAlert, 关闭时零开销)
   CheckPullbackSignal();
   // v2.00: 盈亏播报 — 共用 g_signalAlert 总开关, 整 15 分钟 (00/15/30/45) 检查持仓并发送推送
   CheckPnLReport();
  }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_DRAG || id == CHARTEVENT_OBJECT_ENDEDIT)
     {
      double r = RatioOfHLine(sparam);
      if(r < 0) return;
      double price = ObjectGetDouble(0, sparam, OBJPROP_PRICE, 0);
      ApplyDrag(r, price);
     }
   else if(id == CHARTEVENT_OBJECT_CLICK)
     {
      // v1.07：除 HIDE 外，所有"动作型"按钮处理后立即弹起 (STATE=false)
      // HIDE 保留 sticky 行为：按下表示当前隐藏中 (由 UpdateHideButton 同步设置)
      if(sparam == SwapName())
        {
         DoSwap();
         ObjectSetInteger(0, SwapName(), OBJPROP_STATE, false);
         return;
        }
      if(sparam == AdjustName())   // v1.13: ADJUST 按钮 - 一键调整 1.00/0.00 到最近的高低点
        {
         DoAdjust();
         ObjectSetInteger(0, AdjustName(), OBJPROP_STATE, false);
         return;
        }
      if(sparam == CancelPendingName())
        {
         CancelAllPending();
         ObjectSetInteger(0, CancelPendingName(), OBJPROP_STATE, false);
         return;
        }
      if(sparam == CloseAllName())
        {
         CloseAllPositions();
         ObjectSetInteger(0, CloseAllName(), OBJPROP_STATE, false);
         return;
        }
      if(sparam == CloseHalfName())
        {
         CloseHalfPositions();
         ObjectSetInteger(0, CloseHalfName(), OBJPROP_STATE, false);
         return;
        }
      if(sparam == EvenName())
        {
         DoEven();
         ObjectSetInteger(0, EvenName(), OBJPROP_STATE, false);
         UpdatePnLDisplay();   // 立刻刷一次浮盈数字
         return;
        }
      if(sparam == RiskName())
        {
         CycleRisk();
         // CycleRisk 内部已 RefreshAll -> UpdateRiskButton，无需单独弹起
         return;
        }
      if(sparam == MarketName())
        {
         PlaceMarketOrder();
         ObjectSetInteger(0, MarketName(), OBJPROP_STATE, false);
         return;
        }
      if(sparam == StopName())
        {
         PlaceStopOrder();
         ObjectSetInteger(0, StopName(), OBJPROP_STATE, false);
         return;
        }
      if(sparam == HideName())
        {
         ToggleHide();   // UpdateHideButton 会根据 g_hidden 同步设置 STATE
         return;
        }
      if(sparam == FVGButtonName())
        {
         AdvanceFVGState();   // v1.83: 状态机前进 (FVG→FILL→OFF→FVG), 替代 v1.81 双 bool 翻转
         return;
        }
      if(sparam == SignalName())   // v1.91: 信号提醒开关按钮 — 切换 SIGNAL/OFF
        {
         ToggleSignalAlert();   // 内部已 UpdateSignalButton + Print
         return;
        }
      // v1.81: FILL 按钮 — 切换填补态 (status=2) 显隐
      //   与 InpFVG_ShowFilled AND 关系: 用户点 ON 但输入参数 false → 按钮显示蓝色但无矩形 (UpdateFillButton 灰色提示)
      // v1.83: FILL 按钮已合并入 FVG 按钮 (单按钮 3 态循环), 这里删除独立分支

      // v1.17: STEP 按钮 (UP/DOWN) — 解析名称 → ApplyStepButton
      if(StringFind(sparam, g_prefix + "STEP_") == 0)
        {
         ApplyStepButton(sparam);
         return;
        }

      double r = RatioOfButton(sparam);
      if(r > 0)
        {
         PlaceOrder(r);
         // 0.79/0.49 挂单按钮也立即弹起
         ObjectSetInteger(0, BName(r), OBJPROP_STATE, false);
        }
     }
   else if(id == CHARTEVENT_CHART_CHANGE)
     {
      g_dirty = true;
     }
  }
//+------------------------------------------------------------------+
