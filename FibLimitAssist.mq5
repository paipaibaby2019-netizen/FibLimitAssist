//+------------------------------------------------------------------+
//|                                                 FibLimitAssist.mq5 |
//|                               半自动斐波那契限价下单辅助 EA        |
//|        交易方向 / 行情判断完全人工，EA 只负责绘图 + 按钮 + 下单     |
//+------------------------------------------------------------------+
#property copyright "FibLimitAssist"
#property version   "1.13"
#property description "半自动斐波那契限价下单辅助："
#property description "· 人工拖拽 1.00 起点 / 0.00 终点定义高低区间"
#property description "· 点击 0.79 / 0.49 右侧按钮下发 ORDER_LIMIT 限价单"
#property description "· 单笔风险 = 余额固定百分比，盈亏比固定，手数反算并截断"
#property description "· MKT 按钮两侧实时显示持仓浮盈 + 当日累计盈亏"
#property description "· EVEN 按钮统一把任意持仓调到入场价平仓（盈改 SL，亏改 TP）"
#property description "· ADJUST 按钮一键把 1.00/0.00 调整到图表最近的高低点 (v1.13)"

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

//---------------------------- 固定比例 -----------------------------//
#define RATIO_100 1.00
#define RATIO_079 0.79
#define RATIO_049 0.49
#define RATIO_021 0.21
#define RATIO_000 0.00

//---------------------------- 颜色定义 -----------------------------//
#define CLR_END      C'90,90,90'     // 端点 1.00 / 0.00 线
#define CLR_MID      C'0,140,220'    // 0.79 / 0.49 线
#define CLR_DECO     C'115,115,115'  // 0.21 装饰线（加深，避免看不清）
#define CLR_BUY_BG   C'76,175,80'    // 买单按钮底色
#define CLR_SELL_BG  C'244,67,54'    // 卖单按钮底色
#define CLR_FLAT_BG  C'140,140,140'  // 方向未定义按钮底色
// v1.07 新增：HIDE/SHOW 状态色 + RISK 三档色
#define CLR_HIDE_OFF C'60,60,60'     // SHOW 状态：当前显示（深灰）
#define CLR_HIDE_ON  C'200,120,20'   // HIDE 状态：当前隐藏（橙黄警示）
#define CLR_RISK_LOW C'76,175,80'    // RISK 0.5% 低风险（绿）
#define CLR_RISK_MID C'255,193,7'    // RISK 1%   中风险（黄）
#define CLR_RISK_HI  C'244,67,54'    // RISK 2%   高风险（红）

// v1.08 新增：P/L 数字标签颜色
#define CLR_PLUS        C'0,150,60'   // 盈利（绿，带 +）
#define CLR_MINUS       C'220,0,0'    // 亏损（红，带 -）
#define CLR_PNL_NEUTRAL C'140,140,140'// 盈亏为零（灰）

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

// v1.12 新增: 服务器相对 GMT 的偏移小时数 (OnInit 自动探测一次)
//   由 (TimeCurrent() - TimeGMT()) 推断，如 broker 是 GMT+2 则 g_serverGMTOffset = +2
//   仅用于 CE(S)T 切日换算
int      g_serverGMTOffset = 0;

//---------------------------- 工具函数 -----------------------------//
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
void SaveState()
  {
   GlobalVariableSet(g_prefix + "p1",  g_p1);
   GlobalVariableSet(g_prefix + "p0",  g_p0);
   GlobalVariableSet(g_prefix + "p79", g_p79);
   GlobalVariableSet(g_prefix + "p49", g_p49);
   GlobalVariableSet(g_prefix + "risk", g_riskPercent);
  }
bool LoadState()
  {
   if(!GlobalVariableCheck(g_prefix + "p1")) return false;
   g_p1  = GlobalVariableGet(g_prefix + "p1");
   g_p0  = GlobalVariableGet(g_prefix + "p0");
   g_p79 = GlobalVariableGet(g_prefix + "p79");
   g_p49 = GlobalVariableGet(g_prefix + "p49");
   if(GlobalVariableCheck(g_prefix + "risk"))
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
   ObjectSetInteger(0, name, OBJPROP_XSIZE, 120);   // v1.08：挂单按钮从 200 缩到 120（v1.06 的 60%）
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 22);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
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
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
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
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
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
// 隐藏/显示按钮对象名 (始终显示，不会随 g_hidden 隐藏)
string HideName()          { return g_prefix + "HIDE"; }
// v1.13: 一键调整 1.00/0.00 到最近高低点的按钮对象名
string AdjustName()        { return g_prefix + "ADJUST"; }

bool CreateSwapButton()
  {
   string name = SwapName();
   if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0)) return false;
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, 80);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 22);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
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
   ObjectSetInteger(0, name, OBJPROP_XSIZE, 80);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 22);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
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
   ObjectSetInteger(0, name, OBJPROP_XSIZE, xsize);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 22);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
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
   CreateHLine(HName(RATIO_079), g_p79, true,  CLR_MID,  STYLE_SOLID, 1);
   CreateHLine(HName(RATIO_049), g_p49, true,  CLR_MID,  STYLE_SOLID, 1);
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
   CreateActionButton(HideName(),           80, "HIDE",          C'60,60,60',   "隐藏/显示 EA 全部线条与按钮（此按钮自身始终显示）");

   // v1.08：MKT 两侧的实时盈亏数字标签（OBJ_LABEL 像素定位）
   CreatePnLLabel(PnLLeftName());
   CreatePnLLabel(PnLRightName());

   CreateLabelRight(LName(RATIO_021), "0.21", CLR_DECO);
  }

// v1.08：盈亏数字标签（OBJ_LABEL 像素定位）
bool CreatePnLLabel(string name)
  {
   if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0)) return false;
   ObjectSetString(0, name, OBJPROP_TEXT, "");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
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
   //  · 0.79/0.49 挂单按钮：宽 120，左 X = g_btnX - 20（右边缘与 CALL/CANCEL 右边缘对齐 = w-8）
   //  · EVEN 按钮：宽 80，左 X = g_btnX - 208
   //  · CHALF 按钮：宽 100，左 X = g_btnX - 104
   int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   g_btnX = w - 108;
   if(g_btnX < 0) g_btnX = 0;
  }
void UpdateButton(string name, double price, string text, int dir)
  {
   if(ObjectFind(0, name) < 0) return;
   int x = 0, y = 0;
   if(ChartTimePriceToXY(0, 0, RightAnchor(), price, x, y))
     {
      // v1.08b：挂单按钮宽 120，右边缘与 CALL/COLUMN 右边缘对齐（w-8），左 X = g_btnX - 20
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, g_btnX - 20);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y - 11);
     }
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   color bg = (dir == DIR_UP) ? CLR_BUY_BG : ((dir == DIR_DOWN) ? CLR_SELL_BG : CLR_FLAT_BG);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
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
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, g_btnX + 100);  // 右边缘 = w-8，与按钮列右对齐
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y - 2);
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

   // v1.08b：水平居中 + 垂直放到最上面那根线（MathMax(p1,p0)）中点
   int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int x = 0, y = 0;
   double topPrice = MathMax(g_p1, g_p0);
   if(!ChartTimePriceToXY(0, 0, RightAnchor(), topPrice, x, y)) return;
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, (w - 80) / 2);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y - 11);
  }

// v1.13: ADJUST 按钮位置 (在 SWAP 右侧 4px, 同样在"最上面那根线"中点上方 11px)
void UpdateAdjustButton()
  {
   string name = AdjustName();
   if(ObjectFind(0, name) < 0) return;
   int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int x = 0, y = 0;
   double topPrice = MathMax(g_p1, g_p0);
   if(!ChartTimePriceToXY(0, 0, RightAnchor(), topPrice, x, y)) return;
   // SWAP 位置 = (w-80)/2, ADJUST 宽 80, 间距 4 → ADJUST 左 X = SWAP 左 X + SWAP 宽 + 4
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, (w - 80) / 2 + 84);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y - 11);
  }

// 最上面那根线右侧：仅 CANCEL 按钮（v1.07：SWAP 已移到线段中点）
void UpdateTopButtons()
  {
   double topPrice = MathMax(g_p1, g_p0);
   int x = 0, y = 0;
   if(!ChartTimePriceToXY(0, 0, RightAnchor(), topPrice, x, y)) return;
   int yBtn = y - 26; if(yBtn < 0) yBtn = 0;

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
void UpdateBottomButtons()
  {
   double botPrice = MathMin(g_p1, g_p0);
   int x = 0, y = 0;
   if(!ChartTimePriceToXY(0, 0, RightAnchor(), botPrice, x, y)) return;
   int yBtn = y - 26; if(yBtn < 0) yBtn = 0;
   int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);

   // MARKET 居中位置 (宽 110)
   int marketW = 110;
   int marketX = (w - marketW) / 2;

   // 左侧 HIDE / RISK
   if(ObjectFind(0, HideName()) >= 0)
     {
      ObjectSetInteger(0, HideName(), OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, HideName(), OBJPROP_YDISTANCE, yBtn);
     }
   if(ObjectFind(0, RiskName()) >= 0)
     {
      ObjectSetInteger(0, RiskName(), OBJPROP_XDISTANCE, 10 + 80 + 4);
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
      ObjectSetInteger(0, PnLLeftName(), OBJPROP_XDISTANCE, marketX - 6);
      ObjectSetInteger(0, PnLLeftName(), OBJPROP_YDISTANCE, yBtn + 4);
     }
   if(ObjectFind(0, PnLRightName()) >= 0)
     {
      ObjectSetInteger(0, PnLRightName(), OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, PnLRightName(), OBJPROP_XDISTANCE, marketX + marketW + 6);
      ObjectSetInteger(0, PnLRightName(), OBJPROP_YDISTANCE, yBtn + 4);
     }

   // 右侧 EVEN / CHALF / CALL（CALL 最右，左 X = g_btnX）
   if(ObjectFind(0, CloseAllName()) >= 0)
     {
      ObjectSetInteger(0, CloseAllName(), OBJPROP_XDISTANCE, g_btnX);
      ObjectSetInteger(0, CloseAllName(), OBJPROP_YDISTANCE, yBtn);
     }
   if(ObjectFind(0, CloseHalfName()) >= 0)
     {
      ObjectSetInteger(0, CloseHalfName(), OBJPROP_XDISTANCE, g_btnX - 100 - 4);
      ObjectSetInteger(0, CloseHalfName(), OBJPROP_YDISTANCE, yBtn);
     }
   if(ObjectFind(0, EvenName()) >= 0)
     {
      ObjectSetInteger(0, EvenName(), OBJPROP_XDISTANCE, g_btnX - 100 - 4 - 100 - 4);
      ObjectSetInteger(0, EvenName(), OBJPROP_YDISTANCE, yBtn);
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

   UpdateSwapButton(dir);
   UpdateAdjustButton();   // v1.13: ADJUST 按钮位置 (跟随 SWAP)
   UpdateMarketButton(dir);
   UpdateRiskButton();
   UpdateHideButton();
   UpdateTopButtons();
   UpdateBottomButtons();
   UpdatePnLDisplay();   // v1.08：MKT 两侧的实时盈亏数字

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

   // 4. 改全局变量 (其余 0.21/0.49/0.79 由 RefreshAll 通过 TheoPrice 自动重画)
   g_p1 = NormalizeDouble(pH, _Digits);   // 1.00 = 最近高点
   g_p0 = NormalizeDouble(pL, _Digits);   // 0.00 = 最近低点

   // 5. 保存到全局变量 (会话内有效, 重启 MT5 后回到默认)
   SaveState();

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
   SaveState();
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

   SaveState();
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
   SaveState();
   RefreshAll();
  }

//---------------------------- 生命周期 -----------------------------//
int OnInit()
  {
   g_prefix = "FLA_" + IntegerToString(ChartID()) + "_" + _Symbol + "_";

   // v1.12: 自动探测服务器时区 (用于 CE(S)T 切日换算)
   DetectTimezone();

   if(!LoadState())
     {
      // 首次附加：用当前可见价格区间生成默认斐波那契
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
     }

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
      if(sparam == HideName())
        {
         ToggleHide();   // UpdateHideButton 会根据 g_hidden 同步设置 STATE
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
