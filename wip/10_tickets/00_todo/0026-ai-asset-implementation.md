---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0018", "0019", "0020", "0021", "0022", "0023", "0024", "0025"]
executor: opus
human_review: {required: false, reason: "全体計画書の方針（差分 3）"}
adversarial_review: {required: true, reason: "全体計画書の方針（差分 3: フェーズごとに 1 回）"}
allow:
  write: ["wip/**", ".claude/**"]
  ops: ["read", "remote-read", "build-test", "hook-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0026 S9 参照更新と全体検査

## 目的

計画書の参照更新一覧 7 行を検索して消し込み、プレースホルダ・frontmatter・全機械テストの回帰を通し、本 issue の残り（実装・フィードバック・全体まとめ）が回せることを確かめる。

## DoD

- [ ] 参照更新一覧の 7 行それぞれについて、計画書に書かれた検索語を実行し、期待値（残るものの件数と場所）と一致することが根拠付きで示されている（0 件を成功条件にしない）（根拠: ）
- [ ] 行 1: grep -rn 'HOOK_WORKTREE/logs/' --include="*.sh" .claude/ の結果が logs/hooks/ の 2 行だけになり、grep -rn 'HOOK_SHARED_ROOT/logs/' --include="*.sh" .claude/ が 22 行以上ある（根拠: ）
- [ ] 行 2〜4・7: 20-common-step-worktree / worktree.sh / HOOK_SHARED_ROOT / worktree-merges がアセット側に計画書の期待値どおり現れる（docs 側は除外）（根拠: ）
- [ ] 行 5: WF207 のヒットが 6 行のまま（workflow-guard.sh 2 行・test_workflow_guard.sh 4 行。番号の増減が無く）、workflow-guard.sh の hook_deny WF207 の文言に「この作業ツリーで」が入っている（根拠: ）
- [ ] 行 6: TK00[0-9] のアセット側ヒットが 54 行以上で、既存 53 行が減っていない（根拠: ）
- [ ] プレースホルダ（{{ }} / TODO / TBD）の検査が変更した全アセットで 0 件で、frontmatter が種別ごとの必須項目を満たす（根拠: ）
- [ ] bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --ids が FAIL 0 件・ID 重複 0 件で、割付表の機械テスト 37 件が PASS の一覧に含まれる（根拠: ）
- [ ] 本 issue の残りが回せることを 4 経路で確かめた（commit.sh / boundary.sh status / ticket.sh next / run-tests.sh）。拒否されたものは識別子と対処を記録する（根拠: ）
- [ ] push.sh は実行せず、代わりに CP-T12 の PASS と push 前チェック 項目 5 の実装をもって経路が残っていることを示した（理由: 実行者は作業中チケットを持つので項目 2 で必ず CP005 になり、remote-write:push は ai-asset-implementation の types ops に無いので通らない。実際の push は切れ目で呼び出し元が行う）（根拠: ）
- [ ] 実装結果レポートの逸脱一覧が締められ、md と HTML の対が check-html.sh を通っている（根拠: ）

## 作業内容

- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md の S9 と「参照更新一覧」に従う

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
