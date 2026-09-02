---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0028", "0029"]
executor: main
human_review: {required: true, reason: "基準どおり（拒否側は誤ると自分自身の操作を止める）"}
adversarial_review: {required: true, reason: "基準どおり（中核。ロックアウトを起こし得る）"}
allow:
  write: [".claude/hooks/**"]
  ops: ["read", "remote-read", "hook-test", "build-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0030 拒否側フックの残り 4 本とテスト

## 目的

0028 で確定した終了方式で workflow-entry / workflow-state-guard / block-direct-git / workflow-guard を書く。ホットパスの外部プロセス上限を実装で固定する

## DoD

- [ ] workflow-entry.sh があり、UserPromptSubmit / PreToolUse Skill（宣言の記録）と PreToolUse の未宣言の拒否（WF101 系）の入口を持つ。jq の呼び出しが 2 回（hook_read_input + hook_read_state）で HK-T19 が通る（根拠: ）
- [ ] workflow-state-guard.sh があり、制御方式 0（既定値へのフォールバックと notify。評価は制御方式 1 の後）から 5（判定不能）までを仕様の順で実装している。jq の呼び出しが 1 回で HK-T19 が通る（根拠: ）
- [ ] 置き場の削除が、cmdpos_operands で取った位置引数に対して、正規化した元パスの前方一致で置き場のディレクトリ自身と祖先（wip/10_tickets・wip）も拾い、rm -rf wip/tmp と rm -rf logs は通る。SG-T11 が通る。自前で引数を再パースしていない（根拠: ）
- [ ] block-direct-git.sh があり、cmdpos.sh を使ってサブコマンドを判定する。BG-T01〜T11 が通る。jq の呼び出しが 1 回（根拠: ）
- [ ] workflow-guard.sh があり、制御方式 1〜6 を仕様の順で実装している。web の 3 段判定は scope.sh に委ね、CP_PROVIDED を直に見て素通ししない。jq の呼び出しが 2 回で HK-T19 が通る（根拠: ）
- [ ] 4 本とも作業ツリーの基準に 0027 で hook-common.sh に入れた HOOK_WORKTREE を使い、各フックが自前で解決していない（根拠: ）
- [ ] ホットパス 5 本が git / date / sed / find を呼ばず、make_counting_path で数えた jq の回数が block-chmod・block-direct-git・workflow-state-guard = 1、workflow-guard・workflow-entry = 2 に固定されている。hook_field を追加で呼んでいない（0027 で hook_read_input が prompt などを取っているのが前提）（根拠: ）
- [ ] 4 本とも実装の型に従い、bash -n を通り（`shellcheck` はこの環境に未導入で未実施）、bash <script> < 入力 JSON の単体実行で想定どおりの JSON を出す（ラッパー無しの状態で）（根拠: ）
- [ ] 新規に作った .sh（本体 4 本 + テスト）の `__ss_load` 行が assets/script.template.sh とバイト一致し、SS-T05 が通る（SS-T05 は .claude/hooks/** 全体を走査するため）（根拠: ）
- [ ] 4 本のテストが `run-tests.sh --filter '<glob>' --ids` で通る（WE-T* / SG-T* / BG-T* / WG-T*。boundary.sh 依存の WE-T10 を除く）（根拠: ）

## 作業内容

- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md のステップ 4 に従う
- 0028 で T6 が外れていた場合は exit 2 + stderr の形で書く
- この段では settings.json に登録しない（登録は 0031）。単体実行で確かめる
- .claude/docs/** には書かない。決定は作業ログ「判断と根拠」に書く

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
