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
started_at: ""
completed_at: ""
base_sha: ""
---

# 0039 AI アセット実装・追加: 敵対的レビュー I2-1〜I2-22 の反映（実装 0033〜0036 の切れ目）

## 目的

実装 2 回目（0033〜0036）の切れ目の opus 敵対的レビュー（wip/tmp/review-impl2-findings.md、確度 0.5 以上 22 件）のうち、この issue で直すべき 7 群を反映する: (1) 結果報告の壊れた記述と未記録の逸脱（I2-1 / I2-2 / I2-4 / I2-11 / I2-13 / I2-16）、(2) ticket.sh の create / cancel で末尾のオプションに値が無いときに最終行を出さず終了 1 する契約違反（I2-3）、(3) frontmatter.sh の fm_list がエスケープ付きフロー配列を壊す不具合と fm_get / fm_list のアンエスケープ、および誤った期待値を焼き付けた TICKET-T05 / cancel の往復（I2-6 / I2-7 / I2-8）、(4) 識別力の無いテスト（I2-5 / I2-10 / I2-17）、(5) CP-T04 に残る CP001 assert の帰属と complete の見出し存在検査の厳格化（I2-9 / I2-14）、(6) check-html.sh の未使用定数と読めないファイルの検査、hook_payload --session の値なし呼び出し（I2-12 / I2-15 / I2-21）、(7) --executor の語彙検査（I2-18）と eval の判定基準の引き上げの扱い（I2-20）。仕様の書き戻しが要るもの（I2-19 / I2-22 / I2-23〜I2-28）は 3/3 への申し送りとして結果報告に残す

## DoD

- [ ] frontmatter.sh の fm_list がクォートを認識して要素を分割し、fm_get / fm_list が二重引用符内の \" と \\ を解除する。ticket.sh create で書いた記号入りの理由・glob が fm_get / fm_list で元の値として読み戻せる（TICKET-T05 の create / cancel の往復・3 要素のリスト、FR-T0x の追記が通る）（根拠: ）
- [ ] ticket.sh の create / cancel で値を取るオプションが末尾に来て値が無いとき、最終行 TK008: を出して終了 2 になる（TICKET-T12 に 3 ケース以上）。--executor が語彙（main またはモデル名の形）でなければ TK008 で拒否する（根拠: ）
- [ ] 識別力の無いテストを直した: TICKET-T10 の index 検査は git reset が実際に効く経路で新旧を区別するか、要らないと判断した場合は git reset を削って理由を記録する。TICKET-T10 の index assert が 4 経路にある。CP-T08 の logger 不在の経路に最終行の assert_eq がある（根拠: ）
- [ ] CP-T04 に残っていた CP001 の 4 assert を CP-T03 に移し、complete の固定見出しの存在検査が末尾空白・CR を許す形になっている（TICKET-T03 に「末尾空白付きの見出しは通る」「別見出しを数えない」を追加）。どちらも結果報告の逸脱に記録がある（根拠: ）
- [ ] check-html.sh の未使用定数 SCRIPT_PREFIX を解消し、読めないファイルを RV008 で拒否する。test-lib.sh の hook_payload --session が値なしで呼ばれても unbound variable で落ちない（根拠: ）
- [ ] run-tests.sh --ids が全件 PASS で、本数・ID 数・重複 ID の報告が作業ログにある。プレースホルダ・frontmatter・参照更新の検査結果が件数で作業ログにある（根拠: ）
- [ ] 結果報告 wip/30_reports/0033-ai-asset-implementation.md（+ HTML、check-html.sh OK）に、このチケットの節（レビュー指摘 × 対応の対応表）・訂正（0033 の DoD 根拠が偽だったこと、チケット外コミット 146f218、HK-T15 の assert 数 92、D2-4 の末尾改行の差、受け入れ条件 4 の限定）・3/3 への申し送りの追記がある（根拠: ）

## 作業内容

- wip/tmp/review-impl2-findings.md の指摘表と「追加チケットで直すべきもの」7 群を読み、対応表（指摘 ID × 対応 / 見送りと理由）を先に作る
- テスト先行: fm_list の 3 要素・記号入り、create / cancel の往復、末尾オプションの値なし、--executor の語彙、logger 不在の最終行、見出しの末尾空白を先に書いて失敗を確認してから実装する
- I2-5 は「git reset が効く経路」を実測で特定してから、テストを組み直すか git reset を削るかを決める（現状追認のテストを残さない）

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
