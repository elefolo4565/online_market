# online_market

Godot Engine 4.6.1 で開発するゲームプロジェクト。

## 技術スタック
- Godot Engine 4.6.1
- GDScript

## ディレクトリ構成
- scenes/ - シーンファイル (.tscn)
- scripts/ - GDScript (.gd)
- assets/ - アセットファイル
  - sprites/ - 2Dスプライト
  - fonts/ - フォント (デフォルト: DelaGothicOne-Regular.ttf)
  - sounds/ - サウンド
- export/ - エクスポート出力

## デフォルトフォント
- DelaGothicOne-Regular.ttf が全UIテキストに適用済み
- assets/default_theme.tres でプロジェクト全体のテーマとして設定

## Git ルール
- 「commit」と言われたら確認なしで即座にコミットする（git status/diff/log の事前確認は不要）
- 全変更ファイルをステージングし、変更内容に応じた日本語コミットメッセージを作成する

## 注意事項
- シーンファイルは手動編集せず、可能な限りスクリプトから生成・操作する
- アセットのインポート設定は .godot/imported/ に自動生成される
