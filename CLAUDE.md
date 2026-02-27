# セカンダリーマーケット (Secondary Market)

「ハゲタカのエジキ」ベースのオンライン対戦カードゲーム。Godot Engine 4.6.1で開発。
金融テーマのカジュアル・ポップなUI。ブラウザ/スマホ対応、3〜6人、AI対戦可能。

## 技術スタック
- Godot Engine 4.6.1
- GDScript
- サーバー: Render（将来のオンライン対応）

## アーキテクチャ
- **ロジック層** (`scripts/logic/`): GameState, RoundResolver, GameManager — UIに依存しない
- **UI層** (`scripts/ui/`): GameScreen, CardDisplay等 — シグナルでロジック層と接続
- **AI** (`scripts/ai/`): 3段階の難易度（RandomStrategy / BasicStrategy / AdvancedStrategy）
- **Autoload**: GameEvents（イベントバス）, SceneManager（画面遷移）

## ディレクトリ構成
- scenes/ - シーンファイル (.tscn)
  - ui/ - 各画面シーン (title, lobby, game, result)
  - components/ - 再利用コンポーネント
- scripts/ - GDScript (.gd)
  - autoload/ - Autoloadスクリプト
  - data/ - データモデル (CardData, GameConfig)
  - logic/ - ゲームロジック (GameState, GameManager, RoundResolver, PlayerState)
  - ai/ - AI (AIPlayer, Strategy各種)
  - ui/ - UI制御スクリプト
  - network/ - ネットワーク（将来）
- assets/ - アセットファイル
  - sprites/ - 2Dスプライト
  - fonts/ - フォント (デフォルト: DelaGothicOne-Regular.ttf)
  - sounds/ - サウンド
- export/ - エクスポート出力

## 画面遷移
タイトル → ロビー（人数/AI設定） → ゲーム（15ラウンド） → リザルト → タイトル

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

## 注意事項
- シーンファイルは手動編集せず、可能な限りスクリプトから生成・操作する
- アセットのインポート設定は .godot/imported/ に自動生成される
