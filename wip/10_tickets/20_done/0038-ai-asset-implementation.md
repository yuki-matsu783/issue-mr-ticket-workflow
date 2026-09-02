---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0029"]
executor: main
human_review: {required: true, reason: "振る舞いが変わる（承認④により opus の敵対的自己レビューで代替）"}
adversarial_review: {required: true, reason: "案内側フックの判定と記録の変更"}
allow:
  write: [".claude/hooks/**", "wip/10_tickets/**", "wip/30_reports/**", "wip/tmp/**"]
  ops: ["read", "remote-read", "hook-test", "build-test"]
started_at: "2026-09-02T21:51:44+09:00"
completed_at: "2026-09-02T22:24:44+09:00"
base_sha: "b4154b0"
---

# 0038 0029 の敵対的レビュー指摘 6 件の反映

## 目的

0029（案内側フック 6 本）の敵対的セルフレビューで確度 0.5 以上と判断した 6 件を直す。実測プローブ wip/tmp/adv0029.sh で再現を確認済み

## DoD

- [x] workflow-diff-check がリポジトリルート相対でないパス（絶対パス・リポジトリ外・.. を含む）を承認単位として approvals.json に記録しない。実測（/tmp/outside/evil.md への Write で C:/Users/.../Temp/outside が記録された）を再現するテストを DC-T03 に足した（根拠: `workflow-diff-check.sh` に `__dc_in_repo`（絶対パス・`..` を含むパスを弾く）を足し、承認単位の候補から外した。DC-T03 に「/tmp/outside/evil.md への Write で approvals.json が増えない」を追加（48 件 FAIL 0）。プローブ `wip/tmp/adv0029.sh` の A5 で、直す前は `C:/Users/.../Temp/outside` が記録され、直した後は「なし」になることを実測した）
- [x] workflow-diff-check が base_sha を解決できないとき、WF601 の本文に解決できない値をそのまま「基準点は X」と書かない。復旧指示の git checkout <base> が使えない旨を書くか、仕様の制御方式 7 に倣って黙って抜けるかを決め、根拠を作業ログに書いた。テストを DC-T06 に足した（根拠: 基準点を `git rev-parse --verify` で解決できないときは、差分の取得に失敗したのと同じ（仕様の制御方式 7）として**黙って抜ける**ようにした。続けると WF601 が「基準点は PLACEHOLDER」と書き、復旧指示の `git checkout PLACEHOLDER -- <path>` も動かない案内になる（プローブ A8 で実測）。理由は作業ログ「判断と根拠」に記載。DC-T06 にテストを追加）
- [x] 作業中チケットが 2 枚以上のときの扱いを workflow-diff-check（判定不能として黙って抜ける）と subagent-stop-check（先頭 1 枚で範囲判定する）で揃えた。どちらに揃えたかと理由を作業ログに書き、テストを DC-T06 / SP-T04 に足した（根拠: **`workflow-diff-check` 側（2 枚以上は範囲判定をしない）に揃えた**。WF811 / WF812 は枚数に依らず出す（残っているチケットと差分の一覧は枚数と無関係に事実だから）。WF813 だけを 1 枚のときに限った。理由は作業ログ「判断と根拠」に記載。SP-T04 にテストを追加（57 件 FAIL 0））
- [x] post-push-usage-report が posted:false の間は since_sha を進めない（初回 push で HEAD に進めると、集計値には push 前の分が入っているのに集計期間の起点だけが後ろへずれる）。テストを UR-T04 に足した（根拠: `post-push-usage-report` が `since_sha` / `since_at` を書かないようにした（起点を進めるのは boundary.sh の責務。仕様の既定 5）。UR-T04 に「初回 push の後も `.since_sha` が空のまま」を追加（38 件 FAIL 0））
- [x] WF601 のパス列挙の上限（現在 30）と WF812 / WF813 の上限（20）の不整合を解消した。どちらに揃えたかを作業ログに書き、上限を超えたときの件数表示をテストで固定した（根拠: **`subagent-stop-check` の 20 に揃えた**（仕様に「20 を超えれば先頭 20 件 + 件数」と明記されている側が正で、WF601 の上限は仕様に定めが無かった）。DC-T02 に「範囲外 25 件で 20 件 + 『他 5 件』」を追加）
- [x] subagent-stop-check の縮退判定が decisions.jsonl の末尾 400 行に依存している点を直した（決め打ちの行数を超えると誤って縮退と判定し WF801 を二重に出す）。セッション状態など行数に依存しない引き方に変え、テストを SP-T08 に足した（根拠: `subagent-start-check` が PreToolUse `Agent` の判定のたびに `logs/sessions/<id>/subagent-start-check.json` を置き、`subagent-stop-check` はまずその印を見る（行数に依存しない）。印が無い古いセッション向けに `decisions.jsonl` の全走査を二次の経路として残した（`tail -n 400` の打ち切りは外した）。SA-T08 に印の有無、SP-T08 に「印がある」「記録が 600 行先にある」の 2 件を追加）
- [x] 6 本の filter 実行と全件テストが 2 ロケールで FAIL 0。作業ログと結果報告（md + HTML）を書いた（根拠: 6 本の filter 実行は FAIL 0（workflow-diff-check 48 / post-push-usage-report 38 / subagent-start-check 58 / subagent-stop-check 57 / post-push-compact-prompt 37 / session-start 14）。全件テストは既定ロケールと `LC_ALL=C.UTF-8` の両方で **21 本 / 112 件・FAIL 0**。結果報告は `wip/30_reports/0038-ai-asset-implementation.md` と同名の HTML（`check-html.sh` 7 項目通過））

## 作業内容

- 指摘の出どころは wip/30_reports/0029-ai-asset-implementation.md のレビュー観点 r1〜r7 と、敵対的セルフレビューの実測プローブ
- 案内側なので fail-closed ラッパーは付けない。失敗は通す
- .claude/docs/** には書かない。仕様側を直すべきものは 0032 へ送る

## 作業ログ

### 現在地

- 完了。6 件すべてを直し、プローブで再現と解消を実測。テストを 5 か所に追加

### うまくいったこと

- **プローブを先に書いたのが効いた**。`wip/tmp/adv0029.sh` に「仕様の穴を突く入力」を 8 本並べて実際に流したので、
  読むだけでは気づけなかった 2 件（リポジトリ外のパスが承認単位になる / 基準点が解決できない値のまま案内文に出る）が実測で出た。
  直した後に同じプローブを流し直すだけで解消を確かめられた
- **直した 6 件のうち 4 件は「仕様どおりにすると決める」だけで済んだ**。上限 20・起点は boundary.sh の責務・
  2 枚以上は判定しない・基準点が無ければ黙る、はいずれも仕様のどこかに書いてある側へ寄せる判断だった

### うまくいかなかったこと

- **`if true; then` を残したまま置換した**。基準点の分岐を「解決できなければ抜ける」に変えたとき、
  元の `if ... else ... fi` の骨だけが残った。構文は通るので `bash -n` では気づけず、読み直して消した
- **最初のプローブ A2 の作りが悪く、観点が成立していなかった**。「禁止範囲の追跡済みファイルを削除」を見るつもりで
  `git rm --cached` してから消したので、git からは何も見えなくなっていた。削除の検知そのものは同じプローブの
  `rm src/a.py` の側で確認できた

### 仕様からの逸脱

1. **縮退判定の一次経路をセッション内の印にした**。仕様（`subagent-stop-check` 制御方式 2）は `decisions.jsonl` の記録で引くと書くが、
   決め打ちの行数で切ると記録が育つほど誤って縮退と判定する。`subagent-start-check` が `logs/sessions/<id>/subagent-start-check.json` を置き、
   `subagent-stop-check` がそれを見る。`decisions.jsonl` の全走査は二次の経路として残した。**0032 で仕様側に書き戻す**（0029 の逸脱 4 と同じ項目）
2. **WF601 のパス上限を 20 と決めた**。仕様に定めが無いので逸脱ではないが、値の出どころ（`subagent-stop-check` に合わせた）を仕様に書く必要がある。**0032 へ**
3. **基準点が解決できないときの扱いを制御方式 7 に寄せた**。仕様の制御方式 4 は「`git diff --name-status <base_sha>` を合わせる」としか書かず、
   解決できない場合を定めていない。**0032 で「基準点が解決できなければ黙って抜ける」を明記する**

### 判断と根拠

- **基準点が解決できないときは黙って抜ける**。案内側の原則（判定できないときは黙って通す）に加えて、
  続けると WF601 の本文と復旧指示が両方とも嘘になる。「作業ツリーの差分だけで判定する」という中間の選択肢もあるが、
  そのとき復旧の道（`git checkout <base> -- <path>`）を示せないので、指示として成立しない
- **作業中 2 枚以上は `workflow-diff-check` 側に揃えた**。`subagent-stop-check` が先頭 1 枚で範囲判定すると、
  同じ scope.sh を共有しているのに「片方は判定不能で黙り、片方は 1 枚目の許可範囲で他方の差分を範囲外と呼ぶ」という食い違いが出る。
  ただし WF811 / WF812 は枚数と無関係に事実なので出し続ける
- **上限は 20 に揃えた**。仕様に明記されている側（`subagent-stop-check`）を正とする。30 のままにする理由が無い
- **`since_sha` は usage-report が書かない**。仕様の既定 5 が「リセットはしない。boundary.sh が投稿に成功したら `since_sha = head` を書く」と
  定めているので、書き手を 1 か所にする。初回は「（記録なし）」と出るが、これは事実（まだ 1 度も投稿していない）
- **リポジトリ外のパスは承認単位にしない**。`scope_resolve` の判定はルート相対のパスにしか当たらないので、
  外のパスを覚えても許可には使われない。記録が汚れるだけで、`SC_APPROVED` を読む他のフックのノイズになる

### 拒否・確認・迂回の記録

- なし

### 使った AI アセットと効き目

- 敵対的セルフレビューのプローブ（`wip/tmp/adv0029.sh`）: 8 本の入力を流す 100 行ほどのスクリプト。
  テストと違い「通るか」ではなく「何が出るか」を見る形にしたので、上限やラベルの不整合まで目に入った。**この形は次のチケットでも使う**
- `20-common-step-report-view` の `check-html.sh`: `OK: 検査 7 項目すべて通過（id 21 件 / リンク 14 件を確認。テンプレート: report）`

### スコープ外で見つけたこと

- `subagent-stop-check` の WF812 は移動先だけを出し、移動元（消えた側）を出さない。仕様の「移動は移動先で判定」に従った結果だが、
  「未コミットの変更・未追跡」の一覧としては移動元が消えた事実も伝えたほうが親切。確度が低いので直していない
- WF601 の種別ラベルは「変更 / 未追跡 / 移動先」の 3 つで、削除も「変更」と出る。区別する価値があるかは 0032 で判断する

### AI アセットに反映すべき内容

**0032（設計反映）へ送る（0038 の分）**

- `workflow-diff-check.md` に「基準点が解決できなければ黙って抜ける」を明記する
- `workflow-diff-check.md` に WF601 のパス列挙の上限（20）を書く
- `subagent-stop-check.md` に「作業中が 2 枚以上なら WF813 を出さない（WF811 / WF812 は出す）」を書く
- `subagent-stop-check.md` の縮退判定を「セッション内の印（`subagent-start-check.json`）を見る」に直す
- `subagent-start-check.md` に「PreToolUse `Agent` の判定のたびにセッション内へ印を置く」を書く
- `post-push-usage-report.md` に「`since_sha` / `since_at` はフックが書かない」を明記する

**累積（0029 までに挙がっていて未反映）**

- 0029 の作業ログ「AI アセットに反映すべき内容」の全項目（`-uall`・2 経路出力の公開 API・`hook_notify` と `hook_inject` の差・
  SP-T08 の `sub-opus`・`logs/mr.json` のキー）
- フック共通仕様 §7 の `CP_DATA` / 語の切れ目に改行 / 内部プレースホルダの割り当て表
- `push_detect` の終了コード検査の除去（DDR i0009-07）
- §1 の表の review-state / merge-state を jq 2 回目へ、§2 の worktree 判定、§8 の scope.sh の記述
- 区切りバイトの割り当てを 1 か所にまとめる、DDR i0009-08 の `SS-T00〜T04`
- チケットの `allow.write` に作業ログの置き場を必ず含める規約

### 備考

- `shellcheck` はこの環境に未導入（7 巡連続）
- `check-html.sh` は md と HTML の内容一致を検査しない（18 回連続の申し送り）
