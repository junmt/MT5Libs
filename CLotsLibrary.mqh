//+------------------------------------------------------------------+
//|                                                 CLotsLibrary.mq5 |
//|                                            Copyright 2024, junmt |
//|                                   https://twitter.com/SakenomiFX |
//+------------------------------------------------------------------+
#include <Expert\Money\MoneyFixedMargin.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\Trade.mqh>

class CLotsLibrary
{
private:
    //--- class variables
    bool is_autolots;
    double fixed_lots;
    CMoneyFixedMargin m_money;
    CTrade m_trade;
    CSymbolInfo m_symbol;

public:
    //--- constructor
    CLotsLibrary(void)
    {
    }

    void init(bool isAutoLots, double fixedLots, CMoneyFixedMargin &money, CTrade &trade, CSymbolInfo &symbol)
    {
        is_autolots = isAutoLots;
        fixed_lots = fixedLots;
        m_money = money;
        m_trade = trade;
        m_symbol = symbol;
    }

    //--- LOT function
    double LOT()
    {
        double lots = 0.0;
        if (is_autolots)
        {
            lots = 0.0;
            double sl = 0.0;
            double check_open_long_lot = m_money.CheckOpenLong(m_symbol.Ask(), sl);

            if (check_open_long_lot == 0.0)
                return (0.0);

            double chek_volime_lot =
                m_trade.CheckVolume(m_symbol.Name(), check_open_long_lot,
                                    m_symbol.Ask(), ORDER_TYPE_BUY);

            if (chek_volime_lot != 0.0)
                if (chek_volime_lot >= check_open_long_lot)
                    lots = check_open_long_lot;
        }
        else
            lots = fixed_lots;

        return (LotCheck(lots));
    }

    //--- LotCheck function
    double LotCheck(double lots)
    {
        double volume = NormalizeDouble(lots, 2);
        double stepvol = m_symbol.LotsStep();
        if (stepvol > 0.0)
            volume = stepvol * MathFloor(volume / stepvol);

        double minvol = m_symbol.LotsMin();
        if (volume < minvol)
            volume = 0.0;

        double maxvol = m_symbol.LotsMax();
        if (volume > maxvol)
            volume = maxvol;

        return (volume);
    }
};
