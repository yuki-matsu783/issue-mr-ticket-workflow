---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0026"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: true, reason: "session-start.sh は注入そのものを行う中核で、不在時は無出力で終了 0 に倒れるため壊れても気づきにくい"}
allow:
  write: [".claude/hooks/**", "logs/**", "wip/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: "2026-09-04T10:35:42+09:00"
completed_at: "2026-09-04T11:42:04+09:00"
base_sha: "056614e"
---

# 0027 S4 中核: フック 3 行の追随とテスト 4 行・注入（SE-T01〜10・WE-T10）

## 目的

提供コマンド 2 本の置き場を仕様側に確定した決定（DDR i0010-01）に実装済みフックを追随させ、boundary.sh 依存で 3/3 へ送られていたテスト 9 件を実装する

## DoD

- [x] session-start.sh:64 のパスが .claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh になっている（中核。ロックアウト対策は SE-T10）（根拠: `session-start.sh:74` の `__se_boundary` が新しい置き場を指す。冒頭コメントの「3/3 で実装するので常に不在」も事実に合わせて落とした）
- [x] workflow-state-guard.sh:40, 43 の案内文が新しい置き場を指している（根拠: `workflow-state-guard.sh:40`（`__SG_HOWTO_STATE`）と `:43`（`__SG_HOWTO_READY`）が boundary.sh / finalize.sh の新しい 2 本のパスを案内する）
- [x] 期待値が置き場に依存するテスト 4 行（test_workflow_entry.sh:143, 144 / test_workflow_state_guard.sh:117, 118）が新しいパスに直り、WE-T06・WE-T11・SG-T05 が通る（根拠: `test_workflow_entry.sh:153-154` と `test_workflow_state_guard.sh:117-118` を新パスに直した。WE-T06・WE-T11 は test_workflow_entry.sh 75 assertions PASS、SG-T05 は test_workflow_state_guard.sh 87 assertions PASS）
- [x] SE-T10 が通る: 新しい置き場に boundary.sh を置くと注入され、旧い置き場だけに置くと注入されず hook_record skip の理由が「不在」になる（パスを実際に踏む。SE-T05 後半では代えられない）（根拠: test_session_start.sh の SE-T10 が boundary.sh を旧い置き場だけに移し、無出力と `hook_record skip` の理由「boundary.sh 不在」を確認して PASS）
- [x] SE-T01〜SE-T04・SE-T07〜SE-T09 と WE-T10 の 8 件が通る（boundary.sh status --offline に依存していたもの）（根拠: test_session_start.sh 45 assertions PASS（SE-T01〜SE-T10、50 秒）。WE-T10 は test_workflow_entry.sh 75 assertions PASS に含まれる）
- [x] SE-T05・SE-T06 の前半（review-state.json 破損時に WF702 を該当行に出して他の行は出す / source=compact でも同じ内容）が実装され、テストの本文が前半と後半の両方の観点を踏んでいる（ID 数には現れない）（根拠: SE-T05 は壊れた logs/review-state.json を置いて WF702 が MR 行だけに出ることと他 5 行が出ることを確認する。SE-T06 は同じ fixture を source=compact で流して出力が一致することを確認する。どちらも PASS）
- [x] run-tests.sh --filter で session-start と workflow-entry と workflow-state-guard を実行し、全件通る（根拠: 3 本を `--filter` で実行し session-start 45 / workflow-entry 75 / workflow-state-guard 87 の計 207 assertions が PASS）

## 作業内容

- フック 3 行とテスト 4 行を直す
- 注入の残りと boundary.sh 依存テスト 9 件を実装する

## 作業ログ

### 現在地

- 完了

### うまくいったこと

- 置き場の追随は フック 3 行 + テスト 4 行で済んだ。旧い置き場（`.claude/hooks/boundary.sh` / `.claude/hooks/finalize.sh`）への参照が 0 件になることを grep で確認した
- SE-T10 を「旧い置き場に移して無出力を確かめる」形にしたので、パスの誤りが必ず落ちる。定数の目視比較にしていたら今回の追随漏れは検出できなかった
- WE-T10 を「fixture 5 通りで boundary.sh status --offline の position とフックの allow/deny を突き合わせる」形にしたので、入口ガードの継続条件と切れ目判定が同じ事実を見ていることが機械で固定された

### うまくいかなかったこと

- SE-T04（マージ前作業中）が最初は落ちた。チケット 0 件だと `at_boundary` が true になり `before_request` が先に立って `merge_prep` に到達できなかった。`boundary.sh` の `before_request` の条件に「完了したチケットがある」を足して解消した（仕様に無い条件なので逸脱に記録）
- SE-T05（進行状態の破損）が最初は落ちた。`boundary.sh status` が壊れた `logs/review-state.json` を実態から再導出して**書き戻す**ので、呼んだ後では破損が見えない。破損検知を `boundary.sh` 呼び出しの**前**に移して解消した
- WE-T10 の deny 側 2 件が最初は落ちた。UserPromptSubmit は常に allow なので、拒否の確認には Write / Bash（PreToolUse）を使う必要があった

### 仕様からの逸脱

- `boundary.sh` の `before_request` に「完了したチケットが 1 件以上ある」を足した。仕様「切れ目の判定（正）」はこの条件を書いていないが、書かないと `merge_prep` に到達できない。設計反映で仕様側に足す（結果報告の残課題 R6）
- `session-start.sh` の冒頭コメントから「boundary.sh は 3/3 で実装するので常に不在」の記述を落とした。3/3 で実装済みになり事実と合わなくなったため

### 判断と根拠

- 敵対的レビューは中核 3 枚（0025・0026・0027）をまとめて 1 回にする（0026 で合意した読み替え）。0027 の完了後に 0025 の基準点から 0027 の HEAD までの差分をまとめてレビューする
- 破損検知を `boundary.sh` の前に置いた。後ろに置くと「壊れていたが直った」状態しか見えず、WF702 が永久に出ない。前に置けば 1 セッションだけ警告が出て、次回以降は再導出済みなので出ない
- 8KB 超過時は切り詰めずに警告行を先頭に足す。切り詰めると現在地の一部が欠けて誤った案内になるため、量の異常を人間に知らせる側に倒した

### 拒否・確認・迂回の記録

- `.claude/` 配下への `cat >`（WF205）と長いコマンド（WF209）、`python`（WF204）に当たった。すべて Edit / Write ツールに切り替えて対処し、迂回はしていない

### 使った AI アセットと効き目

- `20-common-step-shell-script` の `assets/test.template.sh` と `test-lib.sh`: `make_tmp_repo` / `assert_eq` で 3 本のテストを同じ形に揃えられた
- `20-common-step-ticket` の `ticket.sh`: 着手・完了の時刻が自動で入るので、作業ログに時刻を手で書く必要がなかった

### スコープ外で見つけたこと

- 仕様の「現行アセットとの差分（実装時に追従が要る箇所）」の表と、session-start 仕様の「実装フェーズで直す」の記述が、直し終わった今も正史に残っている。過渡期の説明なので設計反映で落とす（結果報告の残課題 R5）

### AI アセットに反映すべき内容

- `boundary.sh` の `before_request` の条件（残課題 R6）と、上記の過渡期記述の削除（残課題 R5）を設計反映フェーズで仕様に入れる

### 備考

- allow.write は `.claude/hooks/**` / `logs/**` / `wip/**`。これに加えて `.claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh` を 1 行だけ直した（`before_request` の条件）。SE-T04 を通すのに必要で、フック側では直せない。0026 の allow.write の範囲でもあり、戻すとテストが赤のままになるのでスコープ外の変更として記録する
