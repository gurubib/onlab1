//+------------------------------------------------------------------+
//|                                                 TrailingStop.mqh |
//|                                          Copyright 2020, gurubib |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, gurubib"

#include <Trade\Trade.mqh>

class TrailingStop
{
   protected:
      CTrade trade;
      string symbol;
      ENUM_TIMEFRAMES timeframe;
      bool eachTick;                         //work on each tick
      bool hasIndicator;                     //show indicator
      int shift;                             //bar shift
      int indicatorHandle;                   //indicator handle
      datetime lastExecTime;                 //last execution of trailing stop
      int digits;
      double point;
      string typeName;                       //name of trailing stop type

   public:
   
      virtual bool Refresh() = 0;            // Refresh indicator
      virtual int GetTrend() = 0;            // Trend shown by indicator
      virtual double GetBuyStopLoss() = 0;   // Stop Loss value for the Buy position
      virtual double GetSellStopLoss() = 0;  // Stop Loss value for the Sell position

      void Init(string _symbol,
                ENUM_TIMEFRAMES  _timeframe,
                bool _eachTick = true,
                bool _hasIndicator = false)
                {
                  symbol = _symbol;
                  timeframe = _timeframe;
                  eachTick = _eachTick;
                  
                  if (eachTick)
                  {
                     shift = 0;  //create bars in per tick mode
                  }
                  else
                  {
                     shift = 1;  //create bars in per bar mode
                  }
                  
                  hasIndicator = _hasIndicator;
                  
                  digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
                  point = SymbolInfoDouble(symbol, SYMBOL_POINT);
               }
               
               bool StartTimer()
               {
                  return EventSetTimer(1);
               };
               
               void StopTimer()
               {
                  EventKillTimer();
               };
               
               void Deinit()
               {
                  StopTimer();
                  IndicatorRelease(indicatorHandle);
               };
               
               bool DoStopLoss()
               {  
                  datetime tm[1];
                  tm[0] = TimeCurrent();               
                  if(!eachTick)
                  {
                     if(CopyTime(symbol, timeframe, 0, 1, tm) == -1)
                     {
                        return false;
                     }
                     
                     if(tm[0] == lastExecTime)
                     {
                        return true;
                     }
                  }
                  
                  if(!Refresh())
                  {
                     return false;
                  }
                  
                  double sl;
               
                  switch (GetTrend())
                  {
                     case 1: 
                     {
                        int totalNumOfPositions = PositionsTotal();
                        if (totalNumOfPositions != 0 && PositionSelect(symbol))
                        {
                           if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                           {
                              sl = GetBuyStopLoss();
                              double minimal = SymbolInfoDouble(symbol, SYMBOL_BID) - point * SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
                              sl = NormalizeDouble(sl, digits);
                              minimal = NormalizeDouble(minimal, digits);
                              sl = MathMin(sl,minimal);
                           
                              double positionSl = PositionGetDouble(POSITION_SL);
                              positionSl = NormalizeDouble(positionSl, digits);

                              if (sl > positionSl)
                              {
                                 printf("");
                     
         								if(!trade.PositionModify(symbol, sl, PositionGetDouble(POSITION_TP)) || trade.ResultRetcode() != TRADE_RETCODE_DONE)
         								{
         								   printf("Unable to move Stop Loss of position %s, error #%I64u", symbol, trade.ResultRetcode());
         									return false;
         								}
         								else
         								{
         								   printf("Successful stop loss modification!");
         								}
                              }
                           }
                        }
                     }
                     break;
                     
                     case -1:
                     {
                        int totalNumOfPositions = PositionsTotal();
                        if (totalNumOfPositions != 0 && PositionSelect(symbol))
                        {
                           if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                           {
                              sl = GetSellStopLoss();
                              sl = NormalizeDouble(sl, digits);
                              double spread = SymbolInfoDouble(symbol, SYMBOL_ASK) - SymbolInfoDouble(symbol, SYMBOL_BID);
                              double minimal = SymbolInfoDouble(symbol, SYMBOL_ASK) + point * SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
                              minimal = NormalizeDouble(minimal, digits);
                              
                              sl = MathMax(sl, minimal);
                              double positionSl = PositionGetDouble(POSITION_SL);
                              positionSl = NormalizeDouble(positionSl, digits);
                              
                              if (sl < positionSl || positionSl == 0)
                              {
                                 if (!trade.PositionModify(symbol, sl, PositionGetDouble(POSITION_TP)) || trade.ResultRetcode() != TRADE_RETCODE_DONE)
                                 {
                                    printf("Unable to move Stop Loss of position %s, error #%I64u", symbol, trade.ResultRetcode());
            								return false;
                                 }
                                 else
                                 {
                                    printf("Successful stop loss modification!");
                                 }
                              }
                           }                            
                        }
                     }
                     break;
                  }
				 
                  lastExecTime = tm[0];
                  return true;
              }               
              
};

class ParabolicTrailingStop : public TrailingStop
{
   double priceBuf[1];
   double indBuf[1];

   public:
   
      ParabolicTrailingStop(CTrade& _trade)
      {
         trade = _trade;
         typeName = "SAR";  
      }
      
      virtual bool SetParameters(double sarStep = 0.02, double sarMax = 0.2)
      {
         indicatorHandle = iSAR(symbol, timeframe, sarStep, sarMax);
         
         if (indicatorHandle == -1)
         {
            return false;
         }
         
         if (hasIndicator)    //has -> show
         {
            ChartIndicatorAdd(0, 0, indicatorHandle);
         }
         
         return true;
      }
      
      virtual bool Refresh()
      {
         if (CopyBuffer(indicatorHandle, 0, shift, 1, indBuf) == -1)
         {
            return false;
         }
         
         if (CopyClose(symbol, timeframe, shift, 1, priceBuf) == -1)
         {
            return false;
         }
         
         return true;
      }
      
      virtual int GetTrend()
      {
         if (priceBuf[0] > indBuf[0])
         {
            return 1;
         }
         else
         {
            return -1;
         }
      }
      
      virtual double GetBuyStopLoss()
      {
         return indBuf[0];
      }
      
      virtual double GetSellStopLoss()
      {
         return indBuf[0];
      }
      
};

class NRTRTrailingStop : public TrailingStop
{
   double supBuf[1];
   double resBuf[1];

   public:
   
      NRTRTrailingStop(CTrade& _trade)
      {
         trade = _trade;
         typeName = "NRTR";  
      }
      
      virtual bool SetParameters(int period, double k)
      {
         indicatorHandle = iCustom(symbol, timeframe, "NRTR", period, k);
         
         if (indicatorHandle == -1)
         {
            return false;
         }
         
         if (hasIndicator)    //has -> show
         {
            ChartIndicatorAdd(0, 0, indicatorHandle);
         }
         
         return true;
      }
      
      virtual bool Refresh()
      {
         if (CopyBuffer(indicatorHandle, 0, shift, 1, supBuf) == -1)
         {
            return false;
         }
         
         if (CopyBuffer(indicatorHandle, 1, shift, 1, resBuf) == -1)
         {
            return false;
         }
         
         return true;
      }
      
      virtual int GetTrend()
      {
         if (supBuf[0] != 0)
         {
            return 1;
         }
         else if (resBuf[0] != 0)
         {
            return -1;
         }
         else
         {
            return 0;
         }
      }
      
      virtual double GetBuyStopLoss()
      {
         return supBuf[0];
      }
      
      virtual double GetSellStopLoss()
      {
         return resBuf[0];
      }
      
};