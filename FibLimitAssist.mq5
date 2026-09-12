//+------------------------------------------------------------------+
//|                                                 FibLimitAssist.mq5 |
//|                               半自动斐波那契限价下单辅助 EA        |
//|        交易方向 / 行情判断完全人工，EA 只负责绘图 + 按钮 + 下单     |
//+------------------------------------------------------------------+
#property copyright "FibLimitAssist"
#property version   "1.63"
#property description "半自动斐波那契限价下单辅助 (v1.63)"
#property description "拖拽 1.00/0.00 → 0.79/0.49 挂限价单, STEP 微调, MKT/STP 市价与突破单, EVEN/CHALF/CALL 仓位管理"
#property description "盈亏比实时标签 + ADJUST 高低点对齐 + HIDE 一键隐藏 + UI 缩放 (尺寸/字号分离) + Wine 检测修复"
#property description "v1.45+ 新增 FVG 矩形: 看涨浅绿/看跌浅红/填补浅灰, 3 色方案; 选项含可见区扫描/高级别叠加/最小宽度"
#property description "FVG 完全独立于 HIDE; F 状态矩形止于填补 K 线起点; 部分填补只画剩余未填补 (v1.57)"
#property description "v1.40+ 信号提醒: 强弱回调/反弹形态评分 + Alert推送 + 波段画线(独立于信号,InpWaveLineEnabled)"
#property description "v1.50-v1.59 修复详情见项目说明文档第 13 章 (描述符总数受限, 变更记录仅保留概要)"
#property description "v1.61 顶部按钮左对齐链: LONG→ADJUST→CANCEL 类似底部 HIDE→RISK→FVG 链, stepBox+8/92/176 递进"
#property description "v1.62 EVEN/CHALF/CALL 镜像到底部下方 (y+4 与 STOP 同侧), X 分别对齐 SWAP/ADJUST/CANCEL (stepBox+8/92/176)"
#property description "v1.63 v1.62 位置修正: EVEN/CHALF/CALL 改回 yBtn (最下面线上方) + HIDE/RISK/FVG 同步从底部移到顶部 CANCEL 右侧 (顶部 6 按钮一长链: LONG→ADJUST→CANCEL→HIDE→RISK→FVG)"

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

// v1.38 新增: 默认斐波那契区间基准 — 最近 N 根已收盘 K 线的高低点 (数据驱动, 解决切周期时 ChartGetDouble(CHART_PRICE_MAX/MIN) 返回 0 或过窄导致线条挤死/跑出屏)
input int InpDefaultSpanBars = 60; // [默认区间] 用最近多少根已收盘 bar 的 High/Low 作为默认区间 (0=不用, 恢复旧视图基准)

// v1.27 新增: UI 界面缩放系数 (统一缩放所有按钮/标签的尺寸与间距)
//   Mac/Wine 版或 96DPI 屏幕用 1.0; 远程 Windows 服务器按钮过大时, 调小 (如 0.6~0.8)
//   0 = 自动按平台智能默认 (mac=1.0, Windows=0.6); 其他正数 = 强制使用 (手动覆盖智能默认)
input double InpUIScale = 0.0;   // [UI] 按钮尺寸缩放系数 (0=按平台智能默认; 正数=强制值)

// v1.28 新增: 字号独立缩放系数 (与 InpUIScale 解耦, 防止按钮缩小后文字看不清)
//   0 = 自动按平台智能默认 (mac=1.0, Windows=1.0); 其他正数 = 强制值 (如 0.8=字小一些)
input double InpFontScale = 0.0;  // [UI] 字号缩放系数 (0=按平台智能默认; 正数=强制值)

//---------------------------- 波段画线 (v1.44 独立) -----------------------------//
// 与"交易信号提醒"完全解耦: 只要检测周期里找到一对有效分型(顶+底)且波段幅度达标就画线,
// 不依赖信号提醒的"触达 50% / 未跌破起点 / 评分达标"等触发条件.
// 关闭时 OnTick 不会运行波段扫描, 已画的线会被清除.
input bool InpWaveLineEnabled = false; // [波段画线] 总开关 (默认关, 与 InpSignalEnabled 完全独立)

//---------------------------- 交易信号提醒 (v1.40) -----------------------------//
// 强势上涨→弱势回调 形态识别 + 5维评分 + PC弹窗(Alert) + 手机推送(SendNotification)
// 独立模块: 开关关闭时完全不运行, 不影响现有 fib 绘图/下单逻辑
// 识别用已收盘 bar (shift>=1), 触达/失效用实时价; 按波段去重 (底/顶分型中间 bar 时间戳)
enum ENUM_SIGNAL_DIR
  {
   SIG_DIR_BOTH  = 0,  // 双向 (做多 + 做空)
   SIG_DIR_LONG  = 1,  // 仅做多
   SIG_DIR_SHORT = 2,  // 仅做空
  };
input bool            InpSignalEnabled    = false;        // [信号] 总开关 (默认关)
input ENUM_SIGNAL_DIR InpSignalDirection  = SIG_DIR_BOTH; // [信号] 检测方向 (双向/仅多/仅空)
input ENUM_TIMEFRAMES InpSignalTF         = PERIOD_M5;    // [信号] 检测周期 (独立于图表周期, 默认 M5)
input int             InpSignalBars       = 80;           // [信号] 检测回看根数
input int             InpSignalMinScore   = 40;           // [信号] 最低评分 (低于此分不提醒)

input int             InpBullMinBars      = 3;            // [信号] 上涨波段最少根数
input int             InpBullMaxBars      = 20;           // [信号] 上涨波段最多根数
input double          InpBullBodyRatio    = 0.6;          // [信号] 大实体阳线判定 (实体/振幅 >= 0.6)
input double          InpBullMinATR       = 1.0;          // [信号] 波段最小涨幅 (ATR 倍数, 防噪声, 跨周期自适应)
input int             InpSignalATRPeriod  = 14;           // [信号] ATR 计算周期

input double          InpPullbackDepth    = 0.5;          // [信号] 触发回调位 (50%)
input int             InpPullbackMinBars  = 1;            // [信号] 回调段最少根数
input int             InpPullbackMaxBars  = 25;           // [信号] 回调段最多根数

// v1.45 新增: FVG (公允价值缺口) 矩形画图
input bool               InpFVG_ShowUnfilled     = true;    // [FVG] 显示未填补 (绿/红)
input bool               InpFVG_ShowPartial     = true;    // [FVG] 显示部分填补 (蓝/橙)
input bool               InpFVG_ShowFilled       = false;    // [FVG] 显示完全填补 (灰, 默认关)
input bool               InpFVG_HigherTF_Enabled = false;  // [FVG] 叠加高级别 FVG
input bool               InpFVG_HigherTF_Auto    = true;    // [FVG] 自动按当前周期选高级别 (Auto=false 时用 InpFVG_HigherTF_Period)
input ENUM_TIMEFRAMES    InpFVG_HigherTF_Period  = PERIOD_H1;// [FVG] 手动指定的高级周期 (Auto=false 时生效)
input int                InpFVG_MinPoints        = 0;         // [FVG] 最小缺口宽度 (points), 0=不过滤

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

// v1.58 新增: FVG 配色 — 简化为 3 色: 上涨(浅绿) / 下跌(浅红) / 完全填补(浅灰)
//   不再区分未填补 vs 部分填补, 只看方向. v1.57 之前的 6 色过于细分, 视觉干扰大.
#define CLR_FVG_BULL    C'210,235,215'        // 看涨 (U/P 都用此色, 浅绿)
#define CLR_FVG_BEAR    C'250,210,208'        // 看跌 (U/P 都用此色, 浅红/粉)
#define CLR_FVG_FILLED  C'225,225,225'        // 完全填补 (浅灰, 默认隐藏)
// FVG 按钮 (与 HIDE 同色组, sticky 行为)
#define CLR_FVG_OFF          C'120,120,120'   // SHOW (浅灰)
#define CLR_FVG_ON           C'200,120,20'    // OFF 状态 (橙黄警示, 与 CLR_HIDE_ON 同)

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

// v1.40 新增: 交易信号提醒 — 波段去重 (已提醒波段 ID = 分型中间 bar 时间戳)
//   做多/做空各维护一个已提醒 ID, 同一波段只提醒一次, 新波段(新时间戳)立即提醒
datetime g_sigLongID  = 0;   // 已提醒的做多波段 ID (底分型中间 bar 时间戳)
datetime g_sigShortID = 0;   // 已提醒的做空波段 ID (顶分型中间 bar 时间戳)

// v1.43 新增: 信号波段画线 — 记录最新波段的高低点坐标与方向
//   画线用"绝对时间 + 价格"(与图表周期无关), 检测周期(InpSignalTF)可与图表周期不同
//   独立对象前缀 (不以 g_prefix 开头), 故 ApplyHidden 遍历不会隐藏它, 不受 HIDE 按钮影响
datetime g_waveT1 = 0, g_waveT2 = 0;  // 波段起点/终点时间 (分型 bar 中央)
double   g_waveP1 = 0, g_waveP2 = 0;  // 波段起点/终点价格
int      g_waveDir = DIR_FLAT;        // DIR_UP=上涨(绿线), DIR_DOWN=下跌(红线)

// v1.45 新增: FVG 状态机
//   g_fvgEnabled: FVG 按钮 sticky 状态 (与 HIDE 同步隐藏/显示)
//   g_higherTF:   Auto 模式实际生效的高级周期 (OnInit 时根据 _Period 自动选)
//   g_fvgCache:   缓存上一帧的状态/边界, 减少 ObjectSetInteger 调用
bool              g_fvgEnabled    = true;                       // FVG 显示开关 (默认开)
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
// v1.45: FVG 切换按钮对象名 (sticky: 文字 "FVG"/"OFF", 按下=当前 FVG 关闭)
string FVGButtonName()     { return g_prefix + "FVG_BTN"; }
// FVG 矩形对象名前缀 (矩形本体 + 标签 — 都要按此前缀清理)
string FVGPrefix()         { return g_prefix + "FVG_"; }
// 隐藏/显示按钮对象名 (始终显示，不会随 g_hidden 隐藏)
string HideName()          { return g_prefix + "HIDE"; }
// v1.43: 信号波段线对象名 — 独立前缀 FLAW_ (不以 g_prefix 开头), 故 ApplyHidden/ObjectsDeleteAll(g_prefix) 都不会碰它
string WaveName()          { return "FLAW_" + IntegerToString(ChartID()) + "_" + _Symbol + "_WAVE"; }
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
   // v1.45: FVG 切换按钮 (在 HIDE 右侧, sticky 行为, 文字 FVG/OFF, 默认开)
   CreateActionButton(FVGButtonName(),      80, "FVG",           CLR_FVG_OFF,    "切换 FVG 矩形显示 (公允价值缺口): OFF=隐藏, FVG=显示 (上涨浅绿 / 下跌浅红 / 完全填补浅灰; v1.58 不再区分未填补与部分填补)");

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
void UpdateAdjustButton()
  {
   string name = AdjustName();
   if(ObjectFind(0, name) < 0) return;
   int x = 0, y = 0;
   double topPrice = MathMax(g_p1, g_p0);
   if(!ChartTimePriceToXY(0, 0, RightAnchor(), topPrice, x, y)) return;
   int stepBox  = UI(STEP_BTN_X) + (UI(STEP_BTN_W) + UI(STEP_BTN_GAP)) + UI(STEP_BTN_W);
   int xAdjust  = stepBox + UI(8) + UI(80) + UI(4);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xAdjust);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y + UI(4));
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

// 顶部按钮 — v1.61: 改为左对齐链 (LONG → ADJUST → CANCEL), LONG/ADJUST 由各自函数定位, 这里只设 CANCEL
// v1.26: 改到线下方 (y+4), 与 SWAP/ADJUST 三个按钮统一在 topPrice 线下方 4px, 不被线穿过
void UpdateTopButtons()
  {
   double topPrice = MathMax(g_p1, g_p0);
   int x = 0, y = 0;
   if(!ChartTimePriceToXY(0, 0, RightAnchor(), topPrice, x, y)) return;
   int yBtn = y + UI(4);

   // v1.61: CANCEL X = stepBox + 8 + 80 + 4 + 80 + 4 = stepBox + 176 (ADJUST 右侧相邻 4px)
   //   原右对齐 (g_btnX) 已废弃 — 顶部按钮全部左对齐
   // v1.63: HIDE / RISK / FVG 移到 CANCEL 右侧 — 形成顶部 6 按钮一长链 (LONG→ADJUST→CANCEL→HIDE→RISK→FVG)
   //   底部左侧位置释放给 EVEN/CHALF/CALL (镜像布局)
   int stepBox = UI(STEP_BTN_X) + (UI(STEP_BTN_W) + UI(STEP_BTN_GAP)) + UI(STEP_BTN_W);
   int xCancel = stepBox + UI(8) + UI(80) + UI(4) + UI(80) + UI(4);
   int xHide   = xCancel + UI(100) + UI(4);                 // HIDE 紧邻 CANCEL 右侧
   int xRisk   = xHide   + UI(80)  + UI(4);                 // RISK 紧邻 HIDE 右侧
   int xFVG    = xRisk   + UI(80)  + UI(4);                 // FVG 紧邻 RISK 右侧
   string cancelName = CancelPendingName();
   if(ObjectFind(0, cancelName) >= 0)
     {
      ObjectSetInteger(0, cancelName, OBJPROP_XDISTANCE, xCancel);
      ObjectSetInteger(0, cancelName, OBJPROP_YDISTANCE, yBtn);
     }
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
   if(ObjectFind(0, FVGButtonName()) >= 0)
     {
      ObjectSetInteger(0, FVGButtonName(), OBJPROP_XDISTANCE, xFVG);
      ObjectSetInteger(0, FVGButtonName(), OBJPROP_YDISTANCE, yBtn);
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

   // v1.63: HIDE / RISK / FVG 已从底部左侧移到顶部 CANCEL 右侧 — 见 UpdateTopButtons
   //   原位置 (最下面线上方 yBtn 左侧) 释放给 EVEN/CHALF/CALL, 形成顶部配置链 + 底部仓位镜像对称布局
   //   stepBox 在 UpdateBottomButtons 仍保留 — 供 EVEN/CHALF/CALL 计算 X (复用顶部按钮链公式)
   int stepBox = UI(STEP_BTN_X) + (UI(STEP_BTN_W) + UI(STEP_BTN_GAP)) + UI(STEP_BTN_W);

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

   // v1.63: 右侧 EVEN / CHALF / CALL — 紧贴顶部按钮正下方 (X 与 SWAP/ADJUST/CANCEL 对齐, Y = yBtn 与 HIDE/RISK/FVG 同行)
   //   v1.62 错误: 改为 y+UI(4) (最下面线下方 4px, 镜像顶部按钮) — 实际显示在 K 线下方, 距离顶部按钮太远, 不符合 "正下方" 语义
   //   v1.63 修正: Y 改回 yBtn (最下面线上方 26px, 与 HIDE/RISK/FVG/MARKET 同行), X 仍 = stepBox+8/92/176 与顶部按钮对齐
   //   HIDE/RISK/FVG 同步从底部左侧移到顶部 CANCEL 右侧, 释放底部左侧给 EVEN/CHALF/CALL
   int xEven  = stepBox + UI(8);
   int xChalf = stepBox + UI(92);
   int xCall  = stepBox + UI(176);
   if(ObjectFind(0, EvenName()) >= 0)
     {
      ObjectSetInteger(0, EvenName(), OBJPROP_XDISTANCE, xEven);
      ObjectSetInteger(0, EvenName(), OBJPROP_YDISTANCE, yBtn);
     }
   if(ObjectFind(0, CloseHalfName()) >= 0)
     {
      ObjectSetInteger(0, CloseHalfName(), OBJPROP_XDISTANCE, xChalf);
      ObjectSetInteger(0, CloseHalfName(), OBJPROP_YDISTANCE, yBtn);
     }
   if(ObjectFind(0, CloseAllName()) >= 0)
     {
      ObjectSetInteger(0, CloseAllName(), OBJPROP_XDISTANCE, xCall);
      ObjectSetInteger(0, CloseAllName(), OBJPROP_YDISTANCE, yBtn);
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

// v1.45: FVG 按钮文字 + 颜色 + sticky 状态 (与 HIDE 同模式: 开=文字"FVG"+浅灰+弹起, 关=文字"OFF"+橙黄+按下)
// v1.48: 自愈 — 按钮若不存在 (v1.45/1.46/1.47 旧版本误删过), 自动重建
void UpdateFVGButton()
  {
   string name = FVGButtonName();
   if(ObjectFind(0, name) < 0)
     {
      CreateActionButton(name, 80, "FVG", CLR_FVG_OFF,
                         "切换 FVG 矩形显示 (公允价值缺口): OFF=隐藏, FVG=显示 (上涨浅绿 / 下跌浅红 / 完全填补浅灰; v1.58 不再区分未填补与部分填补; v1.59 FVG 完全独立于 HIDE)");
      if(ObjectFind(0, name) < 0) return;
     }
   ObjectSetString(0, name, OBJPROP_TEXT, g_fvgEnabled ? "FVG" : "OFF");
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, g_fvgEnabled ? CLR_FVG_OFF : CLR_FVG_ON);
   ObjectSetInteger(0, name, OBJPROP_STATE, !g_fvgEnabled);  // sticky: 按下=当前关闭
   // v1.59: FVG 按钮完全独立于 HIDE — 不再跟随 g_hidden 切换 OBJPROP_HIDDEN
   //   (由 ApplyHidden 跳过 FVG 按钮保证 — HIDE 时按钮位置/可见性不变)
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

// v1.45: 主入口 — 检测 + 分类 + 绘制 FVG 矩形
//   扫描范围: 图表可见区 (ChartGetInteger(CHART_FIRST_VISIBLE_BAR) + CHART_WIDTH_IN_BARS)
//   多周期: 当前周期必扫; 启用 InpFVG_HigherTF_Enabled 时额外扫 g_higherTF
//   每 tick 调用, 实时重判状态 (U/P/F)
//   未成熟 FVG: 中间 K 线 = shift 0 (当前未收线), formTime 用最近已收线 K 线 + 1 个 TF 周期估算
void UpdateFVGDisplay()
  {
   // v1.59: 仅由 g_fvgEnabled 控制, 不再受 g_hidden 影响 — HIDE 隐藏主 fib UI, 但 FVG 仍显示
   if(!g_fvgEnabled)
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
   datetime lastBarTime = iTime(_Symbol, _Period, 1);
   if(lastBarTime == 0) lastBarTime = iTime(_Symbol, _Period, 0);

   // 绘制 / 更新
   for(int i = 0; i < allN; i++)
     {
      bool show = (all[i].status == 0 && InpFVG_ShowUnfilled)
                || (all[i].status == 1 && InpFVG_ShowPartial)
                || (all[i].status == 2 && InpFVG_ShowFilled);
      string rectName = FVGObjName(all[i].formTime, all[i].tfMin);
      string lblName  = FVGLblName (all[i].formTime, all[i].tfMin);

      // v1.60: 矩形右边界按状态分支
      //   U (未填补) / P (部分填补) → X2 = lastBarTime (延伸至最新 K 线起点, 缺口当前仍存在)
      //   F (完全填补)               → X2 = fillTime  (止于填补那根 K 线起点, 不再延伸)
      //   fillTime 为 0 时 (极端) fallback 到 lastBarTime
      // 提到循环顶部声明, 供下方 show 分支 (矩形绘制) 与 showLbl 分支 (标签 X 锚点) 共用
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
      bool showLbl = show && (ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0) > 200);
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
         // v1.60: 改用 rectEndTime — U/P 状态 = lastBarTime (与矩形右边界对齐), F 状态 = fillTime (矩形右边界已止于填补 K 线起点)
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
   string hideObj = HideName();
   string fvgBtn  = FVGButtonName();
   for(int i = 0; i < total; i++)
     {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, g_prefix) != 0) continue;   // 仅本实例对象
      // v1.59: FVG 系列 (按钮 + 矩形 + 标签) 完全独立于 HIDE — HIDE 不动它
      //   FVG 按钮: 仍可见 (用户主动切换显示用)
      //   FVG 矩形: 仍可见 (作为独立的辅助图层)
      //   FVG 标签: 仍可见
      //   与波段线 (FLAW_ 独立前缀) 设计意图一致 — FVG 也是"独立于主 fib UI 的辅助图层"
      if(name == fvgBtn
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
      ApplyHidden();        // 确保所有对象处于隐藏 (幂等)
      ChartRedraw(0);
      return;
     }

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
   UpdateFVGButton();       // v1.45: FVG 切换按钮文字 + 颜色 + sticky 状态
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

//---------------------------- 交易信号提醒 (v1.40) -----------------------------//
// 强势上涨→弱势回调 形态识别 + 5维评分 + Alert(PC弹窗) + SendNotification(手机推送)
// 只用已收盘 bar 识别结构 (shift>=1), 触达/失效用实时价; 按波段去重 (底/顶分型中间 bar 时间戳)

// 大实体阳线: 收盘>开盘 且 实体/振幅 >= InpBullBodyRatio
bool IsBigBullBar(int shift)
  {
   double o = iOpen(_Symbol, InpSignalTF, shift);
   double c = iClose(_Symbol, InpSignalTF, shift);
   double h = iHigh(_Symbol, InpSignalTF, shift);
   double l = iLow(_Symbol, InpSignalTF, shift);
   if(c <= o) return false;                 // 非阳线
   double range = h - l;
   if(range <= 0) return false;             // 一字/无振幅不算
   return ((c - o) / range) >= InpBullBodyRatio;
  }

// 大实体阴线 (做空镜像)
bool IsBigBearBar(int shift)
  {
   double o = iOpen(_Symbol, InpSignalTF, shift);
   double c = iClose(_Symbol, InpSignalTF, shift);
   double h = iHigh(_Symbol, InpSignalTF, shift);
   double l = iLow(_Symbol, InpSignalTF, shift);
   if(c >= o) return false;
   double range = h - l;
   if(range <= 0) return false;
   return ((o - c) / range) >= InpBullBodyRatio;
  }

// 顶分型: 3根K线, 中间(shift)最高 > 两边 (须 shift>=1 保证右侧已收盘)
bool IsTopFractal(int shift)
  {
   if(shift < 1) return false;
   double h = iHigh(_Symbol, InpSignalTF, shift);
   return (h > iHigh(_Symbol, InpSignalTF, shift - 1) &&
           h > iHigh(_Symbol, InpSignalTF, shift + 1));
  }

// 底分型: 3根K线, 中间(shift)最低 < 两边
bool IsBottomFractal(int shift)
  {
   if(shift < 1) return false;
   double l = iLow(_Symbol, InpSignalTF, shift);
   return (l < iLow(_Symbol, InpSignalTF, shift - 1) &&
           l < iLow(_Symbol, InpSignalTF, shift + 1));
  }

// v1.44: 找检测周期内"最近一个有效波段" — 不依赖信号触达/失效/评分, 只看波段定义
//   思路: 从 shift=2 开始往旧扫, 找第一个分型(顶或底)作为波段终点; 再往后找最近的相反分型作为起点
//   终点=顶分型 → 做多波段(底→顶, DIR_UP 绿); 终点=底分型 → 做空波段(顶→底, DIR_DOWN 红)
//   校验: 波段幅度 >= InpBullMinATR × ATR(防噪声门槛, 与现有"波段定义"保持一致); 否则视为无效
bool FindLatestWave(int &iStart, int &iEnd, double &pStart, double &pEnd, int &dirOut)
  {
   int totalBars = Bars(_Symbol, InpSignalTF);
   int maxShift = MathMin(InpSignalBars, totalBars) - 1;
   if(maxShift < 5) return false;

   // 1) 找最近一个分型 (shift 最小, 即最靠近当前 bar 的已收盘分型)
   int newest = -1;
   bool newestIsTop = false;
   for(int i = 2; i <= maxShift; i++)
     {
      if(IsTopFractal(i))    { newest = i; newestIsTop = true;  break; }
      if(IsBottomFractal(i)) { newest = i; newestIsTop = false; break; }
     }
   if(newest < 0) return false;

   // 2) 往后(更旧)找最近的相反分型作为波段起点
   int startShift = -1;
   bool wantTop = !newestIsTop;
   for(int i = newest + 1; i <= maxShift; i++)
     {
      if(wantTop  && IsTopFractal(i))    { startShift = i; break; }
      if(!wantTop && IsBottomFractal(i)) { startShift = i; break; }
     }
   if(startShift < 0) return false;

   // 3) 设置起点/终点 + 方向
   iStart = startShift; iEnd = newest;
   if(newestIsTop)
     {
      // 做多波段: 底→顶
      pStart = iLow (_Symbol, InpSignalTF, iStart);
      pEnd   = iHigh(_Symbol, InpSignalTF, iEnd);
      dirOut = DIR_UP;
     }
   else
     {
      // 做空波段: 顶→底
      pStart = iHigh(_Symbol, InpSignalTF, iStart);
      pEnd   = iLow (_Symbol, InpSignalTF, iEnd);
      dirOut = DIR_DOWN;
     }

   // 4) 防噪声: 波段幅度门槛 (与信号模块共用 InpBullMinATR × ATR, 跨周期自适应)
   double atr = SignalATR();
   if(atr <= 0) return false;
   double swing = MathAbs(pEnd - pStart);
   if(swing < InpBullMinATR * atr) return false;

   return true;
  }

// 检测周期 ATR (取不到时用当前价兜底)
double SignalATR()
  {
   // 注意: iATR() 返回的是 indicator handle(int), 不是 ATR 数值, 需用 CopyBuffer 取出
   // 正确签名: int iATR(string symbol, ENUM_TIMEFRAMES period, int ma_period)  — 只 3 个参数
   double atr = 0.0;
   int h = iATR(_Symbol, InpSignalTF, InpSignalATRPeriod);
   if(h != INVALID_HANDLE)
     {
      double buf[];
      if(CopyBuffer(h, 0, 0, 1, buf) == 1) atr = buf[0];   // 当下 shift=0
      if(atr <= 0 && CopyBuffer(h, 0, 1, 1, buf) == 1) atr = buf[0];  // 未完成则取 shift=1
      IndicatorRelease(h);
     }
   if(atr <= 0)
     {
      double p = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(p <= 0) p = 1.0;
      atr = p * 0.005;                     // 兜底: 当前价 0.5%
     }
   return atr;
  }

// 检测周期文字 (PERIOD_M5 → "M5")
string SignalTFStr()
  {
   string s = EnumToString(InpSignalTF);
   return StringSubstr(s, 7);              // 去掉 "PERIOD_" 前缀
  }

// 5维评分 (0~100): 波段强度30 / 实体质量20 / 回调弱势25 / 分型确认15 / 形态完整10
//   iStart/iEnd = 波段起点/终点分型 shift (iStart > iEnd, 起点更旧)
//   startPrice/endPrice = 起点/终点价格 (做多: 低点/高点; 做空: 高点/低点)
//   isLong = true 做多(大实体阳线) / false 做空(大实体阴线)
double ScoreSignal(int iStart, int iEnd, double startPrice, double endPrice, int pullbackBars, double atr, bool isLong)
  {
   int nbars = iStart - iEnd + 1;
   double swing = MathAbs(endPrice - startPrice);   // 波段总幅度
   if(swing <= 0 || nbars <= 0) return 0.0;

   // 1. 波段强度 (30%): 平均每根幅度 / ATR, 每根走满 1 个 ATR 得满分
   double avgSwing = swing / nbars;
   double s1 = MathMin(100.0, (avgSwing / atr) * 100.0);

   // 2. 实体质量 (20%): 中间根里大实体(阳/阴)占比
   int bigCount = 0, midCount = 0;
   for(int i = iEnd + 1; i <= iStart - 1; i++)
     {
      midCount++;
      if(isLong ? IsBigBullBar(i) : IsBigBearBar(i)) bigCount++;
     }
   double s2 = (midCount > 0) ? ((double)bigCount / midCount) * 100.0 : 0.0;

   // 3. 回调弱势度 (25%): 回调斜率(每根) vs 波段斜率(每根), 回调越慢越弱势
   int pb = MathMax(1, pullbackBars);
   double swingSlope = swing / nbars;                    // 波段每根幅度
   double pbSlope    = (swing * InpPullbackDepth) / pb;  // 回调每根幅度(回到50%)
   double s3 = 0.0;
   if(swingSlope > 0)
      s3 = MathMax(0.0, (1.0 - pbSlope / swingSlope) * 100.0);
   s3 = MathMin(100.0, s3);

   // 4. 分型确认度 (15%): 底/顶分型中间超出两侧的幅度 (相对 ATR)
   double exStart = 0.0, exEnd = 0.0;
   if(isLong)
     {
      // 底分型 iStart: 中间低点低于两边低点
      exStart = (iLow(_Symbol, InpSignalTF, iStart - 1) - startPrice) +
                (iLow(_Symbol, InpSignalTF, iStart + 1) - startPrice);
      // 顶分型 iEnd: 中间高点高于两边高点
      exEnd = (endPrice - iHigh(_Symbol, InpSignalTF, iEnd - 1)) +
              (endPrice - iHigh(_Symbol, InpSignalTF, iEnd + 1));
     }
   else
     {
      // 顶分型 iStart: 中间高点高于两边高点
      exStart = (startPrice - iHigh(_Symbol, InpSignalTF, iStart - 1)) +
                (startPrice - iHigh(_Symbol, InpSignalTF, iStart + 1));
      // 底分型 iEnd: 中间低点低于两边低点
      exEnd = (iLow(_Symbol, InpSignalTF, iEnd - 1) - endPrice) +
              (iLow(_Symbol, InpSignalTF, iEnd + 1) - endPrice);
     }
   double s4 = MathMin(100.0, ((exStart + exEnd) / atr) * 100.0);

   // 5. 形态完整度 (10%): 波段根数贴近理想值 8
   double s5 = MathMax(0.0, 100.0 - MathAbs(nbars - 8.0) * 10.0);

   return 0.30 * s1 + 0.20 * s2 + 0.25 * s3 + 0.15 * s4 + 0.10 * s5;
  }

// 识别做多信号: 强势上涨→弱势回调到50%。触达+有效+评分达标 返回 true
bool DetectBullSignal(datetime &waveID, double &score, string &detail)
  {
   waveID = 0; score = 0.0; detail = "";
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0) return false;
   double atr = SignalATR();
   if(atr <= 0) return false;

   int totalBars = Bars(_Symbol, InpSignalTF);
   int maxShift = MathMin(InpSignalBars, totalBars) - 1;
   if(maxShift < 5) return false;   // 检测周期数据不足

   // 扫顶分型 (从新到旧), 顶分型 shift>=2 (右侧已收盘确认)
   for(int iTop = 2; iTop <= maxShift; iTop++)
     {
      if(!IsTopFractal(iTop)) continue;
      double topPrice = iHigh(_Symbol, InpSignalTF, iTop);

      // 往左找最近底分型 (上涨波段起点)
      int iBot = -1;
      for(int j = iTop + 1; j <= maxShift; j++)
        {
         if(IsBottomFractal(j)) { iBot = j; break; }
        }
      if(iBot < 0) continue;

      double botPrice = iLow(_Symbol, InpSignalTF, iBot);
      double rise = topPrice - botPrice;
      if(rise <= 0) continue;

      // 波段根数约束
      int nbars = iBot - iTop + 1;
      if(nbars < InpBullMinBars || nbars > InpBullMaxBars) continue;

      // 最小涨幅 (ATR 倍数, 防噪声)
      if(rise < InpBullMinATR * atr) continue;

      // 回调目标位 = 50% 位
      double pullbackPrice = topPrice - rise * InpPullbackDepth;

      // 实时价触达 + 未跌破起点 (失效条件)
      if(bid > pullbackPrice) continue;     // 未触达
      if(bid <= botPrice)     continue;     // 跌破起点 → 信号失效

      // 回调根数 (顶分型之后到当前的 bar 数 = iTop)
      int pullbackBars = iTop;
      if(pullbackBars < InpPullbackMinBars) continue;
      if(pullbackBars > InpPullbackMaxBars) continue;

      // 评分
      double sc = ScoreSignal(iBot, iTop, botPrice, topPrice, pullbackBars, atr, true);
      if(sc < InpSignalMinScore) continue;

      // 命中
      waveID = iTime(_Symbol, InpSignalTF, iBot);
      score  = sc;
      // 注: 波段坐标与画线由 UpdateWaveLine() 统一负责 (v1.44 起与信号触发解耦)
      detail = StringFormat("涨幅 %.1f点/%d根 | 回调 %.1f点/%d根",
                            rise / _Point, nbars,
                            rise * InpPullbackDepth / _Point, pullbackBars);
      return true;
     }
   return false;
  }

// 识别做空信号: 强势下跌→弱势反弹到50% (做多镜像)
bool DetectBearSignal(datetime &waveID, double &score, string &detail)
  {
   waveID = 0; score = 0.0; detail = "";
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0) return false;
   double atr = SignalATR();
   if(atr <= 0) return false;

   int totalBars = Bars(_Symbol, InpSignalTF);
   int maxShift = MathMin(InpSignalBars, totalBars) - 1;
   if(maxShift < 5) return false;   // 检测周期数据不足

   // 扫底分型 (从新到旧), 底分型 shift>=2
   for(int iBot = 2; iBot <= maxShift; iBot++)
     {
      if(!IsBottomFractal(iBot)) continue;
      double botPrice = iLow(_Symbol, InpSignalTF, iBot);

      // 往左找最近顶分型 (下跌波段起点)
      int iTop = -1;
      for(int j = iBot + 1; j <= maxShift; j++)
        {
         if(IsTopFractal(j)) { iTop = j; break; }
        }
      if(iTop < 0) continue;

      double topPrice = iHigh(_Symbol, InpSignalTF, iTop);
      double fall = topPrice - botPrice;
      if(fall <= 0) continue;

      int nbars = iTop - iBot + 1;
      if(nbars < InpBullMinBars || nbars > InpBullMaxBars) continue;

      if(fall < InpBullMinATR * atr) continue;

      // 反弹目标位 = 50% 位
      double pullbackPrice = botPrice + fall * InpPullbackDepth;

      // 实时价触达 + 未反弹突破起点
      if(ask < pullbackPrice) continue;     // 未触达
      if(ask >= topPrice)     continue;     // 反弹突破起点 → 失效

      int pullbackBars = iBot;
      if(pullbackBars < InpPullbackMinBars) continue;
      if(pullbackBars > InpPullbackMaxBars) continue;

      double sc = ScoreSignal(iTop, iBot, topPrice, botPrice, pullbackBars, atr, false);
      if(sc < InpSignalMinScore) continue;

      waveID = iTime(_Symbol, InpSignalTF, iTop);
      score  = sc;
      // 注: 波段坐标与画线由 UpdateWaveLine() 统一负责 (v1.44 起与信号触发解耦)
      detail = StringFormat("跌幅 %.1f点/%d根 | 反弹 %.1f点/%d根",
                            fall / _Point, nbars,
                            fall * InpPullbackDepth / _Point, pullbackBars);
      return true;
     }
   return false;
  }

// v1.44: 波段画线主入口 — 每 tick 由 OnTick 调用 (在 CheckSignals 之后)
//   与信号提醒完全解耦: 只看"波段定义是否成立"(FindLatestWave), 不依赖触达/失效/评分
//   稳定判断: 用 (iStart, iEnd, dir, tStart, tEnd) 五个量去重, 同一波段不重画, 避免每 tick 闪烁
void UpdateWaveLine()
  {
   // 静态变量记录上一次画线时的波段特征, 用于"波段稳定才重画"判断
   static int      s_iStart   = -1;
   static int      s_iEnd     = -1;
   static int      s_dir      = DIR_FLAT;
   static datetime s_tStart   = 0;
   static datetime s_tEnd     = 0;

   if(!InpWaveLineEnabled)
     {
      // 关闭时清理已有线 + 重置静态变量
      ObjectDelete(0, WaveName());
      s_iStart = -1; s_iEnd = -1; s_dir = DIR_FLAT;
      s_tStart = 0;  s_tEnd   = 0;
      return;
     }

   int    iStart = 0, iEnd = 0, dirOut = DIR_FLAT;
   double pStart = 0, pEnd  = 0;
   if(!FindLatestWave(iStart, iEnd, pStart, pEnd, dirOut))
     {
      // 找不到有效波段, 清理已有线
      ObjectDelete(0, WaveName());
      s_iStart = -1; s_iEnd = -1; s_dir = DIR_FLAT;
      s_tStart = 0;  s_tEnd   = 0;
      return;
     }

   datetime tStart = iTime(_Symbol, InpSignalTF, iStart);
   datetime tEnd   = iTime(_Symbol, InpSignalTF, iEnd);

   // 稳定判断: 同波段(5 个量全等)就不重画, 避免每 tick 闪烁
   if(s_iStart == iStart && s_iEnd == iEnd && s_dir == dirOut &&
      s_tStart == tStart && s_tEnd   == tEnd)
      return;

   s_iStart = iStart; s_iEnd = iEnd; s_dir = dirOut;
   s_tStart = tStart; s_tEnd = tEnd;

   // 锚点居中: 分型 bar 开盘时间 + 半个检测周期
   int tfSec = PeriodSeconds(InpSignalTF);
   g_waveT1  = tStart + tfSec / 2;
   g_waveP1  = pStart;
   g_waveT2  = tEnd   + tfSec / 2;
   g_waveP2  = pEnd;
   g_waveDir = dirOut;

   DrawWaveLine();   // 内部先 ObjectDelete 旧线再 ObjectCreate 新线
  }

// v1.43: 把最新波段高低点画成趋势线 (上涨绿 / 下跌红)
//   锚点 = 分型 bar 中央的绝对时间 + 价格, 因此与图表周期无关:
//   即使 InpSignalTF(检测周期) ≠ 图表周期, 线也会精确落在真实高低点位置上
//   独立前缀 FLAW_ 不被 ApplyHidden 隐藏, 不受 HIDE 按钮影响
void DrawWaveLine()
  {
   string name = WaveName();
   ObjectDelete(0, name);   // 先删旧线: 同名对象存在时 ObjectCreate 会失败, 无法覆盖上一波段的线

   if(g_waveT1 == 0 || g_waveT2 == 0 || g_waveP1 <= 0 || g_waveP2 <= 0)
      return;

   if(!ObjectCreate(0, name, OBJ_TREND, 0, g_waveT1, g_waveP1, g_waveT2, g_waveP2))
      return;
   ObjectSetInteger(0, name, OBJPROP_COLOR,      (g_waveDir == DIR_UP) ? CLR_BUY_BG : CLR_SELL_BG);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,      2);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT,  false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK,       false);
   ChartRedraw(0);
  }

// 信号提醒主入口: OnTick 里调用; 总开关关闭直接返回
void CheckSignals()
  {
   if(!InpSignalEnabled) return;

   bool doLong  = (InpSignalDirection == SIG_DIR_BOTH || InpSignalDirection == SIG_DIR_LONG);
   bool doShort = (InpSignalDirection == SIG_DIR_BOTH || InpSignalDirection == SIG_DIR_SHORT);

   datetime waveID = 0;
   double   score  = 0.0;
   string   detail = "";

   if(doLong && DetectBullSignal(waveID, score, detail))
     {
      if(waveID != 0 && waveID != g_sigLongID)   // 波段去重
        {
         g_sigLongID = waveID;
         // v1.44: 画线由 UpdateWaveLine() 每 tick 独立完成, 与信号触发解耦
         string msg = StringFormat("[FibLimitAssist] 强势看涨信号 (%s %s) 评分 %.0f/100 | %s",
                                   _Symbol, SignalTFStr(), score, detail);
         Alert(msg);
         SendNotification(msg);
         Print("[信号] ", msg);
        }
     }

   if(doShort && DetectBearSignal(waveID, score, detail))
     {
      if(waveID != 0 && waveID != g_sigShortID)
        {
         g_sigShortID = waveID;
         // v1.44: 画线由 UpdateWaveLine() 每 tick 独立完成, 与信号触发解耦
         string msg = StringFormat("[FibLimitAssist] 强势看跌信号 (%s %s) 评分 %.0f/100 | %s",
                                   _Symbol, SignalTFStr(), score, detail);
         Alert(msg);
         SendNotification(msg);
         Print("[信号] ", msg);
        }
     }
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
   ObjectDelete(0, WaveName());   // v1.43: 波段线独立前缀, 需单独清理 (否则切周期残留旧线)
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
   else        { UpdatePnLDisplay(); UpdateRatioLabels(); ChartRedraw(0); }   // v1.08 PnL + v1.35 盈亏比 — 每个 tick 都刷新, 不等新柱

   CheckSignals();      // v1.40 交易信号提醒 (内部判断开关, 关闭时零开销直接返回)
   UpdateWaveLine();    // v1.44 波段画线 (独立于信号提醒, 内部判断开关, 关闭时清理已有线)
   UpdateFVGDisplay();  // v1.45 FVG 矩形 — 每 tick 实时判定 U→P→F (独立于 g_dirty)
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
         g_fvgEnabled = !g_fvgEnabled;
         UpdateFVGButton();   // 同步文字/颜色/sticky 状态
         if(!g_fvgEnabled) UpdateFVGDisplay();   // 关闭时立即清空矩形
         else               { g_dirty = true; }   // 开启时下次 RefreshAll 重建 (OnTick 检测 g_dirty → 走 RefreshAll)
         ChartRedraw(0);
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
