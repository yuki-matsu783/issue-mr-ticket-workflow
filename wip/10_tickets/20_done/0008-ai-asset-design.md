---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0007"]
executor: main
human_review: {required: true, reason: "正史（.claude/docs/）の変更（敵対的レビューで代替）"}
adversarial_review: {required: false, reason: "フェーズの敵対的レビューは 0006〜0008 をまとめて 1 回実施する"}
allow:
  write: [".claude/docs/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-02T09:56:12+00:00"
completed_at: "2026-09-02T09:58:38+00:00"
base_sha: "a26e10f"
---

# 0008 設計: フック共通仕様の許可範囲と残りの置き場の参照

## 目的

フック共通仕様の許可範囲の表と識別子台帳の適用範囲を新しい置き場に合わせ、タスクスキルの要件・仕様と横断文書に残る置き場の記述を揃え、機械的検査の判断を DDR に残す

## DoD

- [x] フック共通仕様の許可範囲の表が apl/*/docs/** apl/*/src/** apl/*/test/** の形になり、scope_match で確認したパターンと一致している（根拠: .claude/docs/10_spec/フック共通仕様.md の初期値 JSON（implementation / ai-asset-implementation）と許可範囲の表 8 行。パターンの注記に apl/*/docs/** が / を跨がない性質を使う旨を追記。scope_match での確認結果は調査結果レポート「照合器の確認」）
- [x] フック共通仕様 §6 に「アプリのエラー識別子の接頭辞は台帳の対象外」が書かれている（根拠: 同ファイル §6 の台帳の後に段落を追加（2 文字 + 3 桁・仕様書が兼ねる・apl/*/docs/10_spec/ を検索））
- [x] タスクスキルの要件 4 本・仕様 3 本と workflow-guard 仕様・自己改善ワークフロー機構の置き場の記述が揃っている（根拠: 要件 5 本（10-task-design-plan / -design-exec / -implementation-exec / -overall-plan / 00-workflow-issue-mr-driven）と仕様 3 本（10-task-design-plan / -design-exec / 00-workflow-issue-mr-driven）、自己改善ワークフロー機構.md:120。workflow-guard 仕様は該当行が無く対象外）
- [x] DDR i0020-03（機械的検査を issue #24 に寄せる）があり、申し送り 2 件が書かれている（根拠: .claude/docs/20_ddr/i0020-03-アプリの設計文書検査をissue24に寄せる.md。申し送り 2 件（対象ルートが 2 つ・仕様書の形の検査の担い先）と却下した案 3 件）
- [x] リポジトリ全体を grep して .claude/docs/ 配下に旧置き場の記述が残っていない（根拠: `src/**` `docs/**` の glob 表記を apl/ を伴わない形で検索して 0 件（DDR i0020-01 の経緯の記述を除く））

## 作業内容

- DoD の各項目を順に満たす

## 作業ログ

### 現在地

- 完了。フック共通仕様の許可範囲と §6、タスクスキルの要件・仕様 8 本、自己改善ワークフロー機構を揃え、DDR i0020-03 を作った

### うまくいったこと

- 許可範囲を `apl/*/docs/**` と `apl/*/src/**` に分けたことで、設計タスクがソースを、実装タスクが設計文書を書けない状態を保てた。`apl/**` 一括だとこの分離が消える
- 旧置き場の残存確認を「glob 表記の検索」に絞ったので、散文の「アプリルートの `docs/`」を誤検知せずに済んだ

### うまくいかなかったこと

- 最初の残存確認は否定先読みの正規表現で書いたが、`apl/<アプリ名>/docs/` のような正しい記述まで拾って 27 件出た。検索対象を glob 表記（`` `docs/**` `` `"src/**"`）に絞り直した
- `workflow-guard` の仕様書に置き場依存の記述があると調査結果に書いていたが、実際には該当行が無かった（調査時に拾った `:102` はサンプルパスで据え置き対象）

### 仕様からの逸脱

- 逸脱なし

### 判断と根拠

- `implementation` の `deny` に `apl/*/docs/**` を明示的に足した。`allow` を `apl/*/src/**` `apl/*/test/**` に絞れば暗黙に書けなくなるが、判定順 (3) の deny で先に落としたほうが理由（WF201）が明確になる
- `ai-asset-implementation` と各 plan タスクの `deny` は `apl/**` の一括にした。これらはアプリ配下をまったく書かないので、細かく分ける意味が無い
- 機械的検査を #24 に寄せる判断を DDR にした（i0020-03）。issue #20 の受け入れ条件 5 は「要否が判断され」なので、判断の記録が成果物になる

### 拒否・確認・迂回の記録

- 迂回は無し

### 使った AI アセットと効き目

- `フック共通仕様.md` の許可範囲の表: `scope-limits.json` の写しなので、フェーズ 3 の実装がこの表をそのまま JSON に落とせる形になっている

### スコープ外で見つけたこと

- `.claude/hooks/lib/tests/test_scope.sh` のフィクスチャは `フック共通仕様.md` の初期値 JSON の写しで、二重管理になっている。仕様が変わるたびに 2 か所を直す必要がある（本 issue の範囲外）

### AI アセットに反映すべき内容

- フェーズ 3 で `scope-limits.json` と `test_scope.sh` を、この仕様書の表と初期値 JSON に合わせる
- ルール本体の「処理フロー 12」の参照を「処理フロー 14」に直す（0007 から引き継ぎ）

### 備考
