## 0. 概要

| 項目 | 内容 |
|---|---|
| システム名 | Claude Code Ticket Guard |
| 目的 | チケット単位の動的スコープ制御による、本番DB・保護ファイル・プロジェクト外領域の破壊防止 |
| 構成要素 | PreToolUse Hook（静的解析）＋ PostToolUse Hook（事後状態監視）＋ セッション承認キャッシュ ＋ チケット承認ゲート |
| 設定ソース | Claude Code settings.json + Hook 組み込み不変ルール + .claude/hooks/config.yaml + .current-ticket.md + 環境変数 |
| 基本原則 | ① Fail-Safe（deny > ask > allow）<br>② 明示宣言された制約は下位レイヤから緩められない |

> 転記注記: 原文ではこの表がページ冒頭に置かれ、表の上に章見出しが写っていない。取り込みにあたって「0. 概要」の見出しを補った。原本に別の見出しがある場合は差し替えること。

## 1. サマリ

### 1.1 システムが提供する機能

| # | 機能 | 目的 |
|---|---|---|
| 1 | シェル構文パースによる構造解析（PreToolUse） | 文字列パターンマッチでは検知できないコマンド構造を、トークン分解した結果に基づいて判定するため |
| 2 | 実行後の Git 差分監視（PostToolUse） | 間接実行・副作用による保護領域の汚染は実行前に検知できないため、事後に検知して復元させる |
| 3 | チケット単位の動的スコープ | 作業ごとに必要最小限の権限だけを開示し、影響範囲を局所化するため |
| 4 | ask の二分類と承認キャッシュ | 定義漏れ由来の確認疲れを抑制しつつ、意図的な確認ポイントは維持するため |
| 5 | 明示宣言に基づく権限上限 | チケット承認が形骸化しても、プロジェクトが明示宣言した制約は破られないようにするため |

### 1.2 権限モデルの骨格

権限設定は 4 レイヤから構成される。

```
Layer 0-A : Claude Code settings.json        ← プラットフォームによる強制
Layer 0-B : Hook 組み込み不変ルール（3 パス）  ← コード固定
Layer 1   : .claude/hooks/config.yaml        ← 人間が PR + レビューで管理
Layer 2   : .current-ticket.md               ← AI 生成 / 人間承認
Layer 3   : 環境変数 TICKET_GUARD_*           ← 実行時
```

### 1.3 宣言済み領域と未宣言領域

判定は以下の 2 種類の領域を明確に区別する。

| 領域 | 定義 | チケットの権限 |
|---|---|---|
| 宣言済み領域 | Layer 0 / Layer 1 が明示的に deny / ask / allow を書いた対象 | ❌ 緩められない（縮小のみ可） |
| 未宣言領域 | どのレイヤも言及していない対象（sandbox 内に限る） | ✅ チケットが allow を宣言すれば allow<br>チケットが沈黙していれば暗黙的 ask |

```
実効権限 = 宣言済み領域 → strictest( 上位レイヤの宣言, チケットの要求 )
           未宣言領域   → チケットの要求（無指定なら暗黙的 ask）
           sandbox 外   → write/exec: deny 固定、read: ask 固定
```

この設計を採る理由：ファイルシステム全域を事前に列挙することは不可能であり、未宣言領域をすべて ask に固定すると確認疲れで承認が形骸化する。一方、守るべき対象は有限であり列挙可能である。したがって「守るべきものはプロジェクトが明示的に列挙し、それ以外はチケットに委譲する」というデニーリスト型のモデルを採用する。

この帰結として、プロジェクト設定の列挙品質が防御力を直接決定する。列挙漏れを検知・是正するため、逸脱の可視化（§16）とリスクスコア（§17）を併設する。

> 転記注記: §1.3 の見出しは原文のスクリーンショットに写っておらず、節の内容から「宣言済み領域と未宣言領域」を補った。原本の見出しに差し替えること。

## 2. 解決する課題

### 2.1 ワイルドカードパターンマッチの構造的限界

`Bash(psql * DROP *)` のようなコマンド文字列の単純なテキスト合致では、以下のすり抜けを防げない。

| すり抜け手法 | 実例 | 突破理由 |
|---|---|---|
| 順序逆転（パイプ） | `echo "DROP TABLE users;" \| psql -d mydb` | DROP が psql より前に出現し、パターンにマッチしない |
| ヒアドキュメント | `psql -d mydb <<EOF`<br>`DROP TABLE users;`<br>`EOF` | 改行を挟むためワイルドカードが到達しない |
| ファイル経由実行 | `psql -d mydb -f /tmp/clean.sql` | コマンド文字列に DROP の語が一切出現しない |
| スクリプト経由実行 | Write で act.sh を生成 → `bash act.sh` | 同上。全層を通過する |

対処：シェル構文をトークン分解し、コマンド・オプション・対象パスを構造として抽出したうえで判定する（§12.3）。

### 2.2 過度なルールによる誤検知

すり抜けを塞ごうとパターンを広げる（例：`Bash(*DROP*)`）と、`git commit -m "Fix DROP bug"` や `grep -rn "DROP TABLE" ./src` のような正常操作まで一律ブロックされる。

対処：クォート保全・コメント除外・コマンド名との共起判定により、文字列としての出現と実行としての出現を区別する（§12.3）。

### 2.3 プロンプト指示の確実性の低さ

`CLAUDE.md` への記述は AI の判断に依存するため、長時間タスクの途中や外部入力に影響された文脈では指示が希薄化し、決定論的なブロックにならない。

対処：Hook による機械的な遮断を防御の主体とし、プロンプト指示は補助的な位置づけとする。

### 2.4 タスク文脈を持たない静的な権限管理

タスクごとに必要な権限は異なるが、固定的な許可リストでは「今回の作業に必要な範囲」を表現できない。また、ツール実行後の副作用で保護領域が書き換わったことを検知する仕組みも必要である。

対処：チケット単位の動的スコープ（§9）と PostToolUse による事後検証（§18）。

### 2.5 確認要求（ask）の質の不均質性

ask には性質の異なる 2 種類が混在する。設定者が意図的に置いた重要な確認ポイントと、単に設定に書き漏れただけの定義漏れ由来の確認である。両者を同列に扱うと後者が頻発して確認疲れを招き、ユーザーは内容を読まずに承認するようになり、前者の確認まで形骸化する。

対処：ask を明示的／暗黙的に二分類し、UI とキャッシュポリシーの両面で分離する（§13）。

### 2.6 チケット承認の形骸化

本システムは「作業開始時にエージェントがチケットを生成し、人間が承認する」運用を前提とするが、レビュー疲れ・流し読み・プロンプトインジェクション・生成ロジックのバグにより、過剰な権限要求が素通りしうる。

人間の承認を防御の唯一の根拠にできない。

対処：プロジェクトが明示宣言した制約はチケットから緩められない構造とし（§11）、加えて逸脱を必ず可視化する（§16）。

### 2.7 防御機構自身の保護と、その柔軟性の両立

設定ファイル・Hook スクリプトが無防備であれば他のあらゆる保護は無意味になる。一方で、`.claude/` 配下にはスキル定義・スラッシュコマンド・サブエージェント定義など、エージェント自身が正当に編集する対象も含まれる。これらを一律にコード固定で禁止すると、正当な運用が阻害される。

対処：組み込み不変ルールは「いかなるプロジェクトでも書き換えを許してはならない最小限」に限定し（§7.2）、`.claude/` 配下の保護範囲はプロジェクト設定に委ねる。プロジェクトがガードを外した場合は、その変更自体が人間の承認（PR レビュー・チケット承認ゲート）を通ることで担保する。加えて Hook 完全性検証（§7.4）により、実際に改変された場合は次回セッション開始時に人間の確認を強制する。

## 3. 脅威モデル

### 3.1 想定する主体

| 主体 | 説明 | 対象 |
|---|---|---|
| A: ドリフトする LLM | 悪意はないが、文脈の希薄化・誤解・幻覚により破壊的操作を行う | ✅ 主対象 |
| B: 誘導された LLM | プロンプトインジェクション（外部ドキュメント・Issue 本文・依存パッケージ経由）により攻撃者の意図に沿って動く | ✅ 主対象 |
| C: 事故 | 正常なコマンドの副作用、ビルドスクリプトの想定外挙動 | ✅ 主対象 |
| D: 実行環境を掌握した攻撃者 | 同一ユーザー権限で任意のシェルを実行できる | ❌ 対象外（§23.3 の OS/IAM 層で対処） |

主体 D を対象外とする理由：Hook と同一ユーザー権限で動作するファイルベースの防御は、任意のシェル実行が可能な主体に対して原理的に境界とならない。本システムは LLM のドリフトと事故に対するガードレールとして設計する。

### 3.2 保護対象資産

| 優先度 | 資産 | 想定被害 | 保護レイヤ |
|---|---|---|---|
| 🔴 最高 | 承認台帳・Git メタデータ・承認キャッシュ | 防御機構の偽装・履歴改竄 | Layer 0-B（不変） |
| 🔴 最高 | 本番 DB | データ消失 | Layer 1（deny_commands / DB 検知） |
| 🔴 最高 | クラウドインフラ（RDS、K8s、Terraform state） | サービス停止 | Layer 1（deny_commands） |
| 🟡 高 | 認証情報（.env、secrets/**） | 漏洩・横展開 | Layer 1（target_directories） |
| 🟡 高 | 設定・Hook 本体（.claude/hooks/**、settings.json） | 防御機構の無効化 | Layer 1（推奨テンプレート）＋ 完全性検証 |
| 🟡 高 | プロジェクト外領域（$HOME、/etc、他リポジトリ） | 影響範囲の拡大 | Layer 1（sandbox_root） |
| 🟢 中 | Git 履歴・保護ドキュメント | 復旧可能だが手戻り | Layer 1 |

### 3.3 対処する攻撃面

| ID | 攻撃面 | 対処箇所 |
|---|---|---|
| T-1 | チケットによる tools の昇格 | §8.3 strictest 合成 |
| T-2 | より深いキーによる deny サブツリーのくり抜き | §11.3 上位レイヤ単独ツリーでの判定 |
| T-3 | プロジェクト外領域への allow 追加 | §8.2 sandbox_root |
| T-4 | 設定・Hook 本体の書き換え | §8.5 推奨保護 ＋ §7.4 完全性検証 ＋ §17.5 承認台帳 |
| T-5 | approval_cache の緩和 | §8.7 上限クランプ |
| T-6 | シンボリックリンクによるサンドボックス脱出 | §8.2 実体解決 ＋ sandbox 境界 |
| T-7 | 承認キャッシュの内容差し替え悪用 | §14.6 内容ハッシュ |
| T-8 | 確認漏れによる過剰権限の承認 | §16 逸脱の可視化 / §17 承認ゲート |
| T-9 | プロジェクトの列挙漏れ領域への allow | §16.3 逸脱表示 / §17.3 リスクスコア / §18 事後監視 |

## 4. 設計原則

| # | 原則 | 内容と理由 |
|---|---|---|
| P1 | Fail-Safe（安全倒し） | 権限の競合時は常に最も厳しいルールを採用する（deny > ask > allow）。解析不能・判定不確定はすべて ask に倒す。判定できない状況を許可に倒すと、解析漏れが即座に脆弱性になるため。 |
| P2 | 明示宣言の不可侵性 | 上位レイヤが明示的に書いた deny / ask は、下位レイヤ（ticket / env）から緩められない。信頼度の低いレイヤに、運用者の明示的な意思を覆す権限を与えないため。 |
| P3 | 未宣言領域の委譲 | どのレイヤも言及していない領域は、チケットの宣言に従う。全域の事前列挙は不可能であり、未宣言領域を一律 ask にすると確認疲れで承認が形骸化するため。ただし逸脱は必ず可視化する。 |
| P4 | 最小の不変ルール | コード固定の不変 deny は、いかなるプロジェクトでも書き換えを許してはならない対象に限定する。正当な運用まで阻害しないため。 |
| P5 | 判定根拠の構造化 | すべての判定は reason_code / access / subject を持つ根拠オブジェクトとして返す。キャッシュキー・監査ログ・LLM フィードバックを同一の情報源から導出し、一貫性を保つため。 |
| P6 | 確認疲れの抑制 | 本質的な危険性の表明でない暗黙的 ask は、根拠単位で 1 セッション 1 回に集約する。明示的 ask は原則毎回確認する。確認の質を維持するため。 |
| P7 | 逸脱は必ず可視化 | 却下された昇格試行、および想定委譲範囲からの逸脱を握り潰さない。起動時表示・LLM への通知・監査ログの 3 経路で人間が事後に必ず気づけるようにするため。 |
| P8 | キャッシュは deny を緩和しない | 承認キャッシュは ask → allow の昇格にのみ作用し、deny 判定には一切影響しない。キャッシュを権限昇格の踏み台にしないため。 |
| P9 | 多層検証（静的 × 動的） | 実行前のコマンド構造解析と実行後の Git 状態検証を併用する。静的解析で検知不能な間接実行・副作用を捕捉するため。 |
| P10 | LLM 向け自己修復フィードバック | 拒否・確認発生時、理由と代替手段を返して AI に自律的な手段修正を促す。同じ拒否の繰り返しを避け、タスク完遂率を維持するため。 |

## 5. アーキテクチャ

### 5.1 全体構成

```
┌ 設定レイヤ（上位ほど強い）────────────────────┐
│ Layer 0-A : .claude/settings.json      （Claude Code が強制）│
│ Layer 0-B : Hook 組み込み不変ルール      （コード固定・3 パス）│
│ Layer 1   : .claude/hooks/config.yaml   （人間が PR で管理）  │
│ Layer 2   : .current-ticket.md          （AI 生成 / 人間承認）│
│ Layer 3   : 環境変数 TICKET_GUARD_*      （実行時）           │
└──────────────────────────────────────────────┘
                    │
                    ▼ 宣言済み／未宣言の区別 + config_hash 算出
┌ セッション開始処理 ──────────────────────────┐
│  - Hook スクリプト完全性検証                    │
│  - チケット完全性検証（承認台帳とのハッシュ照合） │
│  - 昇格試行 / 逸脱の検出 → 起動時レポート表示 + LLM 通知 │
└──────────────────────────────────────────────┘
                    │
                    ▼
┌ 1. PreToolUse Hook ─────────────────────────┐
│                                               │
│  Stage 1: 全チェック完走（根拠の収集）           │
│    ① Layer 0-B 不変 deny 照合                  │
│    ② sandbox_root 境界検査                     │
│    ③ ツール権限判定                            │
│    ④ パス権限判定（read / write / exec 分離）   │
│    ⑤ シェル構文パース（演算子/削除/移動/sed/実行）│
│    ⑥ DB 破壊キーワード検知                      │
│    ⑦ deny_commands 正規表現照合                 │
│              ↓                                 │
│    Decision { deny[], ask_explicit[], ask_implicit[] } │
│                                               │
│  Stage 2: 承認キャッシュ照会（deny[] が空の場合のみ）│
│  Stage 3: ユーザー確認 → キャッシュ登録          │
└──────────────────────────────────────────────┘
                    │ allow
                    ▼
              [ ツール実行 ]
                    │
                    ▼
┌ 2. PostToolUse Hook ────────────────────────┐
│  - git status --porcelain による差分検証        │
│  - 保護領域（Layer0-B / Layer1 write:deny）の汚染検知 │
│  - 原因となったキャッシュエントリの無効化         │
│  - additionalContext 注入で LLM に復元指示       │
└──────────────────────────────────────────────┘

┌ 永続データ ──────────────────────────────────┐
│  - approvals-<session_id>.json    （承認キャッシュ 0600）│
│  - .claude/approved-tickets.jsonl （承認台帳 / 不変deny）│
│  - .claude/hooks/.integrity       （Hook ハッシュ）      │
│  - 監査ログ                                              │
└──────────────────────────────────────────────┘
```

### 5.2 Layer 0-A と Hook の関係

`.claude/settings.json` の permissions は Claude Code 本体が評価する。Hook はその内側で動作し、さらに絞ることしかできない。

```
┌──────────────────────────┐
│ ツール呼び出し ─→│ Layer 0-A: settings.json      │
│                  │   permissions.deny に該当？    │─→ 🔴 遮断（Hook 到達せず）
│                  └──────────────────────────┘
│                            │ 通過
│                            ▼
│                  ┌──────────────────────────┐
│                  │ PreToolUse Hook（本システム）  │─→ deny / ask / allow
│                  └──────────────────────────┘
```

役割分担

| レイヤ | 担う判断 |
|---|---|
| Layer 0-A（settings.json） | 「このプロジェクトではそもそもこのツールを使わせない」というツール単位の恒久的遮断。例：WebFetch、NotebookEdit |
| 本 Hook | ツール内部の引数・対象・構造に依存した動的判断。settings.json では表現できないコマンド構造解析・パス別権限・チケットスコープ |

Layer 0-A は Hook が起動する前に評価されるため、Hook のバグや設定ミスの影響を受けない。恒久的に不要なツールは settings.json 側で落とすことを推奨する。

## 6. Layer構成の概要

### 6.1

| Layer | ソース | 変更主体 | 変更頻度 | 信頼度 |
|---|---|---|---|---|
| 0-B | Hookコード内ハードコード | 開発者(リリース) | 極低 | 最高 |
| 1 | .claude/hooks/config.yaml | 人間(PR + Code Ownerレビュー) | 低 | 高 |
| 2 | .current-ticket.md frontmatter | AI生成→人間承認 | 作業ごと | 低 |
| 3 | 環境変数 TICKET_GUARD_* | 実行者・CI | 毎回 | 中 |

### 6.2 合成規則の総表

| 設定項目 | 合成規則 | ticketが緩和可能か |
|---|---|---|
| Layer 0-A permissions.deny | Claude Codeが強制 | 不可(Hook到達前に遮断) |
| Layer 0-B不変deny(3パス) | コード固定 | 不可(変更手段が存在しない) |
| sandbox_root / sandbox_extra_roots | Layer1、immutable推奨 | 不可 |
| tools(Layer1に記載あり) | strictest(project値, ticket値) | 不可(縮小のみ) |
| tools(Layer1に記載なし) | ticket値をそのまま採用。無指定ならdefault_tool_ceiling | 可 |
| target_directories(Layer1に該当ルールあり) | strictest(project値, ticket値) | 不可(縮小のみ) |
| target_directories(Layer1に該当ルールなし) | ticket値をそのまま採用。無指定なら暗黙的ask | 可(sandbox内に限る) |
| deny_commands | 全Layerの配列結合(追加のみ) | 不可(削除不能) |
| approval_cache.* | max_*による上限クランプ | 不可(縮小のみ) |
| approval_cache.prefix_denylist | 配列結合(追加のみ) | 不可 |
| approval_cache.content_hash_commands | 配列結合(追加のみ) | 不可 |
| expected_roots | Layer1のみ(判定に影響しない) | ― |
| approval_ui | Layer1、immutable推奨 | 不可 |
| immutable | Layer1のみ。自己参照的に保護 | 不可 |

### 6.3 strictest() の定義

```
strictest(a, b) = より厳しい方

厳しさ順序(左が厳しい):
  判定値      : deny < ask < allow
  cache mode  : off < implicit < all
  path_scope  : exact < prefix
  数値上限    : min(a, b)
  真偽(制約)  : true(制約有効)が厳しい
```

### 6.4 immutableセクション

Layer 1に「この設定は下位レイヤから一切変更を受け付けない」を宣言する文法を用意する。運用者が「ここは絶対に動かさない」という意図を設定ファイル上で表現できるようにするため。

```yaml
immutable:
  - sandbox_root
  - tools                              # セクション丸ごと
  - tools.Bash                         # 個別キー
  - target_directories.write.".env"
  - approval_cache
  - approval_ui
  - immutable                          # 自己保護
```

| 挙動 | 内容 |
|---|---|
| 対象キーへの下位レイヤ記述 | マージ時に完全に無視 |
| 無視した記述 | §16のレポートに記録(緩和方向・縮小方向を問わず記録) |
| immutable自体への記述 | 下位レイヤからの追記・削除は不可 |

### 6.5 config_hash

統合後の設定ツリー全体を正規化(キーソート・空白正規化・コメント除去)してシリアライズし、SHA-256を取る。

含めるもの:Layer 0-Bのバージョン識別子/Layer 1の全内容/Layer 2のfrontmatter全内容/Layer 3の有効値(クランプ後)

| 用途 | 内容 |
|---|---|
| 承認キャッシュの失効判定 | 値が変われば全エントリを破棄(§14.9) |
| 監査ログの相関キー | どの設定下での判定かを特定 |

---

## 7. Layer 0:プラットフォーム層と組み込み不変ルール

### 7.1 Layer 0-A:.claude/settings.json

Claude Code本体が評価する権限設定。Hookより外側で強制されるため、Hookのバグ・設定ミス・Hook自体の改変の影響を受けない最も硬い層である。

```json
{
  "permissions": {
    "deny": [
      "WebFetch",                       // 恒久的に使わせないツール
      "Bash(sudo:*)",
      "Bash(curl:*)",
      "Read(./.env)",
      "Read(./secrets/**)"
    ],
    "ask": [
      "Bash(git push:*)"
    ]
  },
  "hooks": {
    "PreToolUse":  [{ "matcher": "*", "hooks": [{ "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/pre_tool_use.py" }] }],
    "PostToolUse": [{ "matcher": "Bash|Write|Edit|MultiEdit", "hooks": [{ "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/post_tool_use.py" }] }]
  }
}
```

**この層に置くべきもの**

| 種別 | 例 | 理由 |
|---|---|---|
| 恒久的に使わないツール | WebFetch, NotebookEdit | Hookによる動的判断が不要であり、より外側で落としたほうが確実なため |
| 絶対に触らせない静的パス | Read(./secrets/**) | 二重防御。Hookが無効化されても遮断が残るため |
| 環境依存の危険コマンド | Bash(sudo:*) | 同上 |

**この層に置かないもの**:チケットごとに変動する権限、コマンド構造に依存する判断。これらは静的なパターン記述では表現できないためHookが担う。

settings.json自体の書き換え保護はLayer 1に委ねる(§8.5)。ただしClaude Codeは原則としてセッション開始時に設定を読み込むため、セッション途中の書き換えが即座に反映されるとは限らない。この時間差は緩和要因ではあるが保証ではないため、Layer 1でのwrite deny宣言を強く推奨する。

### 7.2 Layer 0-B:組み込み不変deny

この3つに限定する理由:いずれも「本システムの判定結果そのものを偽装できる」対象であり、書き換えを許すとシステムの出力が信用できなくなる。逆に言えば、それ以外の保護対象はプロジェクトごとに正当な編集需要がありうるため、コード固定にせずプロジェクト設定に委ねる。

| パス | access | 保護理由 |
|---|---|---|
| .claude/approved-tickets.jsonl | write | 未承認チケットを承認済みに偽装可能になるため |
| .git/** | write | pre-commit等への任意コード注入と履歴改竄が可能になり、PostToolUseの差分検証(§18)の前提が崩れるため |
| ${XDG_RUNTIME_DIR}/ticket-guard/** | write | 任意の承認エントリを注入して確認をすべて迂回できるため |

**.git/** write denyの適用範囲**

Gitバイナリ経由の通常操作は影響を受けない。遮断対象はファイルパスとしての直接書き込みである。

| 操作 | 判定 |
|---|---|
| git commit -m "..." / git add . / git checkout | 影響なし |
| Write: .git/config | 🔴 deny |
| sed -i 's/x/y/' .git/hooks/pre-commit | 🔴 deny |
| echo "..." > .git/hooks/pre-push | 🔴 deny(リダイレクト遮断でも捕捉) |

### 7.3 .claude/** をプロジェクト設定に委ねる理由

.claude/配下には以下が混在する。

| 対象 | 正当な編集需要 |
|---|---|
| .claude/skills/** | エージェント自身がスキル定義を追加・改善する運用がある |
| .claude/commands/** | スラッシュコマンドの追加 |
| .claude/agents/** | サブエージェント定義の調整 |
| .claude/hooks/** | 本システム自体の改修 |
| .claude/settings.json | 権限設定の変更 |

これらを一律にコード固定で禁止すると、正当な運用が阻害される。したがって保護範囲の決定はプロジェクトに委ねる。

**プロジェクトがガードを外した場合の担保**

| 経路 | 担保手段 |
|---|---|
| config.yamlから保護宣言を削除する | Layer 1の変更はPR + Code Ownerレビューを通る |
| チケットが.claude/**へのwrite allowを要求する | 承認ゲートでリスクスコア加点+逸脱表示(§16, §17) |
| 実際にHookが書き換えられた | 次回セッション開始時の完全性検証で人間の確認を強制(§7.4) |
| 設定が書き換えられた | config_hash変更により全承認キャッシュが失効(§14.9) |

### 7.4 Hookスクリプトの完全性検証

```
起動時:
 1. Hookスクリプト群(*.py)とconfig.yamlのハッシュを算出
 2. .claude/hooks/.integrity と照合
    ├ 一致    → 通常起動
    ├ 不一致  → 【人間の確認ゲート】
    │            差分内容を提示し、承認された場合のみ
    │            .integrityを更新して続行。
    │            承認されなければ全操作deny。
    │            承認キャッシュは全件破棄。
    └ ファイル無し → 初回として現在のハッシュを記録し、警告を表示
```

フェイルクローズではなく人間の確認ゲートとする理由:Hookの改修はプロジェクトの正当な運用として発生しうる。無条件のフェイルクローズは開発を停止させる。一方、無警告の通過は改変の検知機会を失う。したがって「必ず人間の目に触れさせる」設計とする。

hook_integrity: strict をLayer 1に設定した場合のみ、不一致時に無条件フェイルクローズする(本番近傍・監査対象環境向け)。

---

## 8. Layer 1:プロジェクト設定

.claude/hooks/config.yaml。人間がPR + Code Ownerレビューを経て変更する、明示宣言による権限上限の定義。

### 8.1 全体構造

```yaml
sandbox_root: "."                        # ①サンドボックス境界
sandbox_extra_roots: []
default_tool_ceiling: ask                # ②ツール権限
tools: { ... }
expected_roots: { ... }                  # ③想定委譲範囲(可視化専用)
target_directories: { ... }              # ④絶対防衛線
deny_commands: [ ... ]
approval_cache: { ... }                  # ⑤承認キャッシュ
approval_ui: { ... }                     # ⑥チケット承認UI
hook_integrity: warn                     # ⑦完全性検証モード
immutable: [ ... ]                       # ⑧変更不可宣言
```

### 8.2 ①sandbox_root ― プロジェクト外への脱出防止

未宣言領域をチケットに委譲する設計(P3)を採る以上、「委譲してよい世界の外縁」を定義する境界が必須となる。これがsandbox_rootである。

```yaml
sandbox_root: "."                        # 既定:プロジェクトルート
sandbox_extra_roots:                     # 明示的に許可する外部領域(既定:空)
  - "/tmp/ticket-guard-workspace"
```

| 対象 | write | read | exec |
|---|---|---|---|
| sandbox_root配下 | 通常判定 | 通常判定 | 通常判定 |
| sandbox_extra_roots配下 | 通常判定 | 通常判定 | 通常判定 |
| それ以外 | deny固定 | ask固定 | deny固定 |

sandbox外のreadをdenyではなくaskとする理由:システムライブラリやツールチェーン、他プロジェクトの参照など正当な読み取りが発生しうるため、人間の判断に委ねる。書き込みと実行には正当な需要が乏しいためdenyとする。

**シンボリックリンクの扱い(T-6)**
- パス正規化はシンボリックリンクの実体解決後に行う。src/link → /etc/passwd は /etc/passwd として評価され、sandbox外→write denyとなる。
- 正規化前後でsandboxの内外が変化した場合はIMPL_SYMLINK_ESCAPE(暗黙ask)を必ず追加し、キャッシュ対象外とする。境界を跨ぐアクセスは、結果的に許可される場合でも人間が毎回認識すべきであるため。

**sandbox_extra_rootsの禁止値(起動時にエラー)**

`"/" "/etc" "/usr" "/var" "/bin" "/sbin" "$HOME" ".." "~"`

### 8.3 ②tools ― ツール権限

```
Layer1.tools[T] に記載あり → strictest( Layer1値, ticket値 )
                              ※ ticket無指定ならLayer1値をそのまま採用
Layer1.tools[T] に記載なし → ticketに指定あり → その値
                              ticket無指定       → default_tool_ceiling
```

```yaml
default_tool_ceiling: ask     # project / ticket ともに言及しないツールの扱い

tools:
  Read:        allow
  Glob:        allow
  Grep:        allow
  Edit:        allow
  Write:       allow
  Bash:        allow     # 個別コマンドはdeny_commands / 構文解析で制御
  WebSearch:   ask
  Task:        ask
```

| Layer1 | ticket | 実効 | 説明 |
|---|---|---|---|
| allow | (未指定) | 🟢 allow | ticketの沈黙は「縮小しない」を意味する |
| allow | allow | 🟢 allow | |
| allow | ask | 🟠 ask | 縮小は有効 |
| ask | allow | 🟠 ask | 明示宣言は緩められない(T-1) |
| deny | allow | 🔴 deny | 同上 |
| (未記載) | allow | 🟢 allow | 未宣言領域の委譲(P3) |
| (未記載) | (未指定) | 🟠 ask | default_tool_ceiling |

ticket無指定を「縮小しない」と解釈する理由:チケットの役割は必要な権限の宣言であって、使用しないツールをすべて列挙させることではない。無指定をaskとすると、AIが全ツールを機械的に列挙するチケットを生成するようになり、承認画面の情報量が増えてレビュー品質が下がる。

帰結:ツールを恒久的に制限したい場合、Layer 1のtoolsに明示的に記載するか、Layer 0-Aのsettings.jsonで落とす必要がある。default_tool_ceilingはチケットも沈黙している場合のフォールバックにすぎない。

### 8.4 ③expected_roots ― 想定委譲範囲(可視化専用)

権限判定には一切影響しない。チケットが宣言したallowがこの範囲を逸脱した場合に、承認画面での強調表示・リスクスコア加点・キャッシュ粒度の降格を行うための基準である。

```yaml
expected_roots:
  read:  ["src", "tests", "docs", "public"]
  write: ["src", "tests"]
  exec:  ["node_modules/.bin", "scripts"]
```

| 用途 | 効果 |
|---|---|
| 承認UI(§17.2) | 範囲外へのallowを「想定外領域」として強調表示 |
| リスクスコア(§17.3) | 範囲外1件につき+15 |
| 起動時レポート(§16.3) | SCOPE_DEVIATIONとして列挙 |
| 承認キャッシュ(§14.5) | 範囲外はprefix→exactに強制降格し、広域承認の生成を防ぐ |

判定に影響させない理由:範囲外をaskに丸める設計は、列挙漏れのたびに作業が止まり確認疲れを招く。一方、逸脱の可視化だけであれば運用コストなしに列挙漏れを検知できる。強制が必要な場合はtarget_directoriesに明示ルールを書くという役割分担とする。

**厳格モード(オプトイン)**

```
strict_delegation: false  # 既定
```

trueにするとexpected_rootsが権限判定に作用し、範囲外へのチケットallowはaskに丸められる。本番近傍・監査対象環境で、確認疲れを許容してでも委譲範囲を強制したい場合に使用する。

### 8.5 ④target_directories / deny_commands ― 絶対防衛線

チケットから緩められない制約はここに書く。ここに書かれていない領域はチケットに委譲されるため、守るべき対象の列挙品質が防御力を直接決定する。

```yaml
target_directories:
  read:
    ".env": deny
    ".env.*": deny
    "secrets": deny
    "infra/production": deny
    "config":
      decision: ask
      ask_once: true
  write:
    # ― 認証情報・インフラ ―
    ".env": deny
    ".env.*": deny
    "secrets": deny
    "infra": deny
    "docs": deny
    # ― 本システム自身の保護(推奨) ―
    ".claude/hooks": deny
    ".claude/settings.json": deny
    ".claude/settings.local.json": deny
    ".current-ticket.md": deny
    # ― 依存関係・マイグレーション ―
    "package-lock.json": ask
    "migrations": ask
    "node_modules": deny

  exec:
    ".claude": deny     # 設定ディレクトリ内スクリプトの実行禁止(推奨)

deny_commands:
  - "aws\s+rds\s+(delete-db-cluster|delete-db-instance)"
  - "terraform\s+(destroy|apply)"
  - "kubectl\s+delete\s+(ns|namespace)"
  - "gh\s+(repo|secret)\s+delete"
  - "npm\s+publish"
  - "git\s+push\s+.*--force"
  - "git\s+reset\s+--hard"
```

.claude/hooks / settings.json / .current-ticket.md を推奨テンプレートに含める理由:これらはコード固定の不変ルールから外した対象であるが、大多数のプロジェクトでは書き換えを許す必要がない。既定で保護し、必要なプロジェクトだけが意図的に外す構成とする。.claude/skills等はテンプレートに含めないため、スキル編集は既定で可能である。

**ルール記述形式**

| 形式 | 記法 | 意味 |
|---|---|---|
| スカラー | "src": ask | decision: ask, ask_once: false と等価 |
| オブジェクト | "config": { decision: ask, ask_once: true } | 明示的にオプション指定 |

| フィールド | 値 | 既定 | 説明 |
|---|---|---|---|
| decision | allow / ask / deny | 必須 | 判定結果 |
| ask_once | true / false | false | decision: askのとき、明示的askをキャッシュ対象に含めるか(§14.3) |

**パスパターン**

| 記法 | 意味 | 例 |
|---|---|---|
| "src" | プレフィックス一致(配下すべて) | src/a.ts, src/b/c.ts |
| "src/config" | より深いプレフィックス(最長一致で優先) | src/config/db.json |
| ".env.*" | globパターン(同階層のみ) | .env.local, .env.production |
| "**/node_modules" | 再帰glob | 任意階層のnode_modules |

アクセス種別の分離:read / write / execを独立したツリーで管理する。「読めるが書けない」(docs)「読めるが実行できない」(scripts)のような非対称な権限を表現する必要があるため。

### 8.6 ⑤approval_cache

```yaml
approval_cache:
  # ― 既定値(ticket / envが縮小可能) ―
  mode: implicit
  path_scope: prefix
  ttl_minutes: 60
  max_entries: 100
  negative_cache: true

  # ― 上限(ticket / envはこれを超えられない) ―
  max_mode: implicit
  max_ttl_minutes: 60
  max_path_scope: prefix
  max_entries_limit: 100
  force_disable_when_non_interactive: true

  # ― 追加のみ可能(削除不可) ―
  prefix_denylist: ["/", "/etc", "/usr", "/var", "$HOME"]
  content_hash_commands:
    [bash, sh, zsh, python, python3, node, ruby, source, psql, mysql, kubectl]
```

**クランプ規則**

```
effective_mode        = strictest_mode(requested, max_mode)      # off < implicit < all
effective_ttl         = min(requested, max_ttl_minutes)
effective_scope       = strictest(requested, max_path_scope)     # exact < prefix
effective_max_entries = min(requested, max_entries_limit)
```

prefix_denylistとcontent_hash_commandsを「追加のみ可能」とする理由:これらはセキュリティ制約であり、下位レイヤから削除できると防御が無効化されるため。

### 8.7 ⑥⑦⑧その他

```yaml
approval_ui:
  high_risk_threshold: 40                     # このスコア超で二段階承認
  require_id_input_on_high_risk: true
  show_diff_from_previous_ticket: true
  max_ticket_rules: 40                        # ルール総数の上限(超過でチケット拒否)
  require_rationale_for_write_allow: true

hook_integrity: warn        # warn(人間の確認ゲート) / strict(フェイルクローズ)

immutable:
  - sandbox_root
  - tools
  - target_directories
  - approval_cache
  - approval_ui
  - hook_integrity
  - immutable
```

---

## 9. Layer 2:チケット設定

.current-ticket.md のYAML Frontmatter。AIが生成し、人間が承認する。

### 9.1 構造

```yaml
---
ticket: PROJ-1234
title: ユーザー設定画面のリファクタリング
rationale: |
  src/components/Settings配下のコンポーネント分割を行う。
  設定値の読み込みロジック確認のためconfig/のreadが必要。

tools:
  Bash: ask                # 今回はコマンド実行を慎重に扱うため自主的に縮小

deny_commands:
  - "npm\s+run\s+deploy"        # 追加のみ可能

target_directories:
  read:
    "src": allow
    "docs": allow
  write:
    "src/components/Settings": allow
    "src/components": ask
---

## 作業内容
...(本文は権限判定に影響しない)
```

### 9.2 チケットの権限範囲

| できること | できないこと |
|---|---|
| ✅未宣言領域(sandbox内)にallowを宣言する | ❌Layer 0-A / 0-Bのdenyを覆す |
| ✅上位レイヤの宣言より厳しいask / denyを設定する | ❌Layer 1が明示宣言したdenyをask/allowにする |
| ✅deny_commandsにパターンを追加する | ❌Layer 1が明示宣言したaskをallowにする |
| ✅approval_cacheをより厳しくする | ❌deny_commandsからパターンを削除する |
| ✅記載のないツールにallowを宣言する | ❌approval_cacheを緩める |
| ― | ❌sandbox外にwrite/execのallowを置く |
| ― | ❌sandbox_root / expected_roots / immutable / approval_uiを変更する |

### 9.3 チケット生成時にAIが守るべきガイドライン

CLAUDE.mdに記載してAIに遵守させる。これは補助であり、Layer 1の明示宣言のみが強制力を持つ。

```
## チケット生成ルール

1. 権限は「作業に必要な最小限」を宣言すること。迷ったら狭く。
2. write allowは、実際に編集するディレクトリだけに限定すること。
   親ディレクトリを一括でallowにしない。
3. .claude/hooks/config.yamlのexpected_rootsを必ず読み、
   その範囲内でのみallowを宣言すること。
   範囲外が必要な場合はrationaleにその理由を明記すること。
4. toolsは、使用するツールのうち制限が必要なものだけを記載すること。
   すべてを機械的に列挙しない。
5. ルール総数が20件を超える場合、作業の分割を検討すること。
6. .claude/配下・.git/配下へのwrite allowは、
   それ自体が作業目的である場合を除いて宣言しないこと。
```

### 9.4 チケットのバリデーション(読み込み時)

| # | 検証項目 | 違反時の挙動 |
|---|---|---|
| 1 | YAMLとしてparse可能か | チケット読み込み失敗→全操作askにフォールバック |
| 2 | ticketフィールドが存在するか | 同上 |
| 3 | ルール総数 ≤ max_ticket_rules | チケット拒否→再生成を要求 |
| 4 | パスに ../絶対パス/~/$ を含まないか | 該当ルールを無視+INVALID_PATHとして記録 |
| 5 | immutable対象キーへの記述がないか | 該当記述を無視+IMMUTABLE_IGNOREDとして記録 |
| 6 | sandbox_root/expected_roots/approval_uiへの記述がないか | 同上 |
| 7 | 承認台帳のハッシュと一致するか | 未承認扱い→§17.5の降格処理 |

ルール総数に上限を設ける理由:大量のルールを列挙して人間のレビューを困難にし、その中に過剰権限を紛れ込ませる手口を防ぐため。

---

## 10. Layer 3:環境変数

### 10.1 一覧

| 環境変数 | 値 | 既定 | 方向性 |
|---|---|---|---|
| TICKET_GUARD_APPROVAL_CACHE | off / implicit / all | implicit | 縮小は即適用、緩和はmax_modeでクランプ |
| TICKET_GUARD_APPROVAL_SCOPE | exact / prefix | prefix | 同上(max_path_scope) |
| TICKET_GUARD_APPROVAL_TTL | 整数(分) | 60 | 同上(max_ttl_minutes) |
| TICKET_GUARD_APPROVAL_MAX_ENTRIES | 整数 | 100 | 同上(max_entries_limit) |
| TICKET_GUARD_ASK_FALLBACK | deny / allow | deny | 非対話時のaskの扱い |
| TICKET_GUARD_LOG_LEVEL | error/warn/info/debug | warn | 監査ログ詳細度 |
| TICKET_GUARD_STRICT | 0 / 1 | 0 | 1で全キャッシュ無効+全askを厳格化 |

### 10.2 上限クランプの適用

```
縮小方向の指定 → 即座に適用(最優先)
緩和方向の指定 → Layer 1の上限でクランプ+逸脱として記録
```

環境変数を無条件に最優先としない理由:環境変数はCI設定・シェル初期化ファイル・依存ツールなど多様な経路から設定されうるため、プロジェクトが定めた上限を超える緩和を許すと防御が容易に無効化されるため。

### 10.3 TICKET_GUARD_APPROVAL_CACHE

| 値 | 明示的ask | 暗黙的ask | 用途 |
|---|---|---|---|
| off | キャッシュしない | キャッシュしない | 監査対象作業、本番環境近傍、キャッシュ挙動のデバッグ時 |
| implicit(既定) | キャッシュしない(ask_once: trueの項目のみ例外) | キャッシュする | 通常の開発作業 |
| all | キャッシュする(ask_onceを無視) | キャッシュする | 大量の反復作業。信頼できる環境のみ |

既定をimplicitとする理由:定義漏れ由来の確認疲れを抑制しつつ、設定者が意図的に置いた確認ポイントは維持するというP6の目的に最も合致するため。allを指定してもdenyは一切キャッシュ・緩和されない(P8)。

### 10.4 TICKET_GUARD_APPROVAL_SCOPE

ファイルパスを対象とする承認のキャッシュ一致粒度の既定値を決める。

| 値 | 動作 | 例:Read: /repo/tmp/build/out/report.jsonを承認 |
|---|---|---|
| exact | そのファイルパスのみ | report.jsonのみヒット |
| prefix(既定) | 直上の親ディレクトリ配下 | /repo/tmp/build/out/配下すべてがヒット |

既定をprefixとする理由:AIは同一ディレクトリ内の複数ファイルを連続して操作することが多く、exactではヒット率が低く確認疲れの抑制効果が得られないため。

**prefixの制約**

| 制約 | 理由 |
|---|---|
| 丸め上げるのは直上の親ディレクトリ1階層のみ。祖先には遡らない | 深いパスの承認が広域承認に化けることを防ぐため |
| 対象がディレクトリならそのディレクトリ自身をsubjectとする | 同上 |
| 親がprefix_denylistに該当する場合exactへ降格 | システム領域への広域承認を防ぐため |
| expected_roots外はexactへ降格 | 想定外領域への広域承認を防ぐため |
| content_hash_commands該当時は常にexact | 内容ハッシュによる同一性保証と両立しないため |

対話セッションでは環境変数の値がプロンプト上の既定選択肢を決めるだけで、ユーザーは個別に選び直せる。

### 10.5 設定例

```bash
# 【厳格】監査対象作業
export TICKET_GUARD_STRICT=1

# 【既定】通常の開発
export TICKET_GUARD_APPROVAL_CACHE=implicit
export TICKET_GUARD_APPROVAL_SCOPE=prefix

# 【慎重】キャッシュは使うがファイル単位で厳密に
export TICKET_GUARD_APPROVAL_SCOPE=exact

# 【CI】キャッシュは自動無効化される
export TICKET_GUARD_ASK_FALLBACK=deny
```

---

## 11. 権限判定の算出仕様

### 11.1 パス権限の決定順序

上から順に評価し、最初に該当したものを採用する。

| 順 | 条件 | 判定 | 種別 |
|---|---|---|---|
| 1 | Layer 0-B不変denyに該当 | deny | hard |
| 2 | sandbox外 | write/exec→deny、read→ask(明示的) | hard |
| 3 | Layer 1ツリー単独で最長一致するルールが存在 | strictest( Layer1値, ticket/env値 ) ※ticket無指定ならLayer1値 | hard |
| 4 | Layer 1に該当なし、ticket/envに明示ルールあり | その値 | 委譲 |
| 5 | Layer 1にもticket/envにも該当なし | ask(暗黙的) | フォールバック |
| 6 | strict_delegation: trueかつ④の値がallowかつexpected_roots外 | ask(暗黙的)に丸める | オプトイン |

順3の判定をLayer 1ツリー単独で行う理由(T-2への対処):マージ後のツリーで最長一致を取ると、チケットがsecrets/keys: allowのようなより深いキーを追加することで、Layer 1のsecrets: denyを回避できてしまう。Layer 1ツリーだけで最長一致を先に確定させることで、チケットが後から深いキーを追加してもLayer 1の宣言が必ず適用される。

### 11.2 ツール権限の決定順序

| 順 | 条件 | 判定 |
|---|---|---|
| 1 | Layer 0-A(settings.json)でdeny | Hook到達前に遮断 |
| 2 | Layer1.tools[T]に記載あり | strictest( Layer1値, ticket値 ) ※ticket無指定ならLayer1値 |
| 3 | 記載なし、ticketに指定あり | その値 |
| 4 | いずれも指定なし | default_tool_ceiling(既定ask、暗黙的) |

### 11.3 具体例による検証

**設定**

```yaml
# Layer 1
sandbox_root: "."
expected_roots:
  write: ["src", "tests"]
tools:
  Bash: ask
target_directories:
  read:  { "secrets": deny }
  write: { "secrets": deny, "docs": deny, ".claude/hooks": deny, "migrations": ask }
```

```yaml
# Layer 2(チケット)
tools:
  Bash: allow
  WebSearch: allow
target_directories:
  read:
    "secrets/keys": allow      # denyサブツリーのくり抜き試行
  write:
    "src/components": allow    # 正当な要求(expected_roots内)
    "tmp/scratch": allow       # 未宣言領域(expected_roots外)
    "migrations": allow        # Layer1の明示askを緩めようとする
    "/": allow                 # 広域
```

判定結果

---

## 12. PreToolUse判定ロジック

### 12.1 判定結果のデータ構造

すべてのチェックは判定値ではなく判定根拠のリストを返す(P5)。

```
Decision {
  deny:         [ Reason, ... ]
  ask_explicit: [ Reason, ... ]
  ask_implicit: [ Reason, ... ]
}

Reason {
  code:      reason_code       # 付録B
  access:    read | write | exec | tool
  subject:   正規化済みの対象
  layer:     platform | builtin | project | ticket | env
  detail:    人間向け説明テキスト
  hint:      LLM向けの代替手段提案
  cacheable: bool              # §14.3で決定
}
```

**最終判定**

```
deny[] が空でない        → deny
それ以外でask_* が空でない → ask(キャッシュ照会へ)
すべて空                 → allow
```

根拠を構造化して保持する理由:同一の判定結果でも、キャッシュキーの生成・監査ログの記録・LLMへの説明生成という3つの異なる用途があり、それらを一貫した情報源から導出するため。

すべてのチェックを完走させる理由:最初のdenyで打ち切ると、AIは1つずつ問題を修正して再試行し、往復回数が増える。全根拠をまとめて返すことで、AIは一度に手段を組み替えられる(P10)。

### 12.2 パス権限判定

| ツール種別 | 対象ツール | 参照するツリー | access |
|---|---|---|---|
| 参照系 | Read, Glob, Grep | target_directories.read | read |
| 編集系 | Write, Edit, MultiEdit | target_directories.write | write |
| Bash実行対象 | bash x.sh, python x.py 等 | target_directories.exec → 未定義時はreadにフォールバック | exec |
