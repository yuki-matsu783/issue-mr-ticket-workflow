---
type: ticket
ticket_type: implementation
predecessors: ["0009"]
executor: main
human_review: {required: false, reason: "全体計画の方針の差分 4 により、人間レビューはワークごとの敵対的レビューに置き換える"}
adversarial_review: {required: true, reason: "振る舞いが変わるため基準どおり要。担い手は差分 4 により汎用サブエージェント"}
allow:
  write: ["src/**", "wip/**"]
  ops: ["read", "build-test"]
started_at: "2026-09-02T06:12:17+00:00"
completed_at: "2026-09-02T06:17:34+00:00"
base_sha: "0166493"
---

# 0010 中核層の実装とテスト（frontmatter / ticket / scan / board / render）

## 目的

VS Code に依存しない層を仕様書のとおりに実装し、テスト TB-T01〜TB-T14 を先に書いて通す

## DoD

- [x] src/vscode-ticket-board/ にプロジェクトの土台（package.json / tsconfig.json / .gitignore）があり、開発依存が typescript・@types/node・@types/vscode の 3 つに限られている（根拠: package.json の devDependencies が 3 件、dependencies は無し。tsconfig は仕様「配置」の JSON と一致）
- [x] core/frontmatter.ts・ticket.ts・scan.ts・board.ts・render.ts が仕様書「モジュール構成」「データの形」「処理フロー」のとおりに実装され、いずれも vscode を import していない（根拠: 5 ファイルすべて作成。grep -rn 'from "vscode"' src/core/ が 0 件）
- [x] テスト TB-T01〜TB-T14 に加え設計修正で足した TB-T15〜TB-T17 も含め、35 件が通る（実行方法: cd src/vscode-ticket-board && npm test）（根拠: npm test の出力 # pass 35 / # fail 0。異常系は frontmatter 無し・終端無し・空・引用符の閉じ忘れ・ブロック配列・読み取り失敗・未知の種類・番号の食い違い・不正なパスを含む）
- [x] npx tsc -p . が警告なく通る（strict 有効）（根拠: npm test の前段で tsc -p . が出力なく exit 0。tsconfig の strict: true）
- [x] チケット由来の文字列が escapeHtml を通ることを TB-T14 が確かめている（根拠: render.test.ts の「チケット由来の文字列をエスケープする」でタイトルの <script> と & と ' 、種類の <b>、filePath の " を検証。escapeHtml 単体でも 5 文字と二重変換を検証）
- [x] 仕様からの逸脱があれば作業ログに記録されている（根拠: 「仕様からの逸脱」節に 2 件を記録）

## 作業内容

- DoD の各項目を順に満たす

## 作業ログ

### 現在地

- 完了。中核層 5 モジュールとテスト 35 件を実装し、すべて通した

### うまくいったこと

- TDD の順序を守れた。5 モジュールとも、テストを書いて `tsc` が「モジュールが無い」で落ちることを確認してから実装に入った
- 設計の敵対的レビューで直した箇所が実装で効いた。とくにインラインマップの外側の波括弧を外す手順は、直っていなければ実チケット全件が TB002 だらけになっていた
- 仕様がテスト ID ごとに観点を書いていたので、テストの粒度で迷わなかった。TB-T15〜T17（パス検証・移動後の再走査・取り消し列）も設計修正で足された分をそのまま書けた

### うまくいかなかったこと

- テストの型注釈で `strict` に 3 回引っかかった。`Partial<Record<...>>` のインデックスと、`Array.prototype.find` のコールバック引数の型が推論されなかった。テスト側に型注釈を足して解決した
- 読み取り失敗（TB007）のテストを作るのに、チケット名に一致するディレクトリを置くという回りくどい手を使った。パーミッションを落とす方法は root 実行では効かないため

### 仕様からの逸脱

- 仕様の `Ticket` 型は `title` を非 optional としているが、読み取り失敗時の生成を別関数 `unreadableTicket` に分けた。仕様の走査 手順 4 は「TB007 だけを持つチケットとして扱い、`number` はファイル名の先頭 4 桁、`title` はファイル名」と定めており、それを満たす生成をパーサ本体から分離しただけで、外から見える振る舞いは仕様どおり
- 仕様の HTML 骨格は `<meta name="viewport">` を含まないが、実装では入れた。Webview の幅に追随させるためで、CSP にも表示にも影響しない

### 判断と根拠

- `escapeHtml` で `&` を最初に変換した。後続の変換が生む `&` を二重変換しないため。仕様の変換表にも明記されている
- 引用符が閉じているかの判定で、末尾の引用符の直前に続くバックスラッシュの個数が偶数かを見る実装にした。`reason: "a\"` のように値が `\` で終わる場合、単純に末尾が `"` かだけを見ると閉じていると誤判定するため
- 状態ディレクトリが読めない場合を「空として扱う（不備にしない）」とした。仕様の走査 手順 2 のとおりで、`30_cancelled` が存在しないリポジトリでも列が出る
- スタイルを VS Code のテーマ変数だけで書いた。仕様の決めごとどおりで、ライトテーマでもダークテーマでも読める

### 拒否・確認・迂回の記録

- 拒否・確認・迂回はいずれも発生していない。`npm install` は 4 パッケージが 1 秒で入った

### 使った AI アセットと効き目

- 仕様書 `docs/10_spec/vscode-ticket-board.md`: 判定順が手順として書かれていたので、実装で迷う箇所がほぼ無かった。とくに frontmatter の解析 6 手順はそのままコードの構造になった
- `20-common-step-commit-push` の commit.sh: `node_modules/**` と `out/**` を自動除外するので、対象を明示するだけでビルド成果物が混入しなかった
- 調査 0005 の入れ子 `.gitignore`: 実装の最初のコミットに含めた結果、`git status --porcelain` が空になり `ticket.sh complete` が通った

### スコープ外で見つけたこと

- `node --test` の出力はテスト名を TAP 形式で列挙するので、テスト ID をテスト名の先頭に書いておくと仕様との対応が出力から読める。TB-T01 のように書いたのはそのため

### AI アセットに反映すべき内容

- 現時点で 0 件。理由: このチケットで使ったアセット（commit.sh・ticket.sh・仕様書）はいずれも仕様どおり動き、直したい点が見つからなかった

### 備考

- テストは 35 件（TB-T01〜TB-T17 の観点を複数のテストに分けたもの）
- `git status --porcelain` が空であることを確認済み
