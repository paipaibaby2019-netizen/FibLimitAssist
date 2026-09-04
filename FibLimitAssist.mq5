//+------------------------------------------------------------------+
//|                                                 FibLimitAssist.mq5 |
//|                               半自动斐波那契限价下单辅助 EA        |
//|        交易方向 / 行情判断完全人工，EA 只负责绘图 + 按钮 + 下单     |
//+------------------------------------------------------------------+
#property copyright "FibLimitAssist"
#property version   "1.05"
#property description "半自动斐波那契限价下单辅助："
#property description "· 人工拖拽 1.00 起点 / 0.00 终点定义高低区间"
#property description "· 点击 0.79 / 0.49 右侧按钮下发 ORDER_LIMIT 限价单"
#property description "· 单笔风险 = 余额固定百分比，盈亏比固定，手数反算并截断"

//---------------------------- 输入参数 -----------------------------//
// 注: 单笔风险(%) 由 RISK 按钮循环控制 (0.5/1/2)，盈亏比按比例分档 (0.79=2:1, 0.49=1:1, 市价=1:1)
input double InpSL_OffsetPercent = 1.0;        // 止损向外偏移占区间百分比 (%)
input int    InpLotDecimals      = 2;          // 手数截断保留的小数位 (不四舍五入)
input long   InpMagicNumber      = 20260903;   // 订单魔术号
input string InpOrderComment     = "FibLimitAssist"; // 订单注释

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
   ObjectSetInteger(0, name, OBJPROP_XSIZE, 200);
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
// 风险切换按钮对象名
string RiskName()          { return g_prefix + "RISK"; }
// 市价下单按钮对象名
string MarketName()        { return g_prefix + "MARKET"; }
// 隐藏/显示按钮对象名 (始终显示，不会随 g_hidden 隐藏)
string HideName()          { return g_prefix + "HIDE"; }

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
   CreateActionButton(CancelPendingName(), 100, "CANCEL",       C'120,120,120', "取消账户内全部挂单（含手动单）");
   CreateActionButton(CloseAllName(),      100, "CLOSE ALL",    C'200,120,20',  "平掉账户内全部持仓（不涉及挂单）");
   CreateActionButton(CloseHalfName(),     100, "CLOSE HALF",   C'230,140,40',  "按手数砍半平仓（账户全部品种）；若砍半后 < 最小手数则全平该仓位");
   CreateActionButton(RiskName(),           80, "",              C'90,90,90',   "点击循环切换单笔风险档位：0.5% → 1% → 2% → 0.5%");
   CreateActionButton(MarketName(),         80, "MARKET",        C'140,140,140',"市价下单（止损 = 1.00 ± Range×1%，盈亏比 1:1）");
   CreateActionButton(HideName(),           80, "HIDE",          C'60,60,60',   "隐藏/显示 EA 全部线条与按钮（此按钮自身始终显示）");

   CreateLabelRight(LName(RATIO_100), "1.00", CLR_END);
   CreateLabelRight(LName(RATIO_000), "0.00", CLR_END);
   CreateLabelRight(LName(RATIO_021), "0.21", CLR_DECO);
  }

//---------------------------- 刷新显示 -----------------------------//
void UpdateButtonX()
  {
   int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   g_btnX = w - 208;
   if(g_btnX < 0) g_btnX = 0;
  }
void UpdateButton(string name, double price, string text, int dir)
  {
   if(ObjectFind(0, name) < 0) return;
   int x = 0, y = 0;
   if(ChartTimePriceToXY(0, 0, RightAnchor(), price, x, y))
     {
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, g_btnX);
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
// 右对齐标签更新：像素定位，右边缘对齐按钮右边缘(g_btnX+200)，Y 对齐线价格
void UpdateLabelRight(string name, double price, string text)
  {
   if(ObjectFind(0, name) < 0) return;
   int x = 0, y = 0;
   if(!ChartTimePriceToXY(0, 0, RightAnchor(), price, x, y)) return;
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, g_btnX + 200);
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
  }

// 最上面那根线两侧按钮：左 SWAP (80) | 间隔 4 | CANCEL (100)，右边缘对齐 g_btnX+200
void UpdateTopButtons()
  {
   double topPrice = MathMax(g_p1, g_p0);
   int x = 0, y = 0;
   if(!ChartTimePriceToXY(0, 0, RightAnchor(), topPrice, x, y)) return;
   int yBtn = y - 26; if(yBtn < 0) yBtn = 0;

   string cancelName = CancelPendingName();
   if(ObjectFind(0, cancelName) >= 0)
     {
      ObjectSetInteger(0, cancelName, OBJPROP_XDISTANCE, g_btnX + 200 - 100);
      ObjectSetInteger(0, cancelName, OBJPROP_YDISTANCE, yBtn);
     }

   string swapName = SwapName();
   if(ObjectFind(0, swapName) >= 0)
     {
      // SWAP 在 CANCEL 左侧：右边 = CANCEL 左边 - 4 = g_btnX + 200 - 100 - 4 = g_btnX + 96
      ObjectSetInteger(0, swapName, OBJPROP_XDISTANCE, g_btnX + 200 - 100 - 4 - 80);
      ObjectSetInteger(0, swapName, OBJPROP_YDISTANCE, yBtn);
     }
  }

// 最下面那根线左侧三个按钮：HIDE (80) | RISK (80) | MARKET (80)，左对齐 X=10 起步
void UpdateBottomLeftButtons()
  {
   double botPrice = MathMin(g_p1, g_p0);
   int x = 0, y = 0;
   if(!ChartTimePriceToXY(0, 0, RightAnchor(), botPrice, x, y)) return;
   int yBtn = y - 26; if(yBtn < 0) yBtn = 0;

   string hideName = HideName();
   if(ObjectFind(0, hideName) >= 0)
     {
      ObjectSetInteger(0, hideName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, hideName, OBJPROP_YDISTANCE, yBtn);
     }
   string riskName = RiskName();
   if(ObjectFind(0, riskName) >= 0)
     {
      ObjectSetInteger(0, riskName, OBJPROP_XDISTANCE, 10 + 80 + 4);
      ObjectSetInteger(0, riskName, OBJPROP_YDISTANCE, yBtn);
     }
   string marketName = MarketName();
   if(ObjectFind(0, marketName) >= 0)
     {
      ObjectSetInteger(0, marketName, OBJPROP_XDISTANCE, 10 + 80 + 4 + 80 + 4);
      ObjectSetInteger(0, marketName, OBJPROP_YDISTANCE, yBtn);
     }
  }

// 最下面那根线右侧两个按钮：CLOSE_HALF (100) | 间隔 4 | CLOSE_ALL (100)，右边缘对齐 g_btnX+200
void UpdateBottomRightButtons()
  {
   double botPrice = MathMin(g_p1, g_p0);
   int x = 0, y = 0;
   if(!ChartTimePriceToXY(0, 0, RightAnchor(), botPrice, x, y)) return;
   int yBtn = y - 26; if(yBtn < 0) yBtn = 0;

   string closeAllName = CloseAllName();
   if(ObjectFind(0, closeAllName) >= 0)
     {
      ObjectSetInteger(0, closeAllName, OBJPROP_XDISTANCE, g_btnX + 200 - 100);
      ObjectSetInteger(0, closeAllName, OBJPROP_YDISTANCE, yBtn);
     }
   string closeHalfName = CloseHalfName();
   if(ObjectFind(0, closeHalfName) >= 0)
     {
      // CLOSE_HALF 在 CLOSE_ALL 左侧：右边 = CLOSE_ALL 左边 - 4 = g_btnX + 200 - 100 - 4 = g_btnX + 96
      ObjectSetInteger(0, closeHalfName, OBJPROP_XDISTANCE, g_btnX + 200 - 100 - 4 - 100);
      ObjectSetInteger(0, closeHalfName, OBJPROP_YDISTANCE, yBtn);
     }
  }

// 0.79/0.49 挂单按钮文字：保留比例与手数，去掉中间的 BL/SL（颜色已区分方向）
string BuildButtonText(double r, double lot)
  {
   return StringFormat("%.2f (%.*f)", r, InpLotDecimals, lot);
  }

// HIDE/SHOW 按钮文字
void UpdateHideButton()
  {
   string name = HideName();
   if(ObjectFind(0, name) < 0) return;
   ObjectSetString(0, name, OBJPROP_TEXT, g_hidden ? "SHOW" : "HIDE");
  }

// 风险按钮文字：循环档位 (0.5 → 1 → 2 → 0.5 ...)
void UpdateRiskButton()
  {
   string name = RiskName();
   if(ObjectFind(0, name) < 0) return;
   ObjectSetString(0, name, OBJPROP_TEXT, "RISK " + DoubleToString(g_riskPercent, 1) + "%");
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
void ApplyHidden()
  {
   int total = ObjectsTotal(0, -1, -1);
   string hideObj = HideName();
   for(int i = 0; i < total; i++)
     {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, g_prefix) != 0) continue;   // 仅本实例对象
      bool hide = g_hidden && (name != hideObj);       // HIDE 按钮自身永远显示
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, hide);
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
   UpdateMarketButton(dir);
   UpdateRiskButton();
   UpdateHideButton();
   UpdateTopButtons();
   UpdateBottomLeftButtons();
   UpdateBottomRightButtons();

   UpdateLabelRight(LName(RATIO_100), g_p1, "1.00");
   UpdateLabelRight(LName(RATIO_000), g_p0, "0.00");
   UpdateLabelRight(LName(RATIO_021), TheoPrice(RATIO_021, g_p1, g_p0), "0.21");

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

// 0.79 挂单 → 2 倍盈亏比；0.49 挂单 → 1 倍盈亏比
void PlaceOrder(double r)
  {
   double rr = (r == RATIO_079) ? 2.0 : 1.0;
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
   Print("[FibLimitAssist] 取消挂单完成：成功=", cancelled, " 失败=", failed);
   Alert("[FibLimitAssist] 取消挂单：成功 ", cancelled, " 张", (failed > 0 ? "，失败 " + IntegerToString(failed) + " 张" : ""));
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
   Print("[FibLimitAssist] 清仓完成：成功=", closed, " 失败=", failed);
   Alert("[FibLimitAssist] 清仓：成功 ", closed, " 笔", (failed > 0 ? "，失败 " + IntegerToString(failed) + " 笔" : ""));
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
   Print("[FibLimitAssist] 平一半完成：半平=", halfClosed, " 全平=", fullClosed, " 失败=", failed);
   Alert("[FibLimitAssist] 平一半：半平 ", halfClosed, " 笔，全平 ", fullClosed, " 笔",
         (failed > 0 ? "，失败 " + IntegerToString(failed) + " 笔" : ""));
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
  }

// 切换隐藏/显示
void ToggleHide()
  {
   g_hidden = !g_hidden;
   ApplyHidden();
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
      if(sparam == SwapName())          { DoSwap();            return; }
      if(sparam == CancelPendingName()) { CancelAllPending();  return; }
      if(sparam == CloseAllName())      { CloseAllPositions(); return; }
      if(sparam == CloseHalfName())     { CloseHalfPositions();return; }
      if(sparam == RiskName())          { CycleRisk();         return; }
      if(sparam == MarketName())        { PlaceMarketOrder();  return; }
      if(sparam == HideName())          { ToggleHide();        return; }
      double r = RatioOfButton(sparam);
      if(r > 0) PlaceOrder(r);
     }
   else if(id == CHARTEVENT_CHART_CHANGE)
     {
      g_dirty = true;
     }
  }
//+------------------------------------------------------------------+
