---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0031"]
executor: main
human_review: {required: true, reason: "正史（要件）の変更"}
adversarial_review: {required: false, reason: "フェーズ 6 の敵対的レビューの指摘対応"}
allow:
  write: [".claude/docs/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-02T11:43:49+00:00"
completed_at: "2026-09-02T11:45:14+00:00"
base_sha: "9147117"
---

# 0032 設計: DDR の置き換えを表す frontmatter のキーと値を定義する

## 目的

status / superseded_by / supersedes の名前・許容値・値の形を正史に定め、部分置き換えを表せるようにする

## DoD

- [x] 両ルールの要件書に、DDR の状態の許容値（置き換え済み / 一部置き換え済み / 廃止）と、一部置き換え済みのときに範囲を書く場所が定義されている（根拠: `00_requirement/rules/design-docs.md:80` と `ai-asset-design-docs.md:78` の「DDR がマージされたあと」の項目を、`status` の許容値を 3 つ（`置き換え済み` = 決定の全体が無効 / `一部置き換え済み` = 一部だけ無効 / `廃止` = 後継を持たずに無効）に限る形に書き換えた。範囲を書く場所は次の項目で `superseded_scope` と定めた）
- [x] superseded_by と supersedes の値の形（パスのみ。散文を混ぜない）と、双方向に付けるかどうかが定義されている（根拠: `design-docs.md:81` と `ai-asset-design-docs.md:79` に「置き換えの関係を frontmatter に書くとき」の項目を追加。置き換えられた側に `superseded_by`、置き換えた側に `supersedes` を**対で**持たせること、値はパスだけで散文・但し書きを混ぜないこと、`一部置き換え済み` のときは `superseded_scope` に 1 行で書くことを定めた）
- [x] .claude/docs/20_ddr/i0020-01 が新しい定義に従っている（i0013-01 を置き換えた側の supersedes）（根拠: `.claude/docs/20_ddr/i0020-01-…` の frontmatter に `supersedes: ../../../apl/vscode-ticket-board/docs/20_ddr/i0013-01-成果物の置き場をsrc配下にする.md` を追加。`cd .claude/docs/20_ddr && ls <その相対パス>` が解決することを確認した。逆向き（`i0013-01` の `superseded_by`）も同様に解決する）
- [x] design-docs と ai-asset-design-docs の要件書で、この規定の内容が食い違っていない（根拠: 2 本の要件書に足した文言は、`design-docs` / `ai-asset-design-docs` の語彙の違い（前者は requirement / spec、後者は要件書 / 仕様書）が出ない箇所なので、1 字違わず同文。`diff <(sed -n '80,81p' design-docs.md) <(sed -n '78,79p' ai-asset-design-docs.md)` が空）

## 作業内容

- 要件書 2 本に規定を足し、i0020-01 の frontmatter を合わせる

## 作業ログ

### 現在地

- 完了。要件書 2 本に DDR の状態と置き換えの規定を足し、`i0020-01` に `supersedes` を付けた

### うまくいったこと

- 0028 で自分が発明したキー（`status` / `superseded_by` / `supersedes`）を、後から正史に定義する形で追いつけた。定義が無いまま使っていたのは順序が逆だった
- 値の形を「パスだけ」と決めたことで、`i0013-02` に書いた「パス + 但し書き」が規定違反として明確になり、直す根拠ができた

### うまくいかなかったこと

- 0028 で新しい frontmatter のキーを 3 つ導入したのに、その時点でルールを見に行かなかった。`.claude/rules/design-docs.md` は状態の値を「置き換え済み / 廃止」の 2 つに名指ししていて、`一部置き換え済み` は語彙に無かった。同じルールの「他の文書と矛盾する記述を見つけたら、片方だけ直さず、矛盾する文書を特定して同じ変更の中で揃える」に反していた

### 仕様からの逸脱

- 実行者: 全体計画のとおりメインエージェント（`10-task-ai-asset-design-exec` スキル本体が未整備のため、`.claude/docs/10_spec/skills/` の対応する仕様書に従って主体で実施。issue #10 の範囲）

### 判断と根拠

- **`一部置き換え済み` を第 3 の値として認めた**: 値を消して `置き換え済み` に寄せる案もあった。だが `i0013-02` は節構成（10 節の名前）と識別子の接頭辞 `TB` の 2 つを決めていて、無効になったのは 7 番目の節名だけ。全体が無効と書くと、残り 9 節と `TB` の決定まで無効に見える。部分置き換えは実際に起きるので、表せる語彙を持つ方が正しい
- **範囲を別キー（`superseded_scope`）に出した**: 値にパスと散文を混ぜると、frontmatter から一覧を生成する仕組み（要件書が「一覧は frontmatter から生成する」と定めている）がパスとして読めない。キーを分ければ両方とも機械可読になる
- **`supersedes` を対で持たせる**: 片方向だけだと、置き換えた側から「自分が何を無効にしたか」を辿れない。索引を作るときに逆引きが要る。`i0020-01` に付けて対を揃えた
- **相対パスにした**: 置き換え関係はアプリの `20_ddr/` と機構の `.claude/docs/20_ddr/` をまたぐ。リポジトリルート相対だと文書の中の他の参照（すべて相対）と書き方が割れる。両方向とも `ls` で解決を確かめた
- **仕様書（`10_spec/`）には書かない**: このリポジトリの `00_requirement/rules/` は要件書のみでルールの仕様書を作らない規約（`ai-asset-design-docs` の 1:1:1）。frontmatter のキー定義は本来 `markdown-docs` ルールの担当だが、そのルールはまだ無い（issue #11）。今回は DDR に固有の規定として両ルールの要件書に置いた

### 拒否・確認・迂回の記録

- なし（`allow.write` の `.claude/docs/**` の範囲内）

### 使った AI アセットと効き目

- `.claude/rules/design-docs.md` 堅牢性の「置き換え済み / 廃止」: 自分が語彙の外の値を使っていたことの根拠になった

### スコープ外で見つけたこと

- frontmatter のキー定義の正は `markdown-docs` ルールだが、そのルールが未作成（issue #11）。今回 DDR 固有のキーを 2 本のルールの要件書に置いたが、`markdown-docs` ができたら移すか、参照関係を整理する必要がある

### AI アセットに反映すべき内容

- 新しい frontmatter のキーを導入するときは、先に定義を書いてから使う。用語辞書について同じ規定（「新しい固有語は、まず辞書に定義してから設計書で使う」）があるのに、キーには無かった。フィードバック計画の B11 に合流させて別 issue で扱う

### 備考

- 次は 0033（ルール本体とテスト）→ 0034（仕様書と DDR）→ 0035（render.ts）
