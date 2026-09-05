---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0020", "0021"]
executor: opus
human_review: {required: false, reason: "全体計画書の方針（差分 3）"}
adversarial_review: {required: true, reason: "全体計画書の方針（差分 3: フェーズごとに 1 回）"}
allow:
  write: ["wip/**", ".claude/skills/**", ".claude/evals/**"]
  ops: ["read", "remote-read", "build-test", "hook-test"]
started_at: "2026-09-06T01:37:07+09:00"
completed_at: "2026-09-06T02:27:58+09:00"
base_sha: "87a2d8b"
---

# 0023 S6 提供コマンド a: 20-common-step-worktree スキルと worktree.sh の新設

## 目的

受け入れ条件 A2・A6 の実体である worktree.sh（add / list / merge / remove）とスキル本体を新設し、合流手順・前提検査 6 項目・衝突時の中断・合流の記録を機械テストで固定する。「本流かどうかの判定」はこのスキルの仕様が正で、ticket.sh / push.sh はこれを共有する。

## DoD

- [x] .claude/skills/20-common-step-worktree/SKILL.md と scripts/worktree.sh が仕様書 10_spec/skills/20-common-step-worktree.md「Script 処理」のとおりになっている（本流かどうかの判定・共通の入口 1〜3・add 1〜7・list 1〜3・merge 1〜6・remove 1〜7・合流の記録・WT001〜WT008）（根拠: レポート「作成・更新したアセットの一覧」#24・#25 の「仕様書の節」列で節ごとに対応づけた。判定は wt_is_main_root / 入口は require_env・resolve_roots・require_main・is_managed_branch / 各サブコマンドは cmd_add・cmd_list・cmd_merge・cmd_remove / 記録は record_merge・build_merge_line / WT001〜WT008 は result_ng の呼び出し。逸脱 4 件は D19〜D22 に記録）
- [x] 合流の記録が共有ルートの logs/worktree-merges.jsonl に 1 回 1 行で追記され、result が merged / up-to-date / aborted の 3 値になっている（同仕様「合流の記録」）（根拠: WT-T04（merged / tickets:["0018"] / merge_commit 7 桁、2 回目は up-to-date で HEAD 不変）・WT-T06（aborted / merge_commit:"" / conflicts 1 件）・WT-T12（2 行のうち merged 1 件・aborted 1 件）。置き場は MAIN_ROOT/logs/worktree-merges.jsonl）
- [x] 機械テスト WT-T01〜WT-T12 が通る（bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*test_worktree*'）（根拠: `run-tests.sh --filter '*test_worktree*' --ids --timeout 300` = OK: 1 本 / 12 件、passed=160 failures=0、PASS ID: WT-T01〜WT-T12、FAIL ID 空、重複 ID なし）
- [x] WT-T01 が「add は logs/hooks/ と logs/sh/ だけを作り、進行状態 7 種（mr.json / review-state.json / merge-state.json / locks/ / usage/ / sessions/ / push-state.json）を 1 つも作らない」ことを固定している（根拠: test_worktree.sh case_WT_T01。`ls <worktree>/logs` = "hooks sh" の exact 一致と、7 種 + review-history.jsonl の計 8 名の存在検査が空文字であること。wip/tmp/.gitkeep がチェックアウトで入ることも同ケース）
- [x] WT-T05 が「前提検査 6 項目それぞれの未充足で git merge を 1 回も実行せずに止まる」ことを固定し、WT-T06 が「WT004・終了 1・--abort 済みで本流が合流前と同一」と負のコントロール（別の節の追記だけなら成功）を固定している（根拠: WT-T05 は git のラッパーで引数を記録し `grep -c '^merge '` = 0 を 6 経路すべてで assert（正のコントロールで 1）。識別子は本流未コミット / 本流作業中 / 対象未コミット / 対象作業中 = WT003、別 issue = WT005（D20）、作業ツリーから = WT001。WT-T06 は WT004・exit 1・git status が空・HEAD 不変・記録に aborted、負のコントロールは別の節の追記で OK: と本流への反映を確認）
- [x] eval WT-E01・WT-E02・WT-E03 が .claude/evals/20-common-step-worktree.md に定義されている（入力・期待する振る舞い・判定方法。**実行しない**）（根拠: 同ファイルの「評価シナリオ」表 3 行（入力プロンプトと状況 / 期待する振る舞い / 判定方法 / 添付ファイルの 4 列）+ 比較条件 + 効果ありの判定基準。「実行状況」は **未実行**（定義のみ）のまま。WT-E02 は判定を拒否の記録ではなく実行ログで数えることを明記）
- [x] 機械テスト WG-T21 が引き続き通る（S4 で入れた置き場引数の例外を、S6 の実体で踏み直す）（根拠: `run-tests.sh --filter '*test_workflow_guard*' --ids --timeout 300` = PASS / passed=217 failures=0 / PASS ID に WG-T21 を含む WG-T01〜WG-T21。実機でも `worktree.sh add Bad_Name ../issue-mr-ticket-workflow-wt/probe` が allow（WF209 にならず WT008 で終了 2））
- [x] SKILL.md の frontmatter が 20-common-step-ai-asset-creator の必須項目を満たし、プレースホルダ（{{ }} / TODO / TBD）が 0 件である（根拠: frontmatter は name / description の 2 項目だけ（skill.template.md が「文書用の項目は付けない」と定める形）。`grep -c "{{\|TODO\|TBD"` = SKILL.md 0 / worktree.sh 0 / test_worktree.sh 0 / evals/20-common-step-worktree.md 0）
- [x] 実装結果レポートに本チケットの節が追記され、仕様と食い違った点は仕様を直さず「仕様からの逸脱」に記録されている（根拠: wip/30_reports/0018-ai-asset-implementation.md に e29〜e34・0023 分の検証の結果 / アセット一覧 #24〜#27 / テスト結果 / 検査結果 / D19〜D22 / 設計への反映 #18〜#23 / 想定と異なった点 5 行 / R24〜R29 を追記。HTML も f29〜f34 で同期し `check-html.sh` が OK: 検査 7 項目すべて通過（id 53 件 / リンク 46 件）。`.claude/docs/**` の差分は 0）

## 作業内容

- remove は --force でも未コミットの差分を消さない仕様を先にテストで固定してから実体を書く（事故の防止）
- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md の S6 と「ロックアウト対策」の S6 行に従う
- WG-T21 の再確認は 0021（S4）が新設するテストに依存するので、predecessors に 0021 を入れてある
- 復旧は git checkout を使わない（checkout は _SC_GIT_READ_SUBCMDS に無く unknown → WF204）。git show <base_sha>:<パス> で内容を取り、Write ツールで書き戻す。書き戻し先（.claude/skills/** と .claude/evals/**）は本チケットの allow.write に入っている

## 作業ログ

### 現在地

- 着手（基準点 87a2d8b）→ テスト先行（失敗確認）→ `worktree.sh` 実装 → 綴りの二重性を修正 → `WT-T01`〜`WT-T12` 全 PASS → SKILL.md → eval 定義 → コミット（1274d77）→ `WG-T21` 再確認 PASS → 実機で 2 回踏んだ → レポート md / HTML を更新して `check-html.sh` OK
- 残り: 全件テストの結果をレポートに反映 → 作業ログを締めて完了

### うまくいったこと

- 仕様「Script 処理」の節をそのまま関数の骨格にしたので、DoD の突き合わせが節単位でできた（`wt_is_main_root` / `require_env`・`resolve_roots`・`require_main` / `cmd_add`・`cmd_list`・`cmd_merge`・`cmd_remove` / `record_merge`・`build_merge_line`）
- テスト先行が効いた。`worktree.sh` が存在しない状態で `WT-T01`〜`WT-T12` を全部書き、`FAIL / exit 2` を確認してから実装した。反転検査は不要（新設なので「書いた時点で通る」ケースが 0 件）
- 「`git merge` を 1 回も実行していない」を、`git` のラッパー（引数を記録して本物に `exec`）を `PATH` に差し込んで数えた。正のコントロール（前提が揃った合流で 1 回）も同じケースに置いた
- `remove --force` が未コミットを消さないことを**実体より先に**テストで固定した（チケットの作業内容の指示どおり）
- 実機のフックで `worktree.sh list` と `worktree.sh add Bad_Name ../…/probe` の 2 回を踏み、`WG-T21` の例外が実物でも効くことを確かめた

### うまくいかなかったこと

- **実装後 1 回目のテストが `passed=125 failures=35`**。しかも中身は「拒否されるはずの `add <リポジトリ>/sub` が成功してリポジトリ直下に作業ツリーを作った」で、その後のケースが連鎖的に落ちた。原因は Windows の綴りの二重性（下の「判断と根拠」）
- テストの `cd` 失敗で 1 回目の実行が途中で打ち切られ、FAIL ID の一覧が 9 件までしか出なかった（`run_in` の `cd` 失敗を `return` で受けるようにして解消）
- `shellcheck` はこの環境に無く、静的検査は `bash -n` のみ（既知の R10）

### 仕様からの逸脱

レポート `wip/30_reports/0018-ai-asset-implementation.md`「仕様からの逸脱」に D19〜D22 として記録した。**`.claude/docs/**` は 1 文字も直していない**。

- D19: 「置き場がリポジトリの配下か」はパスの文字列比較では判定できない（`add` 2 の「正規化」だけでは足りず、git に綴りを解決させた）
- D20: 前提検査の項目 6（同じ issue のブランチ）に到達する経路が無い（`merge` 2 の `WT005` が先に弾く）。両方実装し、`WT-T05` の期待値は `WT005`
- D21: `list` の出力が `OK:` ではなく JSON 1 行（IN / OUT 表とサンプルに従った。`ticket.sh next` と同じ扱い）
- D22: 「タスクの切れ目」を `10_doing/` の `*.md` の枚数で数えた（`.gitkeep` があるため「ディレクトリが空」では判定できない）

### 判断と根拠

- **綴りの二重性を git に解決させた**（D19）。Windows の Git Bash では同じディレクトリが `/tmp/x`（MSYS）と `C:/Users/…/Temp/x`（`getcwd()`）の 2 通りに綴られ、`git rev-parse --show-toplevel` は cwd をどう綴って渡しても後者を返す。`is_under_repo()` は存在する最深の祖先で `git -C <祖先> rev-parse --show-toplevel` を取り、`MAIN_ROOT` / `WT_ROOT` / 登録済みの作業ツリーと突き合わせる。`git -C` は chdir してから `getcwd()` を読むので綴りが一意に決まる
- **「本流かどうかの判定」を関数 `wt_is_main_root()` に切り出した**が、`source` での共有はしていない。`worktree.sh` は提供コマンドで、`source` 専用ライブラリの置き場は `20-common-step-shell-script` の `scripts/` に限られる（同スキル仕様「概要・禁止事項」）。S7（0024）の選択肢は①同じ 1 行（`[ -d "$root/.git" ]`）を書く ②ライブラリに切り出す（`20-common-step-shell-script` 仕様の変更を要する）で、**S6 は①を前提に判定の中身を関数のコメント 1 か所に書いた**。レポートの「設計への反映」#23 として渡す
- **`merge --all` で管理対象が 0 件のとき `OK:` を返す**（仕様に無い実装判断）。「合流するものが無い」はエラーではなく、冪等な運用（切れ目で毎回呼ぶ）に合うため。R29 として残した
- **`WT-T12` の assert を順序に依存しない形にした**。`merge --all` の処理順は `git worktree list` の返す順に依存するので、「w1 が合流し w2 で止まる」と名指しにせず「記録の 2 行のうち `merged` 1 件・`aborted` 1 件」で見る
- **テストの後始末で `git worktree remove --force` を使わない**。`rm -rf <置き場>` → `git worktree prune` → `git branch -D` の順にした（禁止事項の `--force` を、たとえテストの teardown でも使わない）
- **テストの中で `git worktree add` / `git checkout --detach` を呼んだ**。一時リポジトリに閉じており作業リポジトリには触れていない。0022 の `DC-T08` / `DC-T09` と同じ作り（申し送りが許可している形）

### 拒否・確認・迂回の記録

- `cd` を Bash ツールで打って **`WF204`** で拒否された（2 回。着手直後）。迂回せず、以後は既定の作業ディレクトリ（リポジトリルート）からの相対パスで実行した
- `mktemp -d` を Bash ツールで打って **`WF204`** で拒否された（1 回。パスの綴りを実測しようとした）。迂回せず、テストの中で観測する形に切り替えた
- フックに拒否された操作を強行した回数: 0。`WORKFLOW_ENTRY_ENFORCE=0` などの無効化: 0 回
- 実機の `worktree.sh` 2 回はいずれも allow（`WG-T21` の例外が効いた）

### 使った AI アセットと効き目

| アセット | 効き目 |
|---|---|
| `10-task-ai-asset-implementation-exec` | 固定ステップ順・テスト先行・eval は定義まで・完了前の検査（プレースホルダ / frontmatter / 参照更新）の 4 点がそのまま手順になった |
| `20-common-step-shell-script` | 雛形・読み込み行・`test-lib.sh` の API・「回数の約束は数える」がそのまま `WT-T05` の作り（git ラッパー）に落ちた。「ケースごとに git のコミットをしない」も 1 本 120 秒以内に収めるのに効いた |
| `20-common-step-ai-asset-creator` | SKILL.md の frontmatter を 2 項目に絞ること・eval は `eval.template.md` を Read → Write（`cp` は `WF205`）・実行しないことが明確だった |
| `20-common-step-report-view` | 「md にあって HTML に無い節は `check-html.sh` では検出できない」の注意が効いた（見出し数 34 / 34 と節数 12 / 12 を突き合わせた） |
| `20-common-step-ticket` / `20-common-step-commit-push` | 着手・コミットとも 1 回で通った |

### スコープ外で見つけたこと

- `test-lib.sh` に「一時ディレクトリを後始末の対象に足す」公開 API が無い（内部変数 `_TL_TMPS` に直接 append した）。`add` の既定の置き場は `TMP_REPO` の**兄弟**なので trap の対象外になり、これが要る。`tl_register_tmp <path>` のような 1 行の追加で済む
- `test-lib.sh` に「コマンドの引数を記録するラッパー PATH」が無い（`make_counting_path` はコマンド名しか数えない）。`WT-T05` のために各テストで自作することになる

### AI アセットに反映すべき内容

- `test-lib.sh` に `tl_register_tmp <path>`（後始末の対象に足す）と `make_arg_recorder <コマンド名>`（引数を 1 行ずつ記録する PATH。`make_counting_path` の引数版）を足す提案 → フィードバック計画（0028）
- `20-common-step-shell-script` 仕様「テストの書き方（規約）」に「**パスの比較は文字列で行わない**（Windows では同じディレクトリが 2 通りに綴られる。git 目線に揃える）」を足す提案。0022・0023 と 2 チケット連続で踏んだ（R25）

### 備考

- 全件テストは `run-tests.sh --ids --timeout 300` を 1 本だけ走らせた（申し送りどおり並行させない）
