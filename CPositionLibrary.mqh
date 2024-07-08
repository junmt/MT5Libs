//+------------------------------------------------------------------+
//|                                             CPositionLibrary.mq5 |
//|                                            Copyright 2024, junmt |
//|                                   https://twitter.com/SakenomiFX |
//+------------------------------------------------------------------+
#include <Expert\Money\MoneyFixedMargin.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\Trade.mqh>

class CPositionLibrary
{
private:
    //--- class variables
    CTrade m_trade;
    CPositionInfo m_position;
    CSymbolInfo m_symbol;

public:
    ulong magic;                         // マジックナンバー
    double lots;                         // エントリー時のロット数
    double lotRatio;                     // ロット数の比率（自動ナンピン時）
    double profit;                       // プロフィットの価格差（pips）
    double stoploss;                     // ストップロスの価格差（pips）
    double trailing_stop;                // トレイリングストップの価格差（≠pips）
    double breakeven;                    // ブレイクイーブンの価格差（pips）
    double distance;                     // ポジション追加の条件となる価格差（pips）
    ulong slippage;                      // スリッページ(pips)
    double adjusted_point;               // pipsから価格差の調整値（pipsから価格を求める時に使う）
    int digits_adjust;                   // 価格差の調整値
    string trade_comment;                // トレードコメント
    bool is_manual_orders_and_positions; // マニュアルオーダーとポジションも操作するか
    int max_manual_position;             // 有利なポジションを残す数

    //--- constructor
    CPositionLibrary(void)
    {
    }

    void Init(CSymbolInfo &symbol, CTrade &trade, CPositionInfo &position)
    {
        m_symbol = symbol;
        m_trade = trade;
        m_position = position;

        magic = 0;
        lots = 0.01;
        lotRatio = 1.0;
        profit = 0.0;
        stoploss = 0.0;
        trailing_stop = 0.0;
        breakeven = 0.0;
        distance = 0.0;
        slippage = 3.0;
        trade_comment = "";
        is_manual_orders_and_positions = false;
        max_manual_position = 1;

        digits_adjust = 10;
        if (m_symbol.Digits() == 3 || m_symbol.Digits() == 5)
            digits_adjust = 100;
        double point = m_symbol.Point();
        adjusted_point = point * digits_adjust;
    }

    //--- TakeProfit function
    void TakeProfitAll()
    {
        // プロフィットをとる
        if (profit > 0)
        {
            for (int i = 0; i < PositionsTotal(); i++)
            {
                m_position.SelectByIndex(i);
                if (m_position.Symbol() != Symbol() ||
                    (m_position.Magic() != magic && !is_manual_orders_and_positions))
                {
                    continue;
                }
                double profitVol = 0.0;
                if (m_position.PositionType() == POSITION_TYPE_BUY)
                {
                    profitVol = m_position.PriceCurrent() - m_position.PriceOpen();
                }
                else
                {
                    profitVol = m_position.PriceOpen() - m_position.PriceCurrent();
                }
                if (profitVol >= profit * adjusted_point)
                {
                    m_trade.PositionClose(m_position.Ticket());
                }
            }
        }
    }

    //--- StopLoss function
    void StopLossAll()
    {
        if (stoploss > 0)
        {
            for (int i = 0; i < PositionsTotal(); i++)
            {
                m_position.SelectByIndex(i);
                if (m_position.Symbol() != Symbol() ||
                    (m_position.Magic() != magic && !is_manual_orders_and_positions))
                {
                    continue;
                }
                double profitVol = 0.0;
                if (m_position.PositionType() == POSITION_TYPE_BUY)
                {
                    profitVol = m_position.PriceCurrent() - m_position.PriceOpen();
                }
                else
                {
                    profitVol = m_position.PriceOpen() - m_position.PriceCurrent();
                }
                if (profitVol <= stoploss * adjusted_point)
                {
                    m_trade.PositionClose(m_position.Ticket());
                }
            }
        }
    }

    //-- TrailingStop function
    void TrailingStop()
    {
        if (trailing_stop <= 0)
        {
            return;
        }

        for (int i = 0; i < PositionsTotal(); i++)
        {
            m_position.SelectByIndex(i);

            if (m_position.Symbol() != m_symbol.Name() ||
                (m_position.Magic() != magic && !is_manual_orders_and_positions))
            {
                continue;
            }

            double currentPrice = m_position.PriceCurrent();
            double openPrice = m_position.PriceOpen();
            double slPrice = m_position.StopLoss();
            double profitVol = 0.0;
            double sl = 0.0;
            int step = -1;

            if (m_position.PositionType() == POSITION_TYPE_BUY)
            {
                profitVol = currentPrice - openPrice;
                step = (int)(profitVol / trailing_stop * adjusted_point) - 1;
                sl = NormalizeDouble(openPrice + step * trailing_stop + 3 * adjusted_point,
                                     m_symbol.Digits());
            }
            if (m_position.PositionType() == POSITION_TYPE_SELL)
            {
                profitVol = openPrice - currentPrice;
                step = (int)(profitVol / trailing_stop * adjusted_point) - 1;
                sl = NormalizeDouble(openPrice - step * trailing_stop - 3 * adjusted_point,
                                     m_symbol.Digits());
            }

            if (profitVol < 0 || step < 0 || profitVol <= trailing_stop * adjusted_point)
            {
                continue;
            }

            if (sl != slPrice)
            {
                m_trade.PositionModify(m_position.Ticket(), sl,
                                       m_position.TakeProfit());
            }
        }
    }

    void GetPositionWithMaxProfit(ulong &tickets[], int positionType)
    {
        double positionPrice[];
        int priceCounter = 0;
        int counter = 0;

        ArrayResize(positionPrice, GetPositionCount(positionType));

        for (int i = 0; i < PositionsTotal(); i++)
        {
            m_position.SelectByIndex(i);
            if (m_position.Symbol() != Symbol() || (m_position.Magic() != magic && !is_manual_orders_and_positions))
            {
                continue;
            }
            if (m_position.PositionType() == positionType)
            {
                positionPrice[priceCounter] = m_position.PriceOpen();
                priceCounter++;
            }
        }

        // 価格を昇順にソート
        ArraySort(positionPrice);
        if (positionType == POSITION_TYPE_SELL)
        {
            ArrayReverse(positionPrice);
        }

        for (int i = 0; i < PositionsTotal(); i++)
        {
            m_position.SelectByIndex(i);
            if (m_position.Symbol() != Symbol() || (m_position.Magic() != magic && !is_manual_orders_and_positions))
            {
                continue;
            }
            double price = m_position.PriceOpen();
            for (int j = 0; j < max_manual_position; j++)
            {
                if (positionPrice[j] == price)
                {
                    tickets[counter] = m_position.Ticket();
                    counter++;
                    break;
                }
            }
            if (counter == max_manual_position)
            {
                break;
            }
        }
    }

    void GetPositionWithMaxLoss(ulong &tickets[], int positionType)
    {
        double positionPrice[];
        int priceCounter = 0;
        int counter = 0;

        ArrayResize(positionPrice, GetPositionCount(positionType));

        for (int i = 0; i < PositionsTotal(); i++)
        {
            m_position.SelectByIndex(i);
            if (m_position.Symbol() != Symbol() || (m_position.Magic() != magic && !is_manual_orders_and_positions))
            {
                continue;
            }
            if (m_position.PositionType() == positionType)
            {
                positionPrice[priceCounter] = m_position.PriceOpen();
                priceCounter++;
            }
        }

        // 価格を昇順にソート
        ArraySort(positionPrice);
        if (positionType == POSITION_TYPE_BUY)
        {
            ArrayReverse(positionPrice);
        }

        for (int i = 0; i < PositionsTotal(); i++)
        {
            m_position.SelectByIndex(i);
            if (m_position.Symbol() != Symbol() || (m_position.Magic() != magic && !is_manual_orders_and_positions))
            {
                continue;
            }
            double price = m_position.PriceOpen();
            for (int j = 0; j < max_manual_position; j++)
            {
                if (positionPrice[j] == price)
                {
                    tickets[counter] = m_position.Ticket();
                    counter++;
                    break;
                }
            }
            if (counter == max_manual_position)
            {
                break;
            }
        }
    }
    //+------------------------------------------------------------------+
    //| 現在のポジション数を返す                                        |
    //+------------------------------------------------------------------+
    int GetPositionCount(int positionType)
    {
        int positionCount = 0;
        for (int i = 0; i < PositionsTotal(); i++)
        {
            m_position.SelectByIndex(i);
            if (m_position.Symbol() != Symbol() || (m_position.Magic() != magic && !is_manual_orders_and_positions))
            {
                continue;
            }
            if (m_position.PositionType() == positionType)
            {
                positionCount++;
            }
        }
        return positionCount;
    }
    //+------------------------------------------------------------------+
    //| ポジションが２個以上になった場合、不利なポジションに3pipsのTPを設定する|
    //+------------------------------------------------------------------+
    void SetPositionTakeProfit(int positionType)
    {
        ulong tickets[];
        ArrayResize(tickets, max_manual_position);

        int buyPositionCount = GetPositionCount(positionType);
        if (buyPositionCount >= 2)
        {
            GetPositionWithMaxProfit(tickets, positionType);
            for (int i = 0; i < PositionsTotal(); i++)
            {
                m_position.SelectByIndex(i);
                if (m_position.Symbol() != Symbol() ||
                    (m_position.Magic() != magic && !is_manual_orders_and_positions))
                {
                    continue;
                }
                if (m_position.TakeProfit() > 0.0)
                {
                    continue;
                }

                bool isExist = false;
                for (int j = 0; j < ArraySize(tickets); j++)
                {
                    if (tickets[j] == m_position.Ticket())
                    {
                        isExist = true;
                        break;
                    }
                }
                if (m_position.PositionType() == positionType &&
                    !isExist)
                {
                    double profitVol = m_position.Profit();
                    if (profitVol < 0)
                    {
                        double tp = 0.0;
                        if (positionType == POSITION_TYPE_BUY)
                        {
                            tp = NormalizeDouble(
                                m_position.PriceOpen() + breakeven * adjusted_point,
                                m_symbol.Digits());
                        }
                        else if (positionType == POSITION_TYPE_SELL)
                        {
                            tp = NormalizeDouble(
                                m_position.PriceOpen() - breakeven * adjusted_point,
                                m_symbol.Digits());
                        }
                        m_trade.PositionModify(m_position.Ticket(),
                                               m_position.StopLoss(), tp);
                    }
                }
            }
        }
    }
    //+------------------------------------------------------------------+
    //| 現在の最も有利なポジションと比較してdistance以上のマイナスpipsの場合は追加エントリーを行う|
    //+------------------------------------------------------------------+
    void AutoAddPosition(int positionType)
    {
        m_symbol.RefreshRates();
        int positionCount = GetPositionCount(positionType);
        if (positionCount == 0)
        {
            Print("No position found, not add order.");
            return;
        }

        ulong tickets[];
        ArrayResize(tickets, max_manual_position);

        GetPositionWithMaxProfit(tickets, positionType);

        ulong profitTicket = 0;
        double profitVol = 0.0;
        for (int i = 0; i < ArraySize(tickets); i++)
        {
            m_position.SelectByTicket(tickets[i]);
            if (m_position.Profit() > profitVol || profitTicket == 0)
            {
                profitVol = m_position.Profit();
                profitTicket = m_position.Ticket();
            }
        }

        // profitTicketが0の場合はポジションがないため追加エントリーを行わない
        if (profitTicket == 0)
        {
            Print("No profit ticket found, not add order.");
            return;
        }

        m_position.SelectByTicket(profitTicket);
        double openPrice = m_position.PriceOpen();
        double currentPrice = POSITION_TYPE_BUY ? m_symbol.Ask() : m_symbol.Bid();
        double distancePips = (openPrice - currentPrice) / adjusted_point;

        if (positionType == POSITION_TYPE_SELL)
        {
            distancePips = (currentPrice - openPrice) / adjusted_point;
        }

        Print("distancePips: ", distancePips);
        if (distancePips < distance)
        {
            return;
        }

        double volume = lots;
        if (volume == 0)
        {
            return;
        }

        // 最大損失のポジションからロット数を計算する
        GetPositionWithMaxLoss(tickets, positionType);
        m_position.SelectByTicket(tickets[0]);
        double currentLots = m_position.Volume();
        volume = currentLots * MathPow(lotRatio, positionCount);

        MqlTradeRequest request;
        MqlTradeResult result;
        ZeroMemory(request);

        request.action = TRADE_ACTION_DEAL;
        request.symbol = Symbol();
        request.volume = volume;
        request.type = positionType;
        request.price = positionType == POSITION_TYPE_BUY ? m_symbol.Ask() : m_symbol.Bid();
        request.deviation = (ulong)(slippage * digits_adjust);
        request.magic = magic;
        request.comment = trade_comment;

        if (!OrderSend(request, result))
        {
            Print("Order added successfully. Price: ", positionType == POSITION_TYPE_BUY ? m_symbol.Ask() : m_symbol.Bid());
        }
        else
        {
            Print("Failed to add order. Price: ", positionType == POSITION_TYPE_BUY ? m_symbol.Ask() : m_symbol.Bid(),
                  " Error: ", GetLastError());
        }
    }

    //+------------------------------------------------------------------+
    // 一括で最も不利なポジションを起点にしたSLを設定する
    //+------------------------------------------------------------------+
    void SetStopLoss(double slPips, int positionType)
    {
        if (slPips <= 0)
        {
            return;
        }

        double stopPrice = 0.0;
        ulong tickets[];

        ArrayResize(tickets, max_manual_position);
        GetPositionWithMaxLoss(tickets, positionType);
        m_position.SelectByTicket(tickets[0]);

        for (int i = 0; i < ArraySize(tickets); i++)
        {
            m_position.SelectByTicket(tickets[i]);
            if (m_position.StopLoss() > 0.0)
            {
                continue;
            }
            if (m_position.PositionType() == POSITION_TYPE_BUY)
            {
                stopPrice = NormalizeDouble(m_position.PriceOpen() - slPips * adjusted_point,
                                            m_symbol.Digits());
            }
            else if (m_position.PositionType() == POSITION_TYPE_SELL)
            {
                stopPrice = NormalizeDouble(m_position.PriceOpen() + slPips * adjusted_point,
                                            m_symbol.Digits());
            }
        }

        for (int i = 0; i < PositionsTotal(); i++)
        {
            m_position.SelectByIndex(i);
            if (m_position.PositionType() != positionType)
            {
                continue;
            }
            if (m_position.Symbol() != Symbol() || (m_position.Magic() != magic && !is_manual_orders_and_positions))
            {
                continue;
            }
            m_trade.PositionModify(m_position.Ticket(), stopPrice, m_position.TakeProfit());
        }
    }
};
