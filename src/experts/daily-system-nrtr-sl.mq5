//+------------------------------------------------------------------+
//|                                                 SimpleSystem.mq5 |
//|                                          Copyright 2020, gurubib |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, gurubib"
#property link      ""
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <TrailingStop.mqh>

CTrade trade;

input int startHour = 9;
input int lossInPips = 20;
input int profitInPips = 40;
input double volumeInLots = 1.0;

NRTRTrailingStop trailingStop(trade);

input int trailingNRTRPeriod = 58;
input double trailingNRTRK =  2;

int OnInit()
{
   trailingStop.Init(Symbol(), Period(), true, true);
   
   if (!trailingStop.SetParameters(trailingNRTRPeriod, trailingNRTRK))
   {
      Alert("Error during trailing stop setup!");
      return -1;
   }
   
   trailingStop.StartTimer();
   
   return(INIT_SUCCEEDED);
}

void OnTimer()
{
   trailingStop.Refresh();
}

void OnTick()
{
   trailingStop.DoStopLoss();
   
   static bool isFirstTick = true;
   static int ticket = 0;

   MqlDateTime currentTime;
   TimeToStruct(TimeCurrent(), currentTime);
   
   if(currentTime.hour == startHour)
   {
      if(isFirstTick == true)
      {
         isFirstTick = false;
         
         closeAllPositions();
         
         double openAtStart = iOpen(Symbol(), Period(), startHour);
         double lastOpen = iOpen(Symbol(), Period(), 0);
         
         string signal = getNRTRSignal();
         
         if(lastOpen < openAtStart && signal == "BUY")
         {
            Buy();
         }
         else if (lastOpen > openAtStart && signal == "SELL")
         {
            Sell();
         }
      }    
   }
   else
   {
      isFirstTick = true;
   }
}

void Buy()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   if (equity >= balance)
   {
      double askPrice = getAskPrice();
      double bidPrice = getBidPrice();
      double lossLevel = lossInPips * pipPoint();
      double profitLevel = profitInPips * pipPoint();
      
      double sl = NormalizeDouble(bidPrice - lossLevel, Digits());
      double tp = NormalizeDouble(bidPrice + profitLevel, Digits());
      
      trade.Buy(volumeInLots, Symbol(), askPrice, sl, tp);
   }
   else
   {
      Print("Cannot open buy position! Not enough equity!");
   }
}

void Sell()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   if (equity >= balance)
   {
      double bidPrice = getBidPrice();
      double askPrice = getAskPrice();
      double lossLevel = lossInPips * pipPoint();
      double profitLevel = profitInPips * pipPoint();
      
      double sl = NormalizeDouble(askPrice + lossLevel, Digits());
      double tp = NormalizeDouble(askPrice - profitLevel, Digits());
      
      trade.Sell(volumeInLots, Symbol(), bidPrice, sl, tp);
   }
   else
   {
      Print("Cannot open sell position! Not enough equity!");
   }
   
}

void closeAllPositions()
{
   for (int i = PositionsTotal(); i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      trade.PositionClose(ticket);
   }
}

double getAskPrice()
{
   return NormalizeDouble(SymbolInfoDouble(Symbol(), SYMBOL_ASK), Digits());
}

double getBidPrice()
{
   return NormalizeDouble(SymbolInfoDouble(Symbol(), SYMBOL_BID), Digits());
}

double pipPoint()
{
   return Point() * 10;
}

string getNRTRSignal()
{
   int NRTRHandle = iCustom(Symbol(), Period(), "NRTR", trailingNRTRPeriod, trailingNRTRK);

   double supBuf[1];
   double resBuf[1];
   
   CopyBuffer(NRTRHandle, 0, 0, 1, supBuf);
   CopyBuffer(NRTRHandle, 1, 0, 1, resBuf);
   
   if (supBuf[0] != 0)
   {
      return "BUY";
   }
   else if (resBuf[0] != 0)
   {
      return "SELL";
   }
   else
   {
      return "NONE";
   }
   
}
