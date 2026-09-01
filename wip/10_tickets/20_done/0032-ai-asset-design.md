---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0030"]
executor: main
human_review: {required: false, reason: "切れ目の敵対的レビューの反映。反映結果は note で報告する（承認④）"}
adversarial_review: {required: false, reason: "レビュー指摘の反映のみ（差分は文言の修正）"}
allow:
  write: [".claude/docs/**", "wip/**"]
  ops: ["read"]
started_at: "2026-09-01T17:27:55+09:00"
completed_at: "2026-09-01T17:32:29+09:00"
base_sha: "211fd9d"
---

# 0032 AI アセット設計・追加: 敵対的レビュー G-1〜G-21 の反映（設計 0028〜0030 の切れ目）

## 目的

wip/tmp/review-design2-findings.md の指摘のうち確度 0.5 以上の 15 件（G-1〜G-15）を仕様・DDR・結果報告に反映し、0.5 未満のうち修正が 1 行で済むもの（G-16・G-17・G-20）も直す。実装を変える判断（G-6 判定語・G-7 create の YAML エスケープ・G-9 command -v）は 0031 への申し送りに追加する

## DoD

- [x] G-1: フック共通仕様 §7-9 の CP_ARGS / CP_WRITE_TARGETS の区切りバイトが実装（0x1E）と一致している（根拠: フック共通仕様 §7-9 の CP_ARGS を「区切りバイトは RS（0x1E）」、CP_WRITE_TARGETS を「同じ 0x1E 区切り」に修正。cmdpos.sh 24 行 _CP_US=$'\x1e'、scope.sh 20 行 _SC_US と一致。grep 0x1F は 0 件）
- [x] G-2: report-view 仕様の Script 処理冒頭・OUT ひな形・RV-T07 が「導出元テンプレート不在は RV006・終了 1、RV008 は引数・ファイル不正のみ」で矛盾なく揃い、実装 check-html.sh と一致している（根拠: report-view 仕様の Script 処理冒頭を「RV008 は引数が 1 つでない・ファイル無し・読めない・.html 以外（検査前、終了 2）。導出元テンプレートを特定できないときは RV006（終了 1）」に、RV-T07 も同じに修正。OUT ひな形の「それもできなければ RV006」と一致し、check-html.sh 113-115 行（fails+=RV006）・61-66 行（result_ng2）と一致）
- [x] G-3・G-4・G-17: DDR i0006-07 / 09 / 12 の影響・背景の誤り（12-PreToolUse のパス、WF203 の対象、CP001 / CP006 の意味）が直っている（根拠: i0006-07 / 09 の影響を 20-PreToolUse/workflow-guard.md に（09 は「制御方式 6 の無条件許可が実現箇所。ops 未宣言の拒否は WF204 / WF206」に）、i0006-12 の背景を CP001「対象未指定・一括指定」/ CP005・CP006 / TK004 / RV: と CP006 の対処「force しない・状況を報告する」に修正。grep 12-PreToolUse は .claude/docs で 0 件）
- [x] G-5・G-6・G-9・G-16: shell-script 仕様の fm_get の戻り、ticket 仕様の現在地の判定語、フック共通仕様 §8 の read の例示と変数名、build-test / hook-test の実行体（bash と sh）が実装どおりになっている（実装を変える案は 0031 への申し送りとして結果報告に書く）（根拠: shell-script 仕様 fm_get: フロー配列・インラインマップは生の文字列、ブロックマッピングは戻り値 1（frontmatter.sh 189-194 行の case list|inline / *) return 1 と一致）。ticket 仕様 complete 3: 行頭「- 次」「- 未着手」または節内の「未着手」（ticket.sh 250 行の正規表現と一致。コロン無し「次」を外す案は 0031 へ）。フック共通仕様 §8: read の一覧を _SC_READ_ONLY_CMDS / _SC_GIT_READ_SUBCMDS の名前で参照し command -v を外す（command -v git を read にする案は 0031 へ）、build-test / hook-test の実行体を bash（または sh）に（scope.sh 196・214 行と一致））
- [x] G-8: フック共通仕様 §7-3 / §7-5 の語彙表（透過ラッパー・不透明な実行系の 2 系統・書き込み先コマンド）が cmdpos.sh の配列と全要素一致している（比較の根拠を作業ログに）（根拠: §7-3 の透過ラッパーを _CP_PREFIX_WORDS の 21 語（if then elif else do while until ! time sudo doas env command builtin exec nohup nice ionice setsid stdbuf timeout）と同じ集合に、§7-5 を _CP_OPAQUE_WORDS 6 語 + _CP_FIND_EXEC_OPTS 4 語 / _CP_OPAQUE_WITH_OPT 14 語 × _CP_CODE_OPTS 7 語の 2 系統に書き換え（cmdpos.sh 35・39〜42 行）。pwsh script.ps1 は opaque でないことを明記。書き込み先コマンドは §7 の既存記述が _CP_WRITE_CMDS（cp mv tee touch mkdir rm truncate install ln sed）と一致することを目視で確認）
- [x] G-10・G-14・G-15: commit-push 仕様の CP003 の 2 条件と CP001 の終了コード、ticket 仕様の TK008 に commit.sh 不在が書かれている（根拠: commit-push 仕様の CP003 を「全対象が除外、またはステージ後の実パスに除外パターンの一致（手順 4）」、CP001 に「いずれも終了 2」（commit.sh の result_ng 001 … 2 の 6 か所と一致）。ticket 仕様の TK008 に「commit.sh 不在」（ticket.sh 345 行））
- [x] G-7・G-11・G-12・G-13・G-21・G-20: 結果報告 0028 の要約（実装を変える件数と内訳に create の YAML エスケープを追加）・入力範囲（F-1〜F-25）・残課題（bash-script ルールとの二重管理、frontmatter キー名の正の移管）が直り、HTML にも同じ変更が反映され check-html OK。ticket 仕様のテスト観点表の行順が ID 順（根拠: 結果報告 0028 の要約を「実装を変える設計は 9 件」（create の YAML エスケープを追加、read / remote-read / provided は仕様側のみ）に、入力を F-1〜F-25 に、更新した文書に「0032」の表、想定と異なった点 2 項目、残課題に 0031 への追加（G-7 と判断 2 件）と 3/3 への申し送り（bash-script ルールとの重複、frontmatter キー名の正）を追記。HTML に同じ変更（要約・見てほしい点・f6 の段落・想定と異なった点・残課題）、check-html OK（id 20 / リンク 13）。ticket 仕様のテスト観点表を T01〜T12 の ID 順に）

## 作業内容

- wip/tmp/review-design2-findings.md を読み、指摘ごとに実装（cmdpos.sh / scope.sh / frontmatter.sh / ticket.sh / commit.sh / check-html.sh）を再確認してから仕様の文言を直す
- 0.5 未満の G-18・G-19 は残課題に記載のみ（判断は変えない）

## 作業ログ

### 現在地

- 済: wip/tmp/review-design2-findings.md の G-1〜G-21 を読む → 実装（cmdpos.sh / scope.sh / frontmatter.sh / ticket.sh / commit.sh / check-html.sh）の該当行を再確認 → 仕様 5 本・DDR 3 件・結果報告 md + HTML を修正 → このチケットの記入
- 完了: commit.sh → ticket.sh complete 0032 → push → PR #7 に note → 0031 へ

### うまくいったこと

- レビューが実装の行番号と実行確認を根拠に付けていたので、各指摘を実装の該当行と突き合わせるだけで修正文言が決まった（21 件を 1 チケットで処理）
- 0.5 未満の指摘も 1 行で済むもの（G-16・G-17・G-20）は直し、判断に関わるもの（G-18・G-19・G-21）は注記と残課題に分けた

### うまくいかなかったこと

- 実装から写したはずの記述に誤りが 5 件あった（G-1・G-5・G-6・G-8・G-2）。0028・0029 でテストコードや記憶から書いた箇所で、実装の該当行を開いていなかった
- 作業ツリーが別セッションにより feature-8 に切り替わっていたのに気づかず、レビュー中にエージェントが git show でオブジェクト読みに切り替えていた。着手前に git branch --show-current を確認する

### 仕様からの逸脱

- 人間レビュー: 承認④により opus 敵対的レビューで代替。このチケットはその反映で、結果は note で報告する
- 実行者が main（全体計画の方針）

### 判断と根拠

- G-6・G-9 は仕様を実装どおりに書き、実装を変える案は 0031 に判断を渡す: 設計チケットで実装の振る舞いを変える判断をすると、実装計画が読む正が「仕様に書いたが実装が違う」件を増やす。どちらも害は小さい（正当な「- 次…」行は現在地の書き方で避けられる。command -v git は which git で代替できる）
- G-2 は実装（RV006・終了 1）を正にした: 導出元不明は「検査 6 が行えない」状態で他の検査結果と一緒に列挙する方が読み手に有用。RV008 を検査前の引数・ファイル不正に限定
- G-8 の語彙表は仕様を正に格上げ（「この一覧が正で実装と同じ集合」と明記）: HK-T05 の「全要素を踏む」の基準を仕様側に置くため
- G-19 は §8 に注記のみ: workflow-guard 本体は 2/3 で、制御方式 6 の文面は scope.sh の分類結果に対する分岐として読めば整合する。実装時に CP_PROVIDED を直に見ないことを注記した

### 拒否・確認・迂回の記録

- 作業ツリーが feature-8 に切り替わっていたため、ユーザーに確認して feature-6 に戻した（AskUserQuestion。他セッションの未コミット変更は無し）

### 使った AI アセットと効き目

- 20-common-step-spec / -requirement の手順（文言の修正のみ）・20-common-step-report-view（check-html.sh）・20-common-step-ticket
- wip/tmp/apply-pairs.pl、wip/tmp/p32-ddr.pl

### スコープ外で見つけたこと

- 各 SKILL.md のエラー表（CP007 / CP008 / TK008 / RV008）と eval 定義の SP-E は 0031 の対象（レビューも対象外とした）
- テストスイート（run-tests.sh）はこのチケットでは回していない（.claude/docs のみの変更。ops 宣言も read のみ）

### AI アセットに反映すべき内容

- 10-task-ai-asset-design-exec 仕様の処理フローに「実装を正として仕様に写すときは、実装の該当行（ファイル:行）を作業ログに残す」を 1 文 → 3/3

### 備考

- pairs: wip/tmp/p32-{common,skills,report,report-html}.txt、DDR: wip/tmp/p32-ddr.pl
