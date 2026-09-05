---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0018"]
executor: opus
human_review: {required: false, reason: "全体計画書の方針（差分 3）"}
adversarial_review: {required: true, reason: "全体計画書の方針（差分 3: フェーズごとに 1 回）"}
allow:
  write: ["wip/**", ".claude/hooks/**"]
  ops: ["read", "remote-read", "build-test", "hook-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0019 S2 中核 a: hook-common.sh の作業ツリーの三分・集合・畳み込み・共有ルート

## 目的

フック共通仕様 §2 の作業ツリーの三分（HOOK_ROOT / HOOK_WORKTREE / HOOK_SHARED_ROOT）・同一リポジトリの作業ツリーの集合・作業ツリーをまたぐパスの畳み込みと「判定できないときの倒し方」を hook-common.sh に実装し、値の往復になる呼び手 3 本の分岐（WF209 / WF309 / WF605）を同じチケットで揃える。

## DoD

- [ ] hook-common.sh が仕様書 フック共通仕様 §2「作業ツリーの三分」のとおりになっている（HOOK_SHARED_ROOT の値は HOOK_ROOT と同一に固定し、環境変数・設定ファイルからの上書きの口を作らない）（根拠: ）
- [ ] hook_worktrees が <HOOK_ROOT>/.git/worktrees/*/gitdir から集合を作り、git を呼ばない（glob と組み込みの読み込みだけ。stale な登録も集合に残す）（根拠: ）
- [ ] hook_rel_path が仕様書 §2「作業ツリーをまたぐパスの畳み込み」の 4 段（自ツリー → 共有ルート → 集合のいずれか → 畳めない）で判定し、正規化失敗と集合を読めないときは 4 に倒さず「判定できない」を返す（根拠: ）
- [ ] 呼び手 3 本が「判定できない」の規約どおりに分岐する: workflow-guard は WF209、workflow-state-guard は WF309（いずれも deny 側）、workflow-diff-check は WF605（案内側なので additionalContext）（根拠: ）
- [ ] logs/ の置き場が仕様書 §5 の根の列のとおりになっている（判定記録 decisions.jsonl と実行ログ logs/sh/ は作業ツリー側、進行状態・ロック・集計は共有ルート）（根拠: ）
- [ ] 機械テスト HK-T06・HK-T21・HK-T22 が通る（bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*test_hook_common*'）（根拠: ）
- [ ] hook-common.sh を読み込む全フックのテストが通る（run-tests.sh --filter '*hooks*'）（根拠: ）
- [ ] 変更直後に wip/tmp/ への Write を 1 回・Read を 1 回行い、機構が自分を止めないことを確かめた（ロックアウト対策）（根拠: ）
- [ ] 実装結果レポートに本チケットの節が追記され、仕様と食い違った点は仕様を直さず「仕様からの逸脱」に記録されている（根拠: ）

## 作業内容

- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md の S2 に従う
- hook_rel_path は書く側と読む側が往復する値なので、呼び手 3 本の分岐まで同じチケットで閉じる
- 復旧は git checkout を使わない（checkout は _SC_GIT_READ_SUBCMDS に無く unknown → WF204）。git show <base_sha>:<パス> で内容を取り、Write ツールで書き戻す。書き戻し先（.claude/hooks/**）は本チケットの allow.write に入っている

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
