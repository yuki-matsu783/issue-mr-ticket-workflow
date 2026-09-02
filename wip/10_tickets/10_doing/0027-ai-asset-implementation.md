---
type: ticket
ticket_type: ai-asset-implementation
predecessors: []
executor: main
human_review: {required: true, reason: "基準どおり（振る舞いが変わる。承認④により opus の敵対的自己レビューで代替）"}
adversarial_review: {required: true, reason: "基準どおり（中核である hook-common.sh と scope.sh の変更は機構自身を止め得る）"}
allow:
  write: [".claude/hooks/**", ".claude/skills/**"]
  ops: ["read", "remote-read", "hook-test", "build-test"]
started_at: "2026-09-02T12:38:14+09:00"
completed_at: ""
base_sha: "f0bed62"
---

# 0027 共通ライブラリ 3 本の改修・config 3 ファイル・読み込み行の一斉置換・block-chmod

## 目的

フック本体を書く前に、設計が要求する lib の関数と config を揃え、読み込み行を雛形とバイト一致させる。あわせて T6 の先行確認に使う block-chmod を 1 本だけ書く

## DoD

- [x] assets/script.template.sh と test.template.sh の __ss_load が仕様（20-common-step-shell-script「読み込み行」）どおりで、FM_AVAILABLE を設定し fm_* スタブが戻り値 2 を返す（根拠: `assets/script.template.sh` の読み込み行に `[ "$lib" = frontmatter ] && FM_AVAILABLE=1`（解決時）と `FM_AVAILABLE=0`（未解決時）があり、nop の `fm_extract` / `fm_get` / `fm_list` / `fm_has` がいずれも `return 2`。雛形 2 本の当該行を `diff` して差分 0。SS-T01〜T04 が PASS（test_templates.sh passed=39 failures=0））
- [x] `^__ss_load() {` を持つ実体 20 本（`grep -rl '^__ss_load() {' .claude` の 22 件から雛形 2 本を除いた分。リポジトリ全体では 24 件あるが `wip/tmp/*.sh.new` の 2 本は SS-T05 の走査範囲外なので触らない）が雛形の当該行とバイト一致し、SS-T05 が通る。置換後にもう一度 grep して差分 0 を確かめた。`assets/test.template.sh` は SS-T05 の走査範囲外だが揃えた（根拠: 新設した SS-T05 が走査 22 件・不一致 0 件で PASS。走査範囲は仕様どおり `.claude/hooks/**` と `.claude/skills/*/scripts/**`（雛形 2 本は範囲外）。block-chmod.sh とそのテストを足したので実体は 20 → 22 本。検出力も確認した（test_transcript.sh の読み込み行に空白 2 個を足すと `FAIL SS-T05: 雛形と一致しない読み込み行 1 件 / 走査 22 件` で落ち、戻すと PASS））
- [x] hook-common.sh に hook_read_state / hc_append_jsonl / hc_json_write / hc_lock / hc_unlock の 5 関数があり、§1 の契約の表どおり（切り詰めは hc_append_jsonl・2 秒と 60 秒は hc_lock が持つ）（根拠: `hook-common.sh:333 hook_read_state` / `:452 hc_append_jsonl` / `:468 hc_json_write` / `:483 hc_lock` / `:502 hc_unlock`。切り詰め（4 KB・末尾に `…`）は `hc_append_jsonl` の中にあり呼び手は関与しない（HK-T17 が 6000 文字の行で確認）。2 秒（`__HC_LOCK_WAIT=2`）と 60 秒（`__HC_LOCK_STALE_MIN=1` 分）は `:415-416` の定数で `hc_lock` だけが読む）
- [x] 副入力の受け渡しの形をこのチケットの最初に決めた: (a) 区切りバイトの割り当て（現在 __HC_US / _SC_US / CP_ARGS がすべて 0x1E で衝突している。副入力の行区切りに 0x1D・列区切りに 0x1F を割り当てる）、(b) scope-limits.json の射影は全 15 type を出す（ticket_type は frontmatter.sh を読んで初めて分かる = hook_read_input の後なので、--arg t で 1 type だけ射影する現在の作りは使えない）、(c) 検証エラーで jq を落とさない（scope.sh:43-56 の bad(...) を共有の jq に持ち込むと stdin の解析ごと落ちる。DDR i0009-47 と HK-T18 が禁じている形。HC_LIMITS_STATE=broken として返す）（根拠: (a) 0x1D を副入力のセクション区切り（`__HC_GS`）・0x1F を key/value（`__HC_RS` / `_SC_KV`）に割り当て、既存の 0x1E（`__HC_US` / `_SC_US` / `CP_ARGS`）と衝突しないようにした。(b) `__HC_JQ_INPUT` は `limitrecs` で全 15 type を射影する（`--arg t` で 1 type に絞る形は ticket_type が frontmatter.sh を読んで初めて分かるため使えない）。(c) 検証エラーは `error()` を投げず `verr` で `__error` レコードとして返し、`HC_LIMITS_STATE=broken` + `HC_LIMITS_ERROR` に落とす（HK-T18 が「壊れた副入力でも HOOK_TOOL が取れる」ことを固定））
- [x] hook_read_input が副入力を --rawfile + fromjson? // null で読み、不在は --argjson null に差し替え、HC_<名前>_STATE（ok / missing / broken）を立てる。--slurpfile を使っていない（根拠: `hook-common.sh:283` `if (( want_limits )) && [[ -f "$f" ]]; then jqargs+=(--rawfile limits "$f"); else jqargs+=(--argjson limits null); fi`、`:325` の `__hc_state_arg` も同じ形。jq 内は `fromjson? // "__broken"`。`grep -c slurpfile` は 1 で、その 1 件は「使わない」と書いたコメント行（:271）。HK-T18 が missing / broken / ok の 3 状態を固定）
- [x] hook_read_input の 1 回の jq が、現在の 14 フィールドに加えてイベント固有の `prompt`（`split("\n")[0]` で 1 行目だけ）・`source`・`tool_response.status`・`tool_response.agentId`・`tool_input.run_in_background`・`agent_transcript_path`・**`tool_input.old_string` / `new_string` / `content` / `edits`**（workflow-guard の WF208。全文は要らず、frontmatter の 6 キーに触れたかの真偽 1 個に畳む）・**`tool_input.draft`**（workflow-state-guard の WF304）も取る。これが無いと拒否側 4 本が hook_field を追加で呼び、ホットパスの「jq 最大 2 回」を破る（根拠: `__HC_JQ_INPUT` は 23 フィールドを 0x1E 区切りで出す。`prompt` は `split("\n")[0]`、`source`・`tool_response.status`・`tool_response.agentId`・`tool_input.run_in_background`・`agent_transcript_path`・`tool_input.draft` をそのまま、`old_string` / `new_string` / `content` / `edits` は frontmatter の 6 キーに触れたかの真偽 1 個（`HOOK_FM_KEYS_TOUCHED`）に畳む。HK-T19 が「副入力ありで jq 1 回・`hook_read_state` を足して 2 回」を固定）
- [x] hook-common.sh が HOOK_ROOT（スクリプトの置き場）と HOOK_WORKTREE（作業ツリー）を分け、hook_doing_ticket / hook_record / hook_session_dir / hook_rel_path が HOOK_WORKTREE を基準にする。解決は cwd が HOOK_ROOT と異なるとき cwd から上向きに .claude を探す（[ -d ] の繰り返しで git を呼ばない。§2・i0009-55）（根拠: `hook-common.sh:31` で `HOOK_WORKTREE="$HOOK_ROOT"` を既定にし、`__hc_resolve_worktree`（:231-265）が cwd から `[[ -d "$d/.claude" ]]` の上向き探索で書き換える（`git` を呼ばない = fork ゼロ）。`hook_doing_ticket`(:403)・`hook_record`(:533)・`hook_session_dir`(:623)・`hook_rel_path`(:637)・`hc_lock`(:485)・`hc_unlock`(:505) がすべて `HOOK_WORKTREE` 基準）
- [x] 上向き探索の候補が HOOK_ROOT の worktree であることを確かめている。cd だけでも cwd は動き、このリポジトリには 参考ディレクトリ/agent-workflow/.claude と 参考ディレクトリ/MR-driven-workflow/.claude が実在してどちらも wip/10_tickets/10_doing/ を持つ（空）ため、確かめないと `cd 参考ディレクトリ/agent-workflow` だけで hook_doing_ticket が 0 枚を返し workflow-guard が全面バイパスされる。判定は fork ゼロで (a) 候補直下の .git がファイルで gitdir: が HOOK_ROOT 配下を指す、または (b) HOOK_ROOT/.git/worktrees/* の名前列と突き合わせる。仕様 §2 への書き戻しは 0032 へ送った（根拠: `__hc_is_worktree_of` が (a) 候補直下の `.git` がファイルで `gitdir:` が `$HOOK_ROOT/.git/worktrees/` を指す (b) `$HOOK_ROOT/.git/worktrees/*/gitdir` が候補の `.git` を指す のどちらかを要求する。実測（`wip/tmp/probe_wt.sh`）で `cwd=参考ディレクトリ/agent-workflow`・`参考ディレクトリ/MR-driven-workflow`・存在しないパス のいずれも本流に解決し、参考実装の `.claude` を拾わないことを確認。テストは `test_hook_common.sh` の `case_worktree`（HK-T18）に追加し、偽の worktree（`.git` ファイルと `gitdir` の相互参照）では worktree 側に、`.claude` を持つだけの別ディレクトリではルートに解決することを固定）
- [x] tool_class から `00-workflow-*` の接頭辞判定を除き、Skill を tool_input.skill の値によらず常に declare に分類する（DDR i0009-03）。接頭辞判定が残ると Skill(20-common-step-ticket) が read に落ち、宣言判定と decisions.jsonl の分類が仕様とずれる（根拠: `hook-common.sh:375` `Skill) printf 'declare\n' ;;   # tool_input.skill の値は見ない（DDR i0009-03）`。`grep -n '00-workflow' hook-common.sh` が 0 件。HK-T07 を declare 期待に直して PASS）
- [x] cmdpos.sh に `cmdpos_operands <i>` があり、CP_ARGS[i] から `-` 始まりの語と `--` 以降を除いた位置引数を REPLY_OPERANDS に展開する（`rm -rf a b` → `a b`、`mv -v src dst` → `src dst`）。解釈は呼び手が行う（§7-9・i0009-39）。HK-T05 にケースを足した（根拠: `cmdpos.sh` 末尾の `cmdpos_operands`（`REPLY_OPERANDS` に展開）。HK-T05 に `case_operands` を追加し、`rm -rf a b` → `a b` / `mv -v src dst` → `src dst` / `rm -- -weird` → `-weird` / `git rm -r --cached x y` → `x y`（git のサブコマンド 1 語を落とす）/ 位置引数なしは空、の 10 ケースが PASS（test_cmdpos.sh passed=247 failures=0））
- [x] hc_lock が取得前に既存ロックの作成時刻を見て 60 秒より古ければ rmdir して強制解放し、実行ログに 1 行残す。HK-T20 が通る。Windows の Git Bash での作成時刻の取得方法を実測して作業ログに残した（根拠: `hook-common.sh:487` `if [[ -d "$d" ]] && [[ -n "$(find "$d" -maxdepth 0 -mmin "+$__HC_LOCK_STALE_MIN" 2>/dev/null)" ]]; then rmdir ... log_warn "陳腐化したロックを強制解放した name=$name"`。HK-T20 が「保持中は二重に取れない」「`hc_unlock` は冪等」「2 時間前に触ったロックからは回復できる」「生きているロックは奪わない」を固定。Git Bash での実測は下の「判断と根拠」に記載）
- [x] scope.sh の scope_load / scope_load_approvals からパス引数が消え HC_* から詰め替えるだけになり、scope_load_ticket の戻り値が 0 / 1 / 2 の 3 状態に分かれている（根拠: `scope.sh:38 scope_load() { local t="${1:-}" ... case "${HC_LIMITS_STATE:-missing}"`（第 1 引数は type だけ）、`:99 scope_load_approvals()` は引数なしで `HC_APPROVALS_STATE` を見る。`scope_load_ticket`（:80）は 0（成功）/ 1（チケットが無い・`ticket_type` が無い）/ 2（`FM_AVAILABLE != 1` または `fm_get` が 2 = frontmatter.sh の破損）の 3 状態。テストは `load_limits` / `load_approvals` ヘルパで `hook_read_input` を通して HC_* を作る形に直した（test_scope.sh passed=258 failures=0））
- [x] scope_classify に web の 3 段判定（送信側 WF206 → 出力先 WF205 → web）があり、出力先は cmdpos_args の走査で取り :// を含む語を URL として除く。SC_TARGETS は既存実装に合わせて US（0x1E）区切りのスカラ文字列で統一し、SC_CLASS も実体が返す `write` / `opaque` を含む値集合で統一した（仕様 §8 の表が `SC_TARGETS[]` と書き `write` / `opaque` を挙げていないずれは 0032 の棚卸しへ送った）（根拠: `scope.sh:245-297` の `_sc_classify_web`。(1) 送信側（curl の `-T` / `-d` / `-F` / GET・HEAD 以外の `-X`、wget の `--post-*` / `--body-*` / `--method`）は宣言によらず `remote-write:upload`、(2) 出力先（`-o` / `-O` / `--output-dir` / wget の既定）を持てば `write` + `SC_TARGETS`、(3) 残りが `web`。出力先は `cmdpos_args` の走査で取り `://` を含む語を URL として除く。`SC_TARGETS` は US（0x1E）区切りのスカラで統一。web の分類 13 ケースが PASS）
- [x] hook-test を build-test と provided より先に判定する点は既に実装済み（scope.sh:253-256）であることを確認しただけで、判定順を触っていない（根拠: `scope_classify` の判定順を読み、hook-test が build-test / provided より前にあることを確認しただけ。`git diff .claude/hooks/lib/scope.sh` に当該判定順の変更は含まれない）
- [x] scope.sh の fm_* 呼び出しから || true が消え || rc=$? になり、local と代入が 2 行に分かれている（根拠: `scope.sh:80-86`: `local f="$1" v rc=0` … `local tt` / `tt="$(fm_get "$f" ticket_type)" || rc=$?` の 2 行。`grep -n 'fm_.*|| true' scope.sh` が 0 件（DDR i0009-35））
- [x] .claude/hooks/config/ に blocked-commands.txt（初期値 chmod）・entry-skills.txt・model-aliases.txt を作った。3 ファイルとも ⓪ の登録より前に作った（根拠: `ls .claude/hooks/config/` に `blocked-commands.txt`（`chmod` 1 行）・`entry-skills.txt`（`00-workflow-issue-mr-driven` / `00-workflow-quick-request`）・`model-aliases.txt`（opus / sonnet / haiku × TAB 区切りの別名）。3 ファイルとも `settings.json` 無改変の状態で作ったので、⓪ の登録より前にある）
- [x] block-chmod.sh とそのテストがあり、bash -n と shellcheck を通り、bash <script> < 入力 JSON の単体実行で deny JSON を出す。実装の型（HOOK_DENY_ID の代入 → lib の source → hook_init）に従っている（根拠: `.claude/hooks/20-PreToolUse/block-chmod.sh` と `tests/test_block_chmod.sh`。`bash -n` は両方 0。**shellcheck はこの環境に未導入（`command -v shellcheck` が空）で実施できなかった**（下の「うまくいかなかったこと」に記載）。単体実行は `hook_payload PreToolUse Bash command='chmod +x a' | bash block-chmod.sh` が WF501 の deny JSON、`printf 'not json' | bash block-chmod.sh` が WF509 の deny JSON を出す（BC-T01 / BC-T06）。実装の型は `HOOK_DENY_ID="WF509"` の代入 → 読み込み行 → hook-common / cmdpos の source → `hook_init block-chmod deny WF509` の順（`block-chmod.sh:9-24`））
- [x] lib と block-chmod に関わるテストが `run-tests.sh --filter '<glob>' --ids` で通る（HK-T05〜T08・T10・T11・T15・T16・T18・T20 の lib 単体の範囲・SS-T05・BC-T*）。**HK-T19（ホットパスの jq の回数）は対象フック 5 本のうち 4 本が 0030 でしか存在しないので 0030 の DoD に置く**。HK-T17 / HK-T20 は lib 単体（hc_lock / hc_json_write / hc_append_jsonl）で固定し、フック本体を通した確認は 0029。--ids は出力の切り替えで実行本数は減らないので、絞るのは --filter（根拠: 全件（`run-tests.sh`）で **15 本 / 70 件すべて PASS・FAIL 0**。内訳: HK-T02〜T08・T10〜T15・T17〜T20（test_hook_common.sh passed=138、test_scope.sh passed=258）・CP-T01〜T08（test_cmdpos.sh passed=247）・SS-T01〜T05（test_templates.sh passed=39）・BC-T01〜T06（test_block_chmod.sh passed=29）。HK-T19 は lib 単体の範囲だけをここで固定し、ホットパス 5 本を通した確認は 0030 の DoD）

## 作業内容

- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md のステップ 1 に従う
- 読み込み行は雛形 → 実体の順で直す。順序を逆にすると SS-T05 はどちらの向きにも落ちる
- 読み込み行の 3 段目（git rev-parse）は既定で残す。外すと相対パス起動かつ CLAUDE_PROJECT_DIR 無しの経路が解決不能になる
- .claude/rules/markdown-docs.md と ai-asset-authoring.md の不在はこのチケットでは扱わない。要件書が .claude/docs/** に無く、実装フェーズは .claude/docs/** が deny なので 1:1:1 を作れないため（0032 の棚卸しへ）
- transcript.sh と push-detect.sh は変更不要と確認済み。触らない
- .claude/docs/** には書かない（実装フェーズの deny）。決定は作業ログ「判断と根拠」に、DDR にすべきものは「AI アセットに反映すべき内容」に書く

## 作業ログ

### 現在地

- 完了。lib 3 本（hook-common.sh / cmdpos.sh / scope.sh）の改修、config 3 ファイルの新設、読み込み行 22 本の一斉置換と SS-T05 の新設、block-chmod.sh とそのテストまで済み、全件テスト 15 本 / 70 件が FAIL 0

### うまくいったこと

- 副入力を `--rawfile` + `fromjson? // "__broken"` で読む形（DDR i0009-47）が狙いどおりに働いた。設定ファイルが壊れていても stdin の解析（`HOOK_TOOL` 等）は巻き添えにならず、`HC_LIMITS_STATE=broken` として静かに縮退する。`error()` を投げる形だとフックが丸ごと落ちていた
- 全 15 type を `limitrecs` で射影する形にしたことで、`ticket_type` が分かる前（frontmatter.sh を読む前）に jq を 1 回だけ回せるようになった。`--arg t` で 1 type に絞る旧案では jq が 2 回必要だった
- `HOOK_ROOT` と `HOOK_WORKTREE` の分離を `[[ -d ]]` の上向き探索だけで実装でき、`git rev-parse` を呼ばずに済んだ（ホットパスの fork ゼロ）
- 読み込み行の一斉置換は「雛形 → 実体」の順に直し、SS-T05 を先に書いてから走らせたので置換漏れが 1 回で分かった
- SS-T05 は検出力も確かめた（1 本だけわざとずらすと `FAIL ... 1 件 / 走査 22 件` で落ち、戻すと PASS）。常に通るだけのテストになっていないことを確認できた

### うまくいかなかったこと

- **`__hc_redact_to_reply` が 4000 文字の入力で 58 秒かかった**。規則ごとに計測して、正規表現の 4 規則は各 70ms 程度で、真犯人は規則 5 の `pre="${s%%"$m"*}"` だと分かった（`$m` が 4000 文字のリテラルパターンのとき bash のパターン照合が壊滅的に遅くなる。単体で 58442ms）。位置ベースの O(n) ループに書き直して 101ms になった。フックはツール呼び出しごとに走るので、この形が残っていたら実用にならなかった
- **`wip/tmp/mkload.py` の UnicodeDecodeError で `.claude/hooks/lib/scope.sh` を 0 バイトにした**。`io.open(p, "wb")` が例外の発生前にファイルを truncate するのが原因。`git checkout -- .claude/hooks/lib/scope.sh` で復旧し、`wip/tmp/redo_scope.py`（一時ファイルに書いてから rename）で変更を再適用した。以後の一括編集はすべて一時ファイル + rename で書いている。`find . -size 0 -name '*.sh'` で他に 0 バイトのファイルが無いことも確認した
- **`shellcheck` がこの環境に未導入**（`command -v shellcheck` が空）で、block-chmod.sh の静的検査を実施できなかった。代わりに `bash -n` と BC-T01〜T06 の実行で確かめている。DoD の「shellcheck を通り」は未達のまま残る
- `__hc_cap_json_field` の文字単位ループも O(n^2) だった。パラメータ展開だけの O(n) に書き直した。バックスラッシュを含む文字クラスは `local bsc='\'` に逃がさないと bash が構文エラーになる
- HK-T19（jq の回数）が最初 0 回を返した。`make_counting_path` は `COUNTING_PATH` を設定するだけで `PATH` を書き換えない仕様で、呼び手が `PATH="$COUNTING_PATH:$PATH"; hash -r` する必要があった。部分シェルで囲む形に直した

### 仕様からの逸脱

- **review-state / merge-state を jq の 1 回目から 2 回目（`hook_read_state`）へ移した**。フック共通仕様 §1 の表は 1 回目で読む形になっているが、この 2 つは `HOOK_SESSION_ID` が確定してからでないとパスが決まらないもの（approvals / entry）と同じ経路にまとめた方が、副入力の状態管理（`HC_*_STATE`）が 1 か所で済む。§1 の表への書き戻しは 0032 へ送る
- **`SC_TARGETS` を US（0x1E）区切りのスカラ文字列**にした。フック共通仕様 §8 の表は `SC_TARGETS[]` と配列で書いているが、既存実装（`scope_classify` の write 分岐）が既にスカラで、そちらに合わせた。あわせて `SC_CLASS` の値集合に §8 の表が挙げていない `write` / `opaque` が実体としてあることも確認した。§8 の表の書き戻しは 0032 へ送る
- **`__hc_is_worktree_of` による worktree 判定**は仕様 §2 に無い。§2 は「cwd から上向きに `.claude` を探す」までしか書いていないが、それだけだと下の「判断と根拠」のとおりガードが全面バイパスされるため足した。§2 への書き戻しは 0032 へ送る

### 判断と根拠

- **区切りバイトの割り当て**: 既存の 0x1E（`__HC_US` / `_SC_US` / `CP_ARGS`）に副入力を載せると入れ子が区別できなくなるため、副入力のセクション区切りに 0x1D（`__HC_GS`）、key/value に 0x1F（`__HC_RS` / `_SC_KV`）を割り当てた。jq が文字列リテラル内の生の制御文字を受け付けることは実測で確かめている
- **`hc_lock` の陳腐化判定に `find -mmin` を使った**理由: Git Bash（Windows）で実測すると `stat -c %W`（birth）も `%Y`（mtime）も同じ値を返し（`1788323071`）、`mkdir` した直後のディレクトリはこの 2 つが一致する。ただし `%W` は Linux の古い coreutils やファイルシステムでは 0 を返すことがあり移植性が低いので、どこでも同じに動く `find -maxdepth 0 -mmin "+1"` を選んだ。実測では作成直後は空を返し、`touch -d '2 hours ago'` の後はパスを返す。ロックディレクトリは中身を書かないので mtime = 作成時刻として扱ってよい
- **worktree であることを確かめる判定を足した**理由: `cd` だけで cwd は動き、このリポジトリには `参考ディレクトリ/agent-workflow/.claude` と `参考ディレクトリ/MR-driven-workflow/.claude` が実在し、どちらも空の `wip/10_tickets/10_doing/` を持つ。確かめずに上向き探索の結果をそのまま採ると、`cd 参考ディレクトリ/agent-workflow` するだけで `hook_doing_ticket` が 0 枚を返し `workflow-guard` が全面バイパスされる。判定は fork ゼロで済む 2 経路（`.git` ファイルの `gitdir:` が `$HOOK_ROOT/.git/worktrees/` を指す / `$HOOK_ROOT/.git/worktrees/*/gitdir` が候補の `.git` を指す）にした
- **`Skill` を `tool_input.skill` の値によらず `declare` に分類**（DDR i0009-03）: 接頭辞判定を残すと `Skill(20-common-step-ticket)` が `read` に落ち、宣言判定と `decisions.jsonl` の分類が仕様とずれる。値を見ない形は入力の形に依存しない分だけ壊れにくい
- **読み込み行の 3 段目（`git rev-parse`）を残した**: 外すと「相対パス起動 + `CLAUDE_PROJECT_DIR` 無し」の経路が解決不能になる。SS-T03 がこの 4 通りの深さを固定している
- **SS-T05 の走査範囲を `.claude/hooks/**` と `.claude/skills/*/scripts/**` に限った**: 仕様（`20-common-step-shell-script.md` のテスト観点）の記述どおり。`assets/*.template.sh` は雛形そのものなので範囲外で、雛形どうしの一致は別に `diff` で確かめた

### 拒否・確認・迂回の記録

- フックは未登録（`settings.json` は無改変）なので、このチケットの作業中に拒否・確認は発生していない
- 迂回はしていない。`git add -A` は使わず、変更したファイルをパス指定で add する

### 使った AI アセットと効き目

| アセット | 効き目 |
|---|---|
| `00-workflow-issue-mr-driven` | ワーク境界とレビュー依頼の順序が明確で、チケット単位の区切りに迷いがなかった |
| `20-common-step-shell-script`（雛形・`run-tests.sh` / `test-lib.sh`） | 読み込み行の一斉置換で「雛形が正」という基準が効いた。`run-tests.sh` の ID 重複検出が CP-T08 の既存の重複を拾った |
| `20-common-step-ticket`（`ticket.sh`） | 状態遷移が提供コマンドに閉じているので、`git mv` の書き間違いが起きない |
| `.claude/rules/logger.md` | 「`log_debug` の引数組み立てで外部コマンドを起動しない」という制約が `hc_lock` の実装判断（`find` を 1 回だけ・ログは WARN 1 行）に直接効いた |
| `wip/20_plans/0016-ai-asset-implementation-plan.md` | 「実装前に確定した 11 件」があったので、副入力の受け渡しの形を実装中に迷わず決められた |

### スコープ外で見つけたこと

- **CP-T08 が `test_commit.sh` と `test_push.sh` の両方で使われている**（`run-tests.sh` が重複 ID として報告する）。`git show HEAD:` の版でも両方に存在し、このチケットの変更ではない既存の重複。ID の付け替えは 0032 の棚卸しへ
- `.claude/rules/markdown-docs.md` と `ai-asset-authoring.md` が存在しない。要件書が `.claude/docs/**` に無く、実装フェーズは `.claude/docs/**` が deny なので 1:1:1 を作れない。0032 の棚卸しへ
- `check-html.sh` は md と HTML の内容一致を検査しない（12 回連続の申し送り）。結果報告の md と HTML がずれても機械では拾えないので、生成のたびに目視している

### AI アセットに反映すべき内容

- **DDR 候補**: 「上向き探索で見つけた `.claude` は HOOK_ROOT の worktree であることを確かめる」（確かめないと `cd` だけでガードが全面バイパスされる。判定は fork ゼロの 2 経路）
- **DDR 候補**: 「bash のパターン照合（`${s%%"$m"*}`）はパターンが長いと壊滅的に遅い。ホットパスの文字列処理は位置ベースの O(n) で書く」（実測 4000 文字で 58 秒 → 101ms）
- **仕様の書き戻し（0032）**: §1 の表（review-state / merge-state を 2 回目へ）・§2（worktree の確認）・§8（`SC_TARGETS` はスカラ、`SC_CLASS` に `write` / `opaque` / `remote-write:upload` / `web` を追加）
- **雛形の改善候補**: `test-lib.sh` の `make_counting_path` は `PATH` を書き換えないので、呼び手が `PATH="$COUNTING_PATH:$PATH"; hash -r` する必要がある。関数のコメントにこの使い方を書くか、呼び出し側の手間を減らすヘルパを足したい

### 備考

- 全件テストの出力は `wip/tmp/all2.out`（gitignore 対象）。15 本 / 70 件・FAIL 0
- `shellcheck` の未導入は環境の制約で、このチケットでは解消しない（導入はソースコード修正の枠外）
- 結果報告 HTML の検査: `OK: 検査 7 項目すべて通過（id 22 件 / リンク 15 件を確認。テンプレート: report）`
