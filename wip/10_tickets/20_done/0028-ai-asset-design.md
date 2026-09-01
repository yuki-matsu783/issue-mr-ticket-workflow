---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0026"]
executor: main
human_review: {required: true, reason: "正史（仕様）の変更。承認④により opus 自己レビューで代替（切れ目 1 回）"}
adversarial_review: {required: true, reason: "正史の変更で差分が 1 文書・50 行を超える（切れ目 1 回）"}
allow:
  write: [".claude/docs/**", "wip/**"]
  ops: ["read"]
started_at: "2026-09-01T16:39:32+09:00"
completed_at: "2026-09-01T16:51:38+09:00"
base_sha: "e2e6f38"
---

# 0028 AI アセット設計: フック共通仕様と post-push 2 仕様への書き戻し（wip/20_plans/0026-ai-asset-design-plan.md の 0028）

## 目的

計画書 wip/20_plans/0026-ai-asset-design-plan.md「文書一覧と骨子」のフック共通仕様（§1 lib 一覧の HK-Txx / §3 redact の注記 / §6 に CP007・RV008・TK008 と eval 接頭辞 SP-E → SC-E / §7 cmdpos の出力の形と gitlike / §8 tsv ヘッダ・commands.build-test・build-test と hook-test の判定順・read と remote-read は常に可・承認単位の例外 / §9 cancelled_at・cancel_reason / §11 HK-T15 / §12 tool_response と案内側の読み込みポリシーの TBD / H6 jq 1.6）と post-push-usage-report（last_offset の単位）・post-push-compact-prompt（終了コードの読み方と未確認の明記）を更新し、DDR i0006-07（承認単位）・08（redact の除外条件）・09（read / remote-read 常に可）・12（引数・環境の誤りの識別子の新設）を作る

## DoD

- [x] 担当の要件定義書・仕様書が 20-common-step-requirement / -spec のテンプレートと固定節構成に沿って更新され、履歴（以前は〜）を書かず現在の正史だけになっている（フック共通仕様 §1・§3・§6・§7・§8・§9・§11・§12・H6、post-push-usage-report、post-push-compact-prompt）（根拠: フック共通仕様 §1・§3・§6・§7・§8・§9・§11・§12 を更新（git diff で 17 か所）。H6 は仕様に H 節が無いので §1 の transcript.sh の行に jq 1.6 の注記として書いた。post-push-usage-report「--accumulate」4 に last_offset の単位、post-push-compact-prompt「push 検知」2 に終了コードの読み順と未確認を追記。「以前は〜」の履歴は書いていない（差分は現在形の記述のみ））
- [x] 受け入れ条件 2（hooks/lib 5 本とテスト）が §11 のテスト観点に落ちている: HK-T15（scope の判定順・宣言の絞り込み・ops 分類・設定検査）が追加され、HK-T05 / HK-T10 / HK-T11 に 0025 で固定した観点（gitlike の負のケース・redact の除外・承認単位）が書かれている（根拠: §11 に HK-T15 の行（scope.sh の判定順 (1)〜(7)・d.write の絞り込み・ops 分類の常時可 3 種・コマンド分類の表の全要素・WF210 / WF211 の設定検査）を追加。HK-T05 に語彙表の全要素・負のケースの正の期待値・CP_GITLIKE の 0/1（digit / legit / github）、HK-T10 に *_KEY= 系とブランチ名・識別子を壊さないこと、HK-T11 に承認単位 "." とルート直下のファイル単位を追記。HK-T13 / T14 には計数 PATH と jq 1 回の観点も追記）
- [x] 台帳 §6 に CP007 / RV008 / TK008（引数・環境の誤り）が条件付きで登録され、eval 接頭辞が SC-E に改名されて既存接頭辞と重複しない（根拠: §6 の行を TK001–008 / CP001–007 / RV001–008 に改め、各行末に「00N は引数・環境の誤り」と条件を明記。eval 行を SC-E に改名し「SP-T（subagent-stop-check）と接頭辞を重ねない」と注記。§6 の他の接頭辞（SS / TR / FR / HK / WG / SP など）に SC は無いことを目視で確認）
- [x] 横断文書（自己改善ワークフロー機構.md・rules/ルール体系.md・90_glossary）と用語が食い違っていない（変更なしならその確認を根拠に書く）（根拠: 90_glossary/ワークフロー用語.md に「承認単位」「redact」の見出しは無く追加要否は 0030 の横断整合で判断（DoD に明記済み）。workflow-guard.md の WF202 行と workflow-diff-check.md「承認の記憶」の承認単位の文言を §8 に合わせて修正（ルート直下はファイル単位・"." は記録しない）。自己改善ワークフロー機構.md・rules/ルール体系.md は今回の変更語彙（ops 分類名・識別子）を持たないので変更なし）
- [x] 決定の経緯と却下案が担当の DDR に残り、DDR から仕様を参照している（仕様から DDR を参照しない）（i0006-07・08・09・12）（根拠: 20_ddr/i0006-07（承認単位）・08（redact の除外条件とキー名）・09（read / remote-read / provided 常に可）・12（識別子の新設）を i0006-06 と同じ frontmatter と節構成で作成。各 DDR の「影響」から仕様の節を参照。仕様側に書いてしまった DDR 番号 2 か所は削除し、仕様に残る DDR 参照は既存の i0006-01（§7 の依存の説明）だけであることを grep で確認）
- [x] ヘッドレス実行の帰結（止まる / 既定で進む）が変更ごとに仕様に書かれている（根拠: §8 の承認単位（ルート直下は 1 ファイルごとに ask = 止まる）・常時可 3 種（宣言漏れで止まらない = 進む）・hook-test 先行判定（未宣言なら止まる）、§12 T7（フィールド名が無ければ 0 とみなす = 進む側）・T8（deny JSON だが PostToolUse では無視）を仕様と結果報告「ヘッドレス実行で確認すること」の表に書いた）

## 作業内容

- 計画書の対応表と骨子（フック共通・post-push 2 仕様・DDR 4 件）を読み、レポート 0013 の逸脱 D-2・D-4・D-6・D-12・D-22〜D-27・D-33・D-34 とレビュー F-7・F-10・F-12・F-13・F-15・F-19 の根拠を仕様の文言に写す
- 20-common-step-spec / -requirement の手順で更新し、DDR は既存 i0006-01〜06 の形に合わせる

## 作業ログ

### 現在地

- 済: 計画 0026 の対応表と骨子を読む → フック共通仕様 §1/§3/§6/§7/§8/§9/§11/§12 と post-push 2 仕様を更新 → workflow-guard / workflow-diff-check の承認単位の文言を合わせる → DDR i0006-07/08/09/12 → 結果報告 0028 の md と HTML（check-html OK）→ このチケットの記入
- 完了: commit.sh → ticket.sh complete 0028 → 0029 へ（push は 0029 の後でもよいが、done コミット直後の push は許されるので行う）

### うまくいったこと

- 0026 の骨子が節番号まで指定していたので、仕様の編集は「該当行を探して pairs で置換」で 17 か所を一度に当てられた（miss 0）
- DDR を「却下した案を持つ判断」だけに絞る基準を先に決めたので、逸脱 13 件に対して 4 件で済んだ

### うまくいかなかったこと

- 仕様本文に DDR 番号を書いてしまい、DoD の「仕様から DDR を参照しない」に気づいて後から削った。編集前に DoD を読み直すべきだった
- G5（build-test の定義）は計画が「どちらかに合わせる」までしか決めておらず、この場で仕様を狭める判断をした。設計計画で決めておく方が良かった

### 仕様からの逸脱

- 人間レビュー: 承認④により opus 自己レビューで代替（設計の切れ目 0030 の後に 1 回）
- 実行者が main（全体計画の方針）
- 結果報告の HTML は report.template.html を直接コピーせず、同じテンプレート由来の 0008 の HTML の head（スタイル）を再利用して本文を書いた（テンプレートの必須節 data-required はすべて保持。check-html OK）

### 判断と根拠

- 実装を正として仕様に写す: 実装レビューで欠陥とされず、テストで固定済みの振る舞いを仕様に戻すと二重の変更になる
- read / remote-read / provided は常に可（仕様側を変える。DDR i0006-09）: 宣言漏れでヘッドレスが止まる害が大きい
- build-test は tests/ / test/ 始まりに限定: 「配下」に広げると find で全 *.sh を拾う実装になり hook-test との区別が崩れる。参考実装は commands.build-test に列挙する経路（i0006-05）がある
- 識別子は新設（DDR i0006-12）: SKILL.md のエラー表が 1 番号 1 対処を前提にしている
- §12 T7・T8 は未確認として TBD 表に載せる: 0008 の T5・T6 と同じ扱い
- H6 の置き場: 仕様に H 節が無いので §1 の transcript.sh の行に書いた

### 拒否・確認・迂回の記録

- なし

### 使った AI アセットと効き目

- 10_spec/skills/10-task-ai-asset-design-exec.md の処理フローと OUT ひな形: レポートの節構成に使えた
- 20-common-step-spec（固定節構成）・DDR i0006-06（形式の型）・20-common-step-report-view（report.template.html の必須節・check-html.sh）
- wip/tmp/apply-pairs.pl（自作。exact 置換で miss を数える）

### スコープ外で見つけたこと

- workflow-guard.md の WF204 / WF206 の説明（「allow.ops と types[t].ops の両方にあれば許可」）は read / remote-read / provided の例外を書いていない。0030 の横断整合で見る（残課題に記載）
- 90_glossary に「承認単位」の項が無い。追加要否は 0030 で判断

### AI アセットに反映すべき内容

- 10-task-ai-asset-design-plan 仕様: 「実装と仕様が食い違う候補は、計画の段階でどちらを正にするかまで決める」を骨子の書き方に 1 文（G5 の反省）→ 3/3

### 備考

- pairs: wip/tmp/p28-common.txt, wip/tmp/p28-postpush.txt。HTML 本文: wip/tmp/rep-0028-body.html
