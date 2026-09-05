---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0029"]
executor: opus
human_review: {required: false, reason: "全体計画書の方針（差分 3）"}
adversarial_review: {required: true, reason: "全体計画書の方針（差分 3: フェーズごとに 1 回）"}
allow:
  write: ["wip/**", ".claude/hooks/config/**", ".gitignore"]
  ops: ["read", "remote-read", "build-test", "hook-test"]
started_at: "2026-09-05T17:49:40+09:00"
completed_at: ""
base_sha: "9c2e4d7"
---

# 0018 S1 設定・定義: scope-limits.json と .gitignore、実装結果レポートの起こし

## 目的

実装フェーズの許可範囲を通す設定を先に整え（.gitignore を ai-asset-implementation の allow へ）、.claude/worktrees/ を gitignore して push.sh 項目 1 が落ちない状態にし、以降のチケットが積み上げる実装結果レポートを起こす。

## DoD

- [x] .claude/hooks/config/scope-limits.json の types["ai-asset-implementation"].allow に .gitignore が入っている（フック共通仕様 §8「上限設定」の .gitattributes と同じ「common.protected を明示で通す」形）（根拠: git diff 9c2e4d7 -- .claude/hooks/config/scope-limits.json = 1 行の置換で末尾に ".gitignore" が入る。".gitattributes" の直後に置いた。レポート e1）
- [x] .gitignore に .claude/worktrees/ の行がある（設計計画書 結論方針 P10 後半 / 残課題 R55）（根拠: git diff 9c2e4d7 -- .gitignore = 3 行追加（空行 + コメント 1 行 + .claude/worktrees/）。レポート e2）
- [x] 機械テスト HK-T01 と HK-T02 が通る（bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*config_integrity*'）（根拠: PASS / exit 0 / passed=95 failures=0、--ids で PASS ID: HK-T01 HK-T02 HK-T09 / FAIL ID 空 / 重複 ID なし。レポート e3・「テスト結果」）
- [x] jq -e . .claude/hooks/config/scope-limits.json が成功する（構文が壊れていない）（根拠: 終了コード 0。編集の直後に実行。レポート e1）
- [x] scope-limits.json を直した後の .gitignore への Edit が WF201 にならず allow（判定 stage 5）で記録されている（logs/hooks/decisions.jsonl の該当行。変えた判定＝判定順 (2) を types allow で抜ける経路を実際に踏む。ロックアウト対策）（根拠: logs/hooks/decisions.jsonl の ts=2026-09-05T19:15:34+09:00 の行。"decision":"allow" / "tool":"Edit" / "target":".gitignore" / "note":"判定 5 / 種類 ai-asset-implementation"。同じ対象に WF201 の行は無い。レポート e3）
- [x] 実装結果レポート（wip/30_reports/0018-ai-asset-implementation.md と同名 HTML）があり check-html.sh が通っている（根拠: 両ファイルを作成。check-html.sh wip/30_reports/0018-ai-asset-implementation.html = 「OK: 検査 7 項目すべて通過（id 23 件 / リンク 16 件を確認。テンプレート: report）」。md と HTML の突き合わせも実施（e<N> 4 件 = h3 id 4 件 / h2 12 = section 12 / D 行 5 = 5 / R 行 4 = 4））
- [x] 仕様と食い違った点は仕様を直さずレポートの「仕様からの逸脱」に記録されている（フック共通仕様 §8 の初期値の表に .gitignore の行が無い件を含む）（根拠: レポート「仕様からの逸脱」に D1〜D5 の 5 件。D1 が §8 初期値 JSON に .gitignore が無い件、D2 が同 JSON に CLAUDE.md が無い既存の不整合、D3 が common.confirm でサブエージェントが書けない件、D4 が WF601 が宣言済みパスを許可範囲外と報告する件、D5 が計画書の WF205 誤記。.claude/docs/ は 1 文字も編集していない）

## 作業内容

- scope-limits.json → .gitignore の順で編集する（前者が済むまで後者は WF201 で止まる）
- .claude/hooks/config/** は common.confirm なので、宣言していても書き込みのたびに判定順 (4) の WF203（ask）が入る。ヘッドレスでは deny になり得るので、編集は 1 回にまとめる。拒否されたら迂回せず、識別子と現在地を作業ログに残して結果報告に上げる（呼び出し元＝メインエージェントが編集する）
- 復旧は git checkout を使わない（checkout は分類が unknown で WF204）。git show <base_sha>:<パス> で内容を取り、Write ツールで書き戻す
- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md の S1 と「ロックアウト対策」の S1 行に従う

## 作業ログ

### 現在地

- 0018 に着手（基準点 9c2e4d7）。計画書 S1・フック共通仕様 §8・現行の scope-limits.json / .gitignore を確認済み
- scope-limits.json の編集で判定順 (4) の WF203（ask）に落ち、サブエージェント実行者では書けなかった。計画書の保留 P5 のとおり呼び出し元（メインエージェント）が①②を代行
- 実行者側で残りを実施: HK-T01 / HK-T02 の実行 → jq -e . の確認 → 「自分が止まらないこと」の 2 経路確認 → decisions.jsonl から allow / 判定 5 の行を採取 → 実装結果レポート md + HTML の作成と check-html.sh 通過 → DoD の根拠付け
- **完了**: DoD 7 行すべて根拠付きでチェック。commit.sh でコミットし ticket.sh complete 0018 を実行。次は 0019（S2）だが、このチケットでは着手しない

### うまくいったこと

- ①scope-limits.json → ②.gitignore の順を守ったので、②は最初から allow（判定 stage 5）で通った。ロックアウト対策が求める「変えた判定を実際に踏む」確認が、余計な操作なしに 1 回の Edit で取れた
- 編集を 1 回にまとめ、直後に `jq -e .` を打つ手順（計画書のロックアウト対策）が効いた。WF210（形式不正で全書き込み停止）には一度も落ちていない
- 中核の設定を変えた直後の動作確認を 2 経路（Write ツール / 提供コマンド `ticket.sh next`）でやったので、「ツールは通るがコマンドが死んでいる」型の壊れ方も同時に潰せた
- レポートを 0018〜0027 の器として起こすとき、md 側 `e<N>` / HTML 側 `f<N>` という既存の慣行（0012 のレポートを実測）に合わせた。数の突き合わせ（h3 id 4 = e<N> 4、section 12 = h2 12、D 行 5 = 5、R 行 4 = 4）で md と HTML の同期を確認した

### うまくいかなかったこと

- サブエージェント実行者から `.claude/hooks/config/scope-limits.json` を編集できなかった（WF203 の ask に答えられず deny）。迂回はせず、呼び出し元に代行してもらった
- `mkdir -p wip/tmp` が WF205 で拒否された。コマンドで書いてよいのは `wip/tmp/**` と `logs/**` で、ディレクトリ `wip/tmp` そのものはパターンに含まれない（既に存在していたので実害なし）
- `bash --version` が WF204（分類 unknown）で拒否された。実施条件に記録する環境情報を 1 つ取り損ねた（jq のバージョンは取れた）

### 仕様からの逸脱

レポート「仕様からの逸脱」の D1〜D5 が正。要約すると次の 5 件。**`.claude/docs/` は 1 文字も編集していない**。

- D1: フック共通仕様 §8 の初期値 JSON（L306）の `ai-asset-implementation` の allow に `.gitignore` が無い。実物には足した
- D2: 同 §8 の初期値 JSON（L306）と表（L330）が S1 の変更以前から食い違っている（JSON にだけ `CLAUDE.md` が無い。実物と表が正しい）
- D3: `common.confirm` のパスは、チケットで宣言してもサブエージェント実行者には書けない（判定順 (4) の WF203 が (5) より優先。計画書の保留 P5 が予告済み）
- D4: `workflow-diff-check` の WF601 が、チケットの `allow.write` に宣言済みの `.claude/hooks/config/scope-limits.json` を「許可範囲外」として報告し続ける。差分検査が宣言ではなく `scope_classify` の分類（`confirm`）で見ているため。**巻き戻さない**（巻き戻すと S1 の成果が消える）
- D5: 実装計画書 L236 の「②は WF205 で止まる」は WF201 の誤記（同計画書 L151・L153 と DoD は WF201）

### 判断と根拠

- **WF601 に従って巻き戻さないと決めた**。根拠: (1) チケットの `allow.write` に `.claude/hooks/config/**` が入っているので宣言違反ではない、(2) 併記された識別子が WF203（確認）であって WF201（宣言範囲外）ではない、(3) 計画（0029）が「毎回確認が入る」経路として織り込んでいる、(4) 巻き戻すと S1 の成果が消え DoD 1 を満たせなくなる。判断が誤っている可能性を残すため D4 としてレポートに記録し、レビュー依頼の「見てほしい点」に上げた
- **`.gitignore` を allow に残す側に倒した**。根拠: `.gitattributes` と同じ扱いに揃えると、以後の AI アセットフェーズが無視設定を足すたびに設定変更から始めずに済む。外す判断もありうるので R2 として残した
- **`.gitignore` への Edit を自分の手でやり直さなかった**。根拠: DoD 5 が求めるのは decisions.jsonl に allow / 判定 5 の行があることで、それは既にある（19:15:34 の行）。同じ内容の再編集は差分を生まないうえ、無意味な書き込みで判定記録を汚す
- **テスト先行（失敗確認 → 実装 → 成功）を適用しなかった**。根拠: S1 は新しいテストを足さず、既存の `test_config_integrity.sh` が読む設定値を変えるだけである。計画書「依存するテスト」も S1 に新設テストを割り付けていない。レポートの「テスト結果」に理由を明記した
- **レポートの章 ID を md `e<N>` / HTML `f<N>` に分けた**。根拠: テンプレート（`report.template.md` は `e1`、`report.template.html` は `f1`）と先行レポート 0012 の実測がこの形だった。サマリに 1 対 1 である旨を 1 行添えた

### 拒否・確認・迂回の記録

| 識別子 | 操作 | どう扱ったか |
|---|---|---|
| WF203（ask → deny） | `.claude/hooks/config/scope-limits.json` の編集 | 迂回せず、計画書の保留 P5 のとおり呼び出し元（メインエージェント）が代行。D3 として記録 |
| WF601 | 全ツール呼び出しの PostToolUse（`scope-limits.json` を許可範囲外と報告） | **巻き戻さない**と判断（上の「判断と根拠」）。D4 として記録 |
| WF205 | `mkdir -p wip/tmp` | 迂回せず中止。ディレクトリは既にあったので実害なし。R3 として残した |
| WF204 | `bash --version`（分類 unknown） | 迂回せず中止。環境情報は jq のバージョンだけを記録した |

迂回・強制無効化（`WORKFLOW_ENTRY_ENFORCE=0` など）は 1 度も使っていない。`git checkout` も使っていない（復旧が必要な場面が起きなかった）。

### 使った AI アセットと効き目

- `10-task-ai-asset-implementation-exec`（このタスクの手順）: 「中核は小さく変えて都度確かめる」「eval は定義まで」「仕様は直さず逸脱に記録」の 3 点が、そのまま今回の判断の分かれ目に効いた
- `20-common-step-report-view`: テンプレートの必須節と `check-html.sh` で HTML が 1 回で通った。手順 5（md と HTML の数の突き合わせ）が無ければ、md 側 `e<N>` / HTML 側 `f<N>` の使い分けに気づかず不統一のまま出していた
- `20-common-step-shell-script` の `run-tests.sh --ids`: PASS した ID を明示できたので、DoD の「HK-T01 と HK-T02 が通る」に個別 ID の根拠を書けた
- `20-common-step-ticket` の `ticket.sh next`: 中核変更後の提供コマンドの生存確認にそのまま使えた（副作用が無いサブコマンドなので確認用に向く）

### スコープ外で見つけたこと

- コマンドによる書き込みの許可パターンが `wip/tmp/**` なので、ディレクトリ `wip/tmp` 自身を `mkdir` で作れない。`wip/tmp` が無いクローン直後に、コマンドで一時ファイルの置き場を作る手段が無い（Write ツールなら親ディレクトリごと作れるので詰みはしない）。R3
- `test_config_integrity.sh` は `HK-T09` も持っている（S1 の DoD には無いが同じフィルタで走る）。S9 の全件実行までこの ID を意識する場面が無いので、レポートに参考として残した

### AI アセットに反映すべき内容

- **`workflow-diff-check` の WF601 の文面**（D4）: 宣言済みだが `confirm` に分類されるパスは、「許可範囲外」ではなく「確認が要るパスに差分がある（宣言済みなら巻き戻し不要）」と読める文面にしたい。現状の「復旧: git checkout …」は、宣言どおりに作業した AI に成果の破棄を促す
- **`common.confirm` とサブエージェント実行者の関係**（D3）: 型の `allow` で `confirm` を上書きできる形にするか、`common.confirm` を含むチケットの `executor` をメインエージェントに固定する規約を置くか、代行を正式な運用として `00-workflow-issue-mr-driven` に書くか。どれかに決めないと、S2 以降も同じ往復が起きる
- **`10-task-ai-asset-implementation-exec` の復旧手順**: スキル本文は `git checkout <基準点> -- <path>` と書いているが、`git checkout` は分類 unknown で WF204 になる（チケットの作業内容が `git show` → Write に上書きしている）。スキル側を `git show <基準点>:<パス>` → Write に直すべき

### 備考

- このレポートは 0019〜0027 が節を積み上げる器である。次のチケットは md 側 `e5` / HTML 側 `f5` から続け、サマリの件数・逸脱・残課題を都度更新する（累積の数はサマリ 1 か所にだけ置く）
- `wip/tmp/0018-selfcheck.txt` は「自分が止まらないこと」の確認に使った捨てファイル（`wip/tmp/` は gitignore 済みでコミットされない）
