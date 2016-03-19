//+------------------------------------------------------------------+
//+                           Code generated using FxPro Quant 2.1.4 by Toti Cavalcanti |
//+------------------------------------------------------------------+
#property strict

#define __STRATEGY_MAGIC 1001000000
#define __SLEEP_AFTER_EXECUTION_FAIL 400

//Input variables
input double _RISK_PER_TRADE = 5;			// RISK PER TRADE
input double _STOP_LOSS = 50;			// STOP LOSS
input int _TAKE_PROFIT = 0;			// TAKE PROFIT
input int _SLIPPAGE = 3;			// SLIPPAGE
input double _EMA_PERIOD = 3;			// EMA PERIOD

//Global declaration
double _EMA_PRESENTE;
double _MACD_PRESENTE;
double _RCI_PRESENTE;
bool _AND;

int init() {

   return(0);
}

int start() {

   
   //Local declaration
   bool _Buy_with_MM = false;
   _EMA_PRESENTE = iMA(Symbol(), 0, _EMA_PERIOD, 0, 1, 0, 0);
   _MACD_PRESENTE = iMACD(Symbol(), 0, 12, 26, 9, 0, 0, 0);
   _RCI_PRESENTE = iRSI(Symbol(), 0, 14, 0, 0);
   _AND = (((_RCI_PRESENTE > 50) && 
   (_RCI_PRESENTE > iRSI(Symbol(), 0, 14, 0, 1))) && 
   ((_MACD_PRESENTE > 0) && 
   (_MACD_PRESENTE > iMACD(Symbol(), 0, 12, 26, 9, 0, 0, 1))) && 
   ((_EMA_PRESENTE > iBands(Symbol(), 0, 21, 3, 0, 0, 1, 0)) && 
   (_EMA_PRESENTE > iMA(Symbol(), 0, _EMA_PERIOD, 1, 0, 0, 0))));
   if( _AND ) _Buy_with_MM = Buy_with_MM(1, 1, _STOP_LOSS, 1, _TAKE_PROFIT, _SLIPPAGE, _RISK_PER_TRADE, _RISK_PER_TRADE, _RISK_PER_TRADE, "");

   return(0);
}

bool Buy_with_MM (int MagicIndex, int StopLossMethod, double StopLossPoints, int TakeProfitMethod, double TakeProfitPoints, int Slippage,
                  double RiskPerTrade, double RiskPerMagic, double RiskPerAccount, string TradeComment)
{   
   static double pipSize = 0;   
   if(pipSize == 0) pipSize = Point * (1 + 9 * (Digits == 3 || Digits == 5));
   
   double sl = 0, tp = 0;  
   double stopLossPoints = 0, takeProfitPoints = 0;
   
   if (StopLossPoints > 0)
   {
      if(StopLossMethod == 0)
      {
         sl = NormalizeDouble(Ask - StopLossPoints * Point, Digits);
         stopLossPoints = StopLossPoints;
      }
      else if (StopLossMethod == 1)
      {
         sl = NormalizeDouble(Ask - StopLossPoints * pipSize, Digits);
         stopLossPoints = StopLossPoints * (1 + 9 * (Digits == 3 || Digits == 5));
      }
      else
      {
         sl  = StopLossPoints;
         stopLossPoints = (Ask - sl)/Point; 
      }
   }
   
   if (TakeProfitPoints > 0)
   {
      if(TakeProfitMethod == 0)
      {
         tp = NormalizeDouble(Ask + TakeProfitPoints * Point, Digits);
         takeProfitPoints = TakeProfitPoints;
      }
      else if (TakeProfitMethod == 1)
      {
         tp = NormalizeDouble(Ask + TakeProfitPoints * pipSize, Digits);
         takeProfitPoints = TakeProfitPoints * (1 + 9 * (Digits == 3 || Digits == 5));
      }
      else
      {
         tp = TakeProfitPoints;
         takeProfitPoints = (tp - Ask)/Point; 
      }
   }  
   
   double stopLevel = MarketInfo(Symbol(),MODE_STOPLEVEL) + MarketInfo(Symbol(),MODE_SPREAD);
   
   if( (sl > 0 && stopLossPoints <= stopLevel) || (tp > 0 && takeProfitPoints <= stopLevel) )
   {
      Print("Cannot Buy: Stop loss and take profit must be at least " 
      + DoubleToStr(MarketInfo(Symbol(),MODE_STOPLEVEL) + MarketInfo(Symbol(),MODE_SPREAD),0) 
      + " points away from the current price");
      return (false);
   } 
   
   double exposureForAccount;   
   double exposureForMagic;  
   int total = OrdersTotal();  
   double valueAtRiskForMagic = 0, valueAtRiskForAccount = 0;
   int cmd;
   int slPoints;
   double tickValue;
   
   for(int i=total-1;i>=0;i--){
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;      
      cmd = OrderType();
      if(cmd > 1) continue;      
      
      tickValue = MarketInfo(OrderSymbol(),MODE_TICKVALUE);
         
      if(cmd == OP_BUY)
         slPoints = (int)MathRound((OrderOpenPrice() - OrderStopLoss())/MarketInfo(OrderSymbol(),MODE_POINT));     
      else
         slPoints = (int)MathRound((OrderStopLoss() - OrderOpenPrice())/MarketInfo(OrderSymbol(),MODE_POINT));    
      
      if(OrderStopLoss() == 0)valueAtRiskForAccount = 100.00;	 
      else valueAtRiskForAccount += slPoints*tickValue*OrderLots();  

      if(OrderMagicNumber() != __STRATEGY_MAGIC + MagicIndex && OrderSymbol() != Symbol()) {
         if(OrderStopLoss() == 0) valueAtRiskForMagic = 100.00;
         else valueAtRiskForMagic += slPoints*tickValue*OrderLots();   
      }    
   }   
   
   exposureForAccount = NormalizeDouble(valueAtRiskForAccount/AccountBalance()*100,2);
   if(exposureForAccount < 0) exposureForAccount = 0;  
   else if (exposureForAccount > 100.00) exposureForAccount = 100;
   
   exposureForMagic = NormalizeDouble(valueAtRiskForMagic/AccountBalance()*100,2);
   if(exposureForMagic < 0) exposureForMagic = 0;   
   else if (exposureForMagic > 100.00) exposureForMagic = 100;
      
   double eaRiskAlloc = MathMin(RiskPerMagic - exposureForMagic , RiskPerAccount - exposureForAccount);
   double riskAlloc = MathMin(RiskPerTrade, eaRiskAlloc);
   tickValue = MarketInfo(Symbol(),MODE_TICKVALUE);
   double valueAllocation = AccountBalance()*riskAlloc/100;    
   double lots = NormalizeDouble(valueAllocation/stopLossPoints*tickValue, 1 + (MarketInfo(Symbol(),MODE_MINLOT) == 0.01)); 
   
   if(lots < MarketInfo(Symbol(),MODE_MINLOT)) return(false);
   
   if(AccountFreeMarginCheck(Symbol(), OP_SELL,lots) <= 0) {
      Print("Buy error: insufficient capital");
      return(false);
   }              
   
	int result = OrderSend(Symbol(), OP_BUY, lots, MarketInfo(Symbol(), MODE_ASK), Slippage, sl, tp, "FxProQuant" + "(" + WindowExpertName() + ") " + TradeComment,__STRATEGY_MAGIC + MagicIndex);

	if (result == -1){
		printf("Failed to Buy, error code: %i", GetLastError());
		Sleep(__SLEEP_AFTER_EXECUTION_FAIL);
	   return(false); 
	}

   return(true);
}
