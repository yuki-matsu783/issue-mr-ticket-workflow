---
type: spec
title: workflow-guard フック 仕様
description: 作業中チケットの宣言とタスクの種類ごとの上限設定だけを材料に、書き込み・コマンド・プランモード・リモート操作を許可 / 確認 / 拒否するフックの内部仕様。判定に使うチケットは HOOK_WORKTREE の作業中 1 枚で一意に決まる。scope-limits.json の形式（正）、判定順、コマンドの分類、worktree.sh の引数の扱い、チケット自身の改変の拒否、WF20x、記録を定める
tags: [spec, hook, workflow-guard]
keywords: [やってよいこと, 上限, scope-limits.json, 許可範囲, 禁止範囲, 毎回確認, 未記載パス, ask, deny, コマンド分類, 読み取り系, 提供コマンド, リモート書き込み, WIP 1枚, 自己改変, プランモード, パスの正規化, 作業ツリー外, HOOK_WORKTREE, hook_rel_path, worktree.sh, WF201, WF207, WF208, WF209, WF210]
---

# workflow-guard フック 仕様

## 概要・禁止事項

対応する要件は [00_requirement/hooks/20-PreToolUse/workflow-guard.md](../../../00_requirement/hooks/20-PreToolUse/workflow-guard.md)。共通事項は [フック共通仕様](../../フック共通仕様.md)（§2 作業ツリーの三分とパスの畳み込み、§7 コマンド位置、§8 許可範囲と上限設定、§9 チケットの機械可読項目）。

作業中チケット（**`$HOOK_WORKTREE/wip/10_tickets/10_doing/*.md`**）が 1 枚あるときだけ働き、その frontmatter（`ticket_type` / `allow`）と `.claude/hooks/config/scope-limits.json` を材料に判定する。**`scope-limits.json` の形式と判定順の正は共通仕様 §8**（`scope.sh`）で、`workflow-diff-check` / `subagent-stop-check` が同じ関数を使う。

**宣言範囲の強制は作業ツリーごとに一意に決まる**（受け入れ条件 A5）。判定に使うチケットは `HOOK_WORKTREE`（§2 の解決順で決まる、その操作が行われた作業ツリー）の `10_doing/` の 1 枚だけで、他の作業ツリーの `10_doing/` は数にも材料にも入れない。`HOOK_ROOT` と `HOOK_SHARED_ROOT` はチケットの探索に使わない（設定 `scope-limits.json` の置き場だけが `HOOK_ROOT`）。したがって:

- **同時に作業中のチケットが 1 枚**という不変条件は**1 作業ツリーあたり**の話であり、リポジトリ全体の枚数ではない。作業ツリーが N 個あれば、リポジトリ全体では最大 N 枚が同時に作業中になり得る（`WF207` はこの意味で「1 作業ツリーあたり 2 枚以上」を指す）
- **書き込み先のパスがどの作業ツリーの中かと、判定の根拠になるチケットがどの作業ツリーのものかは別**である。前者は `hook_rel_path`（§2）が畳んだ結果で決まり、後者は常に `HOOK_WORKTREE` の 1 枚である

禁止事項:

- AI の説明・会話・チケット本文の散文を判定材料にすること
- 宣言による上限の拡大（`allow.write` は `types[t].allow ∪ common.allow` の内側だけ有効）
- 拒否時の自動巻き戻し（`git checkout --` 等）
- 判定規則の複製（`scope.sh` を source する）
- 作業中チケットが無いときの判定（振り分けは `workflow-entry`）

## 呼出条件（イベント・matcher・登録）

- PreToolUse、matcher: 書き込み / 実行 / プランモード / 起動（共通仕様 §1 の表の PreToolUse 6 行目。**位置であって実行順ではない** — フックは並列に走る（§1）。他の拒否側フックと同時に deny を返し得るので、拒否理由は単独で読んで成立する文面にする）
- 前提: **`$HOOK_WORKTREE/wip/10_tickets/10_doing/`** に `.md` が 1 枚。0 枚なら即座に許可。2 枚以上は異常（WF207）。枚数は操作が行われた作業ツリーの中だけで数える

## 入出力

- 入力: `tool_name`、`tool_input`（書き込み: `file_path` / `notebook_path`。実行: `command`。起動: `subagent_type` / `model`）。参照: 作業中チケットの frontmatter、`scope-limits.json`、`logs/sessions/<session_id>/approvals.json`
- 出力: 許可（無出力）/ `ask`（WF202 / WF203）/ `deny`（WF201 / 204〜213）

## 制御方式

判定順:

1. 停止中 → `disabled` を記録して許可。**`HOOK_WORKTREE` の**作業中チケット 0 枚 → 許可（記録しない）。他の作業ツリーの `10_doing/` は見ない
2. **`HOOK_WORKTREE` の**作業中チケットが 2 枚以上 → 提供コマンド（`ticket.sh` 等）以外の書き込み・実行・**プランモード**（`EnterPlanMode`）を **deny WF207**（1 枚を残して他を `ticket.sh` で戻す対処を案内）。プランモードを含めるのは、どちらのチケットの `plan_mode` を見ればよいかが決まらないため（起動と読み取りは通す）。`ask` にはしない（ヘッドレス実行では確認の応答が得られず、確認が拒否に化けるため。共通仕様 §10）
   - **提供コマンド側は 2 枚以上を検知しない**（非対称）: `run-tests.sh` と `push.sh` は `10_doing/*.md` の 1 枚目だけを読んで `allow.ops` を判定し、`ticket.sh next` も 1 枚目だけを返す。件数で止めるのは `ticket.sh start`（2 枚目の着手を TK002 で拒否）だけで、完了検査は番号引数を取るので非対称ではない。したがって **2 枚以上の状態を「機構の異常」として止めるのはこのフックの役割**であり、提供コマンドの側は 1 枚である前提で動く（issue #9 G8。DDR i0009-02）
   - **並列実施を行う場合**（`00-workflow-issue-mr-driven` が同じ type の依存しないチケットを別の作業ツリーで同時に実施する場合）でも、この判定は作業ツリーの中だけで閉じる。合流はタスクの切れ目（どの作業ツリーも作業中 0 枚）でだけ行うので、合流によって合流先の `10_doing/` が 2 枚になることは構造的に起きない。**それでも 2 枚になっていれば、合流の前提が崩れた異常**として WF207 で止める（合流の前提検査は `20-common-step-worktree` の提供コマンドが持つが、このフックはその成否に依存せず自分で数える）
3. `scope-limits.json` が無い・解釈できない（`HC_LIMITS_STATE` が `missing` / `broken`。副入力の破損は `hook_read_input` を落とさない — §1・DDR i0009-47）→ **deny WF210**。復旧経路として許可するのは: 提供コマンドの実行、`wip/10_tickets/**` への書き込み、`scope-limits.json` 自身への **ask（WF203）付きの**書き込み（設定が読めない間も上限設定の書き換えを AI の裁量にしない。ヘッドレスでは deny になり人間が直す）
4. チケットの frontmatter が読めない・`ticket_type` が `types` に無い → **deny WF211**。復旧経路: 提供コマンドの実行、そのチケットファイル自身の編集
5. **書き込みツール**: 対象パス `p` を `hook_rel_path`（共通仕様 §2）で畳む（**`.` と `..`・パス区切り・大文字小文字を畳んでから判定する** — 畳まないと `wip/../.claude/settings.json` のような書き方が保護範囲の glob に一致せず、未記載パス（WF202）に落ちる）。畳んだ結果の扱いは根ごとに分かれる:
   - `HOOK_WORKTREE` の配下 → そのルート相対パスで以下の判定に掛ける（従来どおり）
   - **同一リポジトリの他の作業ツリーの配下** → **そのツリーのルート相対パス**で同じ判定に掛ける。判定に使う宣言は `HOOK_WORKTREE` の作業中チケットのもの（概要）。「自分の作業ツリーの外だから見ない」としない — 他の作業ツリーの `apl/**` や `.claude/**` を絶対パスで書けば保護をすり抜ける、という穴を作らないため
   - **共有ルートの配下** → 共有ルートのルート相対パスで同じ判定に掛ける（`logs/**` は判定順 (1) で対象外、`common.state_files` は `workflow-state-guard` が deny を返す）
   - **どの根の配下にも畳めない**（同一リポジトリの外であることが確定した。`..` でリポジトリの外へ出る・OS の一時ディレクトリ・別 clone）→ **deny WF209**。承認単位にもしない（どの範囲にも属さないため判定できない）。作業中チケットがある間はリポジトリの外へ書かせない
   - **畳み込みそのものに失敗した**（正規化に失敗した・作業ツリーの集合を読めなかった。§2 の「判定できない」）→ **deny WF209**。「無関係」に倒さない（DDR i0010-09）
   - **帰結として Claude Code のメモリ（`~/.claude/projects/<プロジェクト>/memory/`）にも書けない** — 同一リポジトリのどの根の配下でもないため。このプロジェクトはメモリを使わない前提を採り、どうしても要るときだけ `WORKFLOW_GUARD_ENFORCE=0` の新しいセッションで書く。設定に「作業ツリー外でも書いてよい場所」を足す案は採らない（設定の構造が増えるわりに作業ツリー外への書き込みは本来まれなため）
   - `p` が作業中チケット自身で、変更範囲が frontmatter の `ticket_type` / `allow` / `executor` / `human_review` / `adversarial_review` / `predecessors` に及ぶ（Edit の `old_string` / `new_string` または Write の内容と現在値の差で判定）→ **deny WF208**。本文（DoD・作業ログ）だけなら許可
   - それ以外は `scope.sh` の判定順（共通仕様 §8）で allow / ask WF202 / ask WF203 / deny WF201
6. **実行ツール**: `cmdpos.sh` で実行位置のコマンド列を得て、セグメントごとに:
   - 提供コマンド → 許可。ただし引数にパスを取るもの（`commit.sh -m .. <files>`、`ticket.sh create` の出力先）は各パスに 5 と同じ判定を適用する
     - **例外は `worktree.sh` の作業ツリーの置き場を指す引数**（`worktree.sh add <名前> [<置き場>]` の置き場、`worktree.sh remove <名前|置き場>` の位置引数）で、これらには 5 の判定を当てない。作業ツリーの既定の置き場は**リポジトリの外**（`../<リポジトリ名>-wt/<名前>`。`20-common-step-worktree` 仕様）なので、当てると必ず WF209 になり、提供コマンドを設けた意味が無くなる。置き場が妥当か（既存の作業ツリーと重ならない・同一リポジトリの作業ツリーである）は `worktree.sh` 自身が検査する。`worktree.sh` のそれ以外の引数（`-m` のメッセージ、合流対象のブランチ名）はパスではないので判定の対象にならない
     - 提供コマンドごとに「5 の判定を当てる引数」と「当てない引数」を仕様で決める。当てない引数を増やすときは、その引数の妥当性をコマンド自身が検査することを同じ変更で書く（この 1 行が無いと、引数を除外するだけで統制が消える）
   - `opaque` / `degraded` → **deny WF209**（判定できなかったことを明記）
   - リダイレクト（`>` `>>` `tee`）・`cp` `mv` `mkdir` `touch` `sed -i` 等で**ファイルを作る・更新する** → **deny WF205**（Edit / Write を案内）。ただし対象が `wip/tmp/**` または `logs/**` なら許可
   - **削除だけを行う段**（実行体が `rm`、または `git` でサブコマンドが `rm`）→ 対象ごとに次を順に当てる。Edit / Write にファイルを消す手段が無いため、削除だけは宣言した範囲で許す（DDR `i0010-06`）
     1. 対象を読み取れない（対象なし・クォートで潰れた `_`・`--pathspec-from-file`）→ **deny WF205**
     2. 対象に**展開前の文字列**（`*` `?` `[` `{` `$` `` ` `` `~` `,`）を含む → **deny WF205**（展開後にどのパスになるか決まらない。`.claude/hooks/*` は glob として宣言の `.claude/hooks/**` に一致してしまう）
     3. `common.protected` / `common.confirm` / `common.state_files` / `types[t].deny` / `types[t].confirm` のいずれかの glob が `<対象>/` で始まる（＝対象がディレクトリで、配下に消してはいけない範囲を含み得る）→ **deny WF205**
     4. 対象が `common.state_files` に一致する → **deny WF205**（`logs/**` の中でもコマンドでは消させない）
     5. 対象が `wip/tmp/**` または `logs/**` → 許可
     6. `scope.sh` の判定順（共通仕様 §8）が `allow` を返し、**かつチケットの `allow.write` に明示されている** → 許可。`common.allow` だけで通る範囲（計画書・レポート・未着手チケット）は宣言が無ければ消せない
     7. それ以外 → **deny WF205**
   - `mv` は削除に当たらない（消すと作るの同時実行）。移設は「新しい場所に Write → 旧ファイルを `rm`」の 2 手で行う
   - 削除だけの段にリダイレクトが付いていれば、その宛先には上の「作る・更新する」の判定を当てる（`rm a > b` の `b` は作成）
   - `READ_ONLY_CMDS` → 許可。**作業ツリーに関わる形の内訳は共通仕様 §8 が正**: `git worktree list` は `read` で通り、`git worktree add` / `remove` / `move` / `prune` などは `unknown` → **deny WF204**（`worktree.sh` を使うよう案内する）。`cd` は分類に足さないので `unknown` → **deny WF204**（作業ツリーの中で作業するときは、その作業ツリーを cwd として始める。提供コマンドはルート相対表記で呼ぶ — §7-8）
   - `remote-read`（`gh` / `glab` の参照系）→ 許可
   - `remote-write:<種別>` → チケットの `allow.ops` にその種別があり、かつ `types[t].ops` にもある → 許可、無ければ **deny WF206**
   - `build-test` / `hook-test` / `merge-base` → 同様に `allow.ops` と `types[t].ops` の両方にあれば許可、無ければ **deny WF204**
   - `web`（`curl` / `wget`）→ 共通仕様 §8 の**判定順**（送信側 → 出力先 → `web`）で扱う。(1) 送信側の形（`-T` / `--upload-file` / `-d` / `--data*` / `-F` / `--form` / `-X` の GET・HEAD 以外、`wget` の `--post-*` / `--body-*` / `--method` の GET・HEAD 以外）は**宣言の有無によらず deny WF206**。(2) 出力先を持つ形（`curl` の `-o` / `--output` / `-O` / `--remote-name` / `--output-dir`、`wget` の既定と `-O <file>`）は書き込みとして扱い、出力先パスに 5 と同じ判定を当てる（`wip/tmp/**` / `logs/**` なら許可、それ以外は **deny WF205**）。(3) 残りは `allow.ops` と `types[t].ops` の両方に `web` があれば許可、無ければ **deny WF204**。宣言があっても (1)(2) は免除しない（DDR i0009-41・i0009-56・i0009-57）
   - 上記のいずれにも該当しない → **deny WF204**（既定拒否。読み取り系の一覧に足すか、分類を宣言するかを案内）
7. **プランモード**（`EnterPlanMode`）: `types[t].plan_mode` が true でなければ **deny WF212**
8. **起動**（`Agent` / `Workflow`）: 許可（実行者の不一致は `subagent-start-check` が伝える）
9. ヘッドレス（共通仕様 §10）では 5 の `ask` を **deny WF213** に置き換え、「計画タスクで宣言を十分に列挙する必要がある」を含める
10. 入力不正 → **deny WF209**

- 承認の記憶（WF202 の ask が承認され実行された事実）は `workflow-diff-check` が `approvals.json` に書く。このフックは読むだけ。WF203（毎回確認）は記憶しない
- サブエージェント内でも同じ判定（同じ `session_id`・同じ作業中チケット）

## エラー識別子とメッセージ

| ID | 判定 | 条件 | メッセージに含める内容 |
|----|------|------|----------------------|
| WF201 | deny | 禁止範囲・保護範囲への書き込み | 違反パス / 作業中チケットと種類 / 宣言の範囲内で進める・広げるならユーザーに提案 |
| WF202 | ask | 設定にも宣言にも無いパス | 「想定していないパス」であること / チケット / 承認単位（親ディレクトリ。`file_granular` とルート直下のファイルはファイル単位） |
| WF203 | ask | 毎回確認の範囲 | 毎回確認の範囲であること / チケット |
| WF204 | deny | 分類外のコマンド | コマンドの先頭 / 許可される分類（読み取り系・宣言した ops・提供コマンド） |
| WF205 | deny | コマンドによるファイル書き込み | 対象 / Edit・Write を使うこと |
| WF206 | deny | 宣言に無いリモート書き込み | 操作の種別 / リモート書き込みは切れ目の処理か宣言内のみ |
| WF207 | deny | **1 つの作業ツリーの中で**作業中が 2 枚以上 | チケット番号の一覧 / どの作業ツリーで数えたか / `ticket.sh` で 1 枚に戻す |
| WF208 | deny | 作業中チケット自身の種類・宣言・実行者・レビュー要否（人間・敵対的）の改変 | 変えようとした項目 / 見直しは未着手チケットか計画で |
| WF209 | deny | 判定不能（opaque・縮退・入力不正・**同一リポジトリの外と確定したパス**・**どの作業ツリーの中の位置かを確定できないパス**） | 判定できなかった理由（外と確定したのか、確定できなかったのか）/ 言い換え（`ai-command-style`）またはユーザーへの報告 |
| WF210 | deny | 上限設定なし・不正 | 設定パス / 復旧経路（設定とチケットの修正・提供コマンド） |
| WF211 | deny | チケットの記載不正・種類が設定に無い | チケット / 復旧経路（記載の修正・`ticket.sh cancel`） |
| WF212 | deny | プランモード不可の種類 | 種類 / プランモードは全体計画のみ |
| WF213 | deny | ヘッドレスで確認が必要 | 本来は確認であること / 計画タスクで宣言を列挙する |

## 回復手順

- WF201 / 204 / 205 / 206: 宣言の範囲内で進める。範囲を広げる必要があれば作業を止めてユーザーに提案する（未着手チケットの見直しまたは計画の追加チケット）。迂回しない
- WF202 / 203: 確認に答える（ユーザー）。承認された未記載パスは同セッション内で再確認されない
- WF207 / 211: `ticket.sh` で戻す・直す。WF210: ユーザーが `scope-limits.json` を直す（AI アセット実装のチケットでのみ AI が変更できる）
- WF208: 変更を取り消す。実行者・レビュー要否（人間・敵対的）の変更は未着手チケットの見直し（`00-workflow-issue-mr-driven` 手順 5-1）で行う

## 記録（logs/）

- `decisions.jsonl` に allow / ask / deny をすべて記録（`target` にパスまたはコマンドの先頭、`ticket` に番号と種類、`note` に根拠: 一致したパターンと出どころ）
- 実行ログ: `logs/sh/hook-workflow-guard.log`

## テスト観点

| テスト ID | 種別 | 固定する振る舞い |
|-----------|------|----------------|
| WG-T01 | 正常系 | 作業中 0 枚ですべて通り記録されない |
| WG-T02 | 正常系 | `common.allow` と（宣言が無ければ）`types[t].allow` への Write が通る。宣言 `allow.write` が `types[t].allow` より狭いとき、宣言外だが上限内のパスは WF202（ask）になり通らない。宣言が上限の外を含んでも無視される。`wip/10_tickets/10_doing/` の作業ログ追記は宣言によらず通る |
| WG-T03 | 異常系 | `.claude/**` へ implementation チケットから Write → WF201。ai-asset-design から `.claude/docs/**` は通り `.claude/hooks/**` は WF201。**`.` / `..` を挟んだ書き方（`wip/../.claude/settings.json`）でも同じ判定になる**（畳んでから判定するので保護範囲の glob をすり抜けない） |
| WG-T04 | 正常系 | 未記載パスが WF202（ask）、`approvals.json` に親ディレクトリがあれば通る。`file_granular` のファイルはファイル単位 |
| WG-T05 | 正常系 | `confirm` 範囲は承認済みでも毎回 WF203: `types.confirm` の `package.json`（implementation）と、`ai-asset-implementation` からの `.claude/hooks/config/**` / `.claude/settings.json`。**共通の保護範囲が先に効く場合は WF203 に届かない** — 同じ `.claude/hooks/config/**` でも implementation からは判定 2（共通の保護範囲）で WF201 になる（`common.confirm` が効くのはその種類の `allow` に明示されている `.claude/**` の中だけ） |
| WG-T06 | 正常系 | 読み取り系・提供コマンド・`remote-read` が通り、`echo x > src/a` が WF205、`npm test` は `build-test` を宣言したときだけ通る（無ければ WF204） |
| WG-T07 | 異常系 | `gh issue create` が宣言無しで WF206、overall-plan の宣言ありで通る |
| WG-T08 | 異常系 | 2 枚目の doing で提供コマンド以外（実行・書き込み・**プランモード**）が WF207 になり、チケット番号の一覧が出る。提供コマンド（`ticket.sh cancel`）は通る |
| WG-T09 | 異常系 | 作業中チケットの `ticket_type` や `adversarial_review.required` を Edit → WF208、作業ログの追記は通る |
| WG-T10 | 異常系 | `eval "..."`・4096 文字超が WF209。**作業ツリーの外に出るパス**（`../outside.txt`・`wip/../../outside.txt`）も WF209 で、承認単位にならない |
| WG-T11 | 異常系 | 設定なしで WF210 かつ設定ファイル自身の Write は ask（WF203）になる。設定ありのとき `.claude/hooks/config/**` と `.claude/settings.json` は ai-asset-implementation でも毎回 WF203。種類が設定に無いチケットで WF211 |
| WG-T12 | 正常系 | EnterPlanMode が overall-plan で通り implementation で WF212 |
| WG-T13 | 境界 | `WORKFLOW_HEADLESS=1` で WF202 が WF213（deny） |
| WG-T14 | 正常系 | `commit.sh -m .. <禁止範囲のファイル>` が WF201 |
| WG-T16 | 異常系 | `scope-limits.json` を壊した状態でも `tool_name` と対象パスがメッセージに載った **WF210** が返る（stdout が空にならない）。同じ状態で `commit.sh` の実行・`wip/10_tickets/**` への Write・`scope-limits.json` 自身への Write（WF203）が**通る**（復旧経路が生きている）。`approvals.json` を壊した状態では WF202 の承認済み判定だけが効かなくなり、他の判定は動く |
| WG-T15 | 正常系 | `curl https://example.com/x` は `web` を宣言した investigation で通り、宣言の無い design では WF204。`curl -o wip/tmp/x.md <url>` は通り、`curl -o .claude/settings.json <url>` と `curl -O <url>`（カレントに作る）は宣言があっても WF205。`wget <url>` は `-O -` でなければ WF205。`WebFetch` は matcher 外なのでこのフックに届かない（届かないことを登録表 HK-T01 で固定する） |
| WG-T18 | 正常系・異常系 | **削除だけの段**（`rm` / `git rm`）は宣言した範囲でだけ通る。`.claude/hooks/**` を宣言した `ai-asset-implementation` で `rm .claude/hooks/20-PreToolUse/x.sh`・複数対象の `rm -f`・`git rm`・`git rm -r --cached <dir>/`・`rm wip/tmp/x` が **allow**。`rm apl/app/src/api/a.ts`（宣言外）・`git rm`（同）・`rm .claude/settings.json`（毎回確認）・`rm -rf .claude`（未記載）が **WF205**。作成・更新（`echo x > <file>`・`mv`・`cp`）は **WF205** のまま。対象を読めない `rm -f`（対象なし）・`git rm --pathspec-from-file` が **WF205**。**ディレクトリごとの削除**（`rm -rf .claude/hooks/config`・末尾 `/` 付き・`git rm -r .claude/hooks`・`rm -rf logs`）が **WF205**。**展開前の文字列**（`rm -rf .claude/hooks/*`・ブレース展開・`$X`・コンマ区切り・`~`）が **WF205**。**進行状態のファイル**（`rm logs/review-state.json`・`rm logs/mr.json`）が **WF205** で `rm logs/sh/*.log` は allow。宣言が空のチケット（`overall-plan`）は `wip/30_reports/a.md` を消せず `wip/tmp/a.txt` は消せる。リダイレクト先は削除と分けて判定する（`rm <許可> > .claude/hooks/out.txt` は WF205、`> wip/tmp/out.txt` は allow）。**作業中チケットが 0 枚のときはこのフックが何も判定しない**（WG-T01 と同じ） |
| WG-T17 | 異常系 | **送信側は `web` を宣言しても通らない**: `curl -T a.md <url>`、`curl -d @a.md <url>`、`curl -F file=@a.md <url>`、`curl -X POST <url>`、`wget --post-file=a.md <url>`、`wget --method=PUT <url>` がすべて **WF206**。送信側でない `curl -X GET <url>` は（`web` の宣言があれば）通る。`wget --method=GET <url>` は **WF205** — `wget` は既定で URL の basename にファイルを作るので出力先ありの書き込みとして判定され（判定順は送信側 → 出力先 → `web`）、通るのは `-O -` を付けた形だけ（WG-T15 の「`wget <url>` は `-O -` でなければ WF205」と同じ扱い）。**出力先と URL の取り違えをしない**: `curl <url> -o wip/tmp/a`（URL が先）と `curl -o wip/tmp/a <url>`（出力先が先）がどちらも通り、`curl <url>`（出力先なし）が WF205 にならない |
| WG-T19 | 正常系（機械） | **宣言範囲の強制が worktree 側のチケットで判定される**（受け入れ条件 A1-6 / A5）。一時リポジトリの本流から worktree を切り、**本流の `10_doing/` を 0 枚・worktree の `10_doing/` を 1 枚にする**。テストは判定を呼ぶ前に**両方の枚数を assert** して前提が成立していることを自分で確かめる（既存のリポジトリの状態に依存しない。手作業の実測では両方 0 枚になって判定不能に終わった — 0004 の e48）。`cwd` を worktree にした入力で、worktree 側チケットの `allow.write` の外への書き込みが **deny（WF201）**、未記載パスが **ask（WF202）**、宣言内が **allow** になる。`WF207` は出ない（本流に 0 枚・worktree に 1 枚なので合計 2 枚だが、数えるのは作業ツリーの中だけ） |
| WG-T20 | 境界（機械） | **WG-T19 の負のコントロール**。同じ一時リポジトリで**本流の `10_doing/` を 1 枚・worktree の `10_doing/` を 0 枚**にし（この枚数もテストが assert する）、`cwd` を worktree にした同じ入力を流すと**無出力・終了 0**（作業中 0 枚として素通り）になる。本流側のチケットの `allow.write` は判定に一切使われない。あわせて `cwd` を本流にすると同じ入力が deny になることを**正のコントロール**として添える（「無音」が判定の不在であって機構の故障ではないことを示す） |
| WG-T21 | 正常系・異常系（機械） | **`worktree.sh` の引数の扱い**。`bash .claude/skills/20-common-step-worktree/scripts/worktree.sh add w1 ../repo-wt/w1` が、置き場がリポジトリの外でも **allow**（WF209 にならない）。同じ行の他のパス引数（`commit.sh -m .. <禁止範囲>`）は従来どおり WF201 になる（WG-T14 の正のコントロール）。提供コマンドでない `git worktree add ../repo-wt/w1` は **WF204**、`git worktree list` は **allow**、`cd ../repo-wt/w1` は **WF204** |

## 要件との対応

| 要件（受け入れ基準） | 実現箇所 |
|--------------------|---------|
| メイン: 操作が行われた作業ツリーに作業中なしは何もしない（他ツリーは見ない） | 制御方式 1、WG-T20 |
| メイン: 材料はチケットの宣言と上限設定のみ | 概要、禁止事項 |
| メイン: 判定に使うチケットは作業ツリーごとに一意（A5） | 概要、制御方式 1・2、WG-T19・WG-T20 |
| メイン: 他ツリー・共有ルートの絶対パスは畳んだ先で判定し、根拠は自ツリーのチケット | 制御方式 5、共通仕様 §2 |
| メイン: 上限は設定で定義・15 種 | 共通仕様 §8、HK-T02 |
| メイン: 宣言で上限を超えられない | 制御方式 5（scope.sh (5)） |
| メイン: 共通保護範囲の優先と種類ごとの明示許可 | scope.sh (2) |
| メイン: 禁止・保護範囲の拒否と案内 | WF201 |
| メイン: 許可範囲・宣言範囲の許可 | scope.sh (5) |
| メイン: 毎回確認の範囲 | WF203 |
| メイン: 未記載は警告付き確認・承認単位 | WF202、scope.sh (6)(7) |
| メイン: 承認はセッション内だけ | approvals.json（共通仕様 §5） |
| メイン: 共通の許可範囲 | `common.allow` |
| メイン: コマンドは既定拒否・読み取り系 / 宣言した分類 / 提供コマンドだけ許可 | 制御方式 6 |
| メイン: 提供コマンドは種類を問わず許可 | 制御方式 6 |
| メイン: コマンドによる書き込みの拒否 | WF205 |
| メイン: 削除だけのコマンドは宣言した範囲でのみ許可 | 制御方式 6 の削除の判定（1〜7）、WF205、WG-T18、DDR `i0010-06` |
| メイン: 提供コマンドの引数パスに同じ判定（作業ツリーの置き場を指す引数は対象外） | 制御方式 6、WG-T14、WG-T21 |
| メイン: 作業ツリーの作成・切り替え・片付けは提供コマンド経由（一覧は読み取り） | 制御方式 6、共通仕様 §8、WG-T21 |
| メイン: 作業ディレクトリの移動は拒否 | 制御方式 6（`cd` は `unknown`）、共通仕様 §8、WG-T21 |
| メイン: リモート読み取りは許可 / 書き込みは宣言内のみ | 制御方式 6、WF206 |
| メイン: コマンド位置の判定を共有 | `cmdpos.sh` |
| メイン: 判定不能は拒否側 | WF209（コマンドの分類不能・同一リポジトリの外と確定したパス・位置を確定できないパス） |
| メイン: 2 枚目の着手拒否 / 1 作業ツリーで複数作業中の異常 | WF207（着手の直接操作は state-guard、`ticket.sh` は TK002） |
| 代替: 並列実施の合流の直後も作業ツリーの中だけを数える | 制御方式 2 の並列実施の項 |
| メイン: チケット自身の改変拒否・他欄は許可 | WF208 |
| メイン: プランモードは許可された種類のみ | WF212 |
| メイン: 別モデルのサブエージェント起動は許可 | 制御方式 8 |
| メイン: サブエージェント内も同じ判定 | 制御方式（session_id） |
| メイン: 判定の記録・識別子・確認の文面 | 記録、エラー識別子 |
| 代替: 緊急停止 | 制御方式 1 |
| 代替: ヘッドレスは確認を拒否として扱い案内 | WF213 |
| 例外: 設定なし・不正は安全側 + 復旧経路 | WF210 |
| 例外: 種類が設定に無い・記載不正 | WF211 |
| 例外: 自動巻き戻しをしない | 禁止事項 |
| 例外: 拒否されたら迂回しない | 回復手順 |
