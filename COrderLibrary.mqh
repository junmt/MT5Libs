//+------------------------------------------------------------------+
//|                                             CPositionLibrary.mq5 |
//|                                            Copyright 2024, junmt |
//|                                   https://twitter.com/SakenomiFX |
//+------------------------------------------------------------------+
#include <Expert\Money\MoneyFixedMargin.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\Trade.mqh>

class COrderLibrary
{
private:
    //--- class variables
    CTrade m_trade;
    CPositionInfo m_position;
    CSymbolInfo m_symbol;

public:
    ulong magic;                         // マジックナンバー
    ulong slippage;                      // スリッページ(pips)
    double adjusted_point;               // pipsから価格差の調整値（pipsから価格を求める時に使う）
    int digits_adjust;                   // 価格差の調整値
    string trade_comment;                // トレードコメント
    bool is_manual_orders_and_positions; // マニュアルオーダーとポジションも操作するか

    //--- constructor
    COrderLibrary(void)
    {
    }

    void Init(CSymbolInfo &symbol, CTrade &trade, CPositionInfo &position)
    {
        m_symbol = symbol;
        m_trade = trade;
        m_position = position;

        magic = 0;
        slippage = 3.0;
        trade_comment = "";
        is_manual_orders_and_positions = false;

        digits_adjust = 10;
        if (m_symbol.Digits() == 3 || m_symbol.Digits() == 5)
            digits_adjust = 100;
        double point = m_symbol.Point();
        adjusted_point = point * digits_adjust;
    }

    //+------------------------------------------------------------------+
    //|
    // priceが現在価格よりも上であればSELL、現在価格よりも下であればBUYの指値をMaxOrdersの個数分、均等に指値を入れる
    //|
    //+------------------------------------------------------------------+
    void ZoneEntry(double startPrice, double endPrice, double lots, double lotRatio, int max_orders, double addtionalSl)
    {
        m_symbol.RefreshRates();

        double volume = lots;
        double min_price = 0.0;
        double max_price = 0.0;
        double sl = 0.0;
        double currentPrice = m_symbol.Ask();

        if (startPrice == 0.0)
        {
            return;
        }

        if (startPrice > currentPrice)
        {
            // 指値の最小priceはATR+priceとする
            max_price = NormalizeDouble(endPrice, m_symbol.Digits());
            min_price = startPrice;
            sl = NormalizeDouble(max_price + addtionalSl * adjusted_point,
                                 m_symbol.Digits());
        }
        else
        {
            // 指値の最大priceはATR+priceとする
            min_price = NormalizeDouble(endPrice, m_symbol.Digits());
            max_price = startPrice;
            sl = NormalizeDouble(min_price - addtionalSl * adjusted_point,
                                 m_symbol.Digits());
        }

        MqlTradeRequest request;
        MqlTradeResult result;
        ZeroMemory(request);

        // MaxOrdersの個数分、priceから均等に指値を入れる
        double step = (max_price - min_price) / max_orders;
        for (int i = 0; i < max_orders; i++)
        {
            double target_price = 0.0;
            double lot = NormalizeDouble(volume * MathPow(lotRatio, i), 2);

            request.action = TRADE_ACTION_PENDING;
            request.symbol = Symbol();
            request.volume = lot;
            request.deviation = (ulong)(slippage * digits_adjust);
            request.magic = magic;
            request.comment = trade_comment;

            request.sl = sl;
            request.tp = 0;

            if (startPrice > currentPrice)
            {
                target_price =
                    NormalizeDouble(min_price + step * i, m_symbol.Digits());
                request.type = ORDER_TYPE_SELL_LIMIT;
            }
            else
            {
                target_price =
                    NormalizeDouble(max_price - step * i, m_symbol.Digits());
                request.type = ORDER_TYPE_BUY_LIMIT;
            }

            if (IsPendingOrderExist(target_price))
            {
                continue;
            }

            request.price = target_price;
            Print(target_price, " ", sl, " ", currentPrice, " ",
                  m_symbol.Digits(), " ", m_symbol.Point());

            if (!OrderSend(request, result))
            {
                Print("Order added successfully. Price: ", target_price);
            }
            else
            {
                Print("Failed to add order. Price: ", target_price,
                      " Error: ", GetLastError());
            }
        }
    }
    //+------------------------------------------------------------------+
    //| 指値をすべて削除する                                               |
    //+------------------------------------------------------------------+
    void RemoveAll()
    {
        int totalOrders = OrdersTotal(); // 保留中の注文の総数を取得
        for (int i = totalOrders - 1; i >= 0; i--)
        {
            ulong ticket = OrderGetTicket(i);
            ulong ticketMagic = OrderGetInteger(ORDER_MAGIC);

            // Magic Numberが一致する指値注文をチェック
            if (ticketMagic == magic || is_manual_orders_and_positions)
            {
                // 削除する注文情報をセット
                MqlTradeRequest request;
                MqlTradeResult result;
                ZeroMemory(request);
                ZeroMemory(result);

                request.action = TRADE_ACTION_REMOVE; // 注文削除アクション
                request.order = ticket;               // 削除する注文のチケット番号

                if (!OrderSend(request, result))
                {
                    Print("Order deleted successfully. Ticket: ", ticket);
                }
                else
                {
                    Print("Failed to delete order. Ticket: ", ticket,
                          " Error: ", GetLastError());
                }
            }
        }
    }
    //+------------------------------------------------------------------+
    //| 既に指値が設定されているか確認する                                  |
    //+------------------------------------------------------------------+
    bool IsPendingOrderExist(double price)
    {
        for (int i = 0; i < OrdersTotal(); i++)
        {
            ulong ticket = OrderGetTicket(i);
            ulong ticketMagic = OrderGetInteger(ORDER_MAGIC);
            double order_price = OrderGetDouble(ORDER_PRICE_OPEN);
            if ((ticketMagic == magic || is_manual_orders_and_positions) && order_price == price)
            {
                return true;
            }
        }
        return false;
    }
};
