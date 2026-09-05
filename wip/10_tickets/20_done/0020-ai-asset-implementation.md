---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0019"]
executor: opus
human_review: {required: false, reason: "全体計画書の方針（差分 3）"}
adversarial_review: {required: true, reason: "全体計画書の方針（差分 3: フェーズごとに 1 回）"}
allow:
  write: ["wip/**", ".claude/hooks/**"]
  ops: ["read", "remote-read", "build-test", "hook-test"]
started_at: "2026-09-05T21:53:41+09:00"
completed_at: "2026-09-05T23:15:04+09:00"
base_sha: "6a12e35"
---

# 0020 S3 中核 b: cmdpos.sh の正規化 2 件と scope.sh の分類の穴 6 件

## 目的

フック共通仕様 §7-1 の正規化（算術展開は段を割らない / コマンド置換・プロセス置換の閉じ括弧の後ろの語を実行体にしない）と §8 の「サブコマンド + オプション」の限定適用 6 件を実装し、cd は分類に足さないことを負のコントロールで固定する。全フックが読む共通ライブラリなので、フック本体より先に固める。

## DoD

- [x] cmdpos.sh が仕様書 フック共通仕様 §7-1 のとおりになっている（$(( )) は段を割らず 1 語の _ に潰す / $( ) と <( ) は中身を実行位置として解析したうえで外側は 1 語に潰し、閉じ括弧の後ろの語を新しい段の実行体にしない）（根拠: レポート e12・e13。`case_hk_t05_substitution`（28 assert）が `echo "$((n+1))"` = 1 段 / `sed -n "$(grep … | cut …)" path/to/file.sh` = 3 段で `file.sh` は引数 / `comm -12 <(sort -u a.txt) b.txt` = 2 段 / `$(which git) push` = `exe=_ gitlike=1` を固定）
- [x] scope.sh が仕様書 §8 の限定適用 6 件のとおりになっている（1 git worktree は list だけ read / 2 git branch は書き込みオプションで unknown / 3 git symbolic-ref は位置引数 2 つ以上で unknown / 4 git reflog は show・exists だけ read / 5 --output=<file> は write で SC_TARGETS に出力先 / 6 -c と --config-env は設定名を見ず一律 unknown）（根拠: レポート e14。`_sc_classify_git` に集約し、`case_hk_t15_git_subcmd_opts` の 60 対で 6 件すべてを閉じる側と通す側の対で踏んでいる）
- [x] cd が分類に足されていない（unknown → WF204 のまま）ことが負のコントロールとして固定されている（根拠: レポート e15。`HK-T15` の 5 件（`cd /tmp` / `cd wip` / `cd wip && ls` = `unknown read` / `pushd` / `popd`）。作業中も実機で 2 回 `WF204` に拒否された）
- [x] R52 の軽微 2 件が直っている（_SC_READ_ONLY_CMDS の column の重複を解消 / _SC_SHELL_KEYWORDS に全要素ループの検査を追加）（根拠: レポート e16。あわせて 3 つの語彙表に重複検査を足し、変更前に `column` を検出して FAIL することを確認した）
- [x] 機械テスト HK-T05・HK-T12・HK-T15 が通る（run-tests.sh --filter '*test_cmdpos*' と --filter '*test_scope*'）。HK-T15 は限定適用 6 件を閉じる側と通す側の対で踏む（根拠: `test_cmdpos.sh` `passed=332 failures=0` / `test_scope.sh` `passed=399 failures=0`。テスト先行で 21 件・38 件の FAIL を確認してから実装した）
- [x] 機械テスト HK-T02 が通る（run-tests.sh --filter '*config_integrity*'。classify_real が scope_classify を実際に走らせる）（根拠: `PASS / exit 0 / passed=95 failures=0`）
- [x] 変更直後に git worktree list・git branch -a・git status --porcelain を 1 回ずつ実行し、read として通ること（通す向きの回帰）を確かめた（根拠: レポート e17 の表。3 件とも通り、閉じる側の `git branch -d no-such-branch-xyz` は `WF204` で止まった）
- [x] 実装結果レポートに本チケットの節が追記され、仕様と食い違った点は仕様を直さず「仕様からの逸脱」に記録されている（根拠: `wip/30_reports/0018-ai-asset-implementation.md` に e12〜e18 と D8〜D12 を追記。`.claude/docs/**` は 1 文字も変更していない）

## 作業内容

- cmdpos.sh が壊れると bash で始まるすべての判定が崩れるので、編集は Edit ツールで行い（Bash を介さない）、直後に bash -n .claude/hooks/lib/cmdpos.sh を回す
- 復旧は git checkout を使わない（checkout は _SC_GIT_READ_SUBCMDS に無く unknown → WF204）。git show <base_sha>:<パス> で内容を取り、Write ツールで書き戻す。書き戻し先（.claude/hooks/**）は本チケットの allow.write に入っている
- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md の S3 と「ロックアウト対策」の S3 行に従う

## 作業ログ

### 現在地

- 着手。基準点 6a12e35。復旧用に `git show 6a12e35:<パス>` の内容を `wip/tmp/0020/{cmdpos,scope}.sh.base` に退避した
- 仕様 §7-1・§8 と計画書 S3 を読み、変更点を 4 つに割った: (P-1) 算術展開が段を割らない (P-2) 置換の閉じ括弧の後ろの語を実行体にしない (S-1) git の限定適用 6 件 (S-2) R52 の軽微 2 件
- 進め方はテスト先行に決めた（test_cmdpos.sh → 失敗確認 → cmdpos.sh、test_scope.sh → 失敗確認 → scope.sh）
- P-1・P-2 完了: test_cmdpos.sh に `case_hk_t05_substitution` を追加 → 21 件 FAIL を確認 → cmdpos.sh を変更 → 325 件 PASS
- S-1・S-2 完了: test_scope.sh に `case_hk_t15_git_subcmd_opts` と一覧の重複検査を追加 → 38 件 FAIL を確認 → scope.sh を変更 → 399 件 PASS
- 通す向き・閉じる向きを実機で確認: `git worktree list` / `git branch -a` / `git status --porcelain` は通り、`git branch -d no-such-branch-xyz` は WF204 で止まった
- 全件テスト 1 回目で `test_block_chmod.sh` の `BC-T01` が 4 件 FAIL（`ch$()mod +x a` 系）。原因は置換の印を空白付きで置いたため語が割れ、実行体が `ch` に見えたこと。印を空白なしで置き、段の組み立て側で語を連結する形に直した（`_cp_split_marker_to_reply` / `_cp_push_outer_segment`）。退行を固定する assert を 7 件足して `test_cmdpos.sh` は 332 件 PASS、`test_block_chmod.sh` は 93 件 PASS
- 全件テスト 2 回目: `OK: 27 本 / 216 件`（全 PASS / `FAIL ID:` 空 / 重複 ID なし）
- レポート `wip/30_reports/0018-ai-asset-implementation.md` に e12〜e18 と D8〜D12 を追記し、HTML の対（f12〜f18）も更新して `check-html.sh` 7 項目を通した
- コミット `7282c12`（7 ファイル / 除外なし）。DoD 8 件すべて根拠付きで充足。本チケットの作業は完了

### うまくいったこと

- テスト先行が効いた。`HK-T05` で 21 件・`HK-T15` で 38 件の FAIL を先に見てから実装したので、「何が変わったか」を期待値の形で固定できた。重複検査は変更前に `column` を検出して FAIL し、検査そのものが効くことを確かめてから直せた
- 1 つ変えるごとに `bash -n` → 該当テスト → 実機のコマンド、の順を守ったので、中核 2 本を触っても一度も自分を止めずに済んだ。復旧用に退避した基準点の内容（`wip/tmp/0020/`）は使わずに済んだ
- 実機で通す向き（`git worktree list` / `git branch -a` / `git status --porcelain`）と閉じる向き（`git branch -d`）を 1 回ずつ踏めた。テストは偽の設定を読むので、出荷される `scope-limits.json` と登録済みフックで踏み直す意味があった
- `_sc_classify_git` に git の判定を集約したことで、限定適用が白名簿より先に効く順序を `case` の並びで保証できた

### うまくいかなかったこと

- 担当テスト（`HK-T05` / `HK-T12` / `HK-T15` / `HK-T02`）を全通しさせたあとの**全件テストで `BC-T01` が 4 件 FAIL**した。置換の印を空白付きで置いたせいで `ch$()mod` が 2 語に割れ、難読化した `chmod` が `block-chmod` を素通りしていた。印を空白なしにして語のバッファで連結する形に直し、負のコントロールを 7 件足した（レポート e18）
- 0019 の `SG-T11` に続き 2 チケット連続で「担当テストは通るが他フックのテストが退行を拾う」形になった。中核を触るチケットは**閉じる前に全件を回す**必要がある

### 仕様からの逸脱

- D8: 内部プレースホルダを 3 つ（`\x01` / `\x02` / `\x03`）と定める §7-1 の表に対し、置換の開始 `\x05` / 終了 `\x06` を足した。出力には現れず、生のマーカは入口で `_` に潰す
- D9: 規則 4 の文言どおりに実装した結果、`git reflog HEAD`（ref 直渡し）が `unknown` に落ちる
- D10: 規則 2 の列挙に加えて、束ねた短オプション（`-dr`）を 1 文字ずつ照合して閉じる側に強めた
- D11: 規則 6 を「サブコマンドより前の位置」に限定した（そうしないと `git log -c` の読み取り形まで落ちる）
- D12: 規則 5 を「`read` に分類された形」にだけ当てた（`unknown` を `write` に変えると緩むため）
- いずれも設計文書（`.claude/docs/**`）は 1 文字も直していない。レポート「仕様からの逸脱」D8〜D12 に記録した

### 判断と根拠

- **置換の印に制御文字 2 バイトを使った**: 段の区切りを「置換の開始と終了の対応」で決めるには、素の括弧（サブシェル）と置換の括弧を区別する印が要る。仕様の表は「除去した内容のプレースホルダ」3 つを定めるもので、区切りの印は別の役目だと読んだ。出力に漏れないこと・偽造できないことをテストで固定したうえで、逸脱 D8 として記録した
- **印を空白で区切らない**: `ch$()mod` を bash と同じ 1 語として扱う必要がある（`BC-T01` の退行で判明）。語の連結は段の組み立て側（`cur` のバッファ）で行う
- **段の並び順は「中が先」**: 仕様が順序を定めていないので、実装しやすい順（走査順）にした。呼び手が順序に依存していないかはレビュー依頼に挙げた
- **`cmdpos_operands` を使って位置引数を取る**: `scope.sh` がコマンド文字列を再パースしない規則（§7 冒頭）を守るため、サブコマンド位置の推定を自前で書かず公開 API に寄せた。`REPLY_ARGS` が上書きされるので、呼び出し後に `cmdpos_args` で取り直している
- **`git -C` を `-c` と取り違えない**: cmdpos 側は小文字化して両者を同じ「値を取るグローバルオプション」として扱う（結果的に正しい）が、規則 6 の判定では**大文字小文字を畳まない**。`git -C . status` を `read` のまま通すことをテストで固定した

### 拒否・確認・迂回の記録

- `bash --version` → `WF204`（`bash` が分類外）。迂回せず `echo "$BASH_VERSION"` に置き換えた
- `cd .claude/hooks/lib/tests && grep …` → `WF204`（`cd` は分類に足していない。本チケットの負のコントロールそのもの）。ルート相対のパス指定で回した
- `perl -i -pe 's/…/…/' .claude/hooks/lib/cmdpos.sh` → `WF204`（`perl` が分類外）。Edit ツールの `replace_all` に置き換えた
- `bash -c '…'` → `WF209`（コード文字列を渡す形は opaque）。テストの直接実行に置き換えた。**このときはツールが実際に止まった**（0019 の e11 と対照的で、中核が健全なときの fail-closed は効いている）
- `while … break … done` を含むワンライナー → `WF204`（`break` が分類外）。ポーリングを個別のコマンドに分けた
- いずれも迂回・強制無効化はしていない

### 使った AI アセットと効き目

- `10-task-ai-asset-implementation-exec`（+ `10-task-investigation-exec` の共通手順）: 「中核は 1 つ変えるごとにテストと自分の動作で確かめる」「テスト先行」「レポートは 1 タスク 1 つに追記」がそのまま効いた。全件テストの退行を拾えたのは、この順序を守った結果
- `20-common-step-ticket` の `ticket.sh start`: 基準点（`base_sha`）が自動で入るので、退避（`git show <base_sha>:<パス>`）と許可範囲の確認（`git diff <base_sha> --stat`）の起点が迷わず決まった
- 実装計画書 `0016` の「ロックアウト対策」S3 行: 復旧に `git checkout` を使わない理由（`checkout` は `_SC_GIT_READ_SUBCMDS` に無く `WF204`）まで書いてあったので、退避の手段を考える時間が要らなかった
- 効き目が薄かった点: `run-tests.sh` の既定 120 秒（既知の R9）と、全件テストの所要時間（10 分前後）。中核チケットは全件を回す前提なので、待ち時間を織り込んだ手順（先にレポートを書き進める）が要る

### スコープ外で見つけたこと

- `break` / `continue` が `_SC_SHELL_KEYWORDS` に無く、`while … do … break … done` を含むワンライナーが `WF204` で止まる（実測）。R52 の「シェルのキーワードだけの段」と同じ性質の穴だが、一覧の正は仕様 §8（`for done fi esac case select coproc function`）なので**直していない**。フィードバック計画へ回す候補
- `git reflog HEAD`（サブコマンドを省いて ref を直接渡す読み取り形）が規則 4 の文言どおりだと `unknown` に落ちる。仕様どおりに実装し、レポートの逸脱 D9 に記録した
- `git branch -dr <名前>` のような**束ねた短オプション**は、仕様の列挙の完全一致だけでは素通りする。閉じる側に強めて D10 に記録した

### AI アセットに反映すべき内容

- `10-task-ai-asset-implementation-exec` の「中核の変更は小さく」に、**「チケットを閉じる前に全件テストを回す」**を明記する。0019・0020 と 2 チケット連続で、担当テストが全通ししたあとの全件テストが退行を拾った（`SG-T11` / `BC-T01`）
- 同スキルの「見てほしい点の固定項目」に**「中核変更後に自分が止まらないことだけでなく、閉じる向きが実際に止まることも 1 件踏む」**を足す（通す向きだけ確かめると、分類を緩めた事故に気づけない）
- `work-defaults` の `ai-asset-implementation` の所要時間の見積もりに、**全件テスト 10 分前後の待ち**を織り込む

### 備考
