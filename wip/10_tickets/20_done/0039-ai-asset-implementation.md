---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0036"]
executor: main
human_review: {required: true, reason: "提供コマンドと共通ライブラリの振る舞いが変わる（work-defaults の既定）。承認④により opus 自己レビューに代替"}
adversarial_review: {required: false, reason: "この切れ目の敵対的レビューは 1 回実施済み（wip/tmp/review-impl2-findings.md）。反映の確認は結果報告と全件テストで行う"}
allow:
  write: [".claude/skills/20-common-step-ticket/scripts/**", ".claude/skills/20-common-step-shell-script/scripts/**", ".claude/skills/20-common-step-report-view/scripts/**", ".claude/skills/20-common-step-commit-push/scripts/**", ".claude/evals/**", "wip/**"]
  ops: ["read", "build-test", "hook-test"]
started_at: "2026-09-01T19:58:01+09:00"
completed_at: "2026-09-01T20:13:45+09:00"
base_sha: "be876f2"
---

# 0039 AI アセット実装・追加: 敵対的レビュー I2-1〜I2-22 の反映（実装 0033〜0036 の切れ目）

## 目的

実装 2 回目（0033〜0036）の切れ目の opus 敵対的レビュー（wip/tmp/review-impl2-findings.md、確度 0.5 以上 22 件）のうち、この issue で直すべき 7 群を反映する: (1) 結果報告の壊れた記述と未記録の逸脱（I2-1 / I2-2 / I2-4 / I2-11 / I2-13 / I2-16）、(2) ticket.sh の create / cancel で末尾のオプションに値が無いときに最終行を出さず終了 1 する契約違反（I2-3）、(3) frontmatter.sh の fm_list がエスケープ付きフロー配列を壊す不具合と fm_get / fm_list のアンエスケープ、および誤った期待値を焼き付けた TICKET-T05 / cancel の往復（I2-6 / I2-7 / I2-8）、(4) 識別力の無いテスト（I2-5 / I2-10 / I2-17）、(5) CP-T04 に残る CP001 assert の帰属と complete の見出し存在検査の厳格化（I2-9 / I2-14）、(6) check-html.sh の未使用定数と読めないファイルの検査、hook_payload --session の値なし呼び出し（I2-12 / I2-15 / I2-21）、(7) --executor の語彙検査（I2-18）と eval の判定基準の引き上げの扱い（I2-20）。仕様の書き戻しが要るもの（I2-19 / I2-22 / I2-23〜I2-28）は 3/3 への申し送りとして結果報告に残す

## DoD

- [x] frontmatter.sh の fm_list がクォートを認識して要素を分割し、fm_get / fm_list が二重引用符内の \" と \\ を解除する。ticket.sh create で書いた記号入りの理由・glob が fm_get / fm_list で元の値として読み戻せる（TICKET-T05 の create / cancel の往復・3 要素のリスト、FR-T0x の追記が通る）（根拠: frontmatter.sh: __fm_clean / __fm_split が二重引用符の中のバックスラッシュで次の 1 文字を逃がし（\" で要素を割らない・コメント判定で切らない）、__fm_unquote が \" → " と \\ → \ を戻す（未知の \x は文字どおり）。TICKET-T05 が create の理由（a"b\c & d | e）・3 要素の allow.write（x/** / y"z / p\q）・cancel の理由を元の値として読み戻すことを assert し全 PASS。FR-T03 に同じ観点（fm_get / fm_list / # を含む値）を追記して PASS。テスト先行では 7 件 FAIL していた）
- [x] ticket.sh の create / cancel で値を取るオプションが末尾に来て値が無いとき、最終行 TK008: を出して終了 2 になる（TICKET-T12 に 3 ケース以上）。--executor が語彙（main またはモデル名の形）でなければ TK008 で拒否する（根拠: need_val を新設し create の 12 オプションと cancel --reason に適用（従来は set -e 下の shift 失敗で最終行を出さずに終了 1。実測 create investigation --title → rc=1 出力なし）→ TK008: 終了 2。--executor は ^(main|[A-Za-z][A-Za-z0-9._-]*)��検査して TK008。TICKET-T12 に 4 ケース（--title / --allow-write / --reason の値なし、executor 語彙外）を追加し全 PASS）
- [x] 識別力の無いテストを直した: TICKET-T10 の index 検査は git reset が実際に効く経路で新旧を区別するか、要らないと判断した場合は git reset を削って理由を記録する。TICKET-T10 の index assert が 4 経路にある。CP-T08 の logger 不在の経路に最終行の assert_eq がある（根拠: 実測（wip/tmp/p39-probe.sh で新旧の ticket.sh を一時リポジトリで切り替え）: create / start / cancel の拒否後の git diff --cached は旧版でも空 = do_commit の git reset（L82、旧版にもある）で足りており、0034 が足した 4 か所は冗長。4 か所を削除し（削除後も index は空を実測）、TICKET-T10 の index assert を create / start / complete / cancel の 4 経路に置いた。CP-T08 の logger 不在の経路に最終行の assert_eq（成功側 OK / 失敗側 CP002）と stderr が空の assert を追加）
- [x] CP-T04 に残っていた CP001 の 4 assert を CP-T03 に移し、complete の固定見出しの存在検査が末尾空白・CR を許す形になっている（TICKET-T03 に「末尾空白付きの見出しは通る」「別見出しを数えない」を追加）。どちらも結果報告の逸脱に記録がある（根拠: test_commit.sh の CP001 4 assert（未指定・一括 . / -A・glob・存在しないパス）を CP-T03 に付け替え、assert_contains を最終行の assert_eq に替えた（仕様 CP-T03 が CP001 を持つ）。ticket.sh の見出し一致を grep -cE "^### $h[[:space:]]*$" に緩め、TICKET-T03 に「末尾に空白がある見出しでも完了できる」「前方一致の別見出し（### 現在地の続き）を重複に数えない」を追加。どちらも結果報告の逸脱 D2-6 / D2-5 に記録）
- [x] check-html.sh の未使用定数 SCRIPT_PREFIX を解消し、読めないファイルを RV008 で拒否する。test-lib.sh の hook_payload --session が値なしで呼ばれても unbound variable で落ちない（根拠: check-html.sh: readonly SCRIPT_PREFIX="RV"（参照 0 件）を削除し、[ -r "$file" ] || result_ng2 "RV008: ファイルを読めない: $file" を追加（仕様の「読めない」）。RV-T07 に検査を足したが、本環境（Windows / NTFS）は chmod 000 が効かないためテスト側で -r を見てスキップする形にした（未実行）。test-lib.sh: hook_payload --session を値なしで呼んでも既定 testsession のまま（実測: --session → testsession、--session s9 command=ls → s9 / ls））
- [x] run-tests.sh --ids が全件 PASS で、本数・ID 数・重複 ID の報告が作業ログにある。プレースホルダ・frontmatter・参照更新の検査結果が件数で作業ログにある（根拠: run-tests.sh --ids → OK: 14 本 / 59 件（ID は増えず assert が増えた: test_ticket 102 → 117、test_frontmatter 36 → 41、test_commit 68、test_check_html 51）。FAIL / TIMEOUT なし。重複 ID の報告は CP-T08 のみ（0033 から。完了済みチケットの根拠は訂正 6 として結果報告に記した）。個別実行の所要は test_ticket 60 秒台）
- [x] 結果報告 wip/30_reports/0033-ai-asset-implementation.md（+ HTML、check-html.sh OK）に、このチケットの節（レビュー指摘 × 対応の対応表）・訂正（0033 の DoD 根拠が偽だったこと、チケット外コミット 146f218、HK-T15 の assert 数 92、D2-4 の末尾改行の差、受け入れ条件 4 の限定）・3/3 への申し送りの追記がある（根拠: レポート md + HTML（check-html.sh OK）に 0039 の節を追記: 作成・更新したアセット 10 件 × 指摘、テスト結果、切れ目のレビュー I2-1〜I2-28 × 対応の表、訂正 6 件（0033 の DoD 根拠が偽・チケット外コミット 146f218・HK-T15 は 92 assert・D2-4 の末尾改行・受け入れ条件 4 の限定・「重複 ID なし」の誤り）、逸脱 D2-5 / D2-6 / D2-7、残課題（3/3 へ 7 件・別 issue 1 件）。I2-4 の壊れた日本語も直した）

## 作業内容

- wip/tmp/review-impl2-findings.md の指摘表と「追加チケットで直すべきもの」7 群を読み、対応表（指摘 ID × 対応 / 見送りと理由）を先に作る
- テスト先行: fm_list の 3 要素・記号入り、create / cancel の往復、末尾オプションの値なし、--executor の語彙、logger 不在の最終行、見出しの末尾空白を先に書いて失敗を確認してから実装する
- I2-5 は「git reset が効く経路」を実測で特定してから、テストを組み直すか git reset を削るかを決める（現状追認のテストを残さない）

## 作業ログ

### 現在地

- 済: レビュー結果 wip/tmp/review-impl2-findings.md（22 件 + 6 件）を読み対応表を作る → テスト 4 本を先に変更して FAIL 41 を確認 → frontmatter.sh / ticket.sh / check-html.sh / test-lib.sh / commit.sh / eval を変更 → 該当テスト全 PASS → 全件 → 検査 → レポートに 0039 の節と訂正 6 件 → このチケットの記入
- 完了: commit.sh で成果物をコミット → ticket.sh complete 0039 → push.sh → 切れ目の note コメント → 0037（全体まとめ）

### うまくいったこと

- 指摘のうち「実測で確かめるもの」（I2-5 の git reset、I2-6 の fm_list、I2-3 の最終行）を先に一時リポジトリで再現してから直したので、直す範囲を最小にできた
- 往復（ticket.sh が書く → frontmatter.sh が読む）の修正を 1 枚のチケットの許可範囲に収めたので、0034 / 0035 で割れていた D2-2 をこのチケットで閉じられた

### うまくいかなかったこと

- 0033 の「HTML は check-html.sh OK」を、完了コミットの前ではなく後に検査していた（I2-1）。DoD の根拠を「実行したコマンドと出力」で書いていても、実行した時点が完了の後なら根拠にならない。完了検査は完了コミットの直前に、実際に完了させる版で回す（3/3 の実施タスク仕様へ）
- そのときの修正をチケット外（作業中 0 枚の区間）で行った（I2-2）。チケットの外で成果物を触らない
- 0034 で足した git reset 4 か所は、既に do_commit が同じことをしていた（I2-5）。「足す前に、その保証が既にどこかに無いか」を見ていなかった
- 読めないファイルの検査（I2-15）は実装したが、本環境では chmod 000 が効かずテストが走らない（テスト側で -r を見てスキップ）。環境依存の検査を「実機で確かめた」と書けない

### 仕様からの逸脱

- D2-5（見出しの厳格化）・D2-6（CP-T04 の CP001）・D2-7（冗長な git reset）を過去の逸脱として記録し、いずれもこのチケットで解消した
- 新たな逸脱: frontmatter.sh のアンエスケープは shell-script 仕様の「クォートは外す」に明記が無い（ticket 仕様 TICKET-T05「fm_get で読み戻せる」を根拠に実装した）。仕様の明記は 3/3
- 人間レビュー・敵対的レビューは実装 4 枚の切れ目で 1 回（承認④により opus 代替）。実行者 main

### 判断と根拠

- アンエスケープは「知っているエスケープ（\" と \\）だけ戻す」ことにした（未知の \x を落とすと glob の \ が消える）
- git reset は呼び手側から削って do_commit の 1 か所に集約した（保証を 1 か所に置く。テストは 4 経路とも index が空であることを見る）
- --executor は yaml_escape の対象にせず語彙検査にした（frontmatter に引用符なしで入る値なので、エスケープではなく値の形を縛るのが素直）
- eval の判定基準は「4 シナリオのうち 2 つ以上」に戻した（他の eval と基準を揃える。シナリオを増やしたことを合格の重みに反映しない）
- I2-15（読めないファイル）は実装したがテストは本環境で走らない。テスト側で -r を見て条件付きにし、走らなかった事実をレポートに書いた（環境が変われば動く）

### 拒否・確認・迂回の記録

- なし

### 使った AI アセットと効き目

- opus の敵対的レビュー（wip/tmp/review-impl2-findings.md）: 22 件のうち実測を伴う指摘が多く、そのまま再現手順として使えた
- 20-common-step-shell-script（テストの書き方の規約: 負のケースの正の期待値・最終行を exact に）、20-common-step-report-view（check-html.sh）

### スコープ外で見つけたこと

- test-lib.sh 自身のテスト ID が仕様に無く、--session の値なしのような回帰を置く場所が無い（3/3 へ）
- 仕様 complete 3 の一覧に「固定見出しがすべてある」が無い（実装と SKILL.md にはある）（3/3 へ）
- TK007（取り消し理由が空）だけ終了 1 で、他の引数の誤り（TK008）は終了 2（3/3 へ）

### AI アセットに反映すべき内容

- 3/3 へ: 実施タスク仕様に「完了検査は完了コミットの直前に、実際に完了させる版で回す」/ shell-script 仕様に fm_get・fm_list のアンエスケープと test-lib.sh のテスト ID / ticket 仕様に complete 3 の見出し存在と TK007 の終了コード / report-view 仕様に check-html.sh の awk 前提 — 結果報告「残課題」に集約
- 別 issue（小改善）へ: 全件テストの所要（test_ticket.sh が 117 assert で 60 秒台、全件 5 分）

### 備考

- スクリプト: wip/tmp/p39-tests.pl（テスト先行）/ p39-impl.pl（実装）/ p39-probe.sh（git reset の実測）。全件の出力 wip/tmp/p39-full.out
