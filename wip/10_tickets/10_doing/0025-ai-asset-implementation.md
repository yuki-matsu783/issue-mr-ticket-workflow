---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0021"]
executor: main
human_review: {required: true, reason: "振る舞いが変わる（承認④により opus 自己レビューで代替。切れ目の note に追記）"}
adversarial_review: {required: false, reason: "切れ目の敵対的レビューの指摘対応。上限（切れ目 1 回）に達している"}
allow:
  write: [".claude/rules/**", ".claude/hooks/lib/**", ".claude/hooks/config/**", ".claude/hooks/tests/**", ".claude/skills/20-common-step-*/**", ".claude/evals/**", "wip/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: "2026-09-01T15:21:02+09:00"
completed_at: ""
base_sha: "2475fce"
---

# 0025 AI アセット実装・追加（敵対的自己レビュー F-1〜F-25 の対応）

## 目的

0013〜0021 の切れ目で行った opus 自己レビュー（PR #7 の boundary:note ai-asset-implementation:0021、全文 wip/tmp/review-impl-findings.md）の confidence >= 0.5 の指摘 19 件のうち実装で解消できるもの（F-1〜F-6・F-8〜F-14・F-17〜F-19）と、軽微だが安価な F-20・F-21(a)・F-22・F-23(b)・F-24・F-25(b) を直す。仕様の判断が要る F-7・F-15・F-16・F-23(a)・F-25(a)(c) は 0022 の候補に載せ、ここでは触らない

## DoD

- [ ] F-1 / F-24 / F-18(a): commit.sh が git add 後に実際にステージされた全パス（git diff --cached --name-only）へ除外パターンを当てて除外分を reset し、ディレクトリ引数は CP001 で拒否する。CP-T03 にディレクトリ・symlink・.gitignore 混在のケースがあり、SKILL.md の文言（対象はファイル単位）を合わせた（根拠: ）
- [ ] F-2 / F-18(b): push.sh はスキップ記録を HEAD のコミット済み版（git show HEAD:wip/push-check-skip.md）からだけ読み、未コミットの記録では項目を飛ばせない。テスト（CP-T06 または CP-T07）に未コミット記録のケースがある（根拠: ）
- [ ] F-3: script.template.sh と提供コマンド全部（commit.sh / push.sh / ticket.sh / check-html.sh / run-tests.sh）の読み込み行の nop 分岐で LOGGER_ROOT を必ず設定し、logger.sh 不在で commit.sh -m ... が CP<番号>: または OK: で終わる。SS-T に logger 不在のケースがある（根拠: ）
- [ ] F-4: check-html.sh の属性値抽出（src / href / id / @import 相当）が二重引用符と単一引用符の両方に対応し、RV-T02 に単一引用符の負のケースがある（根拠: ）
- [ ] F-5 / F-6 / F-21(a) / F-25(b): ticket.sh complete が根拠欄の無い - [x] 行を未充足に数える（TICKET-T03 に追加）、cancel --reason と set_field の値の & と \ をエスケープする（TICKET-T09 に記号入りのケース）、未コミット判定を grep -Fvx の完全一致にする、commit.sh の -m 値なしは CP001 終了 2（根拠: ）
- [ ] F-10 / F-19(a)(c): scope.sh でルート直下ファイルの承認単位をファイル単位にして承認済み "." が全体 allow にならない（HK-T11 に追加）、cmdpos の CP_GITLIKE を対象セグメントの exe / args だけで判定し gitlike=0 の負のケースを HK-T05 に置く、hook_record の id / decision も JSON エスケープを通す（根拠: ）
- [ ] F-12 / F-13: redact のパターン 3 のキー名を [A-Za-z_]*(secret|token|key|password)[A-Za-z_]*= に広げ AWS 形式（/ を含む 40 文字）をマスクし、規則 5 は英小文字とハイフンだけの語（ブランチ名・チケット名）を対象外にする。HK-T10 に AWS 形式の正のケースと長いブランチ名の負のコントロールがある（根拠: ）
- [ ] F-9 / F-11 / F-14 / F-17 / F-19(b): テストの実質化 — cmdpos の語彙定数（ラッパー / opaque / 書込先）と scope の読み取り一覧・git 読み取りサブコマンド・gh 分類・tool_class の分類表を配列で全要素ループ検査する、HK-T05 の負のケースに正の期待値（count / exe）を併記する、HK-T13 / HK-T14 の fork ゼロ・jq 1 回を呼び出し記録 PATH で回数として検査する、HK-T08 に CI=false の負のケースを置く。いずれもレビューの変異（M7〜M19・M29）を再現して FAIL することを確かめた（根拠: ）
- [ ] F-8: ルール 4 本（work-defaults / logger / design-docs / ai-asset-design-docs）の eval 定義が .claude/evals/ に eval.template.md の形であり、ID の接頭辞が台帳・既存 eval と重複しない（未実行の明記）（根拠: ）
- [ ] F-20 / F-23(b) / F-22: push.sh の jq 検査を logs/merge-state.json が存在するときに限定した。work-defaults.md の前文に「載っていない種類はスキルの既定に倒し、基準に無いことを明示して合意する」を追加した。レポート 0013 の文言（テンプレート 11 本・旧名は仕様書に 1 件）を訂正し、HTML に逸脱 D-1〜D-28 の一覧表を載せ check-html.sh OK（根拠: ）
- [ ] run-tests.sh --ids が全通過し、ID の追加分（あれば）が仕様のテスト観点と対応している。レポート 0013 に 0025 の節（変更したアセット・追加したテスト・逸脱）を追記した（根拠: ）

## 作業内容

- review-impl-findings.md の F-1〜F-25 を順に読み、修正 → 該当テストに負のケース追加 → 個別テスト → 全体テストの順で進める
- 各修正の前にレビューの再現手順（一時リポジトリ）で FAIL を確かめ、修正後に PASS を確かめる
- 0022 送りの F-7 / F-15 / F-16 / F-23(a) / F-25(a)(c) は作業ログ「仕様からの逸脱」に写すだけで実装に触れない

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
