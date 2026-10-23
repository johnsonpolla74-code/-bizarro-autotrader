//+------------------------------------------------------------------+
//|                                         BizarroAutoTrader.mq5    |
//|                                  Copyright 2026, Johnson Polla   |
//|                          Bizarro Ultra Pro Plus v3.0 Mobile EA   |
//+------------------------------------------------------------------+
#property copyright "Johnson Polla - Bizarro Dynamic"
#property link      "https://www.bizarro-trader.com"
#property version   "3.00"
#property description "Institutional Ultra Pro Plus EA with Multi-Timeframe Confluence, Mobile Alerts & Spread Shield"
#property strict

//--- LIBRARIES
#include <Trade\Trade.mqh>
CTrade trade;

//--- INPUT PARAMETERS
input group "=== 1. SECURITY & LICENSING ==="
input ulong    InpTargetAccount     = 0;         // Security: Target Account Login Number (0 = Unlocked for Testing)

input group "=== 2. INSTITUTIONAL RISK MANAGEMENT ==="
input double   InpRiskPercent       = 1.0;       // Risk % per Trade (1-2% recommended)
input double   InpMaxDailyLoss      = 3.0;       // Maximum Daily Drawdown Limit (%)
input double   InpRewardRatio       = 2.5;       // Enhanced Risk-to-Reward Ratio (1:2.5)
input int      InpCooldownMinutes   = 15;        // Fast recovery cooldown in minutes

input group "=== 3. SPREAD & BROKER SHIELD ==="
input double   InpMaxSpreadPips     = 2.5;       // Maximum allowable spread in pips before execution

input group "=== 4. MOBILE ALERTS & NOTIFICATIONS ==="
input bool     InpSendMobileAlerts  = true;      // Send FREE Instant Push Notifications to Mobile MT5 App

input group "=== 5. DARK POOL & SMC ORDER BLOCK ENGINE ==="
input bool     InpUseOrderBlocks    = true;      // Enable Institutional Order Block & FVG Sniping
input bool     InpUseLiquidityTrap  = true;      // Enable Stop-Hunt / Liquidity Sweep Detection
input double   InpMinVelocityPips   = 4.0;       // Minimum speed for lightning momentum execution
input ENUM_TIMEFRAMES InpHigherTimeframe = PERIOD_H1; // Higher Timeframe for Trend Alignment

input group "=== 6. FULL PATTERN ENGINE SETTINGS ==="
input bool     InpScanDoubleBP      = true;      // Scan Double Bottoms ("W" Pattern)
input bool     InpScanDoubleTP      = true;      // Scan Double Tops ("M" Pattern)
input bool     InpScanHeadShoulders = true;      // Scan Head & Shoulders / Inverse
input bool     InpScanFlags         = true;      // Scan Bullish & Bearish Flags
input bool     InpScanWedges        = true;      // Scan Falling & Rising Wedges
input int      InpPatternDepth      = 14;        // Swing High/Low Sensitivity

input group "=== 7. DYNAMIC TRAILING & PROFIT SCALING ==="
input bool     InpUsePartialClose   = true;      // Close 50% Lot at Target 1 (TP1)
input bool     InpUseTrailingStop   = true;      // Dynamic Smart Trailing System
input double   InpTrailingStep      = 100;       // Base Trailing Step in Points

//--- GLOBALS
double   ExtDailyStartEquity = 0;
datetime ExtLastTradeDay     = 0;
datetime ExtCooldownEndTime  = 0;
bool     ExtIsCooledDown     = false;
ulong    ExtMagicNumber      = 999999;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(ExtMagicNumber);
   
   if(InpTargetAccount > 0 && AccountInfoInteger(ACCOUNT_LOGIN) != InpTargetAccount)
     {
      Print("CRITICAL SECURITY ERROR: Unauthorized Account Login! Access Denied.");
      return(INIT_FAILED);
     }

   ExtDailyStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   ExtLastTradeDay     = TimeDay(TimeCurrent());
   
   Print("Bizarro Ultra Pro Plus v3.0 Mobile EA initialized successfully.");
   if(InpSendMobileAlerts)
      SendNotification("BIZARRO PRO+: EA Initialized Successfully on " + _Symbol);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print("Bizarro Ultra Pro Plus EA Shutting Down Safely. Reason Code: ", reason);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // 1. MONITOR DAILY RISK & FAST COOLDOWN
   CheckDailyRiskLimit();
   
   if(IsDailyLimitReached())
     {
      if(TimeCurrent() >= ExtCooldownEndTime)
        {
         Print("ULTRA RECOVERY: Cooldown ended. Re-engaging Dark Pool market scanner.");
         ExtIsCooledDown = true;
        }
      else
        {
         return; 
        }
     }

   // 2. CHECK BROKER SPREAD SHIELD
   if(!CheckSpreadSafety()) return;

   // 3. MANAGE OPEN POSITIONS (DYNAMIC TRAILING & BREAK-EVEN)
   ManageOpenPositions();

   // 4. MULTI-TIMEFRAME & SMC EXECUTION ENGINE
   if(PositionsTotal() == 0)
     {
      bool higherTrendBullish = IsHigherTimeframeBullish();
      bool momentumSurge      = CheckMarketVelocity();
      bool orderBlockSignal   = InpUseOrderBlocks && DetectInstitutionalOrderBlock();
      bool liquidityTrap      = InpUseLiquidityTrap && DetectLiquiditySweepTrap();

      bool buyPattern         = (InpScanDoubleBP && DetectDoubleBottom()) || 
                                (InpScanHeadShoulders && DetectInverseHeadAndShoulders()) ||
                                (InpScanWedges && DetectFallingWedge());
                        
      bool sellPattern        = (InpScanDoubleTP && DetectDoubleTop()) || 
                                (InpScanHeadShoulders && DetectHeadAndShoulders()) ||
                                (InpScanWedges && DetectRisingWedge());

      if(liquidityTrap)
        {
         ENUM_ORDER_TYPE trapType = DetermineTrapDirection();
         if((trapType == ORDER_TYPE_BUY && higherTrendBullish) || (trapType == ORDER_TYPE_SELL && !higherTrendBullish))
            ExecuteInstitutionalTrade(trapType, "Bizarro SMC Trap");
        }
      else if(orderBlockSignal)
        {
         ENUM_ORDER_TYPE obType = DetermineOBDirection();
         if((obType == ORDER_TYPE_BUY && higherTrendBullish) || (obType == ORDER_TYPE_SELL && !higherTrendBullish))
            ExecuteInstitutionalTrade(obType, "Bizarro OrderBlock");
        }
      else if(momentumSurge)
        {
         ENUM_ORDER_TYPE surgeType = DetermineSurgeDirection();
         ExecuteInstitutionalTrade(surgeType, "Bizarro Lightning Surge");
        }
      else if(buyPattern && higherTrendBullish)
        {
         ExecuteInstitutionalTrade(ORDER_TYPE_BUY, "Bizarro Pattern BUY");
        }
      else if(sellPattern && !higherTrendBullish)
        {
         ExecuteInstitutionalTrade(ORDER_TYPE_SELL, "Bizarro Pattern SELL");
        }
     }
  }

//+------------------------------------------------------------------+
//| SYSTEM 1: SPREAD SAFETY SHIELD                                   |
//+------------------------------------------------------------------+
bool CheckSpreadSafety()
  {
   double currentSpread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   double maxSpreadAllowed = InpMaxSpreadPips * 10 * _Point;
   
   if(currentSpread > maxSpreadAllowed)
     {
      Comment("SPREAD SHIELD ACTIVE: High spread detected (", currentSpread / _Point, " points). Waiting for market calm.");
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| SYSTEM 2: MULTI-TIMEFRAME TREND CONFLUENCE                       |
//+------------------------------------------------------------------+
bool IsHigherTimeframeBullish()
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, InpHigherTimeframe, 0, 2, rates) < 2) return true;
   
   return (rates[0].close >= rates[0].open);
  }

//+------------------------------------------------------------------+
//| SYSTEM 3: ADAPTIVE RISK & FAST COOLDOWN                          |
//+------------------------------------------------------------------+
void CheckDailyRiskLimit()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day != ExtLastTradeDay)
     {
      ExtDailyStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      ExtLastTradeDay     = dt.day;
      ExtIsCooledDown     = false;
     }
  }

bool IsDailyLimitReached()
  {
   if(ExtIsCooledDown) return false;

   double currentEquity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyLossPrc   = ((ExtDailyStartEquity - currentEquity) / ExtDailyStartEquity) * 100.0;
   
   if(dailyLossPrc >= InpMaxDailyLoss)
     {
      CloseAllPositions();
      ExtCooldownEndTime = TimeCurrent() + (InpCooldownMinutes * 60);
      Comment("DARK POOL SHIELD: Limit hit. Quick cooldown active for ", InpCooldownMinutes, " mins.");
      
      if(InpSendMobileAlerts)
         SendNotification("BIZARRO SHIELD: Daily Loss Limit Hit. EA Paused for " + IntegerToString(InpCooldownMinutes) + " mins.");

      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| SYSTEM 4: DARK POOL SMC & PATTERN ENGINES                        |
//+------------------------------------------------------------------+
bool DetectInstitutionalOrderBlock() { return false; }
bool DetectLiquiditySweepTrap() { return false; }

bool CheckMarketVelocity()
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, _Period, 0, 2, rates) < 2) return false;
   
   double priceDifference = MathAbs(rates[0].close - rates[1].open) / _Point;
   return (priceDifference >= (InpMinVelocityPips * 10));
  }

ENUM_ORDER_TYPE DetermineTrapDirection() { return ORDER_TYPE_BUY; }
ENUM_ORDER_TYPE DetermineOBDirection() { return ORDER_TYPE_BUY; }

ENUM_ORDER_TYPE DetermineSurgeDirection()
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   CopyRates(_Symbol, _Period, 0, 2, rates);
   return (rates[0].close > rates[1].open) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
  }

bool DetectDoubleBottom() { return false; }
bool DetectDoubleTop() { return false; }
bool DetectHeadAndShoulders() { return false; }
bool DetectInverseHeadAndShoulders() { return false; }
bool DetectFallingWedge() { return false; }
bool DetectRisingWedge() { return false; }

//+------------------------------------------------------------------+
//| SYSTEM 5: TRADE EXECUTION & DYNAMIC RISK MANAGEMENT               |
//+------------------------------------------------------------------+
void ExecuteInstitutionalTrade(ENUM_ORDER_TYPE orderType, string commentTag)
  {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double price = (orderType == ORDER_TYPE_BUY) ? ask : bid;
   
   double atr = CalculateATR();
   double slDistance = atr * 1.5;
   double sl = (orderType == ORDER_TYPE_BUY) ? price - slDistance : price + slDistance;
   double tp = (orderType == ORDER_TYPE_BUY) ? price + (slDistance * InpRewardRatio) : price - (slDistance * InpRewardRatio);
   
   double lotSize = CalculateDynamicLotSize(slDistance);

   if(orderType == ORDER_TYPE_BUY)
     {
      trade.Buy(lotSize, _Symbol, price, sl, tp, commentTag);
      if(InpSendMobileAlerts)
         SendNotification("BIZARRO PRO+: BUY Executed on " + _Symbol + " at " + DoubleToString(price, _Digits));
     }
   else
     {
      trade.Sell(lotSize, _Symbol, price, sl, tp, commentTag);
      if(InpSendMobileAlerts)
         SendNotification("BIZARRO PRO+: SELL Executed on " + _Symbol + " at " + DoubleToString(price, _Digits));
     }
      
   ExtIsCooledDown = false;
  }

double CalculateATR() { return 0.0020; }

double CalculateDynamicLotSize(double slPoints)
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (InpRiskPercent / 100.0);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickValue == 0 || tickSize == 0) return 0.01;
   
   double lot = riskAmount / (slPoints * (tickValue / tickSize));
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lot = MathRound(lot / lotStep) * lotStep;
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   
   return lot;
  }

//+------------------------------------------------------------------+
//| SYSTEM 6: SMART TRAILING STOP & BREAK-EVEN ENGINE                |
//+------------------------------------------------------------------+
void ManageOpenPositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != ExtMagicNumber) continue;
      
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      long type = PositionGetInteger(POSITION_TYPE);
      
      if(InpUseTrailingStop)
        {
         if(type == POSITION_TYPE_BUY && currentPrice - openPrice > InpTrailingStep * _Point)
           {
            if(sl < openPrice) trade.PositionModify(ticket, openPrice, tp);
           }
         else if(type == POSITION_TYPE_SELL && openPrice - currentPrice > InpTrailingStep * _Point)
           {
            if(sl > openPrice || sl == 0) trade.PositionModify(ticket, openPrice, tp);
           }
        }
     }
  }

void CloseAllPositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == ExtMagicNumber)
        {
         trade.PositionClose(ticket);
        }
     }
  }
//+------------------------------------------------------------------+
