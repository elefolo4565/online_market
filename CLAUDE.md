# セカンダリーマーケット (Secondary Market)

「ハゲタカのエジキ」ベースのオンライン対戦カードゲーム。Godot Engine 4.6.1で開発。
金融テーマのカジュアル・ポップなUI。ブラウザ/スマホ対応、3〜6人、AI対戦可能。

## 技術スタック
- Godot Engine 4.6.1
- GDScript
- サーバー: Node.js (WebSocket) — さくらVPS (Rocky Linux) にデプロイ済み

## アーキテクチャ
- **ロジック層** (`scripts/logic/`): GameState, RoundResolver, GameManager — UIに依存しない
- **UI層** (`scripts/ui/`): GameScreen, CardDisplay等 — シグナルでロジック層と接続
- **AI** (`scripts/ai/`): 3段階の難易度（RandomStrategy / BasicStrategy / AdvancedStrategy）
- **Autoload**: GameEvents（イベントバス）, SceneManager（画面遷移）
- **ネットワーク層** (`scripts/network/`): NetworkClient (WebSocket), NetworkProtocol
- **サーバー** (`server/`): Node.js WebSocketサーバー — 権威サーバーモデル

## ディレクトリ構成
- scenes/ - シーンファイル (.tscn)
  - ui/ - 各画面シーン (title, lobby, online_lobby, game, result)
  - components/ - 再利用コンポーネント
- scripts/ - GDScript (.gd)
  - autoload/ - Autoloadスクリプト
  - data/ - データモデル (CardData, GameConfig)
  - logic/ - ゲームロジック (GameState, GameManager, RoundResolver, PlayerState)
  - ai/ - AI (AIPlayer, Strategy各種)
  - ui/ - UI制御スクリプト
  - network/ - NetworkClient, NetworkProtocol
- server/ - Node.js WebSocketサーバー
  - server.js, room_manager.js, game_room.js, round_resolver.js, server_ai.js, protocol.js
- assets/ - アセットファイル
  - sprites/ - 2Dスプライト
  - fonts/ - フォント (デフォルト: DelaGothicOne-Regular.ttf)
  - sounds/ - サウンド
- export/ - エクスポート出力

## 画面遷移
- **オフライン**: タイトル → ロビー → ゲーム → リザルト → タイトル
- **オンライン**: タイトル → オンラインロビー → ゲーム → リザルト → タイトル

## オンライン対戦
- **通信**: JSON over WebSocket（権威サーバーモデル）
- **マッチング**: ルームコード方式 + 自動マッチング
- **AI補完**: 人数不足時にサーバーサイドAIで補完可能
- **切断処理**: ゲーム中に切断したプレイヤーはAIに自動置換
- **サーバー起動**: `cd server && npm install && npm start`（ポート8080）
- **GameScreenは`_is_online`フラグでオフライン/オンラインを切り替え**

## ゲームルール
- 得点カード（銘柄カード）: +1〜+10, -1〜-5 の計15枚
- 手札（入札カード）: 各プレイヤーが1〜15の15枚
- プラスカード: 最大入札者が獲得 / マイナスカード: 最小入札者が引き取る
- バッティング（同値）: 無効→次の候補 / 全員バッティング: 持ち越し

## デフォルトフォント
- DelaGothicOne-Regular.ttf が全UIテキストに適用済み
- assets/default_theme.tres でプロジェクト全体のテーマとして設定

## Git ルール
- 「commit」と言われたら確認なしで即座にコミットする（git status/diff/log の事前確認は不要）
- 全変更ファイルをステージングし、変更内容に応じた日本語コミットメッセージを作成する

## デプロイ手順

### サーバー（Node.js WebSocket）の更新
サーバーはさくらVPS (elefolo2.com) の Rocky Linux 上で稼働。
```bash
# 1. VPSにSSH接続
ssh elefolo2.com

# 2. サーバーディレクトリで最新コードを取得
cd /var/www/online_market_repo/server
git pull

# 3. サーバーを再起動（pm2の場合）
pm2 restart online-market
```
- **サーバーパス**: `/var/www/online_market_repo/server`
- **接続先URL**: `wss://elefolo2.com/ws/online_market`（本番） / `ws://localhost:8080`（ローカル）
- **server/ 配下のファイルを変更した場合は必ずサーバー再起動が必要**

### クライアント（Godot Web版）の更新
1. Godotエディタで Web エクスポートを実行
2. エクスポートされたファイルをVPSのWebサーバーにアップロード

## 注意事項
- シーンファイルは手動編集せず、可能な限りスクリプトから生成・操作する
- アセットのインポート設定は .godot/imported/ に自動生成される

## クレジット
- BGM 盤面の闘い 
  - 作成者 shimtone様 https://dova-s.jp/_contents/author/profile295.html
  - 楽曲URL https://dova-s.jp/bgm/play18956.html