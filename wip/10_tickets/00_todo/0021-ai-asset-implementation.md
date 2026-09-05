---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0019", "0020"]
executor: opus
human_review: {required: false, reason: "全体計画書の方針（差分 3）"}
adversarial_review: {required: true, reason: "全体計画書の方針（差分 3: フェーズごとに 1 回）"}
allow:
  write: [".claude/hooks/**"]
  ops: ["hook-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0021 S4 中核 c: 拒否側フック 2 本と A1-6 を閉じる機械テスト

## 目的

workflow-guard の宣言範囲の強制と workflow-state-guard の保護対象の畳み込みを作業ツリーごとに一意にし、受け入れ条件 A1-6（worktree 側のチケットで判定されること）を負のコントロール付きの機械テストで閉じる。

## DoD

- [ ] workflow-guard.sh が仕様書 10_spec/hooks/20-PreToolUse/workflow-guard.md の概要（一意性の 2 点）・制御方式 1・2・5・6 のとおりになっている（宣言範囲の強制は「その作業ツリーの作業中チケット 1 枚」で一意に決まり、WF207 は「1 作業ツリーあたり 2 枚」を指す）（根拠: ）
- [ ] workflow-state-guard.sh が仕様書 10_spec/hooks/20-PreToolUse/workflow-state-guard.md「対象パスの畳み込み」・制御方式 2・3 のとおりになっている（作業ツリーをまたぐ絶対パスの保護は無条件）（根拠: ）
- [ ] 機械テスト WG-T19 が通る（run-tests.sh --filter '*test_workflow_guard*'）。本流 10_doing/ 0 枚・worktree 1 枚を**テスト自身が assert してから**判定を呼び、worktree 側チケットの宣言で判定される（根拠: ）
- [ ] 機械テスト WG-T20（WG-T19 の負のコントロール）が通る。本流 1 枚・worktree 0 枚で cwd=worktree のとき判定に入らない。枚数もテストが assert する（根拠: ）
- [ ] 機械テスト WG-T21 と WG-T14 が通る（worktree.sh の置き場を指す引数は WF209 にならず allow / 同じ行の他のパス引数と提供コマンドの引数パスは通常判定）（根拠: ）
- [ ] 機械テスト SG-T12 と SG-T13 が通る（run-tests.sh --filter '*test_workflow_state_guard*'。他の作業ツリーの保護対象への絶対パス書き込みが保護され、集合を読めないときは WF309）（根拠: ）
- [ ] 既存の WG-T01〜WG-T18 と SG-T01〜SG-T11 が引き続き通る（回帰）（根拠: ）
- [ ] 変更直後に bash .claude/skills/20-common-step-commit-push/scripts/commit.sh を 1 回通し、制御方式 5・6 の経路で機構が自分を止めないことを確かめた（ロックアウト対策）（根拠: ）
- [ ] 実装結果レポートに本チケットの節が追記され、仕様と食い違った点は仕様を直さず「仕様からの逸脱」に記録されている（根拠: ）

## 作業内容

- 負のコントロールの前提をテスト自身が枚数の assert で作る形を崩さない（調査の実測が空振りした原因は、どの作業ツリーにも作業中チケットが 0 枚で入口の exit 0 に落ちたこと）
- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md の S4 と「ロックアウト対策」の S4 行に従う

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
