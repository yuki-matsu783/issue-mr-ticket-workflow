---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0012", "0013"]
executor: opus
human_review: {required: false, reason: "全体計画書の方針（差分 3）"}
adversarial_review: {required: true, reason: "全体計画書の方針（差分 3: フェーズごとに 1 回）"}
allow:
  write: ["wip/**", ".claude/docs/**"]
  ops: ["read", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0014 AI アセット設計: 20-common-step-worktree の新設と、合流手順・採番・push の一本化

## 目的

設計計画書（wip/20_plans/0010-ai-asset-design-plan.md）の結論方針 P4・P4a・P5・P10 と受け入れ条件 A2・A6 を .claude/docs/ の正史へ落とす。worktree の作成・一覧・合流・片付けを担う共通ステップを要件と仕様の対で新設し、合流をタスクの切れ目に固定して提供コマンド経由でのみ行う手順を定め、チケットの採番と push を本流に一本化する。

## DoD

- [ ] 00_requirement/skills/20-common-step-worktree.md と 10_spec/skills/20-common-step-worktree.md が 1:1 の対で新規に作られ、テンプレートに沿った章順で書かれている（根拠: ）
- [ ] worktree.sh の 4 サブコマンド（add / list / merge / remove）の引数・出力・判定順が、実装とテストが推測なしに作れる粒度で仕様に書かれている。add は既定の置き場をリポジトリの外に取り、logs/ の初期化で進行状態を複製しないことが書かれている（根拠: ）
- [ ] 合流手順（A6）が定まっている: 単位はタスクの切れ目 / 実行者は AI（worktree.sh merge 経由）/ 前提検査（作業中 0 枚・未コミット無し・同一 issue のブランチ）/ 解けない衝突は中断して失敗終了 / 合流の記録先（根拠: ）
- [ ] 20-common-step-ticket の要件・仕様に、ticket.sh create は本流でのみ実行でき作業ツリーでは拒否することが書かれ、エラー識別子とテスト ID が振られている（束 1 の 1）（根拠: ）
- [ ] 20-common-step-commit-push の要件・仕様に、push は本流でのみ行い作業ツリーからは拒否することが書かれ、テスト ID が振られている（根拠: ）
- [ ] フック共通仕様 §6 の採番台帳に worktree.sh の識別子の接頭辞と範囲が登録され、1 番号 1 原因になっている（根拠: ）
- [ ] DDR i0050-03（合流はタスクの切れ目に固定し提供コマンド経由でのみ行う）と i0050-05（採番は本流の計画タスクだけが行う）が作られ、却下した案と理由を持つ（根拠: ）
- [ ] 束 1 由来の記述（採番・合流・logs の用意）は「並列実施を行う場合」の条件付きで、worktree を 1 つ使うだけで成り立つ記述は無条件で書かれている（根拠: ）
- [ ] ヘッドレス実行の帰結（add / list / remove は進む、merge は解けない衝突で止まる、create と push の拒否は止まる）が要件定義書に書かれている（根拠: ）
- [ ] 0012・0013 が更新した文書（フック共通仕様 §2・§5・§7・§8 と DDR 5 本）を読み直したうえで書かれている（根拠: ）

## 作業内容

- 設計計画書の結論方針 P4・P4a・P5・P10 と文書一覧の 1・7・8 行目を読む
- 調査結果レポートの e25〜e34・e9〜e16・e21・設計への反映 8〜14・22〜24・27〜30 を根拠として読む
- 20-common-step-requirement / 20-common-step-spec の作法で書く（アセット本体は作らない）

## 作業ログ

### 現在地

- 未着手

### うまくいったこと

### うまくいかなかったこと

### 仕様からの逸脱

### 判断と根拠

### 拒否・確認・迂回の記録

### 使った AI アセットと効き目

### スコープ外で見つけたこと

### AI アセットに反映すべき内容

### 備考
