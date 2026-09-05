---
type: report
title: 0018〜0027 AI アセット実装・テスト結果 — 入口の設定・hook-common.sh の作業ツリーの三分・cmdpos / scope の穴の閉塞・拒否側フック 2 本と A1-6（S1〜S4 分）
description: issue #50 の AI アセット実装フェーズ（S1〜S10 / チケット 0018〜0027）が積み上げる実装結果レポート。S1 では scope-limits.json の allow に .gitignore を足し .claude/worktrees/ を無視した。S2 では hook-common.sh に作業ツリーの三分・作業ツリーの集合・パスの 4 段の畳み込み・共有ルートを入れ、decisions.jsonl に cwd と agent_id を足し、呼び手 3 本を WF209 / WF309 / WF605 に分岐させた。S3 では cmdpos.sh の正規化 2 件（算術展開は段を割らない / 置換の閉じ括弧の後ろの語を実行体にしない）と scope.sh の git の限定適用 6 件を入れ、cd は分類に足さないことを負のコントロールで固定した。S4 では workflow-guard の WF207 に「どの作業ツリーで数えたか」を足し、worktree.sh の置き場を指す引数だけを判定の例外にし、受け入れ条件 A1-6 を閉じる WG-T19 / WG-T20（枚数をテスト自身が assert する負のコントロール付き）と WG-T21 / SG-T12 / SG-T13 を新設した。workflow-state-guard は S2 の畳み込みで既に仕様どおりで無改修
tags: [report, ai-asset-implementation, issue-50]
keywords: [scope-limits.json, .gitignore, .claude/worktrees/, common.confirm, WF203, WF601, ロックアウト対策, HK-T01, HK-T02, 判定順, hook-common.sh, HOOK_SHARED_ROOT, hook_worktrees, hook_rel_path, 作業ツリーの三分, 畳み込み, WF209, WF309, WF605, HK-T06, HK-T21, HK-T22, SG-T11, fail-closed, cmdpos.sh, scope.sh, 算術展開, コマンド置換, プロセス置換, git worktree list, 限定適用, 負のコントロール, HK-T05, HK-T12, HK-T15, workflow-guard, workflow-state-guard, WF207, WF201, WF202, WF205, WF301, WF302, WF303, A1-6, WG-T19, WG-T20, WG-T21, WG-T14, SG-T12, SG-T13, worktree.sh, 置き場を指す引数, 枚数の assert]
---

# 0018〜0027 AI アセット実装・テスト結果 — 入口の設定・hook-common.sh の作業ツリーの三分・cmdpos / scope の穴の閉塞・拒否側フック 2 本と A1-6（S1〜S4 分）

- 対象 issue: [#50](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/issues/50)
- MR: [#51](https://github.com/yuki-matsu783/issue-mr-ticket-workflow/pull/51)（draft）
- ブランチ: `feature-50-worktree-parallel-tickets`
- チケット: 0018〜0027（実装計画書 `wip/20_plans/0016-ai-asset-implementation-plan.md` の S1〜S10。**このレポートは各チケットが節を積み上げる器**で、現時点の内容は 0018（S1）・0019（S2）・0020（S3）・0021（S4）分）
- 作成日: 2026-09-05（0018）／更新: 2026-09-05（0019・0020・0021）

## サマリ

S1（0018）は実装フェーズの**入口の設定**を 2 つ変えた。①`.claude/hooks/config/scope-limits.json` の `types["ai-asset-implementation"].allow` に `.gitignore` を足し（`.gitattributes` と同じ「`common.protected` を明示で判定順 (2) を通す」形）、②`.gitignore` に `.claude/worktrees/` を足した。①→② の順を守り、②が `WF201` にならず **judge stage 5 の allow** で `logs/hooks/decisions.jsonl` に記録されたことをもって、変えた判定を実際に踏んだことを確かめた。機械テストは `HK-T01` / `HK-T02` とも PASS、`jq -e .` も成功、変更直後の `Write` と提供コマンド `ticket.sh next` も通り、機構は自分を止めていない。

一方で **`common.confirm` の壁は計画書の保留 P5 のとおりに顕在化した**。`.claude/hooks/config/**` は判定順 (4) の `WF203`（ask）に落ち、サブエージェント実行者は確認に答えられないため書き込めない。①の編集は呼び出し元のメインエージェントが代行した。さらに、チケットの `allow.write` に `.claude/hooks/config/**` を宣言していても `workflow-diff-check` は当該ファイルを**許可範囲外（WF601）として報告し続ける** — 宣言と差分検査の見え方がずれる。どちらも仕様どおりの振る舞いなので仕様は直さず、逸脱として記録した。

S2（0019）は**中核 a**として `hook-common.sh` に作業ツリーの三分（`HOOK_ROOT` / `HOOK_WORKTREE` / `HOOK_SHARED_ROOT`）・同一リポジトリの作業ツリーの集合（`hook_worktrees`。`git` を呼ばない）・作業ツリーをまたぐパスの 4 段の畳み込み（`hook_rel_path`）と「判定できない」の戻り値を入れ、`logs/` の置き場を §5 の根の列に合わせ、`decisions.jsonl` に `cwd` と `agent_id` を足した。値が往復する呼び手 3 本の分岐（`workflow-guard` = `WF209` / `workflow-state-guard` = `WF309` / `workflow-diff-check` = `WF605`）も同じチケットで閉じた。`HK-T06` / `HK-T21` / `HK-T22` を含む**全フックのテスト 17 本・128 ID が PASS**（`--timeout 300`）。

S2 で得た大きな学びは 2 つある。①全通しで **`SG-T11` の退行**（`rm -rf .` が `WF302` → `WF309` に化ける）を検出できた。「点だけの相対パス」を判定できない側に倒したのが原因で、置き場ごと消す形を拾えなくなる退行だった（e10）。②中核を壊した瞬間に **fail-closed の deny が `decisions.jsonl` に記録されたのに、対応する `Edit` は止まらなかった**（e11）。「中核を壊しても機構が自分を止める」という前提が成り立っておらず、原因は特定できていない。

S3（0020）は**中核 b** として、全フックが読む共通ライブラリ 2 本の穴を閉じた。`cmdpos.sh` は §7-1 の正規化 2 件（①算術展開 `$(( ))` はダブルクォートの中でも**段を割らない** ②コマンド置換・プロセス置換は**開始と終了の対応**で畳み、閉じ括弧の後ろの語を新しい段の実行体にしない）を実装し、`scope.sh` は §8 の「サブコマンド + オプション」の**限定適用 6 件**（`worktree list` だけ `read` / `branch` の書き込みオプション / `symbolic-ref` の代入形 / `reflog` の `show`・`exists` / `--output=<file>` は `write` / グローバル `-c`・`--config-env` は一律 `unknown`）を `_sc_classify_git` に集めた。`cd` は**分類に足さず**、負のコントロールとして 5 件の assert で固定した。R52 の軽微 2 件（`_SC_READ_ONLY_CMDS` の `column` の重複・`_SC_SHELL_KEYWORDS` の全要素ループ）も同じチケットで直し、**一覧に重複を残さない検査**を 3 つの語彙表に足した。テストはすべて**先行**（`HK-T05` 側で 21 件・`HK-T15` 側で 38 件の FAIL を確認してから実装）で、最終は `HK-T05`/`HK-T12` 332 件・`HK-T15`/`HK-T11`/`HK-T16` 399 件・`HK-T02` 95 件、そして**全件 27 本 / 216 ID がすべて PASS**。実機でも `git worktree list` / `git branch -a` / `git status --porcelain` は通り、`git branch -d <名前>` は `WF204` で止まった（通す向きと閉じる向きの両方を 1 回ずつ踏んだ）。S2 で観測した e11（fail-closed の deny がツールを止めない）は、S3 では**中核を壊さずに済んだため再現の機会が無かった**。ただし S2 と同じく**全件テストが退行を 1 件拾った**（`BC-T01`。置換の印で語を割ったせいで `ch$()mod` の実行体が `ch` に見え、難読化した `chmod` が素通りしていた）。直して負のコントロールを 7 件足した（e18）。

S4（0021）は**中核 c** として拒否側フック 2 本を仕様に揃え、**受け入れ条件 A1-6**（worktree 側のチケットで判定されること）を機械テストで閉じた。`workflow-guard.sh` で変えたのは 2 点だけで、①`WF207` の文面に**どの作業ツリーで数えたか**を入れ（仕様のエラー識別子の表が要求する 3 項目のうち欠けていた 1 つ）、②`worktree.sh` の**置き場を指す引数**（`add` の位置引数 3 番目・`remove` の 2 番目）を提供コマンドの引数判定の例外にした。**`workflow-state-guard.sh` は変更 0 行** — 仕様「対象パスの畳み込み」は S2（0019）の `hook_rel_path` と `__sg_rel` の `WF309` 分岐で既に満たされていた（0018 レポートの R6 の予告どおり）。テストは `WG-T19`（本流 0 枚・worktree 1 枚を**テスト自身が assert**してから判定を呼ぶ）・`WG-T20`（本流 1 枚・worktree 0 枚で無出力・終了 0。`cwd`=本流 の正のコントロール付き）・`WG-T21`・`SG-T12`・`SG-T13` を新設し、`test_workflow_guard.sh` 217 件・`test_workflow_state_guard.sh` 109 件が PASS。**全件テストも 27 本 / 221 ID が 1 回で全通し**で、S2・S3 と 2 チケット続いた「担当テストが通っても全件が退行を拾う」現象は起きなかった。

S4 の学びは 2 つ。①**`SG-T12` / `SG-T13` は書いた時点で通ってしまった**ので、期待値を 3 か所だけ誤値に差し替えて **3 件だけが FAIL する**ことを確かめてから戻す（反転検査）ことで識別力を測った（e21）。②実機のフックに直接ペイロードを流し、0018 レポートの **R13**（`scope.sh` の規則 5 の `--output=` が呼び手側で `WF205` になること）を閉じた（e22）。起動プロンプトが観測を期待していた e11（fail-closed の deny がツールを止めない）は、**中核を壊す状況が発生しなかったため観測できていない**。

- ◎良 17 件 / △注意 4 件（e4・e10・e18・e21）/ ✕問題 1 件（e11）（節は e1〜e22 の 22 件。HTML ビューの章 ID は `f1`〜`f22` で 1 対 1）
- 機械テスト: S1 は `HK-T01` / `HK-T02` PASS。S2 は `HK-T06` / `HK-T21` / `HK-T22` PASS に加え、**全フックのテスト 17 本 128 ID が PASS / FAIL 0 / 重複 ID なし**。S3 は `HK-T05` / `HK-T12` / `HK-T15` / `HK-T02` PASS（テスト先行で 59 件の FAIL を確認してから実装）に加え、**リポジトリの全テスト 27 本 216 ID が PASS / FAIL 0 / 重複 ID なし**。S4 は `WG-T19` / `WG-T20` / `WG-T21` / `WG-T14` / `SG-T12` / `SG-T13` PASS に加え、**リポジトリの全テスト 27 本 221 ID が 1 回で PASS / FAIL 0**（新設 5 ID の分だけ増えた）
- eval: **S1〜S4 とも対象は 0 件**（設定ファイルとシェルスクリプトのみで、機械検証できない指示文のアセットを作っていない）。このフェーズでは eval を**実行しない**
- 仕様からの逸脱: 14 件（D1〜D14。D6・D7 が S2 分、D8〜D12 が S3 分、D13・D14 が S4 分）

### ◆特に見てほしい（0018 分）

- **`common.confirm` のパスをサブエージェント実行者が書けない運用をこのまま続けてよいか**（D3・D4）。S1 は呼び出し元のメインエージェントが `scope-limits.json` の 1 行だけを代行して抜けたが、同じ問題は S10（0027 / `.claude/settings.json`）でも起きる。計画書は 0027 の実行者を最初からメインエージェントに置いているので実害は無い見込みだが、「サブエージェントに委ねたチケットの一部を呼び出し元が代行する」形自体の是非は人間に判断してほしい

### ◇判断が欲しい（0018 分）

- **`workflow-diff-check` の `WF601` が、宣言済みの `common.confirm` パスを許可範囲外として報告する件（D4）**。差分検査が「宣言（`allow.write`）」ではなく「`scope_classify` の分類が `allow` か」で判定しているために起きる。S2 以降も `.claude/hooks/config/**` に触れるたびに同じ通知が出続けるので、AI が「巻き戻すべき差分」と誤読して成果を消す事故が起こり得る。**このフェーズでは直さず**（`scope.sh` / `workflow-diff-check` の判定を変える話で S3・S5 の範囲を越える）、フィードバック計画（0028）へ渡す案で進めてよいか
- **`.gitignore` を `allow` に足したままにするか**。S1 の目的（`.claude/worktrees/` を無視して `push.sh` 項目 1 が落ちないようにする）は 1 度きりの編集で達成される。以後の実装チケットが `.gitignore` を書く必要は無いので、恒久的に `allow` へ残すか S9 で外すかは選べる。**残す側に倒した**（`.gitattributes` と同じ扱いにしておくほうが、以後 AI アセットフェーズが無視設定を足すたびに設定変更から始めずに済む）

### ◆特に見てほしい（0019 分）

- **fail-closed の deny がツールを止めなかった件（e11 / D7 とは別）**。`hook-common.sh` に未定義関数の呼び出しがある状態で、`workflow-guard` / `workflow-state-guard` の両方が `WF209` / `WF309` を `decisions.jsonl` に記録したのに、`Edit` は 2 回とも成功した。**中核の変更でロックアウトしない**という点では都合がよいが、裏を返せば「中核が壊れたときに機構が止めてくれる」という実装計画書のロックアウト対策の前提が成り立っていない。原因を特定できていないので、S3 以降の中核チケットの進め方（1 つ変えるごとにテスト、を守り続けるか）も含めて判断してほしい
- **`hook_rel_path` の 4 段化で判定対象が広がったこと自体の副作用**。これまで「自ツリーの外」として無視されていたパスが `shared` / `other` として判定に入る。S2 では退行が 1 件（`SG-T11`）出て直したが、`workflow-guard` 側で同じ性質の見落としが無いかは `WG-T19`〜`WG-T21` / `SG-T12` / `SG-T13`（S4）を待たないと確定しない

### ◇判断が欲しい（0019 分）

- **呼び手 3 本の「判定できない」分岐に、S2 では専用の機械テストを足していない**。計画書は `SG-T13`（`WF309`）を S4、`WF605` を S5 に割り付けており、S2 の「依存するテスト」は既存の 3 本が**通り続けること**だけを求めている。この配分のままでよいか（S2 で先に足すべきだったか）を確認したい。現状は既存 IDs（`WG-T10` の `WF209`・`SG-T06`/`SG-T07` の `WF309`・`DC-T01`〜`DC-T07`）が通ることで退行のみを見ている
- **`workflow-state-guard` の実在検査の根を直したこと（e9 後半）が S2 の範囲を越えていないか**。仕様の `SG-T12` が要求する振る舞い（他ツリーの `10_doing/` の既存チケットの更新は通す）を満たすための修正だが、テストは S4 で入る。範囲外なら S4 へ戻す
- **`__hc_roots_n`（正規化済みの根のキャッシュ）を入れたこと**。仕様が要求したものではなく、§1 のホットパスの費用を下げるための実装判断である。`HOOK_WORKTREE` を `__hc_resolve_worktree` の外で代入するとキャッシュが古くなるという制約が増えた（コメントに明記）。残すか外すか

### ◆特に見てほしい（0020 分）

- **`cmdpos.sh` の段の並び順が「置換の中が先、外側が後」になったこと**（e13）。`sed -n "$(grep …)" f.sh` は `grep` → `cut` → `sed` の順に `CP_*` へ積まれる。仕様 §7-9 は段の**順序を定めていない**ので逸脱ではないが、呼び手が「段 0 が主コマンド」と暗黙に仮定していると振る舞いが変わる。呼び手 4 本（`workflow-guard` / `workflow-state-guard` / `block-direct-git` / `block-chmod`）はいずれも `for (( i = 0; i < CP_COUNT; i++ ))` で全段を見る作りで、全フックのテストも通っているが、仕様に順序の記述が無いままでよいか（§7-9 に「順序は定めない」と書くか、並び順を書くか）を判断してほしい
- **規則 6（`-c` / `--config-env`）を「サブコマンドより前の位置」に限定したこと**（D11）。仕様は「`-c` / `--config-env` があればサブコマンドが何であれ `unknown`」と読めるが、そのまま実装すると `git log -c`（combined diff の読み取り）まで `unknown` に落ちる。**グローバルオプションの位置に限る**判定にしたので、`git branch -c old new`（ブランチのコピー）は規則 6 ではなく**規則 2** が閉じている（結果は同じ `unknown`）。この読み替えでよいか

### ◇判断が欲しい（0020 分）

- **内部マーカを 2 バイト増やしたこと**（D8）。§7-1 の表は内部プレースホルダを 3 つ（`\x01` / `\x02` / `\x03`）と定めているが、「段の区切りを括弧の文字ではなく置換の開始と終了の対応で決める」には、素の括弧（サブシェル）と置換の括弧を区別する印が要る。`\x05`（開始）/ `\x06`（終了）を足し、**出力には現れない**（段を組み立てるときに消費する）ようにしたうえで、入力に生のマーカが混じっていたら先に `_` へ潰す負のコントロールを 2 件足した。表に 2 行足す形で設計反映してよいか
- **`git reflog HEAD` が `unknown` に落ちること**（D9）。仕様の規則 4 は「`show` と `exists` だけ `read`」なので、サブコマンドを省いて ref を直接渡す読み取り形（`git reflog HEAD`）は閉じる側に落ちる。安全側なので**仕様の文言どおりに実装した**が、実運用で困るなら規則 4 に「位置引数が ref だけのときも `show` とみなす」を足す判断が要る
- **`git branch` の束ねた短オプション（`-dr`）まで閉じたこと**（D10）。仕様は `-d` `-D` … を列挙する形だが、`git branch -dr origin/topic` は実際に削除する形で、列挙の完全一致だけでは素通りする。単一ダッシュの語は 1 文字ずつ `dDmMcCfu` に照合する実装にした（`-a` `-v` `-vv` `-r` は通る）。強めた側なので確認してほしい

### ◆特に見てほしい（0021 分）

- **`worktree.sh` の置き場を指す引数を判定の例外にしたこと**（e19 ②・D14）。統制に穴を開ける変更なので、範囲の切り方を見てほしい。例外は**引数の位置**（`add` の 3 番目、`remove` の 2 番目）に閉じており、①名前の位置に外のパスを書けば従来どおり `WF209`、②同じ行の他の提供コマンドの引数は従来どおり判定、③`worktree.sh` 以外の提供コマンドに同じ外のパスを渡せば `WF209` — の 3 つを負のコントロールとして機械テストと実機の両方で踏んだ。それでも「置き場が妥当かの検査を `worktree.sh` 自身（`WT002`）に丸投げしている」構造は残る。`worktree.sh` は S6（0023）で作るので、**検査が実際に入るまでこの例外は無検査の穴である**
- **`WG-T19` / `WG-T20` が「疑似の作業ツリー」に対する検査であること**（R16）。`git worktree add` は機構が `WF204` で拒み、起動プロンプトも禁じているので、足場は `.git` ファイルと `<本流>/.git/worktrees/<名前>/gitdir` の相互参照で作った。フックが見る材料はこの 2 つだけ（`__hc_is_worktree_of`）なので判定としては同じものを踏んでいるはずだが、**A1-6 を「実物の worktree で確かめた」と言い切れるのは S10（0027）の実測の後**である。この状態で A1-6 を閉じたとみなしてよいかを判断してほしい

### ◇判断が欲しい（0021 分）

- **S4 の実体が「テストを足すだけ」になったこと**（e21）。計画書は S4 を「拒否側フック 2 本を仕様に合わせる」チケットとしていたが、`workflow-state-guard.sh` は S2（0019）の畳み込みで既に仕様どおりで**変更 0 行**、`workflow-guard.sh` も 2 か所だけだった。0018 レポートの R6 が予告していた配分どおりなので範囲は動かしていないが、「S2 が S4 の分まで実装していた」ことを設計反映で計画側に戻すかどうかは判断が要る
- **通ってしまうテストの扱い**（e21 後半）。`SG-T12` / `SG-T13` は書いた時点で通ったので、テスト先行の「失敗を見る」が踏めない。**期待値を 3 か所だけ誤値に差し替えて 3 件だけが FAIL することを確かめてから戻す**（反転検査）という手順で代えた。戻し切ったことは `git diff HEAD` が空であることで確かめている。この代替手順を今後の「先に通ってしまうテスト」の標準にしてよいか
- **`WG-T19` に「本流 1 枚・worktree 1 枚」のケースを足したこと**（D13）。仕様 `WG-T19` の括弧は「合計 2 枚」と書いているが、前半が指定する枚数（0 枚 + 1 枚）とは足し算が合わない。括弧の意図（合計 2 枚でも `WF207` が出ない）を確かめるためにケースを 1 つ足したが、仕様の枚数を変えたわけではない。この読み方でよいか

### ・細かいレビューは不要（ほぼ確実）

- `.gitignore` の追記 2 行（コメント 1 行 + `.claude/worktrees/`）の文言と置き場所（末尾）
- 実装計画書 S1 の記述 `WF205` は `WF201` の誤記（D5）。同じ計画書の別の 2 か所（許可範囲の節・DoD）は `WF201` と書いており、実測も `WF201` の経路
- `hook_worktrees` が stale な登録を集合に残すこと（仕様がそう定めている。緩まない理由もコメントに書いた）
- `hook_rel_path` の互換の取り方（`REPLY` を stdout にも出し続ける）。既存の呼び手 3 本はいずれも `>/dev/null` して `REPLY` を読む形で、変更していない
- `test_workflow_guard.sh` が 120 秒に収まらないこと（S2 の変更で始まった話ではなく、9/4 の全通しでも 124 秒。全通しは `--timeout 300` で行う）

## 確かめられなかったこと

| 対象 | 確かめられなかった理由 | 引き取り先 |
|---|---|---|
| `.gitignore` に `.claude/worktrees/` を足した効果（`push.sh` 項目 1 が落ちないこと） | `push.sh` は S1 の `allow.ops` に無く（`remote-write:push` 不許可）、そもそも実際に `.claude/worktrees/` が作られる状況（サブエージェント隔離）が S10 の実測まで発生しない | S10（0027）の実測 / 切れ目の `push` |
| `scope-limits.json` の編集がサブエージェント実行者でも通る条件 | 判定順 (4) の `WF203`（ask）はヘッドレスで deny になるため、実行者からは 1 度も成功させられなかった（代行で回避） | フィードバック計画（0028） |
| `HK-T02` が `.gitignore` の追加そのものを検査しているか | `HK-T02` は「3 つのキー集合の照合と `commands.build-test` の振る舞い」を見るテストで、`types[*].allow` の中身の網羅は見ない。追加の妥当性はテストではなく仕様書 §8 との突き合わせで確かめた（D1） | S9（0026）の全体検査 |
| 呼び手 3 本の「判定できない」分岐が**実際の worktree 環境で**期待どおり出ること（0019） | 機械テストは偽のルート（`.git` ファイルと `.git/worktrees/<名前>/gitdir` の相互参照）で作った構成に対する検査で、`git worktree add` は使えない（`WF204`）。実物の worktree での挙動は S10（0027）の実測まで確かめられない | `SG-T13` / `DC-T08` / `DC-T09`（S4・S5）と S10 の実測 |
| e11（fail-closed の deny がツールを止めない）の原因（0019） | 再現させるには中核を意図的に壊す必要があり、そのたびにロックアウトの危険を負う。1 度目の観測記録（`decisions.jsonl` の 4 行）だけを根拠として残し、追試はしていない | フィードバック計画（0028） |
| `shellcheck` による静的検査（0019） | この環境に `shellcheck` が入っていない（`command not found`）。`bash -n` は変更した 4 本すべてで通した | 環境整備 / S9（0026） |
| 閉じる側の 6 件を**実機のフックで**踏んだのは `git branch -d` の 1 件だけ（0020） | `git worktree add` / `git checkout -b` / `git switch` は起動プロンプトが実行を禁じており、`git reflog expire` / `git symbolic-ref <name> <ref>` / `git -c …` は実行すると実害が出る（参照や設定を壊す）。分類そのものは `HK-T15` の 60 対で機械的に踏んでいる | S10（0027）の実測 |
| 規則 5（`--output=<file>`）が呼び手側で実際に `WF205` を出すこと（0020） | `scope.sh` は分類と `SC_TARGETS` までを担い、`WF205` を決めるのは `workflow-guard` 側（S4 / 0021）。`git diff --output=…` を実際に走らせて確かめてはいない（走らせれば実際にファイルが書かれる） | S4（0021）の `WG-T*` |
| 段の並び順（置換の中が先）に呼び手が依存していないこと（0020） | 呼び手 4 本（`workflow-guard` / `workflow-state-guard` / `block-direct-git` / `block-chmod`）が `for (( i = 0; i < CP_COUNT; i++ ))` で**全段を見る**作りであることは `grep` で確認した。ただし「段 0 を主コマンドとみなす」ような暗黙の仮定が本文の別の箇所に無いかまでは読み切っていない | 敵対的レビュー / S4（0021） |
| e11（fail-closed の deny がツールを止めない）の追試（0020） | S3 は中核を 1 つずつ変えて毎回テストを通したので、機構が壊れた状態を作らずに済んだ。壊して追試することはロックアウトの危険を負うので行わなかった | フィードバック計画（0028） |
| **実物の `git worktree` で切った作業ツリー**での `WG-T19` / `WG-T20` / `SG-T12` / `SG-T13` の再現（0021） | `git worktree add` は起動プロンプトが実行を禁じ、機構も `WF204` で拒否する。テストは `.git` ファイルと `<本流>/.git/worktrees/<名前>/gitdir` の相互参照で作った足場に対する検査で、フックが見る材料は同じだが、実物の git が作る構成（`.git/worktrees/<名前>/` の他のファイル・`commondir`・`locked`）までは踏んでいない | S10（0027）の実測 |
| e11（fail-closed の deny がツールを止めない）の追試（0021） | 起動プロンプトが「観測したら原因を追って記録すること」を求めていたが、**中核を壊す状況が発生しなかった**（`workflow-guard.sh` の変更は 2 か所で、どちらも `bash -n` → 担当テスト → `commit.sh` の順で通った）。壊して追試することはロックアウトの危険を負うので行っていない | フィードバック計画（0028） |
| `WF207` の新しい文面が**実物のフックで**出ること（0021） | 実物で出すには 1 つの作業ツリーに作業中チケットを 2 枚作る必要があり、`ticket.sh start` が `TK002` で拒む（＝機構を壊さないと作れない状態）。機械テスト `WG-T08` で「番号の一覧」と「どの作業ツリーで数えたか」の両方を assert して代えた | S10（0027）の実測 / 切れ目のレビュー |
| `worktree.sh` の置き場引数の例外が**実際に `worktree.sh` を動かして**役に立つこと（0021） | `worktree.sh` は S6（0023）で新設する。S4 の時点ではコマンドの実体が無いので、フックが引数の形をどう見るかだけを確かめた（実物のフックへのペイロードでも allow を確認 = e22） | S6（0023）の `WT-T01`〜`WT-T12` と `WG-T21` の踏み直し |

## 実施条件（測った対象・環境）

- 基準点: `9c2e4d7`（チケット 0018 の `base_sha`）。着手コミット `6dcaabc`
- ブランチ: `feature-50-worktree-parallel-tickets`
- 実行コマンド: `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*config_integrity*'` / 同 `--ids` / `jq -e . .claude/hooks/config/scope-limits.json`
- `jq` 1.6

0019（S2）分:

- 基準点: `9059a0f`（チケット 0019 の `base_sha`）。着手コミット `ea6d047`
- 実行コマンド: `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*test_hook_common*'` / 同 `--filter '*hooks*' --timeout 300 --ids` / 各テストの直接実行（`bash .claude/hooks/.../tests/test_*.sh`）/ `bash -n <変更した 4 本>`
- `shellcheck` はこの環境に無い（`command not found`）

0020（S3）分:

- 基準点: `6a12e35`（チケット 0020 の `base_sha`）。着手コミット `209d075`
- 対象: `.claude/hooks/lib/cmdpos.sh`（429 行 → 498 行）と `.claude/hooks/lib/scope.sh`（419 行 → 473 行）。どちらも**全フックが読む共通ライブラリ**
- 実行コマンド: `run-tests.sh --filter '*test_cmdpos*' --timeout 300` / 同 `--filter '*test_scope*' --timeout 300` / 同 `--filter '*config_integrity*' --timeout 300` / 同（全件）`--timeout 300` / `bash -n`（変更した 2 本）/ 実機のフックを通した `git worktree list`・`git branch -a`・`git status --porcelain`・`git branch -d no-such-branch-xyz`
- 編集は計画書のロックアウト対策どおり **Edit ツールだけ**で行い（`sed -i` などを介さない）、変更のたびに `bash -n` → 該当テスト → 実機のコマンドの順で確かめた。復旧用に `git show 6a12e35:<パス>` の内容を `wip/tmp/0020/` に退避した（**使わずに済んだ**）
- bash 5.2.12。`shellcheck` はこの環境に無い

0021（S4）分:

- 基準点: `e348c12`（チケット 0021 の `base_sha`）。着手コミット `ebc6a05`
- 対象: `.claude/hooks/20-PreToolUse/workflow-guard.sh`（454 行 → 469 行）と、そのテスト `test_workflow_guard.sh`（494 行 → 620 行）・`test_workflow_state_guard.sh`（231 行 → 297 行）。`workflow-state-guard.sh` は**変更なし**
- 実行コマンド: `run-tests.sh --filter '*test_workflow_guard*' --timeout 300` / 同 `--filter '*test_workflow_state_guard*'` / 全件 `--timeout 300` / `bash -n`（変更した 3 本）/ `commit.sh` 1 回 / 実物のフックへの直接ペイロード 4 件（e22）
- 編集は **Edit ツールだけ**で行った。復旧は `git checkout` を使わず `git show e348c12:<パス>` → Write の手順を用意したが、**使わずに済んだ**
- `shellcheck` はこの環境に無い

## 実施した内容と結果

### e1. `scope-limits.json` の `ai-asset-implementation` の `allow` に `.gitignore` を足した ◎良

`.claude/hooks/config/scope-limits.json` の `types["ai-asset-implementation"].allow` の末尾（`".gitattributes"` の後ろ）に `".gitignore"` を 1 要素だけ足した。差分は 1 行の置換（`git diff 9c2e4d7 -- .claude/hooks/config/scope-limits.json` が `2 +-` = 1 行削除 1 行追加）。

形は `.gitattributes` と同じで、**`common.protected`（`[".claude/**", ".gitignore", "apl/*/.gitignore", ".gitattributes"]`）に居るパスを型の `allow` に明示することで判定順 (2) を抜ける**（フック共通仕様 §8「上限設定」）。`.gitignore` は `common.confirm` には入っていないので、明示だけで stage 5 の allow に落ちる。

構文の確認は編集直後に `jq -e . .claude/hooks/config/scope-limits.json`（終了コード 0）。`scope-limits.json` が壊れると `WF210` で全書き込みが止まるため、計画書のロックアウト対策どおり編集は 1 回にまとめた。

**この編集は実行者（サブエージェント）ではなく呼び出し元のメインエージェントが代行した**。理由は e4 と D3 を参照。

### e2. `.gitignore` に `.claude/worktrees/` を足した ◎良

`.gitignore` の末尾に次の 2 行を足した（設計計画書 結論方針 P10 後半 / 設計結果 残課題 R55、実装計画書 変更対象 #2）。

```
# Claude Code のサブエージェント隔離が作る作業ツリーの置き場。ローカル限りで追跡しない（設計計画書 結論方針 P10）
.claude/worktrees/
```

`worktree.sh` の既定の置き場はリポジトリの外なので、この行が効くのは **Claude Code のサブエージェント隔離（`isolation: "worktree"`）や `--worktree` 起動のような外部の仕組みが `.claude/worktrees/` を作る場合だけ**である。実装計画書の保留 P4 のとおり「足しても失うものが無い」ので足す側に倒してある。

### e3. 変えた判定を実際に踏み、機構が自分を止めないことを確かめた ◎良

計画書のロックアウト対策 S1 が要求する 2 点をどちらも踏んだ。

1. **`HK-T02` が `scope-limits.json` を実際に読んで `scope_classify` を走らせる**: `run-tests.sh --filter '*config_integrity*'` が `PASS / exit 0 / passed=95 failures=0`。`--ids` での内訳は `PASS ID: HK-T01 HK-T02 HK-T09` / `FAIL ID:`（空）/ 重複 ID なし
2. **`scope-limits.json` を直した後の `.gitignore` への `Edit` が `WF201` にならず allow（判定 stage 5）で記録された**: `logs/hooks/decisions.jsonl` の該当行（時刻 `2026-09-05T19:15:34+09:00`）

```
{"ts":"2026-09-05T19:15:34+09:00", ... ,"hook":"workflow-guard","event":"PreToolUse","decision":"allow","id":"","tool":"Edit","target":".gitignore","ticket":"0018-ai-asset-implementation.md","note":"判定 5 / 種類 ai-asset-implementation"}
```

`note` の `判定 5` が判定順 (5)（型の `allow` に一致）を指す。`.gitignore` は `common.protected` に居るので、S1 の①が無ければ判定順 (2) で `WF201` になる経路である。**変えた判定をそのまま踏んで allow に抜けた**ことがこの 1 行で確かめられる。

加えて、中核の設定を変えた直後に自分の道具が生きていることを 2 経路で確認した。

| 確認 | 実行 | 結果 |
|---|---|---|
| ツールでの書き込み | `Write` で `wip/tmp/0018-selfcheck.txt` を作成 | 成功（拒否なし） |
| 提供コマンド | `bash .claude/skills/20-common-step-ticket/scripts/ticket.sh next` | `{"current":"0018","next":null,"type":"ai-asset-implementation","skill":"10-task-ai-asset-implementation-exec"}` |

### e4. `common.confirm` の壁と `WF601` の見え方のずれが、計画書の想定どおり（一部は想定外に）出た △注意

`.claude/hooks/config/**` は `common.confirm` なので、判定順 (4) が `WF203`（ask）を返し、**宣言の有無に関わらず (5) に落ちない**。サブエージェント実行者は確認に答えられないため deny になり、e1 の編集は成立しなかった。計画書の保留 P5 が予告していた事象で、対処も保留 P5 が書いたとおり（迂回せず呼び出し元のメインエージェントが 1 ファイルの編集だけを代行）にした（D3）。

想定外だったのは**その後**である。チケットの `allow.write` に `.claude/hooks/config/**` が入っているにもかかわらず、`workflow-diff-check`（PostToolUse）は以後すべてのツール呼び出しで次を報告し続けた（D4）。

```
WF601: 作業中チケット 0018-ai-asset-implementation.md（種類: ai-asset-implementation）の許可範囲外に差分がある。基準点は 9c2e4d7。
- .claude/hooks/config/scope-limits.json（変更 / WF203）
```

差分検査が「チケットが宣言したか」ではなく「`scope_classify` の分類が `allow` か」で見ているために起きる。識別子が `WF203` と併記されているので**宣言違反ではない**と読めるが、文面は「巻き戻せ」と指示している。実装フェーズの残り（S2〜S10）は `.claude/hooks/**` をほぼ毎チケットで触るため、この通知は出続ける。**指示に従って巻き戻すと計画の成果が消える**ので、判断の分かれ目としてここに残す。

### e5. 作業ツリーの三分を入れ、共有ルートを `HOOK_ROOT` に固定した（0019 / S2 ①）◎良

`hook-common.sh` に `HOOK_SHARED_ROOT` と `HOOK_WORKTREE_STATE` を足し、フック共通仕様 §2 の 3 つの根（置き場 `HOOK_ROOT` / 判定対象の作業ツリー `HOOK_WORKTREE` / 共有ルート `HOOK_SHARED_ROOT`）を別々の変数で持つようにした。

`HOOK_SHARED_ROOT` は**上書きの口を作らない**。`${HOOK_SHARED_ROOT:-...}` の形にせず、宣言時と `__hc_resolve_worktree` の冒頭の 2 か所で無条件に `HOOK_ROOT` を代入し直す。環境変数で先に置かれていても勝たない。仕様の理由（進行状態の置き場を外から動かせると `workflow-state-guard` の保護対象そのものを外せる）をコメントに残した。`HK-T21` は入力を流す前に `HOOK_SHARED_ROOT=$TMP_REPO/evil-shared` を置き、読み込み後に `HOOK_ROOT` に戻っていることを assert する（負のコントロール）。

### e6. 同一リポジトリの作業ツリーの集合 `hook_worktrees` を `git` なしで作った（0019 / S2 ②）◎良

`<HOOK_ROOT>/.git/worktrees/*/gitdir` を glob で列挙し、各ファイルを組み込みの `$(<file)` で読み、`/.git` を落として集合 `__HC_WT_SET` に入れる。`git` は 1 度も呼ばない（§1 のホットパスの fork 上限）。集合は入力 1 件のあいだキャッシュし、`__hc_resolve_worktree` が入力ごとに捨てる。

- **stale な登録も残す**（指し先が実在しなくても集合に入れる）。この集合は「保護してよい範囲」を広げるためだけに使い、`HOOK_WORKTREE` の決定には使わないので、余分に含めても判定は緩まない
- `.git/worktrees` が**在るのに列挙できない**（ディレクトリでない・読めない・辿れない）ときだけ `unreadable` にして戻り 1。**存在しない（worktree が 1 つも無い）のは正常**で、集合は `HOOK_ROOT` の 1 件になる。`HK-T22` はこの 2 つを別々の assert に分けている

### e7. `hook_rel_path` を 4 段の畳み込みにし、「判定できない」を戻り値で返すようにした（0019 / S2 ③）◎良

畳み込みは仕様 §2 の順で、結果は「どのツリーの、ルート相対のどのパスか」の対で返す。呼び手は `REPLY`（ルート相対パス）・`REPLY_ROOT`（そのツリーのルート）・`REPLY_KIND`・戻り値の 4 つを読む。

| 段 | 条件 | `REPLY_KIND` | 戻り |
|---|---|---|---|
| 1 | `HOOK_WORKTREE` の配下 | `worktree` | 0 |
| 2 | 共有ルートの配下 | `shared` | 0 |
| 3 | 作業ツリーの集合のいずれかの配下 | `other` | 0 |
| 4 | どれの配下でもない（同一リポジトリの外と確定） | `outside` | 1 |
| — | 作業ツリーを確定できない / 正規化に失敗 / 集合を読めない | `unknown` | **2** |

比較の前に `__hc_winpath` で `.` / `..` を畳み、`\` と `/` の差と大文字小文字を吸収する。相対パスは自ツリー基準で絶対に直してから畳む。互換のため `REPLY` を stdout にも出す（既存の呼び手は `>/dev/null` して `REPLY` を読む形のまま動く）。

### e8. `logs/` の置き場を §5 の根の列に合わせ、`decisions.jsonl` に `cwd` と `agent_id` を足した（0019 / S2 ④）◎良

| 記録 | 根 | 実装 |
|---|---|---|
| 判定記録 `logs/hooks/decisions.jsonl` | ツリー | `hook_record` が `$HOOK_WORKTREE/logs/hooks/` へ |
| 実行ログ `logs/sh/` | ツリー | `__hc_relog` が作業ツリー確定後に `LOGGER_DIR` / `LOGGER_FILE` だけを貼り替える（`LOGGER_ROOT` は動かさない — 置き場を探すのに使われるため） |
| 進行状態（`review-state` / `merge-state`） | 共有 | `hook_read_state` が `$HOOK_SHARED_ROOT/logs/` から読む |
| ロック `logs/locks/` | 共有 | `hc_lock` / `hc_unlock` / `__hc_unlock_all`（ロックはブランチ単位の資源なので、ツリーごとに分けると排他が成立しない） |
| セッション状態 `logs/sessions/<id>/` | 共有 | `hook_session_dir`（宣言・承認は issue と MR に属する。ツリーごとに分けると worktree の中で宣言が無い扱いになる） |

`decisions.jsonl` の 1 行に `agent_id`（サブエージェント内のツール呼び出しにだけ付く。メインでは空文字）と `cwd`（判定時の作業ツリー）を足した。**このチケットの実作業でも実際に出ている**（下の e11 の記録は `"agent_id":"a20098422793dfc22","cwd":"c:/Users/.../issue-mr-ticket-workflow"` を含む）。

### e9. 呼び手 3 本を「判定できない」の規約どおりに分岐させた（0019 / S2 ⑤）◎良

`hook_rel_path` は書く側と読む側が往復する値なので、呼び手の分岐を同じチケットで閉じた。

| 呼び手 | 側 | 判定できないとき | 実装 |
|---|---|---|---|
| `workflow-guard` | 拒否 | **deny `WF209`** | `__wg_rel` が戻り 2 を受けて `hook_deny WF209`。4 段目（同一リポジトリの外）は従来どおり絶対パスのまま返るので、既存の「作業ツリーの外」の検査が拾う（文面を「同一リポジトリのどの作業ツリーの外」に直した） |
| `workflow-state-guard` | 拒否 | **deny `WF309`** | `__sg_rel` が戻り 2 を受けて `hook_deny WF309`。外と**確定**した場合はここに来ず、従来どおり許可（保護対象はリポジトリの中にしか無い） |
| `workflow-diff-check` | 案内 | **`WF605` を additionalContext** | 制御方式 0 として `HOOK_WORKTREE_STATE != ok` で `hook_notify PostToolUse WF605` して抜ける。承認の記憶の走査で個別のパスが畳めなかった場合も `__dc_unknown` を立てて `WF605` を 1 段落足す（黙って飛ばさない） |

あわせて `workflow-state-guard` の**実在検査の根**を直した。`10_doing/` への新規作成だけを `WF302` にする判定は `[[ ! -e "$HOOK_WORKTREE/$p" ]]` で見ていたが、他の作業ツリーへ畳まれたパス（`REPLY_KIND=other`）では自ツリーに同名が無いだけで**既存チケットの更新まで拒否**になる。畳んだ根（`REPLY_ROOT`）から見るように変えた。

### e10. 退行 1 件（`SG-T11`）を全フックのテストで検出して直した／ホットパスの費用を測った △注意

`--filter '*hooks*'` の全通しで `SG-T11` が 1 件落ちた: **`rm -rf .` が `WF302` ではなく `WF309`** になっていた。原因は `hook_rel_path` が「正規化の結果が空」を一律に「判定できない」に倒していたこと。`.` / `./` / `./.` は `__hc_winpath` の結果が空文字になるが、これは**自ツリーのルートを指す正当な入力**である。入力そのものが空のときだけ 2 を返し、点だけの相対パスは `.` として相対解決へ回すように直し、`HK-T22` に 3 つの assert（`.` / `./` / `./.` → `0|worktree|.`）を足して固定した。**置き場ごと消す形を拾えなくなる退行**だったので、負のコントロールの価値がそのまま出た形になる。

ホットパスの費用も測った。`hook_rel_path` は書き込み対象の数だけ呼ばれるので、根の正規化を毎回やり直すのは無駄である。`__hc_roots_n` を入れて正規化済みの根（`__HC_ROOT_N` / `__HC_WT_N`）を入力ごとに 1 回だけ作るようにした。一時計測（測定後に削除）で 1 回あたり **1.5〜2.2 ms**（2000 回で 3.0〜4.4 秒。Windows の Git Bash）で、1 回のフック起動あたり数回の呼び出しなら §1 の 1 秒の目安には影響しない。

なお `test_workflow_guard.sh` は **`run-tests.sh` の既定の 120 秒に収まらない**（今回 149〜207 秒）。これは本チケットの変更で始まったことではなく、9/4 の全通し（`--timeout 300`）でも 124 秒かかっていた。同じ日の他のテスト（変更していない `test_block_chmod` 等）も 1.6〜1.8 倍に伸びていたので、機械の負荷（並行セッション）の影響が大きい。**全フックの確認は `--timeout 300` で行った**（9/4 の全通しと同じ条件）。

### e11. 中核を壊した瞬間、fail-closed の deny が記録されたのに**ツールは止まらなかった** ✕問題

`__hc_roots_n` を「呼ぶ側」だけ先に入れ、定義を入れる前に 2 回 `Edit` した瞬間（`hook-common.sh` に未定義関数の呼び出しがある状態）、`decisions.jsonl` に次の 2 組が残った。

```
20:50:48 workflow-state-guard deny WF309 機構の不調 — フックの内部エラー（hook-common.sh:867）...
20:50:48 workflow-guard       deny WF209 機構の不調 — フックの内部エラー（hook-common.sh:867）...
20:51:01 （同じ 2 行）
```

`hook_fail` → `hook_deny` の経路（`__hc_on_err` の ERR トラップ）が正しく発火し、拒否側 2 本が deny を**記録**している。ところが**対応する `Edit` は 2 回とも成功し、ツールは止まらなかった**（ファイルには両方の編集が入っており、直後の `bash -n` も通った）。つまり fail-closed の deny が実際の遮断につながっていない。

- 事実として言えるのはここまでで、**原因は特定できていない**（`__wg_rel` の呼び出しはコマンド置換の中ではないので、「サブシェルで `exit 0` した」という説明は当たらない。拒否側 2 本が同時に deny を出したときの扱い、または登録ラッパーの出力の扱いを疑っている）
- 結果としてロックアウトは起きず、復旧手順（`git show <base_sha>:<パス>` → Write）は使わずに済んだ。ただし**「中核を壊しても機構が自分を止めてくれる」という前提が成り立っていない**ことになるので、実装フェーズの残り（S3〜S10）は今回と同じく**1 つ変えるごとにテストを回す**運用で進める必要がある
- 仕様 §3 は打ち切り（timeout）を「フェイルクローズドの原則の唯一の穴」と書いているが、今回の事象は打ち切りではない。フィードバック計画へ渡す（R8）

### e12. 算術展開 `$(( ))` をダブルクォートの中でも段を割らないようにした（0020 / S3 ①-P-1）◎良

`_cp_normalize_to_reply` の `dq` 状態は、`$` の次が `(` かどうかしか見ておらず、`$((` を**コマンド置換の開始**として扱っていた。そのため `echo "$((n+1))"` は `( ( n+1 ) )` に割れ、`n+1` が実行体の段になっていた（実測: 変更前は `count=2 / seg1: exe=n+1`）。読み取りだけのコマンドが分類外（`WF204`）で落ちる原因である。

`dq` 状態にも `code` 状態と同じ検査（`${rest:1:2}` が `((` なら `_cp_skip_arithmetic_to_reply` で対応する `))` まで読み飛ばす）を入れた。**ダブルクォートの中では語を足さない**のが要点で、クォート全体を表す `_` は `"` を読んだ時点で既に出ているため、ここで `_` を足すと 1 語が 2 語になる。

```
変更前: echo "$((n+1))"          → count=2  seg0: exe=echo / seg1: exe=n+1
変更後: echo "$((n+1))"          → count=1  seg0: exe=echo sub=_ args=[_]
        sed -n "$((s)),$((e))p" f.txt → count=1 seg0: exe=sed args=[-n _ f.txt]
```

### e13. コマンド置換・プロセス置換を「開始と終了の対応」で畳み、閉じ括弧の後ろの語を引数にした（0020 / S3 ①-P-2）◎良

これまで `$( )` / `` ` ` `` / `<( )` / `>( )` はすべて ` ( ` ` ) ` という**区切り文字**に潰されていたので、閉じ括弧の後ろに続く語が新しい段の実行体になっていた（実測: `comm -12 <(sort -u a.txt) b.txt` の `b.txt` が `exe=b.txt` の段、`sed -n "$(…)" path/to/file.sh` の `file.sh` が `exe=file.sh` の段）。仕様 §7-1 の「段の区切りは `(` `)` という文字そのものではなく、置換の**開始と終了の対応**で決める」を実装した。

- 正規化は置換の開始・終了に**専用の内部マーカ**（`\x05` / `\x06`）を置く。素の括弧（サブシェル `( … )`・グループ `{ … }`）は従来どおり ` ( ` ` ) ` のままなので、両者を取り違えない
- `cmdpos_parse` のトークン走査に**外側の段のスタック**（`sstack`）を持たせ、マーカを見たら組み立て途中の段を退避 → 置換の中身を独立した段として出す → 退避した段に戻す。閉じ括弧の後ろの語は戻した段の引数として積まれる（`_cp_pop_outer_segment`）
- 外側が `code` のときだけ 1 語の `_` を足す（ダブルクォートの中は既に `_` があるため足さない）。**実行体の位置に来た `_` は従来どおり `_`** なので `$(which git) push` は `exe=_ / args=[push] / gitlike=1` になり、呼び手は拒否側に倒せる
- 入力に生のマーカが混じっていたら正規化の入口で `_` に潰す（段の偽造を防ぐ負のコントロールを 2 件）
- 閉じない置換（`echo $(git commit`）でも、走査の最後にスタックを畳んで中身の段を落とさない

```
変更後: sed -n "$(grep -n X f | cut -d: -f1),+45p" path/to/file.sh
        → count=3  grep / cut / sed（sed の args=[-n _ path/to/file.sh]）
        comm -12 <(sort -u a.txt) b.txt → count=2  sort / comm（args=[-12 _ b.txt]）
        tee >(cat) out.txt              → count=2  cat / tee（args=[_ out.txt]）
        echo `git commit` x             → count=2  git commit / echo（args=[_ x]）
        echo "$(basename "$(pwd)")" tail.txt → count=3（入れ子でも外側の段は 1 つ）
```

**副作用として段の並び順が変わる**（置換の中の段が先に積まれ、それを含む外側の段が後になる）。仕様 §7-9 は順序を定めていないので逸脱ではないが、レビュー依頼に挙げた。

### e14. `scope.sh` に git の限定適用 6 件を入れた（0020 / S3 ②）◎良

`scope_classify` の `git` の分岐は「サブコマンド名が `_SC_GIT_READ_SUBCMDS` にあるか」だけを見ていたため、`git worktree add`（分類外で拒否＝**通す向きの穴**）と `git branch -d` / `git symbolic-ref <name> <ref>` / `git reflog expire` / `git <read> --output=<file>` / `git -c diff.external=<コマンド> …`（いずれも `read` のまま通る＝**閉じる向きの穴**）が開いていた。仕様 §8 の限定適用 6 件を `_sc_classify_git`（新設）に集約した。

| # | 規則 | 実装 |
|---|---|---|
| 1 | `git worktree` は `list` だけ `read` | サブコマンドの後ろの最初の位置引数が `list` なら `read`、それ以外（`add` / `remove` / `move` / `prune` / `repair` / `lock` / `unlock` / 語を確定できない / 引数なし）は `unknown` |
| 2 | `git branch` は書き込みオプションで `unknown` | `_SC_GIT_BRANCH_WRITE_OPTS`（14 語）の完全一致に加え、`--set-upstream-to=` の等号形と、**束ねた短オプション**を 1 文字ずつ `dDmMcCfu` に照合 |
| 3 | `git symbolic-ref` は位置引数 2 つ以上か `-d` で `unknown` | 位置引数は `cmdpos_operands` で取る（コマンド文字列を再パースしない） |
| 4 | `git reflog` は `show` / `exists`（省略時は `show`）だけ `read` | 位置引数が無ければ `show` とみなす |
| 5 | `--output=<file>` / `--output <file>` は `write` | **`read` に分類された形にだけ**後段で当てる（元々 `unknown` の形を `write` に緩めない）。出力先は `SC_TARGETS` へ（複数なら US 区切り） |
| 6 | グローバルな `-c` / `--config-env` は一律 `unknown` | 設定名を見ない。**サブコマンドより前の位置**に限る（`git log -c` = combined diff や `git branch -c` を巻き込まない）。大文字小文字を畳まないので `git -C <path> status` は `read` のまま |

`config` / `remote` / `merge` / `push` の既存の分岐と `_SC_GIT_READ_SUBCMDS` の既定は同じ関数の中にそのまま移し、**判定の入口を 1 か所に集めた**（`branch` / `symbolic-ref` / `reflog` は白名簿にも載っているので、限定適用が先に効く順序を `case` の並びで保証している）。

### e15. `cd` を分類に足さないことを負のコントロールで固定した（0020 / S3 ③）◎良

DDR `i0050-04` のとおり **`cd` は分類に足していない**（`unknown` → `WF204` のまま）。`read` に足すと `cd <他の場所> && echo x > a.txt` の書き込み先が自分の作業ツリーの相対パスとして判定され、作業ツリーの外への書き込みが通る（`hook_rel_path` は `cd` の効果を追跡しない）。

「足していない」ことは差分では見えないので、`HK-T15` に**負のコントロール 5 件**（`cd /tmp` / `cd wip` / `cd wip && ls` = `unknown read` / `pushd wip` / `popd`）を置いて固定した。今回の作業中にも実際に `cd` を含むコマンドを 2 回 `WF204` で拒否されており（作業ログ「拒否・確認・迂回の記録」）、迂回せずルート相対表記で回した。

### e16. R52 の軽微 2 件を直し、語彙表の重複を検査で固定した（0020 / S3 ④）◎良

- `_SC_READ_ONLY_CMDS` の末尾にあった 2 つ目の `column` を削った（`fold column od` の位置に 1 つ残る）
- `_SC_SHELL_KEYWORDS`（`for done fi esac case select coproc function`）を**全要素ループ**で踏む検査を `HK-T15` に足した（`_SC_READ_ONLY_CMDS` と `_SC_GIT_READ_SUBCMDS` には既にあった）
- あわせて **3 つの語彙表それぞれに「重複を残さない」検査**を足した（`printf | sort | uniq -d` が空であること）。重複は「足したつもりが既にある」ことに気づけず、全要素ループも同じ語を 2 度踏むだけで空回りするため。この検査は変更前に `column` を検出して FAIL した

### e17. 通す向きと閉じる向きを実機のフックで 1 回ずつ踏み、機構が自分を止めないことを確かめた（0020 / S3 ⑤）◎良

`scope.sh` を変えた直後に、**実際のフックを通して**次を 1 回ずつ実行した（テストは偽の設定を読むので、出荷される `scope-limits.json` と登録済みフックで踏み直す意味がある）。

| コマンド | 期待 | 実測 |
|---|---|---|
| `git worktree list` | 規則 1 の**通す側**。変更前は分類外で `WF204` | 通った（本流 1 件を出力） |
| `git branch -a` | 規則 2 の**通す側**（従来どおり `read`） | 通った |
| `git status --porcelain` | 既存の `read` 分類の回帰 | 通った |
| `git branch -d no-such-branch-xyz` | 規則 2 の**閉じる側** | `WF204` で止まった（git は起動していない） |

`cmdpos.sh` を変えた直後も同様に `git status --porcelain` / `git branch -a` が通ることを確かめており、**2 本とも「1 つ変える → `bash -n` → 該当テスト → 実機」の順**を守った。S2 で観測した e11（fail-closed の deny がツールを止めない）は、S3 では機構を壊す状態を作らずに済んだため**再現の機会が無かった**（追試もしていない）。復旧手順（`git show <base_sha>:<パス>` → Write）は使わずに済んだ。

なお、作業中に `bash --version` / `cd` / `perl -i -pe` / `bash -c` がそれぞれ `WF204` / `WF204` / `WF204` / `WF209` で拒否された。いずれも**迂回せず**、別の手段（`echo "$BASH_VERSION"` / ルート相対表記 / Edit ツールの `replace_all` / テストの直接実行）に置き換えた。`bash -c` の `WF209` は e11 と対照的に**実際にツールを止めている**（中核が健全なときの fail-closed は効いている）。

### e18. 全件テストが `BC-T01` の退行を拾った（置換の印で語を割っていた）△注意

`cmdpos.sh` と `scope.sh` の担当テスト（`HK-T05` / `HK-T12` / `HK-T15` / `HK-T02`）がすべて通った後の**全件テスト 1 回目**で、`test_block_chmod.sh` の `BC-T01` が 4 件 FAIL した（`ch$()mod +x a` / `ch$( : )mod +x a` / `ch$(echo)mod +x a` / `ch$()mod` 系）。いずれも **`allow` を返しており、難読化した `chmod` が素通りする**退行である。

- 原因: 置換の印（`\x05` / `\x06`）を**空白付き**で置いていたため、`ch$()mod` が `ch` と `_mod` の 2 語に割れ、実行体が `ch` に見えた。`block-chmod` の制御方式 5 は「実行体を特定できない段」（`$` を含む / 全部 `_` / `_` を含むのに生の文字列に現れない）だけを拒否側に倒すので、`ch` は「特定できた実行体」として通ってしまう
- 変更前は `ch$()mod` が `ch$` と `mod` に割れ、`ch$` が `$` を含むために拒否側へ倒れていた（**たまたま**閉じていた形）
- 直し方: 印を**空白なし**で置き、段の組み立て側で語を連結するようにした（`_cp_split_marker_to_reply` で空白区切りのトークンを印で割り、`cur`（語のバッファ）を `_cp_push_outer_segment` / `_cp_pop_outer_segment` が退避・復元する）。`ch$()mod` は bash と同じく **1 語**になり、実行体は `ch_mod`（`_` を含み生の文字列に現れない）→ 特定できない → 拒否
- 固定: `HK-T05` に 7 件の assert を足した（`ch$()mod` / `ch$( : )mod` / `ch$(echo)mod` / `chmod$()` / ``ch`echo`mod``）。`test_block_chmod.sh` は `passed=93 failures=0` に戻った

**学び**: S2 の `SG-T11` と同じで、**中核の変更は担当テストが全通ししても他のフックのテストが退行を拾う**。計画書の「1 つ変えるごとにテスト」に加えて、**チケットを閉じる前に全件を回す**運用が実際に効いている（2 チケット連続で退行を検出した）。

### e19. 拒否側フック `workflow-guard` を作業ツリーごとの判定に揃えた（0021 / S4 ①）◎良

仕様の概要「宣言範囲の強制は作業ツリーごとに一意に決まる」と制御方式 1・2・5・6 に照らして `workflow-guard.sh` を読み直し、**足りていたのは 2 点だけ**だった。判定に使うチケットを `HOOK_WORKTREE` の `10_doing/` に限る部分（制御方式 1・2 の数え方、`__wg_list` の走査元）と、畳んだ結果の根ごとの扱い（制御方式 5）は **S2（0019）で既に入っていた**ので、S4 で変えたのは次の 2 点である。

1. **`WF207` の文面に「どの作業ツリーで数えたか」を入れた**（仕様のエラー識別子の表が要求する 3 項目のうち、`HOOK_WORKTREE` だけが欠けていた）。枚数は 1 作業ツリーあたりの話なので、どこを 1 枚に戻せばよいかが文面から決まらないと復旧できない。あわせて「他の作業ツリーの作業中チケットは含まない」を明記した
2. **`worktree.sh` の置き場を指す引数を、提供コマンドの引数判定の例外にした**（制御方式 6 の例外）。作業ツリーの既定の置き場は**リポジトリの外**（`../<リポジトリ名>-wt/<名前>`）なので、`__wg_check_provided_args` の判定を当てると必ず `WF209` になり、提供コマンドを設けた意味が消える。例外は**引数の位置**で決めた（`add <名前> [<置き場>]` の位置引数 3 番目、`remove <名前|置き場>` の位置引数 2 番目）。オプションと値を取るオプションは従来どおり読み飛ばしてから数える

例外を「`worktree.sh` の引数すべて」ではなく位置に限ったのは、統制が消える範囲を最小にするためである。仕様も「当てない引数を増やすときは、その引数の妥当性をコマンド自身が検査することを同じ変更で書く」と定めており、置き場の妥当性検査は `worktree.sh` の `WT002`（`20-common-step-worktree` 仕様 `add` 2・3・4）が担う。

### e20. A1-6 を閉じる `WG-T19` / `WG-T20` を「枚数をテスト自身が assert する」形で新設した（0021 / S4 ②）◎良

**このチケットの主目的**。調査（0004 の e48）の実測が空振りした原因は「どの作業ツリーにも作業中チケットが 0 枚で、フックが入口で `exit 0` した」ことだったので、テストは**判定を呼ぶ前に本流と worktree の `10_doing/` の枚数を数えて assert する**形にした（`doing_count()`）。前提が崩れたら判定より先にテストが落ちる。

- 足場（`wt_fixture`）は `.git` ファイルと `<本流>/.git/worktrees/<名前>/gitdir` の**相互参照**で作る。`git worktree add` は起動プロンプトが禁じており、そもそもフックはこの相互参照しか見ない（`__hc_is_worktree_of`）ので、実物と同じ材料で試せる。`HK-T21` / `HK-T22`（0019）と同じ手口
- **`WG-T19`（正）**: 本流 0 枚・worktree 1 枚を assert してから `cwd`=worktree で 3 本流す。worktree 側チケット（`allow.write` = `apl/app/src/api/**`）の宣言内が **allow**、`.claude/settings.json` が **`WF201`**、未記載の `tools/gen.py` が **`WF202`**。さらに**本流にも 1 枚置いた状態**（合計 2 枚）でも同じ結果で、`WF207` は出ない — 数えるのが作業ツリーの中だけであることをここで固定した
- **`WG-T20`（負のコントロール）**: 本流 1 枚・worktree 0 枚を assert してから同じ入力を `cwd`=worktree で流すと**無出力・終了 0**（`raw_at` の生出力と `$?` の両方を assert）。本流側チケットの宣言は一切使われない。**正のコントロール**として同じ入力を `cwd`=本流 で流すと `WF201` / `WF205` になる — 「無音」が判定の不在であって機構の故障でないことを、同じケースの中で示している

同じパス（`apl/app/src/api/a.ts`）が `cwd`=worktree では **allow**、`cwd`=本流（`overall-plan`。宣言は空）では **`WF202`** になることも assert した。判定の材料が「操作が行われた作業ツリーのチケット」であることの直接の証拠になる。

### e21. `WG-T21` / `WG-T14` と `SG-T12` / `SG-T13` — state-guard は**無改修で通り**、テストの識別力を反転検査で確かめた（0021 / S4 ③）△注意

- **`WG-T21`**: `worktree.sh add w1 ../repo-wt/w1` と `remove ../repo-wt/w1` が **allow**。名前の位置に外のパスを書いた `add ../repo-wt/w1` は従来どおり **`WF209`**（例外が位置で決まることの負のコントロール）。同じ行に置いた `commit.sh -m 'chore: x' .claude/settings.json` は **`WF201`**、別の提供コマンドに同じ外のパスを渡した `commit.sh -m 'chore: x' ../repo-wt/w1/a.md` は **`WF209`**（例外が `worktree.sh` に閉じていることの負のコントロール）。`git worktree add` / `remove` は **`WF204`**、`git worktree list` は **allow**、`cd ../repo-wt/w1` は **`WF204`**
- **`WG-T14`**（既存）は変更せずに通り続けた。`WG-T21` の「同じ行」のケースが `WG-T14` の正のコントロールを兼ねる
- **`SG-T12` / `SG-T13` は `workflow-state-guard.sh` を 1 行も変えずに通った**。仕様「対象パスの畳み込み」が要求する 3 通りの扱いは、S2（0019）の `hook_rel_path` と `__sg_rel` の `WF309` 分岐、実在検査を畳んだ根から見る修正（0019 の e9 後半）で既に満たされていた。0018 レポートの R6 が「その振る舞いを固定するテストは `SG-T12`（S4）」と書いていたとおりで、S4 は**テストを足すだけ**で閉じた

テストが最初から通ってしまうと「テスト先行で失敗を見てから実装する」手順が踏めない。そこで**期待値を 3 か所だけ意図的に誤った値に差し替えて実行し、3 件だけが FAIL することを確かめてから元に戻した**（正の側 `WF303` / 負のコントロール `allow` / `WF309` を 1 件ずつ）。これで「assert が実際に走り、フックまで届いていて、正の側と負の側が別々の結果を返している」ことを測定として示せる。反転を戻した後の差分は `git diff HEAD` で空であることも確認した。

### e22. 実機のフックで新しい例外と R13 を踏み、機構が自分を止めないことを確かめた（0021 / S4 ④）◎良

変更直後に `commit.sh` を 1 回通した（制御方式 5・6 の経路。コミット `d00d458`）。止まらなかった。加えて、**動いている実物のフックに直接ペイロードを流して** 4 件を測った（`jq` で入力 JSON を組み、`bash .claude/hooks/20-PreToolUse/workflow-guard.sh` にパイプする形。この呼び方自体が提供コマンドの形なので機構を迂回していない）。

| 入力 | 結果 | 意味 |
|---|---|---|
| `git diff --output=apl/app/x.ts` | `WF205`（対象が文面に出る） | 0018 レポートの **R13 を閉じた**。`scope.sh` の規則 5 が呼び手側で実際に `WF205` になる |
| `git diff --output=wip/tmp/x.diff` | allow（無出力） | 同上の負のコントロール（置き場なら通る） |
| `bash .claude/skills/20-common-step-worktree/scripts/worktree.sh add w1 ../repo-wt/w1` | allow（無出力） | S4 で入れた例外が実物でも効く |
| `bash .claude/skills/20-common-step-commit-push/scripts/commit.sh -m x ../repo-wt/w1/a.md` | `WF209` | 例外が `worktree.sh` に閉じている（実物での負のコントロール） |

## 検証の結果

| 検証 | 結果 |
|---|---|
| `jq -e . .claude/hooks/config/scope-limits.json` | 終了コード 0（構文は壊れていない） |
| `run-tests.sh --filter '*config_integrity*'` | `PASS / exit 0 / passed=95 failures=0`（1 本 / 3 件） |
| 同 `--ids` | `PASS ID: HK-T01 HK-T02 HK-T09` / `FAIL ID:` 空 / 重複 ID なし |
| `.gitignore` の `Edit` が allow / stage 5 | `logs/hooks/decisions.jsonl` に 1 行（`"decision":"allow"` かつ `"note":"判定 5 / 種類 ai-asset-implementation"`）。`WF201` の行は同じ対象に無い |
| 変更が S1 の許可範囲に収まっているか | `git diff 9c2e4d7 --stat` = `scope-limits.json` 1 行 / `.gitignore` 3 行 / チケット 1 枚。いずれも `allow.write`（`wip/**`, `.claude/hooks/config/**`, `.gitignore`）の内側 |
| 中核変更後に自分が動くか | `Write`（`wip/tmp/`）と `ticket.sh next` の 2 経路が成功 |
| S1 が担当する参照更新 | 実装計画書「参照更新一覧」7 行はすべて S9（0026）担当。**S1 の担当は 0 行**（消し込む対象が無い） |
| プレースホルダ | 二重波かっこのテンプレート記法は md・HTML とも 0 件（`check-html.sh` の検査 1 が数えるのはこの記法だけ）。`TODO` / `TBD` は**検査項目の名前として書いた 2 行**（この表と「検査結果」の表）以外に 0 件 |
| frontmatter | このレポートの md に `type` / `title` / `description` / `tags` / `keywords` の 5 キー。S1 は frontmatter を持つアセット（スキル・エージェント・チケット）を作成・変更していないので、他に検査対象なし |

0019（S2）分:

| 検証 | 結果 |
|---|---|
| `bash -n`（変更した 4 本） | `hook-common.sh` / `workflow-guard.sh` / `workflow-state-guard.sh` / `workflow-diff-check.sh` すべて終了コード 0 |
| `run-tests.sh --filter '*test_hook_common*'` | `PASS / exit 0 / passed=238 failures=0`（`HK-T01`〜`HK-T22`） |
| `run-tests.sh --filter '*hooks*' --timeout 300 --ids` | `OK: 17 本 / 128 件`。全 17 本 PASS、`FAIL ID:` 空、重複 ID なし。`HK-T06` / `HK-T21` / `HK-T22` / `SG-T11` を含む |
| 退行の検出と修正 | 既定の 120 秒で回した 1 回目に `SG-T11` が FAIL（`rm -rf .` → `WF309`）。`hook_rel_path` を直し、`HK-T22` に assert を 3 つ足して再実行し PASS |
| 中核変更後に自分が動くか | `Write`（`wip/tmp/0019-lockout-check.txt`）と `Read` が成功。`decisions.jsonl` に `workflow-guard allow / 判定 5 / 種類 ai-asset-implementation` が 1 行 |
| `decisions.jsonl` の新しい列が実運用でも入るか | 上の 1 行が `"agent_id":"a20098422793dfc22"`（サブエージェント）と `"cwd":"c:/Users/.../issue-mr-ticket-workflow"` を持つ |
| `WF605` の誤爆 | `decisions.jsonl` に `"id":"WF605"` は **0 件**（`grep` で確認） |
| 変更が S2 の許可範囲に収まっているか | `git diff 9059a0f --stat` = `.claude/hooks/**` 5 ファイル / `wip/10_tickets/**` 1 枚。いずれも `allow.write`（`wip/**`, `.claude/hooks/**`）の内側。範囲外の差分・未追跡ファイルなし |
| S2 が担当する参照更新 | 実装計画書「参照更新一覧」7 行はすべて S9（0026）担当。**S2 の担当は 0 行** |

0020（S3）分:

| 検証 | 結果 |
|---|---|
| `bash -n`（変更した 2 本 + テスト 2 本） | `cmdpos.sh` / `scope.sh` / `test_cmdpos.sh` / `test_scope.sh` すべて終了コード 0 |
| テスト先行（`HK-T05` / `HK-T12`） | 新しい assert を書いた時点で `passed=304 failures=21`（21 件すべて新しい assert）→ `cmdpos.sh` 変更後 `passed=325 failures=0` |
| テスト先行（`HK-T15`） | 新しい assert を書いた時点で `failures=38`（`column` の重複検査 1 件を含む）→ `scope.sh` 変更後 `passed=399 failures=0` |
| `run-tests.sh --filter '*test_cmdpos*' --timeout 300` | `PASS / exit 0 / passed=325 failures=0`（1 本 / 2 件） |
| `run-tests.sh --filter '*test_scope*' --timeout 300` | `PASS / exit 0 / passed=399 failures=0`（1 本 / 3 件） |
| `run-tests.sh --filter '*config_integrity*' --timeout 300` | `PASS / exit 0 / passed=95 failures=0`（1 本 / 3 件。`classify_real` が出荷される `scope-limits.json` で `scope_classify` を実際に走らせる） |
| 全件テスト（`run-tests.sh --timeout 300 --ids`） | **`OK: 27 本 / 216 件`（全 PASS / `FAIL ID:` 空 / 重複 ID なし）**。1 回目は `BC-T01` が 4 件 FAIL（e18）、修正後の 2 回目で全通し |
| 通す向きの回帰（実機） | `git worktree list` / `git branch -a` / `git status --porcelain` の 3 件が通った |
| 閉じる向き（実機） | `git branch -d no-such-branch-xyz` が `WF204` で止まった |
| `cd` の負のコントロール | `HK-T15` に 5 件（`cd /tmp` / `cd wip` / `cd wip && ls` / `pushd` / `popd` がすべて `unknown`）。作業中も実際に 2 回 `WF204` で拒否された |
| 中核変更後に自分が動くか | `Edit`（`.claude/hooks/**` と `wip/**`）・`Read`・`grep`・`run-tests.sh`（`hook-test`）・`ticket.sh` のいずれも止まらなかった。復旧手順は使わずに済んだ |
| 変更が S3 の許可範囲に収まっているか | `git diff 6a12e35 --stat` = `.claude/hooks/lib/` 4 ファイル（本体 2・テスト 2）/ `wip/10_tickets/**` 1 枚 / `wip/30_reports/**` 2 ファイル。いずれも `allow.write`（`wip/**`, `.claude/hooks/**`）の内側。範囲外の差分なし（`wip/tmp/0020/` の退避 2 本は `.gitignore` 対象で追跡されない） |
| S3 が担当する参照更新 | 実装計画書「参照更新一覧」7 行はすべて S9（0026）担当。**S3 の担当は 0 行** |

0021（S4）分:

| 検証 | 結果 |
|---|---|
| `bash -n`（変更した 3 本） | `workflow-guard.sh` / `test_workflow_guard.sh` / `test_workflow_state_guard.sh` すべて終了コード 0 |
| テスト先行（`WG-T21`） | 新しいケースを書いた時点で `passed=212 failures=4`（`WG-T19` の期待値の誤り 1 件 + `WG-T21` の 3 件）→ 期待値を直し `workflow-guard.sh` を変更して `passed=216 failures=0` |
| テスト先行（`SG-T12` / `SG-T13`） | **書いた時点で `passed=109 failures=0`**（実装は S2 で済んでいた）。識別力の確認として期待値を 3 か所だけ誤値に差し替えると `passed=106 failures=3`（差し替えた 3 件だけが FAIL）→ 戻して `passed=109 failures=0` |
| `run-tests.sh --filter '*test_workflow_guard*' --timeout 300` | `PASS / exit 0 / passed=217 failures=0`（`WG-T01`〜`WG-T21`） |
| `run-tests.sh --filter '*test_workflow_state_guard*'` | `PASS / exit 0 / passed=109 failures=0`（`SG-T01`〜`SG-T13`） |
| 全件テスト（`run-tests.sh --timeout 300`） | **`OK: 27 本 / 221 件`（全 27 本 PASS / 退行 0 件）**。1 回で通った（S2・S3 は 2 回目で全通しだった）。件数が 216 → 221 に増えたのは S4 で新設した 5 ID（`WG-T19` / `WG-T20` / `WG-T21` / `SG-T12` / `SG-T13`）の分 |
| ロックアウト対策（`commit.sh` を 1 回） | 変更直後に `bash .claude/skills/20-common-step-commit-push/scripts/commit.sh` が成功（`OK: 4 ファイルをコミットした（d00d458）`）。制御方式 5・6 の経路で機構は自分を止めなかった |
| 実物のフックで新しい判定を踏む | 4 件（e22 の表）。`git diff --output=apl/app/x.ts` = `WF205` / `git diff --output=wip/tmp/x.diff` = allow / `worktree.sh add w1 ../repo-wt/w1` = allow / `commit.sh -m x ../repo-wt/w1/a.md` = `WF209` |
| `workflow-state-guard.sh` の変更量 | **0 行**（`git diff e348c12 -- .claude/hooks/20-PreToolUse/workflow-state-guard.sh` が空） |
| 変更が S4 の許可範囲に収まっているか | `git diff e348c12 --stat` = `.claude/hooks/20-PreToolUse/` 3 ファイル（本体 1・テスト 2）/ `wip/10_tickets/**` 1 枚（`00_todo` → `10_doing` の移動）/ `wip/30_reports/**` 2 ファイル。いずれも `allow.write`（`wip/**`, `.claude/hooks/**`）の内側。範囲外の差分なし |
| S4 が担当する参照更新 | 実装計画書「参照更新一覧」7 行はすべて S9（0026）担当。**S4 の担当は 0 行** |

## 作成・更新したアセットの一覧（仕様書の節との対応）

| # | アセット | 種別 | 変更 | 仕様書の節 | チケット |
|---|---|---|---|---|---|
| 1 | `.claude/hooks/config/scope-limits.json` | フックの設定 | 更新（1 行） | `10_spec/フック共通仕様.md` §8「上限設定」（`ai-asset-implementation` の行） | 0018 |
| 2 | `.gitignore` | リポジトリ設定 | 更新（2 行追加） | 設計計画書 結論方針 P10 後半 / 設計結果 残課題 R55（仕様書に節は無い） | 0018 |
| 3 | `wip/30_reports/0018-ai-asset-implementation.md` / `.html` | 成果物（レポート） | 新規 | `10_spec/skills/10-task-ai-asset-implementation-exec.md`「OUT ひな形」 | 0018 |
| 4 | `.claude/hooks/lib/hook-common.sh` | フックの共通ライブラリ | 更新 | `10_spec/フック共通仕様.md` §2「作業ツリーの三分」「同一リポジトリの作業ツリーの集合」「作業ツリーをまたぐパスの畳み込み」「判定できないときの倒し方」／§5「記録と状態」の根の列 | 0019 |
| 5 | `.claude/hooks/lib/tests/test_hook_common.sh` | フックのテスト | 更新（`HK-T06` 追記・`HK-T21`・`HK-T22` 新設） | 同 §11 テスト（`HK-T06` / `HK-T21` / `HK-T22`） | 0019 |
| 6 | `.claude/hooks/20-PreToolUse/workflow-guard.sh` | フック | 更新（`__wg_rel` の `WF209` 分岐） | `10_spec/hooks/20-PreToolUse/workflow-guard.md` 制御方式 5（畳み込みの結果ごとの扱い） | 0019 |
| 7 | `.claude/hooks/20-PreToolUse/workflow-state-guard.sh` | フック | 更新（`__sg_rel` の `WF309` 分岐・実在検査の根） | `10_spec/hooks/20-PreToolUse/workflow-state-guard.md`「対象パスの畳み込み」・制御方式 2 | 0019 |
| 8 | `.claude/hooks/22-PostToolUse/workflow-diff-check.sh` | フック | 更新（制御方式 0 の `WF605`・承認の記憶の `WF605`） | `10_spec/hooks/22-PostToolUse/workflow-diff-check.md` 制御方式 0・`WF605` | 0019 |
| 9 | `.claude/hooks/lib/cmdpos.sh` | フックの共通ライブラリ | 更新（内部マーカ 2 種の追加・`dq` の算術展開・置換の開始/終了の対応・`_cp_pop_outer_segment` 新設・`cmdpos_parse` のスタック走査） | `10_spec/フック共通仕様.md` §7-1（正規化）・§7-9（出力の形） | 0020 |
| 10 | `.claude/hooks/lib/tests/test_cmdpos.sh` | フックのテスト | 更新（`case_hk_t05_substitution` 新設。21 assert） | 同 §11 テスト（`HK-T05` / `HK-T12`） | 0020 |
| 11 | `.claude/hooks/lib/scope.sh` | フックの共通ライブラリ | 更新（`_sc_classify_git` 新設・語彙表 3 種の追加・`_SC_READ_ONLY_CMDS` の `column` の重複解消） | `10_spec/フック共通仕様.md` §8「git の分類は『サブコマンド + オプション』で決める（限定適用 6 件）」「`cd` は分類に足さない」 | 0020 |
| 12 | `.claude/hooks/lib/tests/test_scope.sh` | フックのテスト | 更新（`case_hk_t15_git_subcmd_opts` 新設 = 60 対 + 出力先 + 通す向き + `cd` の負のコントロール。`case_classify` に全要素ループ 1 件と重複検査 3 件） | 同 §11 テスト（`HK-T15`） | 0020 |
| 13 | `.claude/hooks/20-PreToolUse/workflow-guard.sh` | フック | 更新（`WF207` の文面に `HOOK_WORKTREE`／`__wg_check_provided_args` に `worktree.sh` の置き場を指す引数の例外） | `10_spec/hooks/20-PreToolUse/workflow-guard.md` 概要（一意性の 2 点）・制御方式 2・制御方式 6 の例外・`WF207` | 0021 |
| 14 | `.claude/hooks/20-PreToolUse/tests/test_workflow_guard.sh` | フックのテスト | 更新（`WG-T19` / `WG-T20` / `WG-T21` を新設。作業ツリーの足場 `wt_fixture` / 枚数を数える `doing_count` / cwd を差し替える `payload_at`・`run_at`・`raw_at` を追加。`WG-T08` に「どの作業ツリーで数えたか」の 1 件） | 同 テスト観点（`WG-T19` / `WG-T20` / `WG-T21` / `WG-T08` / `WG-T14`） | 0021 |
| 15 | `.claude/hooks/20-PreToolUse/tests/test_workflow_state_guard.sh` | フックのテスト | 更新（`SG-T12` / `SG-T13` を新設。作業ツリーの足場 `sg_wt_fixture` と cwd を差し替える `payload_at`・`tfa`・`tca` を追加） | `10_spec/hooks/20-PreToolUse/workflow-state-guard.md` テスト観点（`SG-T12` / `SG-T13`）・「対象パスの畳み込み」 | 0021 |

`.claude/skills/**` / `.claude/rules/**` / `.claude/agents/**` / `.claude/evals/**` / `.claude/settings.json` は S1〜S4 では**1 件も触っていない**。`.claude/hooks/config/**` は S1 のみ（S2〜S4 は触っていない）。**`.claude/hooks/20-PreToolUse/workflow-state-guard.sh` は S4 の対象だったが変更が要らなかった**（e21）ので、この表には本体としての行を置かない（S2 の 7 行目が最後の変更）。

## テスト結果

### 機械テスト

| テスト ID | 対象 | 実行コマンド | 結果 |
|---|---|---|---|
| HK-T01 | `settings.json` の登録表（PreToolUse `Agent` の行が無いことの負のコントロール。S1 では `settings.json` を変えないことの確認として踏む） | `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*config_integrity*'` | **PASS** |
| HK-T02 | `scope-limits.json` の 3 つのキー集合の照合と `commands.build-test` の振る舞い | 同上 | **PASS** |
| HK-T09 | 同じテストファイル（`test_config_integrity.sh`）が持つ 3 件目。S1 の DoD には無いが同時に走る | 同上 | **PASS**（参考） |

- 集計: `1 本 / 3 件`、`passed=95 failures=0`、`FAIL` 0 件、重複 ID なし
- テスト先行（失敗確認 → 実装 → 成功）は**適用していない**。S1 は既存のテスト（`test_config_integrity.sh`）が読む設定値を変えるだけで、新しいテストを足していないため（計画書「依存するテスト」も S1 に新設テストを割り付けていない）

0019（S2）分:

| テスト ID | 対象 | 実行コマンド | 結果 |
|---|---|---|---|
| HK-T21 | 作業ツリーの三分（`cwd`=worktree で `HOOK_WORKTREE`=worktree・`HOOK_ROOT`/`HOOK_SHARED_ROOT`=本流）と `logs/` の根。環境変数での `HOOK_SHARED_ROOT` 上書きが効かないこと（負のコントロール）、作業ツリーが 1 つなら 3 つとも同じ値になること（負のコントロール） | `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*test_hook_common*'` | **PASS**（新設） |
| HK-T22 | `hook_rel_path` の 4 段の畳み込み。`.` / `..` / `\` 区切り / 大文字小文字を畳んでも同じ、外の絶対パスは畳めない（負のコントロール）、集合を読めないときは「判定できない」、集合が空なだけなら「判定できない」にならない（負のコントロール）、点だけの相対パスは自ツリーのルート | 同上 | **PASS**（新設） |
| HK-T06 | `decisions.jsonl` の 1 行が §5 のスキーマ（12 キー）を満たし、`cwd` に判定時の作業ツリー、サブエージェント内では `agent_id` が入る。メインでは空文字（負のコントロール） | 同上 | **PASS**（`agent_id` / `cwd` の検査を追記） |
| SG-T11 | 置き場ごとの削除（`rm -rf .` を含む）。**1 回目は FAIL**（`WF302` を期待して `WF309`）。`hook_rel_path` を直して PASS | `run-tests.sh --filter '*hooks*' --timeout 300` | **PASS**（修正後） |
| 全フック 17 本 / 128 ID | `hook-common.sh` を読み込むフックの全テスト | `run-tests.sh --filter '*hooks*' --timeout 300 --ids` | **全 PASS**（`FAIL ID:` 空 / 重複 ID なし / `OK: 17 本 / 128 件`） |

- テスト先行: `HK-T21` / `HK-T22` は**実装より先に書いて失敗を確認**してから実装した（0019 の前半。作業ログ参照）。`SG-T11` は**既存テストが退行を先に落とした**形で、失敗を見てから直した
- 呼び手 3 本の「判定できない」分岐に対する**新設テストは無い**。計画書が `SG-T13`（`WF309`）を S4、`WF605` を S5 に割り付けており、S2 の「依存するテスト」は既存 3 本が通り続けることだけを求めているため（◇判断が欲しい に挙げた）

0020（S3）分:

| テスト ID | 対象 | 実行コマンド | 結果 |
|---|---|---|---|
| HK-T05 | §7-1 の正規化 2 件を負のコントロール付きで。(a) `echo "$((n+1))"` が 1 段 (b) `sed -n "$(grep -n X f \| cut -d: -f1),+45p" path/to/file.sh` が 3 段で `file.sh` は引数 (c) `comm -12 <(sort -u a.txt) b.txt` が 2 段 (d) `$(which git) push` は実行体 `_` のまま。加えて素の括弧は従来どおり段を割ること・生の内部マーカで段を偽造できないこと・語の途中の置換は語を割らないこと（`ch$()mod`） | `run-tests.sh --filter '*test_cmdpos*' --timeout 300` | **PASS**（`case_hk_t05_substitution` 新設 28 assert。`passed=332 failures=0`） |
| HK-T12 | 提供コマンドの識別はルート相対表記だけ（既存。置換の扱いを変えても退行しないこと） | 同上 | **PASS** |
| HK-T15 | 限定適用 6 件を**閉じる側と通す側の対**で（60 対）。`git worktree list`=read / `git worktree add ../x`=unknown、`git branch -a`=read / `git branch -d x`=unknown ほか。`--output=` の `SC_TARGETS`、`cd`=unknown の負のコントロール 5 件、語彙表の全要素ループと重複検査 | `run-tests.sh --filter '*test_scope*' --timeout 300` | **PASS**（`case_hk_t15_git_subcmd_opts` 新設。`passed=399 failures=0`） |
| HK-T11 / HK-T16 | 同じテストファイルが持つ glob と読み込み系 3 関数の戻り値（S3 の DoD には無いが同時に走る） | 同上 | **PASS**（参考） |
| HK-T02 | 出荷される `scope-limits.json` を読んだうえで `classify_real` が `scope_classify` を実際に走らせる | `run-tests.sh --filter '*config_integrity*' --timeout 300` | **PASS**（`passed=95 failures=0`） |
| BC-T01 | 難読化した `chmod` の拒否（既存）。**全件テスト 1 回目で 4 件 FAIL**（e18） | `run-tests.sh --timeout 300` | **PASS**（修正後 `passed=93 failures=0`） |
| 全件 27 本 / 216 ID | リポジトリの全テスト（フック 17 本 + 提供コマンド 10 本） | `run-tests.sh --timeout 300 --ids` | **全 PASS**（`OK: 27 本 / 216 件` / `FAIL ID:` 空 / 重複 ID なし） |

- 全件テストは **2 回**回した。1 回目（修正前）は `test_block_chmod.sh` のみ FAIL（`BC-T01` 4 件）、2 回目（修正後）は **27 本すべて PASS / 216 ID**。所要は 1 回あたり約 24 分（`test_workflow_guard.sh` が既定 120 秒に収まらないため `--timeout 300` が要る。既知の R9）
- **テスト先行**: `HK-T05` 側は 21 件、`HK-T15` 側は 38 件の FAIL を**実装より先に確認**してから実装した（合計 59 件）。重複検査は変更前に `column` を検出して FAIL し、検査が効くことを確かめてから直した
- 退行対策として `HK-T05` に 7 件の assert を追加（`ch$()mod` 系）。`case_hk_t05_substitution` は最終的に 28 assert

0021（S4）分:

| テスト ID | 対象 | 実行コマンド | 結果 |
|---|---|---|---|
| WG-T19 | **A1-6**。本流 0 枚・worktree 1 枚を**テスト自身が assert**してから `cwd`=worktree で判定を呼ぶ。宣言内 = allow / `.claude/settings.json` = `WF201` / 未記載 = `WF202`。本流にも 1 枚置いた（合計 2 枚の）状態でも同じで `WF207` は出ない。同じパスが `cwd`=本流 では `WF202` | `run-tests.sh --filter '*test_workflow_guard*' --timeout 300` | **PASS**（新設。書いた時点で通り、実装の追加は不要だった） |
| WG-T20 | **WG-T19 の負のコントロール**。本流 1 枚・worktree 0 枚を assert してから同じ入力を `cwd`=worktree で流すと**無出力・終了 0**（生出力と `$?` の両方を assert）。正のコントロールとして `cwd`=本流 では `WF201` / `WF205` | 同上 | **PASS**（新設） |
| WG-T21 | `worktree.sh add w1 ../repo-wt/w1` / `remove ../repo-wt/w1` が allow。名前の位置に外のパスを書いた `add ../repo-wt/w1` は `WF209`（例外が位置で決まる）。同じ行の `commit.sh … .claude/settings.json` は `WF201`、別の提供コマンドに同じ外のパスを渡すと `WF209`。`git worktree add` / `remove` = `WF204` / `git worktree list` = allow / `cd` = `WF204` | 同上 | **PASS**（新設。**3 件の FAIL を先に確認**してから `workflow-guard.sh` を変更） |
| WG-T14 | 提供コマンドの引数パスに書き込みと同じ判定が掛かること（既存）。`WG-T21` の「同じ行」のケースが正のコントロールを兼ねる | 同上 | **PASS**（変更なし） |
| WG-T08 | 2 枚以上の `WF207`（既存）に「どの作業ツリーで数えたか」の assert を 1 件追加 | 同上 | **PASS**（追記） |
| WG-T01〜WG-T18 | 既存の回帰 | 同上 | **全 PASS**（`passed=217 failures=0`） |
| SG-T12 | 他の作業ツリーの保護対象を絶対パスで書く。`cwd`=worktree から本流の `20_done/` = `WF303` / `10_doing/` の新規 = `WF302` / 共有ルートの `logs/mr.json` へのリダイレクト = `WF301`。`.` / `..` を挟んだ形と `\` 区切りでも同じ。**負のコントロール**として同一リポジトリの外の同名ファイルは allow | `run-tests.sh --filter '*test_workflow_state_guard*'` | **PASS**（新設。`workflow-state-guard.sh` は無改修） |
| SG-T13 | `.git/worktrees` を読めない状態にすると、リポジトリ内と確定できない絶対パスへの書き込みが `WF309`。リポジトリ内の相対パスは従来どおり判定できる（全面拒否にならない）。**負のコントロール**として `.git/worktrees` が無いだけなら `WF309` にならない | 同上 | **PASS**（新設。同上） |
| SG-T01〜SG-T11 | 既存の回帰 | 同上 | **全 PASS**（`passed=109 failures=0`） |
| 全件 27 本 / 221 ID | リポジトリの全テスト（フック 17 本 + 提供コマンド 10 本） | `run-tests.sh --timeout 300` | **全 PASS**（`OK: 27 本 / 221 件`。**1 回で通り、他のフックの退行は 0 件**） |

- 全件テストは **1 回**で通った。S2（`SG-T11`）・S3（`BC-T01`）と 2 チケット続いた「担当テストが通っても全件が退行を拾う」現象は S4 では起きていない。所要は約 30 分（`--timeout 300`）
- **テスト先行**: `WG-T21` は 3 件の FAIL を先に確認してから実装した。`WG-T19` / `WG-T20` / `SG-T12` / `SG-T13` は**書いた時点で通った**ので、`SG-T12` / `SG-T13` は反転検査（期待値を 3 か所だけ誤値に差し替え、3 件だけが FAIL することを確認 → 戻す）で識別力を測った（e21）

### eval

| eval ID | 状態 |
|---|---|
| （該当なし） | S1 は設定ファイルのみを変更し、機械検証できない指示文のアセット（スキル・ルール・エージェント）を作成・変更していないので、定義すべき eval は 0 件 |
| （該当なし・0021） | S4 が触ったのはフック 1 本とテスト 2 本（いずれも機械実行できる）。指示文のアセットは 1 件も作成・変更していないので、定義すべき eval は 0 件 |

**このフェーズで eval は実行しない**（`10-task-ai-asset-implementation-exec` の禁止事項。実行は人間の判断）。S5 以降で作るスキル・ルール・エージェントの eval も、定義まで作って実行しない。

## 検査結果

| 検査 | 対象 | 件数 | 判定 |
|---|---|---|---|
| プレースホルダ（二重波かっこのテンプレート記法 / `TODO` / `TBD`） | `wip/30_reports/0018-ai-asset-implementation.md` と `.html` | 0 件（`TODO` / `TBD` は検査項目名として書いた 2 行を除く） | OK |
| frontmatter の必須項目 | 上記 md（`type` / `title` / `description` / `tags` / `keywords`） | 5 / 5 | OK。S1 は frontmatter を持つアセットを作成・変更していない |
| 参照更新一覧の消し込み | 実装計画書の 7 行 | S1 の担当 0 行 | 対象なし（全 7 行が S9 / 0026 担当） |
| HTML ビュー | `wip/30_reports/0018-ai-asset-implementation.html` | `check-html.sh` 7 項目 | OK（作業ログに出力を記録） |
| プレースホルダ（0019） | 変更した 4 本のシェルスクリプトとこのレポート md / HTML | 0 件（テンプレート由来の二重波かっこ・`TODO` / `TBD` とも。`TODO` / `TBD` はこの表と「検証の結果」の項目名を除く） | OK |
| frontmatter（0019） | S2 が触ったアセットに frontmatter を持つものは無い（シェルスクリプト 4 本）。チケット 0019 の frontmatter は変更していない | 対象 0 件 | OK |
| 参照更新一覧の消し込み（0019） | 実装計画書の 7 行 | S2 の担当 0 行 | 対象なし（全 7 行が S9 / 0026 担当） |
| 静的検査（0019） | 変更した 4 本 | `bash -n` 4 / 4 OK、`shellcheck` は環境に無く未実施 | 一部未実施（「確かめられなかったこと」に記載） |
| プレースホルダ（0020） | 変更した 4 本（`cmdpos.sh` / `scope.sh` / テスト 2 本）とこのレポート md / HTML | 0 件（テンプレート由来の二重波かっこ・`TODO` / `TBD` とも。`TODO` / `TBD` はこの表と「検証の結果」の項目名を除く） | OK |
| frontmatter（0020） | S3 が触ったアセットに frontmatter を持つものは無い（シェルスクリプト 4 本）。チケット 0020 の frontmatter は `ticket.sh` が書いた項目以外を変更していない（`executor` / `human_review` は変えていない） | 対象 0 件 | OK |
| 参照更新一覧の消し込み（0020） | 実装計画書の 7 行 | S3 の担当 0 行 | 対象なし（全 7 行が S9 / 0026 担当） |
| 静的検査（0020） | 変更した 4 本 | `bash -n` 4 / 4 OK、`shellcheck` は環境に無く未実施 | 一部未実施（「確かめられなかったこと」に記載） |
| 内部マーカが出力に漏れないこと（0020） | `cmdpos_parse` の出力（`CP_EXE` / `CP_ARGS` / `CP_SUBCMD`） | `HK-T05` の 21 assert に `\x05` / `\x06` を含む期待値は 0 件。生のマーカを入力に混ぜた 2 件も `_` に潰れて段を偽造できない | OK |
| プレースホルダ（0021） | 変更した 3 本（`workflow-guard.sh` / テスト 2 本）とこのレポート md / HTML | 0 件（テンプレート由来の二重波かっこ・`TODO` / `TBD` とも。`TODO` / `TBD` はこの表と「検証の結果」の項目名を除く） | OK |
| frontmatter（0021） | S4 が触ったアセットに frontmatter を持つものは無い（シェルスクリプト 3 本）。チケット 0021 の frontmatter は `ticket.sh` が書いた項目以外を変更していない（`executor` / `human_review` / `adversarial_review` は変えていない） | 対象 0 件 | OK |
| 参照更新一覧の消し込み（0021） | 実装計画書の 7 行 | S4 の担当 0 行 | 対象なし（全 7 行が S9 / 0026 担当） |
| 静的検査（0021） | 変更した 3 本 | `bash -n` 3 / 3 OK、`shellcheck` は環境に無く未実施 | 一部未実施（「確かめられなかったこと」に記載） |
| 反転検査を戻し切ったか（0021） | `test_workflow_state_guard.sh`（識別力の確認で 3 か所の期待値を一時的に誤値へ差し替えた） | `git diff HEAD -- <当該ファイル>` が空。`XX` で始まる仮の期待値は 0 件 | OK |

## 仕様からの逸脱

**設計文書（`.claude/docs/**`）は 1 文字も直していない**（実装フェーズの `deny`）。食い違いはすべてここに記録し、フィードバック計画（0028）→ 設計反映フェーズへ渡す。

| # | 逸脱 | 仕様・計画の記述 | 実装の実態 | 扱い |
|---|---|---|---|---|
| D1 | フック共通仕様 §8 の**初期値の JSON**（`"ai-asset-implementation"` の行）に `.gitignore` が無い | `10_spec/フック共通仕様.md` L306: `"allow": [".claude/skills/**", ..., ".claude/evals/**", ".gitattributes"]` | 実物の `scope-limits.json` は `..., "CLAUDE.md", ".gitattributes", ".gitignore"` | 仕様は直さず記録。設計反映で JSON と表を実物に合わせる |
| D2 | 同 §8 の**初期値の JSON と同節の表が、S1 の変更より前から食い違っている** | L306 の JSON には `CLAUDE.md` が**無い**が、L330 の表には `CLAUDE.md` がある | 実物には `CLAUDE.md` がある（表が正しい） | S1 の変更とは無関係な既存の不整合。D1 と同じ箇所を直すときに一緒に直す |
| D3 | `common.confirm` のパスは、チケットで宣言しても**サブエージェント実行者には書けない** | 実装計画書 保留 P5 が予告（「サブエージェントは確認に答えられないので deny になり得る」） | そのとおり deny。呼び出し元のメインエージェントが `scope-limits.json` の編集を代行した | 迂回せず代行という保留 P5 の運用に従った。運用の是非は切れ目のレビューで人間に確認する |
| D4 | `workflow-diff-check` の `WF601` が、**チケットが宣言済みのパスを「許可範囲外」として報告する** | チケット 0018 の `allow.write` に `.claude/hooks/config/**` がある | `common.confirm` のパスは `scope_classify` が `confirm`（`WF203`）に分類するため `allow` にならず、差分検査が許可範囲外として列挙し続ける | **巻き戻さない**（巻き戻すと S1 の成果が消える）。差分検査が宣言ではなく分類で見ている点の是非をフィードバック計画へ |
| D5 | 実装計画書 S1 の識別子の誤記 | 計画書 L236: 「①が済むまで②は **WF205** で止まる」 | 正しくは `WF201`（`Edit` / `Write` ツールの宣言範囲外）。同じ計画書の L151・L153 と 0018 の DoD は `WF201` と書いている | 計画書の誤記。設計文書ではないが、S9 の全体検査で直すか設計反映へ渡す |
| D6 | `workflow-diff-check` の `WF605` を、仕様の**制御方式 0**（停止中の判定より前）ではなく**制御方式 1 の後**に置いた（0019） | `10_spec/hooks/22-PostToolUse/workflow-diff-check.md` は「0. 作業ツリーの確定 … 決められない → WF605 を伝えて抜ける」を 1 より前に置く | 実装は `hook_enforce_enabled \|\| hook_disabled` の**後**に置いた | 共通仕様 §3「停止中のフックは判定・注入を行わず `disabled` を 1 行残す」と両立させるため。`workflow-state-guard` 仕様は同じ状況に「0 は 1 の後に評価する」と明記しており、そちらに揃えた。仕様は直さず、diff-check 仕様にも同じ注記を足す案を設計反映へ |
| D7 | `hook_read_state`（`review` / `merge` / `approvals` / `entry`）が共通仕様 §1 の**1 回目の jq** ではなく**2 回目**にある（0019 で維持） | §1 の表は `review-state` / `merge-state` を 1 回目に置く | 共有ルートの解決は `cwd`（= stdin）を読む `__hc_resolve_worktree` の後なので、1 回目には渡せない。既存の逸脱コメント（「作業ツリー」基準）を S2 で「共有ルート」基準に読み替えて維持した | S2 で作った逸脱ではなく、三分の導入で理由が変わった逸脱。設計反映で §1 の表を実装に合わせる |
| D8 | 内部プレースホルダを**表の 3 つより 2 つ多く**使っている（0020） | §7-1 の表は `\x01`（複製リダイレクト）/ `\x02`（`&>`）/ `\x03`（データ）の 3 つを「用途を重ねない」と定める | 置換の開始 `\x05` / 終了 `\x06` を足した。段の区切りを「置換の開始と終了の対応」で決めるには、素の括弧と置換の括弧を区別する印が要る。**出力には現れない**（段の組み立てで消費する）し、入力に生のマーカが混じっていたら先に `_` へ潰す | 仕様は直さず記録。表に 2 行足す形で設計反映へ（負のコントロール 2 件で固定済み） |
| D9 | `git reflog <ref>`（サブコマンドを省いて ref を直接渡す読み取り形）が `unknown` に落ちる（0020） | §8 の規則 4: 「`show` と `exists` は `read`、それ以外は `unknown`。サブコマンド省略時は `show` とみなす」 | 位置引数が**無い**ときだけ `show` とみなす実装にした。`git reflog HEAD` は位置引数が `HEAD` なので `unknown` | 仕様の文言どおり（安全側）に倒した。実運用で困るなら規則 4 に「位置引数が ref だけなら `show`」を足す。設計反映の候補 |
| D10 | 規則 2 で**束ねた短オプション**（`git branch -dr x`）まで閉じている（0020） | §8 の規則 2 は `-d` `-D` `--delete` … の**列挙** | 列挙の完全一致に加え、単一ダッシュの語を 1 文字ずつ `dDmMcCfu` に照合する。`-a` `-v` `-vv` `-r` は通る | 列挙の完全一致だけだと `-dr` が `read` で素通りするため強めた。仕様の意図（穴を閉じる）に沿うが、文言は「列挙」なので記録する |
| D11 | 規則 6 を**サブコマンドより前の位置**に限定した（0020） | §8 の規則 6: 「`-c` / `--config-env` があればサブコマンドが何であれ `unknown` に倒す」 | グローバルオプションの位置（サブコマンドの語より前）に現れた `-c` / `--config-env` だけを見る。`git log -c`（combined diff）や `git branch -c old new` は規則 6 では拾わない（後者は**規則 2** が `unknown` にする） | 文字どおり全引数を見ると読み取り形の `git log -c` まで落ちる。規則の見出しが `git -c <name>=<value> …` とグローバル位置を示しているのでそちらに従った。設計反映で「グローバル位置に限る」を明記する案 |
| D12 | 規則 5 を **`read` に分類された形にだけ**当てている（0020） | §8 の規則 5 の見出しは `git <read サブコマンド> --output=<file>` だが、本文は `format-patch` など `read` に分類されない形も例に挙げる | `SC_CLASS` が `read` になった後で `--output` を探し、見つかれば `write` に変える。`git format-patch --output=…` は元々 `unknown` なので `unknown` のまま | `unknown` を `write` に変えると**緩む**（`write` は許可範囲内なら通る）ため、閉じる側に倒した。設計反映で本文の例を見出しに合わせる案 |
| D13 | `WG-T19` の仕様の文面が**それ自身と食い違っている**（0021） | `workflow-guard` 仕様 テスト観点 `WG-T19`: 前半は「本流の `10_doing/` を **0 枚**・worktree の `10_doing/` を **1 枚**にする」、末尾の括弧は「本流に 0 枚・worktree に 1 枚なので**合計 2 枚**だが、数えるのは作業ツリーの中だけ」 | 0 枚 + 1 枚は 1 枚で、「合計 2 枚」にならない。DoD と仕様の前半に従って **0 枚 + 1 枚**を主のケースにし、括弧が言おうとしている振る舞い（合計 2 枚でも `WF207` が出ない）を確かめるために**本流 1 枚・worktree 1 枚のケースを同じ `WG-T19` に足した** | 仕様は直さず記録。テストは仕様が要求する両方を満たす（前半の枚数どおり + 括弧の意図）。設計反映で括弧を「本流にも 1 枚あって合計 2 枚でも」に直す案 |
| D14 | 提供コマンドの引数判定の例外を、仕様が挙げる**引数の意味**ではなく**引数の位置**で実装した（0021） | `workflow-guard` 仕様 制御方式 6: 例外は「`worktree.sh add <名前> [<置き場>]` の**置き場**、`worktree.sh remove <名前\|置き場>` の**位置引数**」 | オプションと値付きオプションを読み飛ばして数えた位置引数のうち、`add` の 3 番目と `remove` の 2 番目だけを例外にする。`add ../repo-wt/w1`（名前の位置に置き場を書いた形）は例外にならず `WF209` | 「置き場を意味する語」をコマンド行から判定する手段がフック側に無い（`worktree.sh` の引数解析を複製することになる）。位置で決めるほうが統制の穴が小さく、負のコントロールも書ける。設計反映で「位置で決める」を仕様に明記する案 |

## 設計への反映

| # | 反映すること | 引き取り先 |
|---|---|---|
| 1 | フック共通仕様 §8 の初期値 JSON と表に `.gitignore`（と JSON 側の `CLAUDE.md`）を反映する（D1・D2） | `10_spec/フック共通仕様.md` / 設計反映フェーズ |
| 2 | `common.confirm` のパスをサブエージェント実行者が扱えない件の恒久的な扱い（型の `allow` で `confirm` を上書きできる形にするか、実行者をメインエージェントに固定するか、代行を正式な運用として書くか）（D3） | フィードバック計画（0028）→ 設計反映 |
| 3 | `workflow-diff-check` が宣言済みの `confirm` パスを許可範囲外として報告する件（D4） | フィードバック計画（0028）→ 設計反映（`workflow-diff-check` 仕様 / `scope.sh`） |
| 4 | 実装計画書 S1 の `WF205` → `WF201` の訂正（D5） | S9（0026）の全体検査 |
| 5 | `workflow-diff-check` 仕様の制御方式 0 に「1（停止中）の後に評価する」注記を足す（D6。`workflow-state-guard` 仕様には既にある） | 設計反映フェーズ |
| 6 | フック共通仕様 §1 の副入力の表（1 回目 / 2 回目）を実装に合わせる（D7） | 設計反映フェーズ |
| 7 | 中核が壊れたときの fail-closed が実際には遮断にならない件（e11）。仕様 §3 は打ち切りだけを「唯一の穴」と書いている | フィードバック計画（0028）→ 設計反映 |
| 8 | フック共通仕様 §7-1 の内部プレースホルダの表に、置換の開始 `\x05` / 終了 `\x06` の 2 行を足す（D8） | 設計反映フェーズ |
| 9 | §8 の規則 4 に「位置引数が ref だけのときも `show` とみなす」を足すか、`git reflog HEAD` を閉じたままにするかを決める（D9） | フィードバック計画（0028）→ 設計反映 |
| 10 | §8 の規則 2 に「束ねた短オプションも同じ扱い」、規則 6 に「グローバルオプションの位置に限る」、規則 5 に「`read` に分類された形にだけ当てる」を明記する（D10・D11・D12） | 設計反映フェーズ |
| 11 | §7-9 に段の並び順（置換の中の段が先、それを含む段が後）を書くか、「順序は定めない」を明記する（e13） | 設計反映フェーズ |
| 12 | `workflow-guard` 仕様 `WG-T19` の括弧「合計 2 枚」を、前半の枚数（本流 0 枚・worktree 1 枚）と矛盾しない書き方に直す（D13） | 設計反映フェーズ |
| 13 | `workflow-guard` 仕様 制御方式 6 の例外を「引数の位置で決める」と明記する（D14）。あわせて `worktree.sh` に位置引数以外の置き場の指定（`--path` 等）を作らないことを `20-common-step-worktree` 仕様に書く | 設計反映フェーズ |

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| S1 の実行者（サブエージェント）が `scope-limits.json` を編集できるかは五分五分（保留 P5） | できなかった（判定順 (4) の `WF203` が ask を返し、ヘッドレスでは deny） | 迂回せず、呼び出し元のメインエージェントが**その 1 ファイルの編集だけ**を代行した。実行者は結果報告に上げる運用（保留 P5 の記述どおり）を守った |
| 宣言に書いたパスは差分検査で許可範囲内として扱われる | `common.confirm` のパスは宣言していても `WF601` で許可範囲外として報告され続ける | 巻き戻さず、D4 として記録した。作業ログの「拒否・確認・迂回の記録」にも同じ判断を残した |
| `.gitignore` を先に編集しようとすると `WF205` で止まる（計画書 L236） | 止まるのは `WF201`（`Edit` ツールの宣言範囲外）。`WF205` は**コマンドによる書き込み**の識別子 | D5 として記録。実測では①→②の順を守ったので、②は最初から allow で通った |
| 中核を変えた直後は何かが止まりうる | `Write`・`ticket.sh next`・`run-tests.sh` のいずれも止まらなかった | ロックアウト対策の復旧手順（`git show <base_sha>:<パス>` → `Write`）は使わずに済んだ |
| （想定外）`mkdir -p wip/tmp` が通る | `WF205` で拒否された。コマンドで書いてよいのは `wip/tmp/**` と `logs/**` で、**ディレクトリ `wip/tmp` そのもの**はパターンに含まれない | ディレクトリは既に存在していたので実害なし。R3 として残す |
| （0019）`hook_rel_path` の 4 段化は「これまで無視していたパスを判定に入れる」変更なので、**通っていた書き込みが落ちる**のが主なリスク（計画書のリスク 1） | 落ちたのは書き込みではなく `rm -rf .`（`WF302` → `WF309`）だった。「範囲が広がる」方向ではなく「判定できないに倒しすぎる」方向の退行 | 既存の `SG-T11` が拾った。`hook_rel_path` を直し、`HK-T22` に負のコントロールを足して固定した（e10） |
| （0019）中核を壊せば機構が自分を止める（＝ロックアウト対策が要る） | `decisions.jsonl` には deny が記録されたが、**ツールは止まらなかった**（e11）。復旧手順（`git show` → Write）は使わずに済んだ | 止まらなかったこと自体を ✕問題として記録し、R8 でフィードバック計画へ渡す。運用は「1 つ変えるごとにテスト」を続ける |
| （0019）`test_workflow_guard.sh` は既定の 120 秒で回る | 149〜207 秒かかり `TIMEOUT`。9/4 の全通しでも 124 秒で、変更していないテストも同日比 1.6〜1.8 倍に伸びていた（機械の負荷） | 全通しは 9/4 と同じ `--timeout 300` で行った。S2 の変更による退行ではないと判断（e10） |
| （0019）`shellcheck` を掛けられる | この環境に入っていない | `bash -n` だけで確認し、「確かめられなかったこと」に残した |
| （0020）`$(which git) push` は変更前から実行体 `_` の段になっている（仕様 §7-1 の「潰れた語が実行体の位置にあるとき」の例） | 変更前は `exe=$` の段（`opaque=1`）と `exe=which` の段と `exe=push` の段の**3 段**に割れていた。`push` が独立した段の実行体になっており、`git` の引数として見えていなかった | 変更後は仕様どおり 2 段（`which git` と `exe=_ / args=[push] / gitlike=1`）。呼び手が「`_` かつ対象語を含む」で拒否側に倒せる形になった |
| （0020）`cmdpos.sh` を変えると `bash` で始まるすべての判定が崩れ、`git show` すら通らなくなり得る（計画書のロックアウト対策） | 崩れなかった。`bash -n` → 該当テスト → 実機の順で 1 つずつ確かめ、退避しておいた基準点の内容（`wip/tmp/0020/`）は使わずに済んだ | 手順は守った（Edit ツールだけで編集し、`git checkout` は使わない前提で退避を先に取った） |
| （0020）`scope.sh` の限定適用は「閉じる向き」が 5 件・「通す向き」が 1 件（計画書 S3） | そのとおりだが、**通す向きの 1 件（`git worktree list`）は変更前に実測していない**（変更後に通ることだけを確かめた）。閉じる向きは実機で 1 件（`git branch -d`）だけ踏んだ | 分類自体は `HK-T15` の 60 対で機械的に踏んでいる。実機で踏めない理由は「確かめられなかったこと」に記載 |
| （0020）担当テスト（`HK-T05` / `HK-T12` / `HK-T15` / `HK-T02`）が全通しすれば中核の変更は安全 | **全件テストが `BC-T01` の退行を 4 件拾った**（`ch$()mod` の実行体が `ch` に見え、難読化した `chmod` が素通りしていた）。S2 の `SG-T11` に続いて 2 チケット連続 | 直して `HK-T05` に負のコントロールを 7 件足した（e18）。「チケットを閉じる前に全件を回す」運用を続ける |
| （0020）置換を 1 語の `_` に潰すとき、印を空白で区切っても差し支えない | `ch$()mod` のように**語の途中**に置換がある形で語が割れ、bash が 1 語として実行するものを 2 語として解析していた | 印を空白なしで置き、段の組み立て側で語を連結する形に直した。`cmdpos` は「bash が 1 語とみなすものは 1 語」を守る必要がある |
| （0020）語彙表の全要素ループは 3 つの表すべてに既にある | `_SC_SHELL_KEYWORDS` だけ無かった（R52 の指摘どおり）。加えて `column` の重複も残っていた | 全要素ループ 1 件と重複検査 3 件を足した。重複検査は変更前に `column` を検出して FAIL した（検査が効くことを確かめてから直した） |
| （0021）S4 は拒否側フック **2 本**を仕様に合わせて書き換えるチケット（計画書 S4 ①②） | 変えたのは `workflow-guard.sh` の **2 か所だけ**で、`workflow-state-guard.sh` は**変更 0 行**だった。仕様「対象パスの畳み込み」は S2（0019）の `hook_rel_path` と `__sg_rel` の `WF309` 分岐・実在検査の根の修正で既に満たされていた | S4 は「テストを足して固定する」チケットになった。0018 レポートの R6 が予告していたとおりで、範囲は動かしていない（e21） |
| （0021）テスト先行（失敗確認 → 実装 → 成功）が全テストで踏める | `WG-T21` は 3 件の FAIL を確認してから実装できたが、**`WG-T19` / `WG-T20` / `SG-T12` / `SG-T13` は書いた時点で通った**（実装が S2 で済んでいたため） | 「通ってしまうテスト」を信用しないために、`SG-T12` / `SG-T13` は期待値を 3 か所だけ誤値に差し替えて **3 件だけが FAIL する**ことを確かめてから戻した。`WG-T19` / `WG-T20` は正のコントロールと負のコントロールが同じケースの中で別の結果を返すことをもって代えた（e21） |
| （0021）`WG-T19` の「本流側のチケットは判定に使われない」は `WF201` で示せる | 本流に置いた `overall-plan` チケットは宣言が空なので、`apl/app/src/api/a.ts` は保護範囲ではなく**未記載**（`WF202`）に落ちた | 期待値を `WF202` に直した。同じパスが `cwd`=worktree で allow・`cwd`=本流 で `WF202` になる対比のほうが「材料が別のチケットである」ことを直接示せる |
| （0021）中核（拒否側フック）を触るので、e11（fail-closed の deny がツールを止めない）を観測できる見込みが高い（起動プロンプト） | **観測の機会が無かった**。変更が 2 か所と小さく、`bash -n` → 担当テスト → `commit.sh` の順で 1 つずつ確かめたので、機構が壊れた状態を作らずに済んだ | 追試のために意図的に壊すことはしていない（ロックアウトの危険）。R8 のままフィードバック計画へ |

## 残課題

| # | 残課題 | 引き取り先 |
|---|---|---|
| R1 | `.gitignore` の `.claude/worktrees/` が実際に効くこと（`push.sh` 項目 1 が落ちないこと）の確認 | S10（0027）の実測 / 切れ目の `push` |
| R2 | `.gitignore` を `ai-asset-implementation` の `allow` に**恒久的に残すか**の判断（S1 の目的は 1 度きりの編集で達成済み） | 切れ目のレビュー / S9（0026） |
| R3 | コマンドによる書き込みの許可パターンが `wip/tmp/**` で、ディレクトリ `wip/tmp` 自身の作成（`mkdir`）を通さない | フィードバック計画（0028） |
| R4 | このレポートは 0019〜0027 が節を積み上げる器である。各チケットは md 側 `e5, e6, …` / HTML 側 `f5, f6, …` と連番を続け、サマリの件数・逸脱・残課題を**その都度更新**する（累積の数は「サマリ」1 か所にだけ置く） | 0019〜0027 |
| R5 | 呼び手 3 本の「判定できない」分岐に専用の機械テストが無い（`SG-T13` は S4、`WF605` は S5 の割り付け）。S2 は既存テストの非退行だけで確かめている | S4（0021）/ S5（0022） |
| R6 | `workflow-state-guard` の実在検査を畳んだ根から見るように直した（e9 後半）が、その振る舞いを固定するテストは `SG-T12`（S4）である | S4（0021） |
| R7 | `__hc_roots_n`（正規化済みの根のキャッシュ）は仕様に無い実装判断。`HOOK_WORKTREE` を `__hc_resolve_worktree` の外で代入するとキャッシュが古くなる制約が増えた | 切れ目のレビュー / 設計反映 |
| R8 | 中核が壊れたとき、fail-closed の deny が `decisions.jsonl` に残るのに**ツールが止まらない**（e11）。原因未特定 | フィードバック計画（0028） |
| R9 | `test_workflow_guard.sh` が `run-tests.sh` の既定 120 秒に収まらない（9/4 時点で 124 秒）。全通しに `--timeout 300` が要る | S9（0026）/ フィードバック計画（0028） |
| R10 | `shellcheck` がこの環境に無く、シェルスクリプトの静的検査が `bash -n` だけになっている | 環境整備 / S9（0026） |
| R11 | `git reflog HEAD`（ref 直渡し）が `unknown` に落ちる（D9）。読み取りだけの形が閉じる側にある | フィードバック計画（0028）→ 設計反映 |
| R12 | 段の並び順が「置換の中の段が先」になった（e13）。呼び手 4 本が全段をループする作りであることは確認したが、仕様 §7-9 が順序を定めていないので、将来の呼び手が「段 0 が主コマンド」と仮定しうる | 敵対的レビュー / 設計反映（§7-9 に順序の有無を明記） |
| R13 | 規則 5（`--output=<file>`）が呼び手側で `WF205` を出すことは未確認（`scope.sh` は分類と `SC_TARGETS` まで） | S4（0021）の `WG-T*` |
| R14 | 閉じる向きの 6 件のうち、実機のフックで踏めたのは `git branch -d` の 1 件だけ（他は実行すると実害が出るか、起動プロンプトが禁じている） | S10（0027）の実測 |
| R15 | **0021 で閉じた残課題**: R5 の前半（`workflow-state-guard` の「判定できない」= `SG-T13`）・R6（畳んだ根からの実在検査を固定するテスト = `SG-T12`）・R13（規則 5 が呼び手側で `WF205` になること = e22 で実測）。R5 の後半（`workflow-diff-check` の `WF605` = `DC-T08` / `DC-T09`）は S5（0022）に残る | 閉じた（記録のみ） |
| R16 | `WG-T19` / `WG-T20` / `SG-T12` / `SG-T13` は**足場を相互参照で作った疑似の作業ツリー**に対する検査で、`git worktree add` が作る実物の構成では踏んでいない（`git worktree add` は `WF204`・起動プロンプトも禁止） | S10（0027）の実測 |
| R17 | `worktree.sh` の置き場を指す引数の例外は**引数の位置**で決めている（D14）。`worktree.sh` に位置引数以外の置き場の指定（`--path <置き場>` のようなオプション）を後から足すと、その値には判定が当たってしまう（`WF209`）。`worktree.sh` の CLI を変えるときはこの例外も一緒に見る | S6（0023）の `worktree.sh` 新設 / 設計反映 |
| R18 | `WF207` の新しい文面（どの作業ツリーで数えたか）は機械テストでしか踏めていない。実物で 2 枚の状態を作るには `ticket.sh start` の `TK002` を越える必要がある | S10（0027）の実測 / 切れ目のレビュー |
