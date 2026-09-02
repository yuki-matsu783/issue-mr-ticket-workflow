---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0030"]
executor: main
human_review: {required: true, reason: "中核（scope-limits.json）を含む"}
adversarial_review: {required: false, reason: "フェーズ 6 の敵対的レビューでまとめて見る"}
allow:
  write: [".claude/hooks/config/scope-limits.json", ".claude/hooks/tests/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: "2026-09-02T11:32:55+00:00"
completed_at: ""
base_sha: "18dc8c0"
---

# 0031 実装: 旧置き場の deny とテストのアサーションを落とす

## 目的

0030 で直した §8 に合わせて設定とテストから旧置き場を外す

## DoD

- [x] scope-limits.json に src/** と docs/** が 0 件で、apl/** と .claude/** の deny は残っている（V5）（根拠: `grep -c '"src/\*\*"\|"docs/\*\*"' .claude/hooks/config/scope-limits.json` が 0。`"apl/**"` は 9 件（計画・調査 7 type の deny、`ai-asset-design` の deny、`ai-asset-implementation` の deny）で残っている。`.claude/**` も各 deny に残る。`jq -e .` が成功）
- [x] test_config_integrity.sh の旧置き場のアサーション 4 件が、特別扱いが無いこと（判定順 (7) の ask WF202）を見る 2 件に置き換わっている（根拠: 旧置き場の 4 件を、`docs/10_spec/x.md` と `src/vscode-ticket-board/src/a.ts` が判定順 (7) の `ask WF202` に落ちる（特別扱いが無い）ことを見る 2 件に置き換えた）
- [x] 計画・調査タスクが apl/** を書けないことがテストで固定されている（根拠: 計画・調査タスクが成果物を書けないことを 4 件で固定した。`investigation` → `apl/*/src/**`、`design-plan` → `apl/*/docs/**`、`ai-asset-design-plan` → `apl/*/package.json` はいずれも `deny WF201 3`（type の deny）、`implementation-plan` → `.claude/rules/x.md` は `deny WF201 2`（`common.protected` が type の deny より先に効く））
- [x] 変更前に落ちて変更後に通ることを確かめ、run-tests.sh --ids が 14 本すべて PASS する（V6）（根拠: 設定変更前 `passed=50 failures=2`（落ちた 2 件は旧置き場の deny が残っていたため）、変更後 `passed=52 failures=0`。`run-tests.sh --ids` は 14 本すべて PASS、59 テスト ID、`FAIL ID:` は空）

## 作業内容

- テストを先に直して落としてから設定を直す

## 作業ログ

### 現在地

- 完了。7 type の deny から旧置き場を外し、テストの旧置き場のアサーション 4 件を 6 件（特別扱いが無いこと 2 件 + 成果物を書けないこと 4 件）に置き換えた

### うまくいったこと

- テストを先に直して落としてから設定を直す順を守れた（50/2 → 52/0）。落ちた 2 件がちょうど旧置き場の deny が効いていた 2 件で、他は落ちなかった。変更の範囲が意図どおりだと確かめられた
- 消すだけでなく、消したことで**緩みすぎていないか**を固定するアサーションを足した。計画・調査タスクが `apl/*/src/**` `apl/*/docs/**` `apl/*/package.json` `.claude/rules/**` のいずれも書けないことを 4 件で見る。deny を編集する変更では、消した側だけでなく残った側を確かめないと片方向にしか気付けない

### うまくいかなかったこと

- `.claude/rules/x.md` の期待値を `deny WF201 3`（type の deny）と書いて落ちた。実際は `deny WF201 2` で、`.claude/**` は `common.protected` にもあるので判定順 (2) が先に効く。同じ deny でも段階が違う。期待値をコメント付きで直した

### 仕様からの逸脱

- 実行者: 全体計画のとおりメインエージェント（`10-task-ai-asset-implementation-exec` スキル本体が未整備のため、`.claude/docs/10_spec/skills/` の対応する仕様書に従って主体で実施。issue #10 の範囲）

### 判断と根拠

- **7 type すべてを 1 度に置換した**: `"deny": ["apl/**", ".claude/**", "src/**", "docs/**"]` は 7 type で完全に同じ文字列だった。件数を先に数えて（7）から置換し、置換後に数え直した。1 行ずつ直すより取りこぼしが無い
- **旧置き場を「ask に落ちること」で置き換えた**: 単にアサーションを消すと、将来 `src/**` が別の理由で deny に戻ったときに気付けない。「特別扱いが無い」ことを積極的に固定した
- **`apl/**` と `.claude/**` の deny は残した**: 計画・調査タスクが成果物を書けない状態は移行と関係なく必要。外すのは移行のために置いていた 2 つだけ

### 拒否・確認・迂回の記録

- なし（`allow.write` の範囲内）

### 使った AI アセットと効き目

- `.claude/hooks/lib/scope.sh` の判定順: `.claude/rules/x.md` の期待値の食い違いを、実装を読んで（判定順 (2) が (3) より先）すぐ説明できた
- `run-tests.sh --ids`: deny を消す変更で他のテストに波及していないことを 1 回で確認できた

### スコープ外で見つけたこと

- 特になし

### AI アセットに反映すべき内容

- 許可範囲の deny を消す変更では、消した側（もう deny されない）と残った側（まだ deny される）の両方をテストで固定する、という指針を残したい。今回は意識してやったが、規定は無い。フィードバック計画の B1（テストの構成）に合流させて別 issue で扱う

### 備考

- これでフェーズ 6 の F1〜F6 がすべて終わった。次はフェーズ 6 の敵対的レビュー
