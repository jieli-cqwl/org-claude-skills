<div align="center">

# midas.skill

> *「富はBloombergターミナルにもVCのピッチデックにも隠れていない。富はあなたの日常のノイズに隠れている — あなたはそれを無視するよう訓練されてきただけだ。」*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Python 3.9+](https://img.shields.io/badge/Python-3.9%2B-blue.svg)](https://python.org)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Skill-blueviolet)](https://claude.ai/code)
[![AgentSkills](https://img.shields.io/badge/AgentSkills-Standard-green)](https://agentskills.io)

[![Discord](https://img.shields.io/badge/Discord-Join%20Community-5865F2?logo=discord&logoColor=white)](#)

<br>

今週、あなたのSlackチャットは3つのビジネスアイデアを漏らした — そしてあなたはスクロールで通り過ぎた。<br>
あなたのカメラロールには近所のアービトラージの論拠が眠っている — そしてあなたはその写真の存在を忘れていた。<br>
あなたの友人グループの不満は自然発生のフォーカスグループだ — そしてチャットの誰もそれを知らない。<br>
あなたのYouTube履歴は、あなたが有料の専門家になりつつある14時間分の証拠だ — そしてあなたはそれを「時間の無駄」と呼んだ。<br>
あなたのAmazon購入履歴は検証済みの需要だ — そしてあなたはただの買い物だと思っている。<br>

**あなたの繰り返しの注文を金に変える — ノイズから金への精錬所へようこそ!**

<br>

日常のどんな情報ストリームでも与える(Slack、写真、チャット、閲覧履歴、レシート、不満)<br>
あなた自身の直感と疑問を添えて<br>
**マネーシグナル、機会、即座の次のアクションのランク付けされたリスト**を受け取る

[対応ソース](#対応ソース) · [インストール](#インストール) · [使い方](#使い方) · [デモ](#デモ) · [詳細インストール](#詳細インストール) · [💬 Discord](#)

[**English**](README.md) · [**中文**](README_ZH.md) · [**Español**](README_ES.md) · [**Deutsch**](README_DE.md) · [**Русский**](README_RU.md) · [**Português**](README_PT.md)

</div>

---

作成者: [@realteamprinz](https://github.com/realteamprinz) | ポジショニング: **Nuwaは人が*どう考えるか*を蒸留する。Midasはあなたの日常のノイズを*どう金に変えるか*を蒸留する。**

## 対応ソース

> Midasはあなたが自発的に与えるあらゆる情報ストリームを受け入れます。**繰り返しこそがシグナル** — 生活の中で2回以上出会ったなら、Midasに与えてください。

| ソース | 最適レンズ | 備考 |
|--------|:----------:|------|
| Slack / Teams メッセージ | 需要ギャップ、マネーシグナル | チームチャンネル = ベンダーへの不満、予算シグナル、手動の回避策 |
| WhatsApp / iMessage / WeChatチャット | 需要ギャップ、ネットワーク経路 | 複数人からの繰り返しの不満 = 満たされていない需要 |
| スマホのカメラロール(未整理) | アービトラージ、需要ギャップ | 工事現場、空き店舗、人混み、価格、看板 |
| YouTube / TikTok 視聴履歴 | スキルブリッジ、行動 | 一貫したテーマの焦点 = 潜在的な専門性の蓄積 |
| ブラウザ履歴 | スキルブリッジ、マネーシグナル | 調査パターン、価格比較、トラブルシューティング |
| 購入履歴 / サブスクリプション | マネーシグナル、行動 | 繰り返しの購入 = 検証済みの需要、自動運転の習慣 |
| ミーティングノート(内部) | マネーシグナル、需要ギャップ | 予算の会話、ツールへの不満、壊れたプロセス |
| メール `.eml` / `.mbox` | マネーシグナル、ネットワーク経路 | 報酬オファー、紹介チェーン、ベンダー見積もり |
| レシート / 注文確認 | マネーシグナル、アービトラージ | あなたが本当に価値を置くものの最も正直なシグナル |
| テキストを直接貼り付け | 6つのレンズすべて | 1本のボイスメモの書き起こしでもシグナルを生む |

完全なソース階層とトライアンギュレーションルールは [references/sources-guide.md](references/sources-guide.md) を参照してください。

---

## インストール

### Claude Code

> **重要**: Claude Codeは**gitリポジトリのルート**にある`.claude/skills/`でSkillを探します。正しい場所で実行してください。

```bash
# 現在のプロジェクトにインストール(gitリポジトリのルートで実行)
mkdir -p .claude/skills
git clone https://github.com/realteamprinz/midas-skill .claude/skills/midas-skill

# またはグローバルにインストール(すべてのプロジェクトで利用可能)
git clone https://github.com/realteamprinz/midas-skill ~/.claude/skills/midas-skill
```

### OpenClaw

```bash
git clone https://github.com/realteamprinz/midas-skill ~/.openclaw/workspace/skills/midas-skill
```

### 依存関係(オプション)

MidasはピュアMarkdownです — ランタイム依存関係は不要。自動入力収集のためのPythonツール(ブラウザ履歴パーサー、レシートOCRなど)は予定されており、将来のリリースで `tools/` 以下に配置されます。

---

## 使い方

Claude CodeまたはOpenClawで、Midasのトリガーフレーズのいずれかを入力します:

```
Midas, mine this                 → 任意の入力を貼り付け、シグナルレポートを取得
Turn this into gold              → 同じ
What money signal is here        → より具体的なフレーミング
点石成金                         → 中国語で同じ
Midas, analyze this deal         → ディール分析モード
What am I missing                → 1週間分の自分のメッセージを与える
```

Midasはすべての入力を6レンズ抽出エンジンに通し、あなたの `evolution/evolution.jsonl` ログと相互参照し、**即座の次のアクション**付きのランク付けされたシグナルレポートを返します。

### 6つのレンズ

| # | レンズ | 中核となる問い |
|---|--------|----------------|
| 1 | **マネーシグナル** | お金はどこで動き、詰まり、漏れているか? |
| 2 | **需要ギャップ** | 誰も提供していないが人々が欲しているものは何か? |
| 3 | **アービトラージウィンドウ** | 価値はどこで誤って価格設定されているか? |
| 4 | **スキルブリッジ** | あなたが既に知っている市場価値のあるものは何か? |
| 5 | **ネットワーク経路** | 誰が誰と話すべきで、紹介料はいくらか? |
| 6 | **行動レバレッジ** | 収入からピボット1つ分の自動運転の習慣は何か? |

完全な方法論は [references/signal-extraction-framework.md](references/signal-extraction-framework.md) にあります。

---

## デモ

> 入力: *"Midas, mine this — これが先週のSlackです: [73メッセージ貼り付け]"*

```
[MIDAS シグナルレポート]

入力タイプ:       slack_messages
ボリューム:       3チャンネル + 4 DMで73メッセージ
スキャン日時:     2026-04-09

🟡 検出されたマネーシグナル: 7
🔴 破棄されたノイズ:         ~65メッセージ (89%)

🥇 #1 — Marcusを内部コンサルタントとして(スキルブリッジの楔)
    信頼度: 50% | 労力: 低 | 上昇余地: 副収入 $3–8k/月
    証拠:
      - SarahのDM:「誰かがAWSのタグ付けをエンドツーエンドで $5k 未満で解決できたら、おそらく払う」
      - PriyaのDM:「私自身がそれに払う」
      - 同じ週に3人の異なるステークホルダーがMarcusに3つの問題の助けを求めた
    パターンマッチ: Buffett — あなたの能力の円の中にとどまる

    ⚡ 即座の次のアクション:
       月曜午前9時、Sarahにスコープされたオファーを DM:
       「AWSタグ付けプロジェクト — 固定費 $3,500、次の金曜日までに配信。」

🥈 #2 — AWSコスト可視化ワンタイムコンサルティング(プロダクト化)
    信頼度: 52% | 労力: 低 | 上昇余地: エンゲージメントあたり $5k、繰り返し可能
    パターンマッチ: Thiel — 誰も真剣に受け止めない小さな独占
    ...
```

完全なウォークスルーは [examples/daily-slack-mining/](examples/daily-slack-mining/) にあります。

**5つのサンプル実行が含まれています:**

| 例 | 入力タイプ | 結果 |
|---|---|---|
| [daily-slack-mining](examples/daily-slack-mining/) | 仕事Slack、1週間 | 「退屈な」メッセージから7つのシグナル、5つの機会 |
| [photo-roll-mining](examples/photo-roll-mining/) | 30枚の電話写真、1週間 | 🏆 **ゴールデン** 75% — 完全な木工委託ビジネスが浮上 |
| [complaint-mining](examples/complaint-mining/) | WhatsApp グループ、2週間 | 🏆 **ゴールデン** 78% — 近隣信頼プロバイダー名簿の機会 |
| [browsing-mining](examples/browsing-mining/) | ブラウザ + YouTube、1週間 | 🏆 **ゴールデン** 82% — サンプルセット中最高の信頼度 |
| [billionaire-pattern-match](examples/billionaire-pattern-match/) | 累積 | 4つのユーザープロファイルを Musk/Buffett/Thiel のプレイブックと照合 |

---

## 詳細インストール

### ステップ 1 — リポジトリをクローン

```bash
git clone https://github.com/realteamprinz/midas-skill
cd midas-skill
```

### ステップ 2 — Claude Code が見る場所に配置

Claude Code では、Skills は **git リポジトリのルート** の `.claude/skills/`(プロジェクトごと)または `~/.claude/skills/`(グローバル)に存在します。1 つ選んでください:

```bash
# プロジェクトごと: まず Skill をアタッチしたい git リポジトリに cd する
mkdir -p .claude/skills
cp -r /path/to/midas-skill .claude/skills/midas-skill

# またはグローバル(すべてのプロジェクトで利用可能)
mkdir -p ~/.claude/skills
cp -r /path/to/midas-skill ~/.claude/skills/midas-skill
```

### ステップ 3 — Skill がロードされたか確認

インストールしたリポジトリで Claude Code セッションを開きます。入力:

```
What skills are available?
```

Midas は `midas-skill` として表示されるはずです。そうでない場合は、`SKILL.md` がインストールされたフォルダのルートにあり、YAML フロントマターが有効であることを確認してください。

### ステップ 4 — 最初のマイニングを実行

トリガーフレーズとともに任意のノイズのある入力を貼り付けます:

```
Midas, mine this — 私の #general Slack の最新 50 メッセージ:
[内容を貼り付け]
```

Midas は最初のシグナルレポートを生成し、`evolution/evolution.jsonl` に最初のエントリを追加します。

### ステップ 5 — 時間をかけて多様性を与える

Midas は入力が多様になるほど鋭くなります。推奨される毎週のローテーションは [references/sources-guide.md](references/sources-guide.md) を参照してください(月曜日 Slack、水曜日写真、木曜日ブラウジングなど)。1 日目は推測を、30 日目は確信を、90 日目はプレイブックを与えます。

---

## 機能

### 🔍 6-レンズ抽出エンジン

すべての入力は マネーシグナル / 需要ギャップ / アービトラージ / スキルブリッジ / ネットワーク経路 / 行動レバレッジ を通過します。すべてのシグナルはそれを生成した正確なフレーズ、画像、データポイントまで追跡可能です。

### 🧠 自己学習する累積インテリジェンス

Midas はセッション間でリセットされません。すべての入力は `evolution/evolution.jsonl` に追加されます。新しいシグナルはすべての過去のシグナルと相互参照されます。**信頼度は独立した相互参照される証拠を通じてのみ増加します。**

| 証拠 | 信頼度 | Midas フラグ |
|---|---|---|
| 1 つの単一ソースシグナル | 15–35% | 観察中 |
| 2 つの独立したソースが確認 | 40–65% | 作業仮説 |
| 3+ の独立したソースが収束 | 70–90% | 🏆 ゴールデン — 行動 |
| 直接的な市場検証 | 85–95% | 🏆 ゴールデン — 今すぐ行動 |

### 🎯 有名な富の OS パターンマッチャー

[Musk](references/famous-models/elon-musk.md)、[Buffett](references/famous-models/warren-buffett.md)、[Thiel](references/famous-models/peter-thiel.md) の事前構築された富のオペレーティングシステム。あなたのシグナルが蓄積されると、Midas はどのプレイブックがあなたの状況に構造的にマッチするかを自動的にチェックします。

>「あなたのパターンは初期 Thiel のように見えます: 誰も真剣に受け止めないニッチでの独占。Thiel のプレイブックは『まず小さな市場を支配する』と言っています。」

### 💼 ディール分析ツール

特定の取引(自分のもの、または公開された M&A)を *"Midas, analyze this deal"* で指して、構造化された 8 部構成の内訳を取得: 当事者、構造、資金源、リスク配分、イグジット経路、隠れたレバレッジ、判断、パターンマッチ。[references/deal-template.md](references/deal-template.md) を参照してください。

### ⚡ 分析ではなくアクション

すべてのシグナルレポートは **即座の次のアクション** で終わります — 具体的な動詞 + 具体的な名詞。決して「オプションを探る」ではない。常に「今夜 Dave に DM して、手動レポートに週何時間かかるか聞く」。

---

## プロジェクト構造

```
midas-skill/
├── SKILL.md                              # メインエントリ
├── README.md                             # メインの英語 README
├── README_ZH.md · README_ES.md · ...     # 言語バリアント
├── LICENSE                               # MIT
├── references/
│   ├── signal-extraction-framework.md    # 6-レンズ方法論
│   ├── noise-to-gold-pipeline.md         # 7 段階の抽出パイプライン
│   ├── deal-template.md                  # ディール分析テンプレート
│   ├── sources-guide.md                  # 入力ソース階層
│   └── famous-models/                    # Musk / Buffett / Thiel 富の OS
├── examples/                             # 5 つの実例
└── evolution/
    └── evolution.jsonl                   # あなたの個人累積インテリジェンスログ
```

---

## 設計原則

1. **あなたのノイズはあなたの鉱石。** すべての平凡なやり取りには潜在的な富のシグナルがあります。
2. **繰り返しが主要なシグナル。** あなたの生活に 2 回現れるものは市場です。
3. **相互参照は単一ソースに勝る。** 1 つのシグナルは推測。3 つは確信。
4. **分析より行動。** Midas は次のステップを出力し、エッセイではない。
5. **複利的インテリジェンス。** 1 日目は推測、90 日目はプレイブック。
6. **道徳的判断なし。** Midas はお金がどう動くかを研究し、どう動く*べきか*ではない。
7. **正直な境界。** 予測なし。保証なし。金融アドバイスなし。
8. **公開情報のみ。** あなたが自発的に与えるもののみ。

---

## ライセンス

MIT。[LICENSE](LICENSE) を参照してください。

## 金融アドバイスではありません

Midas は投資、税務、法律、会計のアドバイスを提供しません。Midas の出力は、いかなる証券の売買推奨でもありません。実質的な資本を含む Midas 生成の機会に基づいて行動する前に、あなたの管轄区域の認可された専門家に相談してください。

---

**あなたの繰り返しの注文を金に変える。**
