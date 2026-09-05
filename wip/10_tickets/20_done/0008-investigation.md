---
type: ticket
ticket_type: investigation
predecessors: []
executor: opus
human_review: {required: false, reason: "全体計画書の差分 3（人間レビューを敵対的レビューに置き換える）"}
adversarial_review: {required: true, reason: "全体計画書の差分 3。フェーズごとに 1 回、claude-fable-5-1 で実施する"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-05T01:03:46+09:00"
completed_at: "2026-09-05T01:47:15+09:00"
base_sha: "35dd59f"
---

# 0008 調査: scope.sh の git 分類の穴と塞ぎ方の選択肢

## 目的

調査計画書の観点 E に答える。scope.sh の scope_classify で checkout / switch / worktree / cd が unknown に落ち WF204 で既定拒否される件について、穴を全件洗い出し、塞ぎ方の案を 2 つ以上出す。受け入れ条件 A1 に効き、AI アセット設計の材料になる。

## DoD

- [x] 観点 E『scope.sh の git 分類にどれだけ穴があり、どう塞げるか』への答えが wip/30_reports/0004-investigation.md に書かれている（根拠: e35「観点 E の答え — 穴は 4 層に分かれる」。サマリ「0008 まで」の段落にも同じ結論を置いた）
- [x] unknown に落ちる git サブコマンドの全件一覧が、git のサブコマンド一覧と _SC_GIT_READ_SUBCMDS の突き合わせとして根拠付きで載っている（checkout / switch / worktree を含む）（根拠: e36。母集合 174 件（git-core の実体）と白名簿 29 件を `comm` で突き合わせて 145 件を e36-1 に全件列挙。checkout / switch / worktree / merge-tree / stash は e36-2 の表にも行がある）
- [x] _SC_READ_ONLY_CMDS に無いために unknown に落ちる基本コマンドの一覧が載っている（本調査計画の実施中に踏んだ cd を含む）（根拠: e37。e37-1 が decisions.jsonl の WF204 全 62 件の実行体別集計（cd 22 件が最多）、e37-2 が候補 95 語の membership 表（シェル組み込み 33 語・実在する外部コマンド 28 語が unknown））
- [x] 塞ぎ方の案が 2 つ以上あり、案ごとに『変更する箇所・block-direct-git.sh との関係・scope-limits.json との整合・影響する既存テスト ID・拒否が緩む範囲』が書かれている（根拠: e42 に案 A〜E の 5 案。各案の表は求められた 5 列に「隔離下で通るか」「長所 / 短所」を足した 7 行で空欄なし。組み合わせと評価軸は e43）
- [x] 答えが出なかった問いは理由付きで残課題に残っている（根拠: 「確かめられなかったこと」に 0008 分 7 行、「残課題」に R25〜R30 の 6 件。いずれも理由と引き取り先つき）

## 作業内容

- scope.sh の scope_classify と _SC_GIT_READ_SUBCMDS / _SC_READ_ONLY_CMDS を読み、分類に落ちない入力を特定する
- git のサブコマンド一覧を取得し、_SC_GIT_READ_SUBCMDS と突き合わせて差分を全件出す
- block-direct-git.sh と workflow-guard.sh の WF204 / WF205 を読み、拒否の経路と識別子を確かめる
- .claude/hooks/config/scope-limits.json と該当仕様を読み、分類の定義がどこで正になっているかを確かめる
- lib/tests/test_scope.sh を読み、案ごとに影響する既存テスト ID を列挙する

## 作業ログ

### 現在地

- 読み取り調査は完了。`wip/30_reports/0004-investigation.md` に観点 E の節（e35〜e44）を追記し、HTML を同期して完了する

### うまくいったこと

- git のサブコマンド一覧を、リポジトリ外の実物（`C:/Program Files/Git/mingw64/libexec/git-core/` の `git-*`）から機械的に取り出せた（174 件）。`_SC_GIT_READ_SUBCMDS`（29 件）との `comm` による突き合わせで、`unknown` に落ちる 145 件を全件出せた
- `logs/hooks/decisions.jsonl` の WF204 全 62 件を実行体別に集計でき、「実際に踏んだ穴」を推測なしで一覧にできた（`cd` 22 / `bash` 11 / `git` 7 / `_` 4 / `python` 3 / `sleep` 2 / `read` 2 ほか）
- 本チケットの実施中にも `cd`・`while read`・`$( )` 由来の誤分類を**その場で再現**でき、静的解析の読みを実測で裏取りできた

### うまくいかなかったこと

- `scope_classify` を実際に走らせて分類を確かめられなかった。`bash .claude/hooks/lib/tests/test_scope.sh` は `hook-test` 分類で、本チケットの `allow.ops`（`read` / `remote-read`）に無い。全件の分類は静的読解にとどまる（レポート「確かめられなかったこと」に記載）

### 仕様からの逸脱

- なし（読み取りのみ。`wip/**` 以外に書いていない）

### 判断と根拠

- 「git サブコマンドの全件」の母集合を `git help -a` ではなく `git-core` ディレクトリの実体一覧に取った。`git help` 自体が `_SC_GIT_READ_SUBCMDS` に無く WF204 で実行できないため。内部ヘルパ（`*--helper` 等）も含む母集合になるが、`git <名前>` として起動できる名前の集合としては正しく、除外の判断を主観で入れないほうが突き合わせの根拠になると考えた
- 「基本コマンド」の候補集合は、①`decisions.jsonl` の実績（機械的）②bash の組み込み・予約語 ③本 issue の起動プロンプトが名指しした語、の 3 つから作り、実在確認を `C:/Program Files/Git/usr/bin` の一覧で行った。候補列挙そのものは網羅ではないので、レポートに「網羅ではない」と明記した
- 塞ぎ方は 5 案（A〜E）に広げた。計画書は「最低 2 案（既存分類への追加 / 新分類の導入）」を求めていたが、観点 C・D から「隔離下でも通ること」「合流を通すか」という条件が足されており、2 案では条件を満たす組み合わせを比較できないため
- 案の採否は決めていない。評価軸と「何が新しく通ってしまうか」を対にして並べるところまでにした（調査の範囲）

### 拒否・確認・迂回の記録

- WF204（`cd`）を 2 回踏んだ（`2026-09-05T01:03:54` / `01:06:29`）。迂回せず絶対パスに切り替えた
- WF204（`read`）を 1 回踏んだ（`while read w; do …; done` の `read`。`01:12:37`）。`awk` に書き換えた
- WF204（`hook-common.sh` / `-v` / `_` / `none.txt`）を 4 回踏んだ（`01:10:19` / `01:12:07` / `01:25:51` / `01:41:34`）。前 3 件は `$( )` を二重引用符の中に書いた行、最後の 1 件はプロセス置換 `<( )` で、いずれも閉じ括弧の後ろの語が実行体として読まれたもの。引用とプロセス置換を外し、中間結果を `wip/tmp/` のファイルに落とす形に書き換えた
- WF205（宛先が読めない）を 1 回踏んだ（`01:06:03`。`> "C:/…/wip/tmp/x.txt"` の引用符付きリダイレクト先が `_` に潰れた）。引用符なしのルート相対に書き換えた
- 本チケットの拒否は合計 8 件（WF204 7 / WF205 1）。うち 4 件がレポート e38 の X2・X2b の再現、1 件が e37 の再現
- WF205（宛先が読めない）を 1 回踏んだ（`> "C:/…/wip/tmp/x.txt"`）。リダイレクト先を引用符なしのルート相対に書き換えた
- いずれも機構の指示どおり、範囲を広げず宣言の内側で進めた

### 使った AI アセットと効き目

- `10-task-investigation-exec`: 「表に載せきれない対象を本文で足さない」の指示が効き、145 件・95 件の一覧を散文に逃がさず表と一覧で出した
- `20-common-step-ticket` / `20-common-step-commit-push`: 提供コマンド経由の着手・コミットは問題なく動いた
- `20-common-step-report-view`: `check-html.sh` は `OK: 検査 7 項目すべて通過（id 59 件 / リンク 52 件を確認。テンプレート: report）`。md と HTML の突き合わせは、①結論の見出し数（md `^### e[0-9]` = **44** / HTML `<h3 id="f…">` = **44**）②件数タイル（md「◎良 19 件 / △注意 17 件 / ✕問題 8 件」/ HTML `◎良 19` `△注意 17` `✕問題 8`）③0008 の主要な数（145 件 / 174 件 / 29 件 / 62 件 / 67 件 / 75 語 / 40 語 / 28 語 / 67 語 / 95 語 / 5 案）が両方に同じ値で出ること、の 3 点で確認した。表の数は md 55 / HTML 48 と差があるが、これは HTML が案 A〜E の 5 表を 1 表（7 行 × 5 列）にまとめているためで、0007 までの差（md 41 / HTML 37）と同じ性質の圧縮である

### スコープ外で見つけたこと

- `git -c diff.external='<任意のコマンド>' diff` が `read` に分類され、`workflow-guard` も `block-direct-git` も止めない（e40 の X5）。**試していない**（実行すると任意コマンドの実行になるため）。全体計画書の保留 P2（別 issue）か本 issue の設計かの判断を人間に委ねる
- `_SC_READ_ONLY_CMDS` に `column` が 2 回入っている（`scope.sh:31`）。害は無いが表形式の実装としては重複（e37 の注記）
- `_SC_SHELL_KEYWORDS` を直接指す既存テストが 1 件も無い（`grep -rn _SC_SHELL_KEYWORDS .claude/` が定義行と参照行の 2 行のみ）。`WG-T06` の `for f in a; do …; done` が間接的に踏んでいるだけ（e42 の影響テスト欄に記載）

### AI アセットに反映すべき内容

- レポートの「設計への反映」32〜41 に集約した（案 A〜E、パーサの 2 件、逆向きの穴 5 件、`merge` の分類）

### 備考

- 本チケットは `git worktree add` / `git checkout -b` / `git switch` を一切実行していない（起動プロンプトの指示）。実測が要る箇所は e44 に人間向けの手順として残した
