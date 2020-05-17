//+------------------------------------------------------------------+
//|                                                 SimpleSystem.mq5 |
//|                                          Copyright 2020, gurubib |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, gurubib"
#property link      ""
#property version   "1.00"

#include <Trade\Trade.mqh>

CTrade trade;

input int startHour = 9;
input int lossInPips = 20;
input int profitInPips = 40;
input double volumeInLots = 1.0;

void OnTick()
{   
   static bool isFirstTick = true;
   static int ticket = 0;

   MqlDateTime currentTime;
   TimeToStruct(TimeCurrent(), currentTime);
   
   if(currentTime.hour == startHour)
   {
      if(isFirstTick == true)
      {
         isFirstTick = false;
         
         CloseAllPositions();
         
         double openAtStart = iOpen(Symbol(), Period(), startHour);
         double lastOpen = iOpen(Symbol(), Period(), 0);
                  
         if(lastOpen < openAtStart)
         {
            Buy();
         }
         else if (lastOpen > openAtStart)
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
      double askPrice = GetAskPrice();
      double bidPrice = GetBidPrice();
      double lossLevel = lossInPips * PipPoint();
      double profitLevel = profitInPips * PipPoint();
      
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
      double bidPrice = GetBidPrice();
      double askPrice = GetAskPrice();
      double lossLevel = lossInPips * PipPoint();
      double profitLevel = profitInPips * PipPoint();
      
      double sl = NormalizeDouble(askPrice + lossLevel, Digits());
      double tp = NormalizeDouble(askPrice - profitLevel, Digits());
      
      trade.Sell(volumeInLots, Symbol(), bidPrice, sl, tp);
   }
   else
   {
      Print("Cannot open sell position! Not enough equity!");
   }
   
}

void CloseAllPositions()
{
   for (int i = PositionsTotal(); i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      trade.PositionClose(ticket);
   }
}

double GetAskPrice()
{
   return NormalizeDouble(SymbolInfoDouble(Symbol(), SYMBOL_ASK), Digits());
}

double GetBidPrice()
{
   return NormalizeDouble(SymbolInfoDouble(Symbol(), SYMBOL_BID), Digits());
}

double PipPoint()
{
   return Point() * 10;
}
