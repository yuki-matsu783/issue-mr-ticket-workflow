---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0020", "0021"]
executor: opus
human_review: {required: false, reason: "全体計画書の方針（差分 3）"}
adversarial_review: {required: true, reason: "全体計画書の方針（差分 3: フェーズごとに 1 回）"}
allow:
  write: ["wip/**", ".claude/skills/**", ".claude/evals/**"]
  ops: ["read", "remote-read", "build-test", "hook-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0023 S6 提供コマンド a: 20-common-step-worktree スキルと worktree.sh の新設

## 目的

受け入れ条件 A2・A6 の実体である worktree.sh（add / list / merge / remove）とスキル本体を新設し、合流手順・前提検査 6 項目・衝突時の中断・合流の記録を機械テストで固定する。「本流かどうかの判定」はこのスキルの仕様が正で、ticket.sh / push.sh はこれを共有する。

## DoD

- [ ] .claude/skills/20-common-step-worktree/SKILL.md と scripts/worktree.sh が仕様書 10_spec/skills/20-common-step-worktree.md「Script 処理」のとおりになっている（本流かどうかの判定・共通の入口 1〜3・add 1〜7・list 1〜3・merge 1〜6・remove 1〜7・合流の記録・WT001〜WT008）（根拠: ）
- [ ] 合流の記録が共有ルートの logs/worktree-merges.jsonl に 1 回 1 行で追記され、result が merged / up-to-date / aborted の 3 値になっている（同仕様「合流の記録」）（根拠: ）
- [ ] 機械テスト WT-T01〜WT-T12 が通る（bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*test_worktree*'）（根拠: ）
- [ ] WT-T01 が「add は logs/hooks/ と logs/sh/ だけを作り、進行状態 7 種（mr.json / review-state.json / merge-state.json / locks/ / usage/ / sessions/ / push-state.json）を 1 つも作らない」ことを固定している（根拠: ）
- [ ] WT-T05 が「前提検査 6 項目それぞれの未充足で git merge を 1 回も実行せずに止まる」ことを固定し、WT-T06 が「WT004・終了 1・--abort 済みで本流が合流前と同一」と負のコントロール（別の節の追記だけなら成功）を固定している（根拠: ）
- [ ] eval WT-E01・WT-E02・WT-E03 が .claude/evals/20-common-step-worktree.md に定義されている（入力・期待する振る舞い・判定方法。**実行しない**）（根拠: ）
- [ ] 機械テスト WG-T21 が引き続き通る（S4 で入れた置き場引数の例外を、S6 の実体で踏み直す）（根拠: ）
- [ ] SKILL.md の frontmatter が 20-common-step-ai-asset-creator の必須項目を満たし、プレースホルダ（{{ }} / TODO / TBD）が 0 件である（根拠: ）
- [ ] 実装結果レポートに本チケットの節が追記され、仕様と食い違った点は仕様を直さず「仕様からの逸脱」に記録されている（根拠: ）

## 作業内容

- remove は --force でも未コミットの差分を消さない仕様を先にテストで固定してから実体を書く（事故の防止）
- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md の S6 と「ロックアウト対策」の S6 行に従う
- WG-T21 の再確認は 0021（S4）が新設するテストに依存するので、predecessors に 0021 を入れてある
- 復旧は git checkout を使わない（checkout は _SC_GIT_READ_SUBCMDS に無く unknown → WF204）。git show <base_sha>:<パス> で内容を取り、Write ツールで書き戻す。書き戻し先（.claude/skills/** と .claude/evals/**）は本チケットの allow.write に入っている

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
