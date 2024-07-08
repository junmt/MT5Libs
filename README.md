# MT5Libs
MT5用のライブラリ

## 説明

|ファイル名|説明|
| ---- | ---- |
|CLotsLibrary.mqh|ロット計算用のライブラリ|
|COrderLibrary.mqh|指値用のライブラリ|
|CPositionLibrary.mqh|ポジション操作用のライブラリ|

### CLotsLibrary.mqh
ロット自動計算用のライブラリ。
資金に合わせて自動でロット計算をしてくれます。

- Lot()で自動計算した結果を返します。
- CheckLot()で引数のロット数が上限を超えている場合はエントリー可能なロット数で返してくれます。

### COrderLibrary.mqh
指値用のライブラリ。
指値を登録するために役に立つかもしれないライブラリ

- ZoneEntry()でstart, endの価格帯の帯で指値をばらまく
- RemoveAll()ですべての指値を削除する
- IsPendingOrderExist()で既に指値があるか判定する

### CPositionLibrary.mqh
ポジション操作用のライブラリ
ポジションの入れ替えなどに役立つライブラリ

- TakeProfitAll()でプログラム上に設定されているTPに到達している場合、クローズする
- StopLossAll()でプログラム上に設定されているSLに到達している場合、クローズする
- TrailingStop()でプログラム上に設定されているTrailingStopに到達している場合、3pipsを加算してSLを設定する。
- GetPositionWithMaxProfit()で最大の利益が出ているticketidを取得する
- GetPositionWithMaxLoss()で最大の損失が出ているticketidを取得する
- GetPositionCount()で対象のポジション数を返す
- SetPositionTakeProfit()で不利なポジションにTPを設定する
- AutoAddPosition()で設定値に従ってナンピンをする
- SetStopLoss()で最も不利なポジションを起点に計算された値でSLを一括で設定する

## ライセンス
GPL-3

※MITに変える可能性あり。