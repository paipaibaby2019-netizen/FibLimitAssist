//+------------------------------------------------------------------+
//|                                                 FibLimitAssist.mq5 |
//|                               半自动斐波那契限价下单辅助 EA        |
//|        交易方向 / 行情判断完全人工，EA 只负责绘图 + 按钮 + 下单     |
//+------------------------------------------------------------------+
#property copyright "FibLimitAssist"
#property version   "1.34"
#property description "半自动斐波那契限价下单辅助："
#property description "· 人工拖拽 1.00 起点 / 0.00 终点定义高低区间"
#property description "· 点击 0.79 / 0.49 右侧按钮下发 ORDER_LIMIT 限价单"
#property description "· 单笔风险 = 余额固定百分比，盈亏比固定，手数反算并截断"
#property description "· MKT 按钮两侧实时显示持仓浮盈 + 当日累计盈亏"
#property description "· EVEN 按钮统一把任意持仓调到入场价平仓（盈改 SL，亏改 TP）"
#property description "· ADJUST 按钮一键把 1.00/0.00 调整到图表最近的高低点 (v1.13)"
#property description "· 1.00/0.79/0.49/0.00 各一对 STEP 按钮微调单线, 双击=×10 加速 (v1.17, v1.24 浅灰配色)"
#property description "· HIDE 按钮改浅灰底 (与 CANCEL 同色, v1.25); EVEN/CHALF/CALL 等距 4px (v1.25); 0.79/0.49 线随方向变色 (long 绿/short 红, v1.25)"
#property description "· SWAP/ADJUST/CANCEL 三个按钮统一放最上面线下方 4px (v1.26, 不再被线穿过)"
#property description "· UI 缩放拆尺寸/字号: InpUIScale 缩按钮, InpFontScale 缩字号 (v1.28)"
#property description "· v1.29 修复 Wine 误判: 平台检测改用 Z 盘/便携模式特征, mac(Wine) 不再被误当 Windows 缩放"
#property description "· v1.30 STEP 按钮调整端点 (1.00/0.00) 时, 中间线 0.79/0.49 也按比例跟随 (与鼠标拖动端点行为一致)"
#property description "· v1.31 新增 BUY/SELL STOP 突破挂单按钮 (在 MKT 右侧 slack 区): long=绿挂视觉 top+1tick, short=红挂视觉 bot-1tick, SL/TP/lot 与 MKT 一致"
#property description "· v1.32 STOP/MKT 关于底线镜像对称 (MKT 上方 4px, STOP 下方 4px); STOP 不再抢占 g_btnX (恢复 CALL/CHALF/EVEN/CANCEL/挂单按钮/PnL 标签右对齐)"
#property description "· v1.33 按钮文字缩短: BUY STOP→BUY STP, SELL STOP→SELL STP (修正 v1.33 漏掉的 #property version bump)"
#property description "· v1.34 底线下新增盈亏比标签 (右对齐 CALL 右边缘, 关于底线上对衬): (1.4:3.2) NN%, 1.4=∑浮盈/∑止盈 (绿/红/灰), 3.2=∑止盈/∑止损 (saddle brown), NN%=1.4/3.2*100 四舍五入"

//---------------------------- 输入参数 -----------------------------//
// 注: 单笔风险(%) 由 RISK 按钮循环控制 (0.5/1/2)，盈亏比按比例分档 (0.79=3:1, 0.49=1:1, 市价=1:1)
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

// v1.17 新增: 1.00/0.00/0.79/0.49 线上 UP/DOWN 按钮 - 单击步长 = swing 区间 × (InpStepPercent)%, 双击 ×10
input double InpStepPercent  = 1.0; // [STEP] 单击移动步长占 swing 区间百分比 (%); 双击同按钮 300ms 内 = ×10

// v1.27 新增: UI 界面缩放系数 (统一缩放所有按钮/标签的尺寸与间距)
//   Mac/Wine 版或 96DPI 屏幕用 1.0; 远程 Windows 服务器按钮过大时, 调小 (如 0.6~0.8)
//   0 = 自动按平台智能默认 (mac=1.0, Windows=0.6); 其他正数 = 强制使用 (手动覆盖智能默认)
input double InpUIScale = 0.0;   // [UI] 按钮尺寸缩放系数 (0=按平台智能默认; 正数=强制值)

// v1.28 新增: 字号独立缩放系数 (与 InpUIScale 解耦, 防止按钮缩小后文字看不清)
//   0 = 自动按平台智能默认 (mac=1.0, Windows=1.0); 其他正数 = 强制值 (如 0.8=字小一些)
input double InpFontScale = 0.0;  // [UI] 字号缩放系数 (0=按平台智能默认; 正数=强制值)

//---------------------------- 固定比例 -----------------------------//
#define RATIO_100 1.00
#define RATIO_079 0.79
#define RATIO_049 0.49
#define RATIO_021 0.21
#define RATIO_000 0.00

//---------------------------- 颜色定义 -----------------------------//
#define CLR_END      C'90,90,90'     // 端点 1.00 / 0.00 线
// v1.25 删除 CLR_MID：0.79/0.49 线颜色改为随方向动态变化 (DIR_UP→CLR_BUY_BG 绿, DIR_DOWN→CLR_SELL_BG 红, DIR_FLAT→CLR_FLAT_BG 灰), 由 RefreshAll 同步
#define CLR_DECO     C'115,115,115'  // 0.21 装饰线（加深，避免看不清）
#define CLR_BUY_BG   C'76,175,80'    // 买单按钮底色 (+0.79/0.49 线 long 态)
#define CLR_SELL_BG  C'244,67,54'    // 卖单按钮底色 (+0.79/0.49 线 short 态)
#define CLR_FLAT_BG  C'140,140,140'  // 方向未定义按钮底色 (+0.79/0.49 线未方向态)
// v1.07 新增：HIDE/SHOW 状态色 + RISK 三档色
// v1.25 调整：HIDE 按钮改为浅灰底（与 CANCEL 按钮同色 C'120,120,120'），仅 HIDE 态保留橙黄警示
#define CLR_HIDE_OFF C'120,120,120'  // SHOW 状态：当前显示（浅灰，与 CANCEL 一致）
#define CLR_HIDE_ON  C'200,120,20'   // HIDE 状态：当前隐藏（橙黄警示，仍保留）
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
double   g_riskValues[3] = {0.5, 1.0, 2.0};  // 可选档位 (循环顺序: 1 → 2 → 3 → 1 → ...)

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

//---------------------------- 工具函数 -----------------------------//
// v1.29: 导入 kernel32.dll 的 GetLogicalDrives 用于探测 Wine 的 Z: 盘
//   (仅读取逻辑盘位掩码, 无副作用; 若终端禁用 DLL 导入则返回 0, 由 path 兜底检测接住)
#import "kernel32.dll"
   uint GetLogicalDrives(void);
#import

// v1.29: 判断当前是否为 Wine 环境 (macOS/Linux 上通过 Wine 运行的 MT5)
//   背景: v1.28 用 StringFind(TERMINAL_DATA_PATH,"\\") 判 Windows, 但 Wine 版数据路径同样含 '\\',
//         导致 mac(Wine) 被误判为 Windows → 按钮被错误缩放到 0.6
//   信号1: Wine 默认把 Unix 根 "/" 映射为 Z: 盘, 原生 Windows 几乎不会分配 Z 盘 (bit25)
//   信号2(兜底, DLL 被禁用时): Wine 官方版是便携模式, 数据目录在 "Program Files" 下; 原生 Windows 标准安装数据目录在 "AppData" 下
bool IsWine()
  {
   uint drives = GetLogicalDrives();                 // 若 DLL 被禁用, 返回 0
   if(drives != 0 && (drives & (1u << 25)) != 0)     // bit25 = Z 盘
      return true;
   string dp = TerminalInfoString(TERMINAL_DATA_PATH);
   if(StringFind(dp, "Program Files") >= 0 && StringFind(dp, "AppData") < 0)
      return true;
   return false;
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
// 使用非临时全局变量：会话内(切换周期/缩放)保留，MT5 重启后自动清空
// v1.15: 1.00/0.00/0.79/0.49 位置不再记忆, 每次插入完全重新初始化
//        仅保留风险档位 (g_riskPercent) 会话内持久
void SaveRisk()
  {
   GlobalVariableSet(g_prefix + "risk", g_riskPercent);
  }
bool LoadRisk()
  {
   if(!GlobalVariableCheck(g_prefix + "risk")) return false;
   g_riskPercent = GlobalVariableGet(g_prefix + "risk");
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
// 市价下单按钮对象名
string MarketName()        { return g_prefix + "MARKET"; }
// v1.31：突破挂单按钮对象名 (BUY STP / SELL STP)
string StopName()          { return g_prefix + "STOP"; }
// v1.34：盈亏比标签 (3 段 OBJ_LABEL: A=含(的浮盈占比, B=含:)的止盈/止损比, C=百分比)
string RatioAName()        { return g_prefix + "RATIO_A"; }
string RatioBName()        { return g_prefix + "RATIO_B"; }
string RatioCName()        { return g_prefix + "RATIO_C"; }
// 隐藏/显示按钮对象名 (始终显示，不会随 g_hidden 隐藏)
string HideName()          { return g_prefix + "HIDE"; }
// v1.13: 一键调整 1.00/0.00 到最近高低点的按钮对象名
string AdjustName()        { return g_prefix + "ADJUST"; }

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
                   "· 0.21/0.49/0.79 自动按新 Range 重新计算\n"
                   "参数: Depth=" + IntegerToString(InpAdjustDepth) +
                   ", Deviation=" + IntegerToString(InpAdjustDeviation) +
                   ", Backstep=" + IntegerToString(InpAdjustBackstep));
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
   CreateHLine(HName(RATIO_100), g_p1,  true,  CLR_END,  STYLE_SOLID, 2);
   CreateHLine(HName(RATIO_000), g_p0,  true,  CLR_END,  STYLE_SOLID, 2);
   CreateHLine(HName(RATIO_079), g_p79, true,  CLR_FLAT_BG, STYLE_SOLID, 1);
   CreateHLine(HName(RATIO_049), g_p49, true,  CLR_FLAT_BG, STYLE_SOLID, 1);
   CreateHLine(HName(RATIO_021), TheoPrice(RATIO_021, g_p1, g_p0), false, CLR_DECO, STYLE_DASHDOT, 1);

   CreateButton(BName(RATIO_079));
   CreateButton(BName(RATIO_049));
   CreateSwapButton();
   CreateAdjustButton();   // v1.13: ADJUST 按钮 (位置由 UpdateAdjustButton 跟随 SWAP 设置)
   CreateActionButton(CancelPendingName(), 100, "CANCEL",       C'120,120,120', "取消当前品种全部挂单（含手动单），不影响其他品种");
   CreateActionButton(CloseAllName(),      100, "CALL",          C'200,120,20',  "平掉当前品种全部持仓（不涉及挂单），不影响其他品种");
   CreateActionButton(CloseHalfName(),     100, "CHALF",         C'230,140,40',  "按手数砍半平仓当前品种持仓；若砍半后 < 最小手数则全平该仓位");
   CreateActionButton(EvenName(),           80, "EVEN",          C'60,120,200',  "一键入场价（仅当前品种）：盈利仓位SL改到入场；亏损仓位TP改到入场（保本平仓）");
   CreateActionButton(RiskName(),           80, "",              C'90,90,90',   "点击循环切换单笔风险档位：0.5% → 1% → 2% → 0.5%");
   CreateActionButton(MarketName(),        110, "MARKET",        C'140,140,140',"市价下单（止损 = 1.00 ± Range×1%，盈亏比 1:1）");
   CreateActionButton(StopName(),          110, "STOP",          CLR_FLAT_BG,    "突破挂单: BUY STOP (long) 挂在视觉 topPrice + 1 tick, SELL STOP (short) 挂在视觉 botPrice - 1 tick; SL/TP/lot 与 MARKET 共用公式");
   CreateActionButton(HideName(),           80, "HIDE",          CLR_HIDE_OFF,   "隐藏/显示 EA 全部线条与按钮（此按钮自身始终显示）");

   // v1.08：MKT 两侧的实时盈亏数字标签（OBJ_LABEL 像素定位）
   CreatePnLLabel(PnLLeftName());
   CreatePnLLabel(PnLRightName());
   // v1.34: 盈亏比标签 — 3 段 (浮盈占比 + 风险回报比 + 百分比), 颜色不同需独立对象
   CreatePnLLabel(RatioAName());
   CreatePnLLabel(RatioBName());
   CreatePnLLabel(RatioCName());

   CreateLabelRight(LName(RATIO_021), "0.21", CLR_DECO);

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

//---------------------------- 刷新显示 -----------------------------//
void UpdateButtonX()
  {
   // v1.08：g_btnX = 最右边 CALL 按钮的左 X（CALL 宽 100，右边距 8）
   //  v1.27：UI 缩放后右边缘 = w - UI(108)
   //  v1.32：STOP 放回中间 slack 区, 不再吃 g_btnX 的位置 (回退到 v1.25 的 X)
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
//  v1.08b：0.21 标签右边缘与 0.79/0.49 按钮、CALL 按钮右边缘对齐
void UpdateLabelRight(string name, double price, string text)
  {
   if(ObjectFind(0, name) < 0) return;
   int x = 0, y = 0;
   if(!ChartTimePriceToXY(0, 0, RightAnchor(), price, x, y)) return;
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, g_btnX + UI(100));  // 右边缘 = w-UI(8)，与按钮列右对齐
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y - UI(2));
   ObjectSetString(0, name, OBJPROP_TEXT, text);
  }

void UpdateSwapButton(int dir)
  {
   string name = SwapName();
   if(ObjectFind(0, name) < 0) return;
   string t = (dir == DIR_UP) ? "LONG" : ((dir == DIR_DOWN) ? "SHORT" : "FLAT");
   ObjectSetString(0, name, OBJPROP_TEXT, t);
   color bg = (dir == DIR_UP) ? CLR_BUY_BG : ((dir == DIR_DOWN) ? CLR_SELL_BG : CLR_FLAT_BG);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);

   // v1.08b：水平居中 + 垂直放到最上面那根线（MathMax(p1,p0)）下方 4px
   // v1.26: 由 y-11 (线穿过按钮) 改为 y+4 (按钮位于线下方, 不被线穿过)
   int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int x = 0, y = 0;
   double topPrice = MathMax(g_p1, g_p0);
   if(!ChartTimePriceToXY(0, 0, RightAnchor(), topPrice, x, y)) return;
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, (w - UI(80)) / 2);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y + UI(4));
  }

// v1.13: ADJUST 按钮位置 (在 SWAP 右侧 4px)
// v1.26: Y 改 y+4 (SWAP/ADJUST/CANCEL 三个按钮统一在 topPrice 线下方 4px, 不被线穿过)
void UpdateAdjustButton()
  {
   string name = AdjustName();
   if(ObjectFind(0, name) < 0) return;
   int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int x = 0, y = 0;
   double topPrice = MathMax(g_p1, g_p0);
   if(!ChartTimePriceToXY(0, 0, RightAnchor(), topPrice, x, y)) return;
   // SWAP 位置 = (w-UI(80))/2, ADJUST 宽 UI(80), 间距 UI(4) → ADJUST 左 X = SWAP 左 X + SWAP 宽 + 间距
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, (w - UI(80)) / 2 + UI(84));
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y + UI(4));
  }

//+------------------------------------------------------------------+
//| v1.17: STEP UP/DOWN 按钮 (1.00/0.00/0.79/0.49 各一对)
//| 单击 = 移动区间比例 InpStepPercent%, 双击 300ms 内 = ×10
//+------------------------------------------------------------------+
#define STEP_BTN_W     22   // 按钮宽度
#define STEP_BTN_H     18   // 按钮高度
#define STEP_BTN_GAP   2    // UP/DOWN 之间的间距
#define STEP_BTN_X     6    // 距图表左边距
#define STEP_BTN_DN_OFFSET (STEP_BTN_W + STEP_BTN_GAP)

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
   ObjectSetString(0, name, OBJPROP_TOOLTIP,
                   dirTxt + "移动 " + rstr + " 线 (单击=" +
                   DoubleToString(InpStepPercent, 1) + "%, 双击=×10 加速)");
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

// 处理 STEP 按钮点击: 解析 name → (ratio, dir), 双击检测, 计算步长, 调用 ApplyStepDrag
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

// 最上面那根线右侧：CANCEL 按钮
// v1.26: 改到线下方 (y+4), 与 SWAP/ADJUST 三个按钮统一在 topPrice 线下方 4px, 不被线穿过
void UpdateTopButtons()
  {
   double topPrice = MathMax(g_p1, g_p0);
   int x = 0, y = 0;
   if(!ChartTimePriceToXY(0, 0, RightAnchor(), topPrice, x, y)) return;
   int yBtn = y + UI(4);

   string cancelName = CancelPendingName();
   if(ObjectFind(0, cancelName) >= 0)
     {
      // v1.08：CANCEL 左 X = g_btnX（右边距 8px，宽 100），原表达式 g_btnX+200-100 等价
      ObjectSetInteger(0, cancelName, OBJPROP_XDISTANCE, g_btnX);
      ObjectSetInteger(0, cancelName, OBJPROP_YDISTANCE, yBtn);
     }
  }

// 最下面那根线的全部按钮 (v1.08)：
//  左侧：HIDE(80) | RISK(80) | ...空隙... | PL_LEFT(标签) | MARKET(110 居中) | PL_RIGHT(标签) | ...空隙... | EVEN(80) | CHALF(100) | CALL(100)
//  右侧等距（v1.25）：EVEN(80) | gap 4px | CHALF(100) | gap 4px | CALL(100)  → 三个按钮视觉间距一致
void UpdateBottomButtons()
  {
   double botPrice = MathMin(g_p1, g_p0);
   int x = 0, y = 0;
   if(!ChartTimePriceToXY(0, 0, RightAnchor(), botPrice, x, y)) return;
   int yBtn = y - UI(26); if(yBtn < 0) yBtn = 0;
   int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);

   // MARKET 居中位置 (宽 110, v1.27 UI 缩放)
   int marketW = UI(110);
   int marketX = (w - marketW) / 2;

   // 左侧 HIDE / RISK
   // v1.22: HIDE / RISK 右移到 STEP 按钮 (X=[6, 52]) 右侧, 避免 long 模式
   //   0.00 在底部时与 0.00 STEP 按钮 Y 重叠
   //   STEP 按钮范围 X=[STEP_BTN_X, STEP_BTN_X + STEP_BTN_DN_OFFSET + STEP_BTN_W]
   // v1.27: 全部按 UI 缩放
   int stepBox = UI(STEP_BTN_X) + (UI(STEP_BTN_W) + UI(STEP_BTN_GAP)) + UI(STEP_BTN_W); // 缩放后的 STEP 列右边缘
   int xHide   = stepBox + UI(8);                                 // HIDE 左 X
   int xRisk   = xHide + UI(80) + UI(4);                          // RISK 左 X
   if(ObjectFind(0, HideName()) >= 0)
     {
      ObjectSetInteger(0, HideName(), OBJPROP_XDISTANCE, xHide);
      ObjectSetInteger(0, HideName(), OBJPROP_YDISTANCE, yBtn);
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
   // PL_LEFT：MKT 左 4px 处，右对齐文字（"(-1012)"等，最右字符对齐到该 X）
   // PL_RIGHT：MKT 右 4px 处，左对齐文字
   if(ObjectFind(0, PnLLeftName()) >= 0)
     {
      ObjectSetInteger(0, PnLLeftName(), OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
      ObjectSetInteger(0, PnLLeftName(), OBJPROP_XDISTANCE, marketX - UI(6));
      ObjectSetInteger(0, PnLLeftName(), OBJPROP_YDISTANCE, yBtn + UI(4));
     }
   if(ObjectFind(0, PnLRightName()) >= 0)
     {
      ObjectSetInteger(0, PnLRightName(), OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, PnLRightName(), OBJPROP_XDISTANCE, marketX + marketW + UI(6));
      ObjectSetInteger(0, PnLRightName(), OBJPROP_YDISTANCE, yBtn + UI(4));
     }

   // 右侧 EVEN / CHALF / CALL（CALL 最右，左 X = g_btnX）
   if(ObjectFind(0, CloseAllName()) >= 0)
     {
      ObjectSetInteger(0, CloseAllName(), OBJPROP_XDISTANCE, g_btnX);
      ObjectSetInteger(0, CloseAllName(), OBJPROP_YDISTANCE, yBtn);
     }
   if(ObjectFind(0, CloseHalfName()) >= 0)
     {
      ObjectSetInteger(0, CloseHalfName(), OBJPROP_XDISTANCE, g_btnX - UI(100) - UI(4));
      ObjectSetInteger(0, CloseHalfName(), OBJPROP_YDISTANCE, yBtn);
     }
   if(ObjectFind(0, EvenName()) >= 0)
     {
      ObjectSetInteger(0, EvenName(), OBJPROP_XDISTANCE, g_btnX - UI(100) - UI(4) - UI(80) - UI(4));  // v1.25: 与 CHALF/CALL 等距 4px
      ObjectSetInteger(0, EvenName(), OBJPROP_YDISTANCE, yBtn);
     }

   // v1.32: BUY/SELL STOP 按钮 — 与 MARKET 同宽、同中心、关于底线镜像对称
   //  MARKET: 顶边距底线 4px 上方 (yBtn = y - 26)
   //  STOP:   顶边距底线 4px 下方 (y + 4)
   if(ObjectFind(0, StopName()) >= 0)
     {
      ObjectSetInteger(0, StopName(), OBJPROP_XDISTANCE, marketX);  // 与 MARKET 同 X 中心
      ObjectSetInteger(0, StopName(), OBJPROP_YDISTANCE, y + UI(4));
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

// 风险按钮文字 + 颜色（v1.07：循环档位 0.5 → 1 → 2 → 0.5；底色按档位变化，比例越高越醒目）
void UpdateRiskButton()
  {
   string name = RiskName();
   if(ObjectFind(0, name) < 0) return;
   string s = DoubleToString(g_riskPercent, 1);
   int dot = StringFind(s, ".");
   if(dot >= 0 && StringSubstr(s, dot + 1) == "0")   // 去掉末尾 ".0"，如 1.0 → 1
      s = StringSubstr(s, 0, dot);
   ObjectSetString(0, name, OBJPROP_TEXT, s + "%");

   // 三档配色：低风险绿 / 中风险黄 / 高风险红
   color bg = CLR_RISK_MID;
   if(MathAbs(g_riskPercent - 0.5) < 1e-9) bg = CLR_RISK_LOW;
   else if(MathAbs(g_riskPercent - 1.0) < 1e-9) bg = CLR_RISK_MID;
   else if(MathAbs(g_riskPercent - 2.0) < 1e-9) bg = CLR_RISK_HI;
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

// 应用隐藏/显示状态：遍历所有 EA 对象，HIDE 按钮自身除外
// v1.07 改进：
//  · 按钮：OBJPROP_HIDDEN 无效，移出屏幕 (XDISTANCE = -10000)
//  · 水平线：OBJPROP_HIDDEN 在部分 MT5 版本对 HLINE 不生效，改为把价格改到 1e20（屏幕外）
//          显示时由 UpdateLabel 改回 g_p1/g_p0/g_p79/g_p49（UpdateLabel 自身在 g_hidden 时跳过）
//  · 标签：OBJPROP_HIDDEN 对 OBJ_LABEL 有效，继续用 HIDDEN
void ApplyHidden()
  {
   int total = ObjectsTotal(0, -1, -1);
   string hideObj = HideName();
   for(int i = 0; i < total; i++)
     {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, g_prefix) != 0) continue;   // 仅本实例对象
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
   UpdateButtonX();

   UpdateLabel(HName(RATIO_100), g_p1);
   UpdateLabel(HName(RATIO_000), g_p0);
   UpdateLabel(HName(RATIO_079), g_p79);
   UpdateLabel(HName(RATIO_049), g_p49);
   UpdateLabel(HName(RATIO_021), TheoPrice(RATIO_021, g_p1, g_p0));

   int dir = Dir();
   double price79 = LevelPrice(RATIO_079);
   double price49 = LevelPrice(RATIO_049);
   double lot79 = CalcLotFor(price79, dir);
   double lot49 = CalcLotFor(price49, dir);

   UpdateButton(BName(RATIO_079), price79, BuildButtonText(ActualRatio(price79), lot79), dir);
   UpdateButton(BName(RATIO_049), price49, BuildButtonText(ActualRatio(price49), lot49), dir);
   UpdateMidLines(dir);   // v1.25: 0.79/0.49 线颜色随方向 (与按钮配色统一)

   UpdateSwapButton(dir);
   UpdateAdjustButton();   // v1.13: ADJUST 按钮位置 (跟随 SWAP)
   UpdateStepButtons();   // v1.17: 4 条主线的 UP/DOWN 按钮 (跟随线移动)
   UpdateMarketButton(dir);
   UpdateStopButton(dir);   // v1.31: 突破挂单按钮文字与配色跟随方向
   UpdateRiskButton();
   UpdateHideButton();
   UpdateTopButtons();
   UpdateBottomButtons();
   UpdatePnLDisplay();   // v1.08：MKT 两侧的实时盈亏数字
   UpdateRatioLabels();  // v1.34：底线下方的盈亏比三指标 (浮盈占比/风险回报比/百分比)

   UpdateLabelRight(LName(RATIO_021), TheoPrice(RATIO_021, g_p1, g_p0), "0.21");  // v1.07：仅保留 0.21 标签

   ApplyHidden();
   ChartRedraw(0);
  }

//---------------------------- 手数计算 -----------------------------//
// 单笔最大亏损金额 = Balance × g_riskPercent / 100
// g_riskPercent 由 RISK 按钮循环控制 (0.5/1/2%)，会话内持久化
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
   req.comment     = InpOrderComment;

   if(!OrderSend(req, res))
     {
      Alert("[FibLimitAssist] 下单失败 retcode=", res.retcode, " ", res.comment);
      return;
     }
   Print("[FibLimitAssist] 挂单成功 ticket=", res.order, " ",
         (dir == DIR_UP ? "BUY" : "SELL"), " LIMIT vol=", DoubleToString(lot, InpLotDecimals));
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

// 0.79 挂单 → 3 倍盈亏比；0.49 挂单 → 1 倍盈亏比
void PlaceOrder(double r)
  {
   double rr = (r == RATIO_079) ? 3.0 : 1.0;
   PlaceOrderWithRR(r, rr);
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

// v1.31: 突破挂单 — 入场=视觉 topPrice+1tick (BUY STOP) / botPrice-1tick (SELL STOP),
//   SL/TP/lot 与市价按钮完全一致 (复用 PlaceMarketOrder 的公式).
void PlaceStopOrder()
  {
   int dir = Dir();
   if(dir == DIR_FLAT)
     {
      Alert("[FibLimitAssist] 区间未定义：1.00 与 0.00 重合，无法下突破单");
      return;
     }

   double topPrice = MathMax(g_p1, g_p0);
   double botPrice = MathMin(g_p1, g_p0);
   double entry    = (dir == DIR_UP) ? NormalizeDouble(topPrice + _Point, _Digits)
                                     : NormalizeDouble(botPrice - _Point, _Digits);
   double range    = MathAbs(g_p0 - g_p1);

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
//| v1.13: ADJUST 入口 - 点击按钮后调用                                |
//+------------------------------------------------------------------+
void DoAdjust()
  {
   // 1. 找最近高点 (1.00)
   datetime tH = 0; double pH = 0;
   if(!FindNearestSwing(DIR_UP, tH, pH))
     {
      Alert("[FibLimitAssist] ADJUST 失败: 未识别到有效高点 (请放大图表或调整 Depth/Deviation/Backstep 参数)");
      return;
     }

   // 2. 找最近低点 (0.00)
   datetime tL = 0; double pL = 0;
   if(!FindNearestSwing(DIR_DOWN, tL, pL))
     {
      Alert("[FibLimitAssist] ADJUST 失败: 未识别到有效低点 (请放大图表或调整 Depth/Deviation/Backstep 参数)");
      return;
     }

   // 3. 异常检查
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

   // 4. 改全局变量: 1.00 / 0.00 按新高低点
   g_p1 = NormalizeDouble(pH, _Digits);   // 1.00 = 最近高点
   g_p0 = NormalizeDouble(pL, _Digits);   // 0.00 = 最近低点

   // 端点变了 → 0.49 / 0.79 立即回归理论值 (与 ApplyDrag 拖动端点行为一致).
   // 否则 g_p79/g_p49 残留的手调值会让按钮停在旧位置.
   g_p79 = TheoPrice(RATIO_079, g_p1, g_p0);
   g_p49 = TheoPrice(RATIO_049, g_p1, g_p0);

   // 5. v1.15: 端点位置不再记忆, 这里无需保存 (下次插入会重新初始化)

   // 6. 重画
   RefreshAll();

   // 7. 反馈 (Print + Alert)
   double rangePoints = (pH - pL) / _Point;
   int dir = Dir();
   string dirText = (dir == DIR_UP) ? "做多" : ((dir == DIR_DOWN) ? "做空" : "FLAT");

   Print("[ADJUST] High (1.00): ", DoubleToString(pH, _Digits),
         "  time=", TimeToString(tH, TIME_DATE|TIME_MINUTES));
   Print("[ADJUST] Low  (0.00): ", DoubleToString(pL, _Digits),
         "  time=", TimeToString(tL, TIME_DATE|TIME_MINUTES));
   Print("[ADJUST] Range:       ", DoubleToString(rangePoints, 1), " points (", DoubleToString(pH - pL, _Digits), ")");
   Print("[ADJUST] Direction:   ", dirText);
   Print("[ADJUST] 0.79 = ", DoubleToString(TheoPrice(RATIO_079, g_p1, g_p0), _Digits));
   Print("[ADJUST] 0.49 = ", DoubleToString(TheoPrice(RATIO_049, g_p1, g_p0), _Digits));
   Print("[ADJUST] 0.21 = ", DoubleToString(TheoPrice(RATIO_021, g_p1, g_p0), _Digits));

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
   RefreshAll();   // v1.07：刷新按钮文字 + 三档配色（之前忘记调用，文字不变）
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
   return -1.0;   // 0.21 不可拖拽，忽略
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
   //   平台检测: IsWine() 判 Wine 环境(mac/Linux), 否则视为原生 Windows(远程 RDP/本地 Win)
   //   智能默认: Wine(mac) → UI 1.0 / Font 1.0;  原生 Windows → UI 0.6 / Font 1.0 (按钮缩小但字保持清晰)
   bool isWindows = !IsWine();
   double defaultUIScale   = isWindows ? 0.6 : 1.0;
   double defaultFontScale = 1.0;   // 默认字号不变 (按钮缩小但字保持可读)
   g_uiScale   = (InpUIScale   > 0.01) ? InpUIScale   : defaultUIScale;
   g_fontScale = (InpFontScale > 0.01) ? InpFontScale : defaultFontScale;
   if(g_uiScale   < 0.2) g_uiScale   = 0.2;   // 下限保护
   if(g_uiScale   > 3.0) g_uiScale   = 3.0;   // 上限保护
   if(g_fontScale < 0.2) g_fontScale = 0.2;   // 下限保护
   if(g_fontScale > 3.0) g_fontScale = 3.0;   // 上限保护

   // v1.12: 自动探测服务器时区 (用于 CE(S)T 切日换算)
   DetectTimezone();

   // v1.15: 1.00/0.00 端点位置不再记忆, 每次插入都用当前可见价格区间重新生成默认 fib
   double pmax = ChartGetDouble(0, CHART_PRICE_MAX, 0);
   double pmin = ChartGetDouble(0, CHART_PRICE_MIN, 0);
   if(pmax <= pmin || pmin <= 0)
     {
      pmax = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      pmin = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(pmax <= pmin) { double c = pmin; pmax = c + 100 * _Point; pmin = c - 100 * _Point; }
     }
   double span = pmax - pmin;
   g_p1  = pmin + span * 0.1;
   g_p0  = pmax - span * 0.1;
   g_p79 = TheoPrice(RATIO_079, g_p1, g_p0);
   g_p49 = TheoPrice(RATIO_049, g_p1, g_p0);

   // 风险档位会话内持久
   LoadRisk();

   CreateObjects();
   g_lastBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   RefreshAll();
   g_dirty = false;
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
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

   if(g_dirty) { RefreshAll(); g_dirty = false; }
   else        { UpdatePnLDisplay(); ChartRedraw(0); }   // v1.08：每个 tick 刷新 MKT 两侧的实时盈亏
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
