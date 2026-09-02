---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0001"]
executor: main
human_review: {required: true, reason: "振る舞いが変わる。提供コマンドの中核"}
adversarial_review: {required: false, reason: "敵対的レビューエージェントが未作成。機械テストで代替する"}
allow:
  write: [".claude/skills/20-common-step-commit-push/scripts/commit.sh", ".claude/skills/20-common-step-commit-push/scripts/tests/test_commit.sh", ".claude/skills/20-common-step-ticket/scripts/ticket.sh", "wip/**"]
  ops: ["read", "build-test"]
started_at: "2026-09-02T11:40:04+00:00"
completed_at: "2026-09-02T11:44:33+00:00"
base_sha: "6bb378d"
---

# 0004 commit.sh をステージ済みの削除に対応させ、テストを追加する

## 目的

レビュー済みの仕様どおりに commit.sh を直し、削除の 3 経路と混在ケース・誤り経路をテストで固定する

## DoD

- [x] rm のみ / rm + git add / git rm の 3 経路で削除だけのコミットが成功し、コミットに削除が記録される（根拠: test_commit.sh CP-T09 の 3 経路。各経路で git show --name-status が D <path> だけになることを exact で確認）
- [x] 削除と追加・変更の混在を 1 回で渡してもコミットできる（根拠: test_commit.sh CP-T09 末尾（D del4.txt / A new1.txt / M mod1.txt を 1 コミットで））
- [x] 実在しないパスと .gitignore 対象は CP001 で止まり、メッセージがステージ済みの削除と区別できる（根拠: test_commit.sh CP-T10 前半。綴り誤りは「作業ツリーにも追跡対象にも無く、ステージ済みの差分も無い」、.gitignore 対象は「ステージできない」で、互いに assert_not_contains で分離）
- [x] 除外パターンの検査が削除対象にも効くことがテストで固定されている（根拠: test_commit.sh CP-T10 末尾（追跡済みの deleted-token.txt を git rm してから渡すと CP003））
- [x] test_commit.sh に CP-T09 と CP-T10 のテストが追加され、run-tests.sh が全通過する（根拠: run-tests.sh --filter '.claude/skills/*' が 8 本 / 48 件 PASS、FAIL 0）
- [x] ticket.sh の do_commit の回避が不要かを確認し、判断と根拠を作業ログに残している（根拠: 下の「判断と根拠」。回避は残し、コメントを実態に合わせた）

## 作業内容

- 20-common-step-ai-asset-creator と 20-common-step-shell-script に従って実装とテストを行う
- run-tests.sh でスクリプト全体のテストを回し、bash -n と shellcheck の結果を残す

## 作業ログ

### 現在地

- 完了。commit.sh の修正・テスト追加・スキルのテスト全通過まで済み

### うまくいったこと

- テストを先に書いて失敗を確認してから実装した。実装前は passed=84 / failures=13（FAIL ID: CP-T09 CP-T10）、実装後は passed=97 / failures=0
- 修正が `git add` の手前の振り分け 1 か所で済んだ。`git commit` の pathspec はステージ済みの削除でもそのまま通るため、コミット経路には触れていない
- スキルのテスト 8 本（442 アサーション）が全通過し、既存の振る舞いへの巻き込みが無いことを確認できた

### うまくいかなかったこと

- チケット 0002 を `--allow-write` の指定を誤って起こしてしまい、取り消して 0004 として起こし直した。`ticket.sh create` の `--allow-write` / `--allow-ops` はカンマ区切りの 1 回渡しで、複数回渡すと黙って最後の 1 件だけが残る
- 混在ケースの検証に `git status --porcelain` 全体を使ってしまい、前のテスト節が残した未追跡ファイルを拾って FAIL した。対象 3 パスに絞って直した

### 仕様からの逸脱

- `shellcheck` がこの環境に無いため静的検査を省略した。`bash -n` は変更した 3 本すべてで通している
- テストの全体実行（`run-tests.sh --ids`）は、`.claude/hooks/**` のテストに `hook-test` が要り TR006 で止まるため行っていない。今回の変更はフックに触れないので `--filter '.claude/skills/*'` に絞った

### 判断と根拠

- **`ticket.sh` の `do_commit` の回避は残す**。この回避が実際に効くのは「git が一度も知らないパス」（作業ツリーにも index にも無く、ステージ済みの差分も無い）だけで、commit.sh の修正後もそれは CP001 になる。`start` / `complete` / `cancel` が渡す旧パスは plain `mv` の後も index に残るので区分 1 に入り、回避の条件には当たらない。外すと未追跡のチケットを動かす経路で CP001 になり得るため、コメントだけを実態に合わせた
- ステージ済みかの判定を `has_staged_diff` に切り出し、`git rev-parse --verify -q HEAD` で HEAD の有無を先に見る。コミットが 1 つも無いリポジトリで `git diff --cached` がエラーになるのを避けるため
- 区分 1 の条件に `[ -L "$f" ]` を足した。壊れたシンボリックリンクは `[ -e ]` が偽になるが、`git add` は扱えるため
- CP001 のメッセージを 2 つに分けた。振り分けで落ちる側は該当パスを名指しし、`git add` が失敗する側は git の出力をそのまま添える。旧メッセージにあった「未追跡のまま削除」は、その状態が正常系になったので消した

### 拒否・確認・迂回の記録

### 使った AI アセットと効き目

- `20-common-step-shell-script`: 「テストは失敗を先に確認してから実装する」が効いた。実装前の FAIL ID が仕様のテスト観点 CP-T09 / CP-T10 と一致することを確認してから直せた
- `run-tests.sh` の `--ids`: PASS ID の一覧が仕様のテスト観点表との突合にそのまま使えた

### スコープ外で見つけたこと

- `ticket.sh create` の `--allow-write` / `--allow-ops` を複数回渡すと、エラーにならず最後の 1 件だけが採用される。宣言漏れに気づけない
- `run-tests.sh --ids` の「重複 ID」に `CP-T08` が出る。仕様が CP-T08 に commit.sh と push.sh の両方の振る舞いを載せているためで、今回の変更とは無関係

### AI アセットに反映すべき内容

- 上のスコープ外 2 件は 0003（全体まとめ）で issue 化の要否を判断する

### 備考
