---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0028", "0029"]
executor: main
human_review: {required: true, reason: "基準どおり（拒否側は誤ると自分自身の操作を止める）"}
adversarial_review: {required: true, reason: "基準どおり（中核。ロックアウトを起こし得る）"}
allow:
  write: [".claude/hooks/**", "wip/10_tickets/**", "wip/30_reports/**", "wip/tmp/**"]
  ops: ["read", "remote-read", "hook-test", "build-test"]
started_at: "2026-09-02T22:25:44+09:00"
completed_at: "2026-09-03T00:43:28+09:00"
base_sha: "c6d4013"
---

# 0030 拒否側フックの残り 4 本とテスト

## 目的

0028 で確定した終了方式で workflow-entry / workflow-state-guard / block-direct-git / workflow-guard を書く。ホットパスの外部プロセス上限を実装で固定する

## DoD

- [x] workflow-entry.sh があり、UserPromptSubmit / PreToolUse Skill（宣言の記録）と PreToolUse の未宣言の拒否（WF101 系）の入口を持つ。jq の呼び出しが 2 回（hook_read_input + hook_read_state）で HK-T19 が通る（根拠: `.claude/hooks/10-UserPromptSubmit/workflow-entry.sh`。test_workflow_entry.sh 65 件 FAIL 0。WE-T03 で jq=2・git/date/sed/find=0、WE-T05 でチケット継続の経路は jq=1）
- [x] workflow-state-guard.sh があり、制御方式 0（既定値へのフォールバックと notify。評価は制御方式 1 の後）から 5（判定不能）までを仕様の順で実装している。jq の呼び出しが 1 回で HK-T19 が通る（根拠: `.claude/hooks/20-PreToolUse/workflow-state-guard.sh`。test_workflow_state_guard.sh 87 件 FAIL 0。SG-T07 で jq=1）
- [x] 置き場の削除が、cmdpos_operands で取った位置引数に対して、正規化した元パスの前方一致で置き場のディレクトリ自身と祖先（wip/10_tickets・wip）も拾い、rm -rf wip/tmp と rm -rf logs は通る。SG-T11 が通る。自前で引数を再パースしていない（根拠: `__sg_hits_dir` と `cmdpos_operands` の呼び出しのみ。SG-T11 PASS）
- [x] block-direct-git.sh があり、cmdpos.sh を使ってサブコマンドを判定する。BG-T01〜T11 が通る。jq の呼び出しが 1 回（根拠: `.claude/hooks/20-PreToolUse/block-direct-git.sh`。test_block_direct_git.sh 76 件 FAIL 0、`run-tests.sh --ids` で BG-T01〜T11 の 11 件。BG-T11 で jq=1）
- [x] workflow-guard.sh があり、制御方式 1〜6 を仕様の順で実装している。web の 3 段判定は scope.sh に委ね、CP_PROVIDED を直に見て素通ししない（根拠: `.claude/hooks/20-PreToolUse/workflow-guard.sh` は `scope_classify` の戻り値だけで分岐し、`CP_PROVIDED` を直接読むのは「すべての段が提供コマンドか」の復旧経路だけ。test_workflow_guard.sh 147 件 FAIL 0、`--ids` で WG-T01〜T17 の 17 件。WG-T13 で書き込み経路 jq=2・コマンド経路 jq=1）
- [x] 4 本とも作業ツリーの基準に 0027 で hook-common.sh に入れた HOOK_WORKTREE を使い、各フックが自前で解決していない（根拠: 4 本の `grep -n 'rev-parse|CLAUDE_PROJECT_DIR'` は読み込み行のみで、`wip/` と `logs/` の参照はすべて `$HOOK_WORKTREE` 起点）
- [x] ホットパス 5 本が git / date / sed / find を呼ばず、make_counting_path で数えた jq の回数が block-chmod・block-direct-git・workflow-state-guard = 1、workflow-guard・workflow-entry = 2 に固定されている。hook_field を追加で呼んでいない（根拠: BC-T05（今回追加）・BG-T11・SG-T07・WG-T13・WE-T03 の 5 か所で `counted_calls` により固定。5 本とも `hook_field` の呼び出しは無い）
- [x] 4 本とも実装の型に従い、bash -n を通り（`shellcheck` はこの環境に未導入で未実施）、bash <script> < 入力 JSON の単体実行で想定どおりの JSON を出す（ラッパー無しの状態で）（根拠: 4 本とも `bash -n` OK。各テストは `payload | bash <hook>` の素の起動で判定しており、敵対的プローブ `wip/tmp/adv0030.sh` も同じ形で流している）
- [x] 新規に作った .sh（本体 4 本 + テスト）の `__ss_load` 行が assets/script.template.sh とバイト一致し、SS-T05 が通る（SS-T05 は .claude/hooks/** 全体を走査するため）（根拠: test_templates.sh 43 件 FAIL 0）
- [x] 4 本のテストが `run-tests.sh --filter '<glob>' --ids` で通る（WE-T* / SG-T* / BG-T* / WG-T*。boundary.sh 依存の WE-T10 を除く）（根拠: WE 10 件 / SG 11 件 / BG 11 件 / WG 17 件、いずれも FAIL ID なし・重複 ID なし）

## 作業内容

- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md のステップ 4 に従う
- 0028 で T6 が外れていた場合は exit 2 + stderr の形で書く
- この段では settings.json に登録しない（登録は 0031）。単体実行で確かめる
- .claude/docs/** には書かない。決定は作業ログ「判断と根拠」に書く

## 作業ログ

### 現在地

- 完了。拒否側フック 4 本（workflow-entry / workflow-state-guard / block-direct-git / workflow-guard）とテスト 4 本を実装し、全件テストを 2 ロケールで FAIL 0（25 本 / 161 件・FAIL 0（既定ロケールと LC_ALL=C。--timeout 600））

### うまくいったこと

- 敵対的セルフレビューを「読む」ではなく実物への入力（`wip/tmp/adv0030.sh` / `adv0030b.sh`）で行い、読みだけでは出ない穴を 3 件見つけた（`..` を挟んだ保護範囲の迂回・作業ツリー外への書き込みが承認単位になる・シェルのループが既定拒否に落ちる）
- 1 巡目を「拒否をすり抜けられるか」、2 巡目を「正当な操作を止めていないか」に分けたことで、拒否側フック特有の偽陽性（= ロックアウト）を先に見つけられた
- 既存の 4 本のテストを毎回回し直したことで、共有ライブラリ（hook-common.sh / scope.sh）に手を入れた影響をその場で確認できた

### うまくいかなかったこと

- `hook_read_state` が常に空を返す重大バグ（0027/0028 由来）を、workflow-entry のテストが全滅するまで見つけられなかった。jq のプログラムが 4 つの変数をすべて参照するのに、要求された副入力だけを渡していたためコンパイルに失敗し、出力が空 = すべて `missing` に化けていた。**この間、workflow-diff-check の承認の記憶と subagent-stop-check の approvals 参照は実際には効いていなかった**
- テストの下ごしらえで PATH を絞るとき（`make_counting_path`）、フックが使う外部コマンド（`cat`）を数える対象に入れ忘れて 1 件が偽の失敗になった。PATH を絞る検査は「数えたいもの」ではなく「使うもの全部」を渡す必要がある
- 全件テストの実行中に本体を直してしまい、2 度中断して回し直した（5 分 × 2 の無駄）
- テストが重すぎた。`test_workflow_guard.sh` は単体で 5 分 07 秒かかり、`run-tests.sh` の既定の上限（120 秒）を超える。原因はフック 1 回の起動が約 1.9 秒（bash 起動 0.3 + ライブラリ 3 本の読み込み 0.48 + 内部の jq 0.24 + 記録の書き込み）で、147 件の判定がすべて別プロセスになるため。全件テストは `--timeout 600` で回した

### 仕様からの逸脱

- WG-T17 の「`wget --method=GET <url>` は（web の宣言があれば）通る」は、scope.sh の 3 段判定では成立しない。wget は既定で URL の basename にファイルを作るので、送信側ではなくても出力先ありの `write` になり **WF205** で止まる（WG-T15 の「`wget <url>` は `-O -` でなければ WF205」と整合する）。テストは WF205 を固定し、`-O -` を付けた形が通ることを併記した。仕様の WG-T17 の文言を直す（0032 へ）
- WG-T05 の「`confirm` 範囲は承認済みでも毎回 WF203」は、`implementation` から `.claude/hooks/config/**` を触る例では成立しない。共通の保護範囲（判定 2）が毎回確認（判定 4）より先に効くため WF201 になる。テストは `package.json`（types.confirm）と `ai-asset-implementation` からの `.claude/**`（types.allow に明示があるので判定 2 を抜ける）で固定した。仕様の例示を直す（0032 へ）
- 作業中が 2 枚以上のとき、仕様の制御方式 2 は「提供コマンド以外の**書き込み・実行**を WF207」と書いているが、実装はプランモード（EnterPlanMode）も WF207 にした。どちらのチケットの `plan_mode` を見ればよいか決まらないため（起動と読み取りは仕様どおり通す）。仕様に 1 行足す（0032 へ）
- jq の呼び出し回数の検査は、仕様の WG-T の表に項目が無いため WG-T13（停止中・ヘッドレスの境界）に相乗りさせた。block-chmod も同様に BC-T05 へ足した

### 判断と根拠

- **`hook_read_state` は要求しない副入力も `null` で必ず jq に渡す**: jq のプログラムが 4 変数すべてを参照するため。渡し漏れはコンパイルエラーになり、出力が空になって「壊れている」ではなく「無い」に化ける（縮退と区別できない）ので、退行テストを HK-T18 に足した
- **`cmdpos.sh` の opaque に `invoke-expression` / `iex` を足した**: PowerShell の eval 相当で、入っていないと `Invoke-Expression "git commit"` が素通りする（実測）
- **PowerShell のヒアストリングのように語が 1 つも無い段は通す**: `_`（読めない）と「語が無い」を同じ扱いにすると、ヒアストリングを含むだけで拒否になる。読めないときだけ拒否側に倒す
- **`rm -rf wip` は WF302（作業中の置き場）に倒す**: 両方の置き場の祖先を消す形では、先に見た方の識別子が出る。仕様 SG-T11 が WF302 を求めているので、作業中を先に見る
- **`fmkeys` に入れ子の `write:` / `ops:` を足した**: `allow:` の行に触れずに `  write: [...]` の行だけを差し替えると WF208 をすり抜けられた（実測）。字下げのある行に限ったので、`- ops: ...` のような箇条書き（作業ログ）は巻き込まない
- **workflow-guard でパスの `.` / `..` を畳む**: `wip/../.claude/settings.json` が保護範囲の glob に一致せず WF202（確認）に落ちた（実測）。畳んだうえで作業ツリーの外に出るパスは WF209 で拒否する（承認単位にもしない。workflow-diff-check の 0038 の判断と揃えた）
- **シェルのキーワードだけの段（`for` / `done` / `fi` / `esac` / `case`）は scope.sh で読み取り扱いにする**: 入っていないと `for f in a b; do ...; done` が「分類外のコマンド」で WF204 になり、ふつうのループが全部止まる。判定規則はフック側に複製せず scope.sh に置いた。リダイレクトは段に残るので `done > out.txt` は従来どおり書き込みとして拾われる
- **提供コマンドの引数のパス判定は「パスらしい語」だけに当てる**: `-m` などの値を取るオプションの次の語を飛ばし、空白を含む語と拡張子も `/` も無い語は対象にしない。コミットメッセージを未記載パスとして確認に出さないため

### 拒否・確認・迂回の記録

- フックはまだ `settings.json` に登録していない（登録は 0031）ため、実際のブロックは発生していない。判定は各テストと敵対的プローブの中でだけ起きている
- 迂回は無し。`WORKFLOW_ENTRY_ENFORCE=0` などの無効化は使っていない

### 使った AI アセットと効き目

- `20-common-step-shell-script`（`test-lib.sh` / `run-tests.sh` / `logger.sh`）: `make_counting_path` と `--ids` が DoD の根拠をそのまま作れる形になっていて効いた
- `20-common-step-commit-push`（`commit.sh`）: ファイル単位の指定で他セッションの変更を巻き込まずに済んだ
- `.claude/rules/logger.md`: ログの出し方と「拒否理由に値を書かない」の判断に使った
- 参考: `hook-common.sh` / `cmdpos.sh` / `scope.sh` の 3 つの共有ライブラリは、フック側に規則を複製させない狙いどおりに働いた（workflow-guard は判定規則を 1 つも持っていない）

### スコープ外で見つけたこと

- **`python` / `python3` が既定拒否（WF204）になる**: 実作業では一時スクリプトを `python wip/tmp/x.py` で走らせる場面があるが、どの分類にも当たらない。`commands.build-test` に足すか「`wip/tmp/**` のスクリプト実行」の分類を作るかは設定・仕様の判断なので 0032 へ送る
- **PowerShell の読み取り系コマンドがすべて既定拒否**: `Get-Content` / `Select-String` などが `_SC_READ_ONLY_CMDS` に無く WF204 になる。Windows で PowerShell を常用するなら §8 の読み取り一覧に PowerShell 側の名前が要る（0032 へ）
- `shellcheck` がこの環境に未導入（8 巡連続）。`bash -n` と全件テストで代替している
- **フック 1 本の起動が約 1.9 秒（Windows / Git Bash）**: 5 本を登録すると 1 ツール呼び出しあたりの待ちが無視できない。内訳は bash 起動 0.3 秒・共有ライブラリ 3 本の読み込み 0.48 秒（hook-common 0.26 / cmdpos 0.12 / scope 0.10）・jq 0.24 秒。0031 の実測（T1〜T4）で確かめる
- **`run-tests.sh` の既定の上限（120 秒）で 5 本が TIMEOUT する**: `test_workflow_guard` / `test_workflow_state_guard`（今回追加）と `test_post_push_usage_report` / `test_check_html` / `test_ticket`（既存）。テストを軽くするか既定値を上げるかは 0032 で決める
- `check-html.sh` は md と HTML の内容一致を検査しない（19 回連続）

### AI アセットに反映すべき内容

- フック共通仕様 §1: `hook_read_state` は要求しない副入力も `null` で渡す（4 変数すべてを定義する）
- フック共通仕様 §7: `_CP_OPAQUE_WORDS` に `invoke-expression` / `iex`。語が 1 つも無い段は「読めない段」と区別して通す
- フック共通仕様 §8: シェルのキーワードだけの段は読み取り扱い。`python` と PowerShell の読み取り系の扱いを決める
- フック共通仕様 §9 / workflow-guard 仕様: WF208 の判定は入れ子の `write:` / `ops:` の行も見る
- workflow-guard 仕様: パスの `.` / `..` を畳んでから判定し、作業ツリーの外は WF209。WG-T05 / WG-T17 の例示を実装に合わせて直す。作業中 2 枚以上のときはプランモードも WF207 に含める
- 20-common-step-shell-script 仕様: `run-tests.sh` の既定の上限（120 秒）に収まらないテストの扱い（軽くするか、テスト側で上限を宣言できるようにするか）

### 備考

- 敵対的セルフレビューは 2 巡（1 巡目 = すり抜け、2 巡目 = 偽陽性）で、確度 0.5 以上の指摘 3 件はすべてこのチケット内で直した（追加チケットは起こしていない）
- 次は 0031（settings.json への段階登録と TBD T1〜T4 / T9 の実測。人間の操作）
