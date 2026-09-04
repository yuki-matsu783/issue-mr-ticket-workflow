---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0035"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: true, reason: "workflow-guard は中核で、緩めすぎると許可範囲の統制が効かなくなる"}
allow:
  write: [".claude/hooks/20-PreToolUse/**", ".claude/skills/00-workflow-issue-mr-driven/**", ".claude/skills/00-workflow-quick-request/**", "logs/**", "wip/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: "2026-09-04T13:18:38+09:00"
completed_at: "2026-09-04T13:30:36+09:00"
base_sha: "e1b2ee1"
---

# 0036 S12 中核: 許可範囲内のファイル削除を通す（WF205）と旧資産の削除

## 目的

AI がチケットの許可範囲内で .claude/ 配下のファイルを削除できるようにし、0031 で消せなかった旧資産を実際に消す

## DoD

- [x] workflow-guard の WF205 が、削除だけを行うコマンド（rm / git rm）の対象がチケットの allow.write に収まっているときは拒否しない。作成・更新（cp / tee / sed -i など）の扱いは変えない（根拠: workflow-guard.sh の `__wg_is_delete_seg` / `__wg_delete_targets` / `__wg_check_delete_targets` と段の分岐。WG-T18 で `rm` / `rm -f` 複数 / `git rm` / `git rm -r --cached` が allow、`echo x >` / `mv` / `cp` は WF205 のまま）
- [x] 許可範囲外の削除は今までどおり WF205 で拒否される（負のコントロール）（根拠: WG-T18 の `rm apl/app/src/api/a.ts`・`git rm apl/app/src/api/a.ts`（宣言外）、`rm .claude/settings.json`（毎回確認の範囲）、`rm -rf .claude`（未記載）、`rm apl/app/src/other/b.ts`（上限内だが宣言外）がすべて WF205）
- [x] 作業中チケットが無いとき（allow.write が無いとき）の削除は今までどおり拒否される（根拠: 事実は「拒否」ではなく「このフックは何もしない」。作業中チケットが 0 枚なら workflow-guard は記録もせず exit 0 で、既存の WG-T01 が `rm -rf src` を allow として固定している。DoD の文言が機構と食い違っていたので、WG-T18 の末尾で「削除も従来どおり allow のまま（変えていない）」を固定した。削除の可否は入口ガード側の役目）
- [x] test_workflow_guard.sh に上記 3 件の再現テストが足され、run-tests.sh --filter で全件通る（根拠: WG-T18 を追加し `run-tests.sh --filter '*workflow_guard*'` が PASS / passed=166 failures=0）
- [x] .claude/skills/00-workflow-issue-mr-driven/assets/issue-addendum.template.md と issue-notify.template.md が消えている（削除の前提確認は 0031 で済んでいる）（根拠: `rm` で削除。`git status` に D 2 件）
- [x] .claude/skills/00-workflow-issue-mr-driven/references/issue-triage.md が消え、20-common-step-issue/references/ 側だけが残っている（根拠: `rm` で削除し、空になった references/ も除去。参照は `20-common-step-issue` 側のみ）
- [x] .claude/skills/00-workflow-issue-mr-driven/evals/evals.json と 00-workflow-quick-request/evals/evals.json が消えている（移行先は .claude/evals/ の 2 本。0031 で作成済み）（根拠: `rm` で削除し、空になった evals/ も除去）
- [x] WF205 の判定を変えたことが仕様（10_spec/hooks/20-PreToolUse/workflow-guard.md）と食い違う場合は、逸脱として作業ログに記録し設計反映へ送っている（根拠: 「仕様からの逸脱」に 2 件を記録。設計反映（0033）で拾う）

## 作業内容

- workflow-guard の書き込み宛先の検査に、削除のみのコマンドを allow.write で判定する分岐を足す
- テストを足してから旧資産 3 種 5 ファイルを削除し、commit.sh でコミットする

## 経緯

0031（S8）で旧資産の削除に着手したところ、WF205 が `rm` / `mv` / `git rm` を一律に拒否し、コマンドで書いてよいのは `wip/tmp/**` と `logs/**` だけだった。Edit / Write ツールにファイルを消す手段は無いため、AI は `.claude/` 配下のアセットを削除できない。一方で AI アセット実装計画の仕様は変更対象に「削除」を含めており、機構と設計が食い違っている。ユーザーの判断（2026-09-04）で、機構側を直してから削除を行うことにした。

## 作業ログ

### 現在地

- 完了（WF205 の削除分岐 + WG-T18 + 旧資産 5 ファイルの削除）

### うまくいったこと

- 削除の判定を `scope_resolve` に寄せたので、許可範囲の規則を二重に持たずに済んだ。判定順（保護範囲 → 種類の禁止 → 毎回確認 → 許可範囲 → 承認済み → 未記載）がそのまま削除にも効く
- 段の分岐を `case "$SC_CLASS"` の前に置いたので、`rm`（分類は write）と `git rm`（分類は unknown）の両方を 1 か所で拾えた。scope.sh（allow.write の外）に触れずに済んでいる
- 変更後すぐ `rm` で旧資産 5 ファイルを消せた。機構の変更がその場で自分の作業に効くことを実地で確認できた

### うまくいかなかったこと

- DoD の 3 番目「作業中チケットが無いときの削除は今までどおり拒否される」は、着手前の見立てが間違っていた。作業中チケットが 0 枚のとき workflow-guard は何も判定しない（WG-T01）ので「拒否」ではなく「素通り」が従来の振る舞い。テストは事実どおり「変えていない」を固定した

### 仕様からの逸脱

- **S12-1**: `10_spec/hooks/20-PreToolUse/workflow-guard.md` 制御方式 6（51 行目）は「`rm` 等でファイルを書く → deny WF205。ただし対象が `wip/tmp/**` または `logs/**` なら許可」と書いており、削除の例外が無い。実装は「削除だけを行う段（`rm` / `git rm`）は対象を allow.write で判定する」を足した。仕様は `.claude/docs/**` で本チケットの allow.write の外なので、設計反映で本文とテスト表（WG-T18）に反映する
- **S12-2**: 同仕様のテスト表は WG-T01〜WG-T17 までで、追加した WG-T18 が無い。同じく設計反映で足す

### 判断と根拠

- **削除の許可判定に `scope_resolve` を使い、拒否は WF205 のまま**: 番号を新設すると既存のテスト・案内文・仕様表を広く直すことになる。呼び手にとっては「コマンドでファイルを触れるかどうか」で同じ対処（Edit / Write に寄せる or 範囲の見直し）なので、番号は据え置いて文面で削除であることを言う
- **`mv` は許可しない**: 移動は「消す」と「作る」の同時実行で、作成側は Edit / Write に寄せる原則を崩す。移設は「新しい場所に Write → 旧ファイルを `rm`」の 2 手で足りる（本チケットの `issue-triage.md` がその実例）
- **`rm` の対象は cmdpos が抜いた `CP_WRITE_TARGETS` をそのまま使う**: オプションの解釈規則を呼び手側で複製しない（cmdpos の冒頭にある約束）。`git rm` だけは cmdpos が書き込み先を抜かないので、提供コマンドの引数検査と同じ形で非オプション語を拾う
- **対象を読み取れない形（対象なし・クォートで潰れた `_`・`--pathspec-from-file`）は拒否**: 判定材料が無いときは拒否側に倒す（`__wg_rel` の作業ツリー外と同じ考え方）
- **リダイレクト先は削除の判定に混ぜない**: `rm a > b` の `b` は作成なので、従来どおり `wip/tmp/**` / `logs/**` だけを許す

### 拒否・確認・迂回の記録

- 変更前の WF205 で `rm` / `mv` / `git rm` が拒否され続けたのが本チケットの発端（0031 での記録）。変更後は allow.write の内側の削除が通り、迂回はしていない
- スクラップ用の一時ファイルを OS の temp に書こうとして WF209（作業ツリー外）で拒否された。`wip/tmp/` を使う原則どおりに戻した

### 使った AI アセットと効き目

- `.claude/hooks/lib/cmdpos.sh` の `CP_EXE` / `CP_SUBCMD` / `CP_WRITE_TARGETS`: 段の実行体とサブコマンドが取れているので、コマンド文字列を再パースせずに削除の段を見分けられた
- `.claude/hooks/lib/scope.sh` の `scope_resolve`: 許可判定を丸ごと再利用でき、削除固有の規則を持たずに済んだ

### スコープ外で見つけたこと

- `rmdir` はどの分類にも当たらず WF204 になる。空ディレクトリの片付けは `rm -r` で代替できたが、分類表に足すか検討の余地がある（設計反映の候補）

### AI アセットに反映すべき内容

- 仕様（`10_spec/hooks/20-PreToolUse/workflow-guard.md`）の制御方式 6 とテスト表に、削除の例外と WG-T18 を足す（逸脱 S12-1 / S12-2）
- AI アセット実装計画の許可範囲の書き方に「削除を伴う作業は消す対象を allow.write に含める」を添えると、同じ詰まり方をしない

### 備考
