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
started_at: "2026-09-04T22:38:46+09:00"
completed_at: ""
base_sha: "9721416"
---

# 0004 調査: worktree 上でのフックの作業ツリー解決と、WIP・宣言範囲・差分判定の健全性

## 目的

調査計画書（wip/20_plans/0003-investigation-plan.md）の観点 A に答える。Claude が worktree に入ったとき、フックが worktree 側の wip/ と logs/ を見て判定するか（DDR i0009-55 の言う静かな無効化に落ちないか）を、読み取りで確かめられるところまで確かめ、残余を実測手順にする。受け入れ条件 A1 と A5、全体計画書の保留 P1 に効く。

## DoD

- [x] 観点 A『Claude が worktree に入ったとき、フックは worktree 側の wip/ と logs/ を見て判定するか』への答えが調査結果レポート wip/30_reports/0004-investigation.md に書かれている（根拠: レポート サマリの主文と e1「答え（観点 A の主文）」。条件 2 つ（cwd が worktree を指す / 相互参照が双方向に成立）つきで書いた）
- [x] grep -rn "HOOK_ROOT|HOOK_WORKTREE" .claude/hooks/ の全参照が、ファイル:行と『スクリプトの置き場（HOOK_ROOT が正）/ 作業ツリーの状態（HOOK_WORKTREE が正）』の判定つきで一覧になっており、総件数と取り違えの件数が書かれている（根拠: レポート e2「全参照の一覧」81 行の表。総件数 81 行 / 90 箇所、取り違え・疑い 4 件を「取り違え 4 件の内訳」表に X1〜X4 として明記）
- [x] workflow-guard / workflow-diff-check / workflow-entry / workflow-state-guard / session-start / subagent-stop-check の 6 本それぞれについて、worktree 側で判定されるか本流側で判定されるかの結論と根拠（ファイル・行）が添えられている（根拠: レポート e3 の表 6 行。各行に判定に使う状態とファイル:行、結論を記載）
- [x] .claude/hooks/lib/tests/test_hook_common.sh が検証済みの範囲と、実測でしか確かめられない残余が分けて書かれている（根拠: レポート e7 の 2 つの表。検証済み 15 項目（行番号つき）と残余 A〜E を別表にした）
- [x] 残余について、そのまま貼れるコマンド列と観点ごとの予測を対にした実測手順がレポートに書かれている（実行は人間が行い、結果は wip/tmp/worktree-probe/ に置く前提を明記する）（根拠: レポート e8 の P0〜P8。前提の段落に「実行は人間が行う」「結果は wip/tmp/worktree-probe/ に置く」を明記し、各プローブに予測と判定基準を対にした）
- [x] 答えが出なかった問いは理由付きで残課題に残っている（根拠: レポート「確かめられなかったこと」6 行と「残課題」R1〜R6。いずれも理由と引き取り先つき）
- [x] 調査結果レポートが md と HTML の対で作られ、check-html.sh を通っている（根拠: wip/30_reports/0004-investigation.md と .html。check-html.sh が「OK: 検査 7 項目すべて通過（id 23 件 / リンク 16 件を確認。テンプレート: report）」）

## 作業内容

- grep -rn "HOOK_ROOT|HOOK_WORKTREE" .claude/hooks/ で全参照を抜き、1 件ずつ判定して表にする
- hook-common.sh の __hc_resolve_worktree / __hc_is_worktree_of を読み、上向き探索と worktree 検証の条件を書き出す
- .claude/docs/10_spec/ のフック共通仕様 §2 と DDR i0009-55 を読み、実装が決定どおりかを突き合わせる
- test_hook_common.sh の worktree 関連ケースを読み、検証済み範囲を特定する
- 実測手順（worktree の作成・確認・片付けのコマンド列と予測）を書く。git worktree add / checkout は AI からは実行できないため、実行は人間に回す

## 作業ログ

### 現在地

- 完了。観点 A の調査を終え、wip/30_reports/0004-investigation.md と同名 HTML（check-html.sh 通過）を作った。次は 0005（観点 B）だが、本チケットの範囲外なので着手しない

### うまくいったこと

- 全参照の抽出を grep 1 本（`grep -rn "HOOK_ROOT\|HOOK_WORKTREE" .claude/hooks/`）で機械的に固定し、件数（行 81 / 箇所 90 / 本体 71）を `wc -l`・`grep -rno`・`grep -v /tests/`・`grep -rc` の 4 通りで突き合わせた。表の行数（W 55 + R 8 + C 4 + X 4 + T 10 = 81）と一致する
- 作業ツリーの決定が `hook_read_input` の末尾 1 か所（hook-common.sh:369）に集約されていたため、6 本のフックを 1 本ずつ読まなくても「解決を通っているか」を確実に言えた
- 実測を「Claude を worktree に入れる」形に頼らず、stdin の cwd を与えてフックを直接叩く形に設計し直せた。識別子に main 基点の作業ツリー（10_doing が .gitkeep のみ＝チケット 0 枚）を選んだことで、「worktree 側を見たか本流を見たか」が出力の有無で一意に切り分けられる

### うまくいかなかったこと

- 分類用の一時スクリプト（wip/tmp/0004-refs.sh）を書いたが、`bash <スクリプト>` は提供コマンドでないため WF204 で実行できなかった。表は grep の出力を手で分類して作った（分類の根拠は各行のコードを読んだうえでの判定で、機械的ではない）
- `cat > <ファイル> <<EOS` のヒアドキュメントによる書き込みは WF205（宛先を読み取れない）で拒否された。ファイルの作成は Write ツールに寄せた

### 仕様からの逸脱

- 無し（読み取りと wip/ への書き込みだけで、宣言の範囲を出ていない）

### 判断と根拠

- 取り違えの判定基準を「その参照が指しているものが ①スクリプト・設定の実体か ②wip/ logs/ git の状態か」の 2 択に固定し、定義行・コメント・テストの設定は対象外にした。根拠は仕様 §2（:101）の「スクリプトの置き場は常に HOOK_ROOT」「logs/ と wip/ は作業ツリー側」という 2 分法
- session-start.sh:74（boundary.sh を HOOK_WORKTREE から取る）を「取り違え」と断じず、X2 として「原則と不一致だが原則どおりに直すと壊れる」と書いた。boundary.sh は自分の BASH_SOURCE からルートを決めるので、本流の実体を呼ぶと本流の wip/ を読む。設計判断なので決めずにレポートの ◆ に上げた
- 仕様 §13 と DDR i0009-64 の記述がコードと食い違う 2 件（D1・D2）は、文書を直さずレポートに記録した。調査は設計・実装の決定をしないため
- 実測手順の worktree を `--detach` で作ることにした。1 issue = 1 ブランチ = 1 MR の原則に触れず、ブランチを 2 つの作業ツリーに縛らないため

### 拒否・確認・迂回の記録

- WF204（`cd`）: `cd <リポジトリ> && grep ...` の形が拒否された。迂回せず、grep に絶対パスを渡す形に変えた
- WF204（`git`）: `git worktree list` を含む複合コマンドが拒否された（`worktree` が _SC_GIT_READ_SUBCMDS に無く、同じ行の他の git 読み取りも巻き添え）。`git ls-tree` / `git rev-parse` に分けて取り直した。観点 E（0008）の材料としてレポートの「想定と異なった点」に記録
- WF204（`bash`）: 一時スクリプトの実行が拒否された。手作業の分類に切り替え、実測手順も「人間が実行する」前提で書いた
- WF205（ヒアドキュメント・リダイレクト）: `cat > file <<EOS` と `bash script > file` が「宛先を読み取れない」として拒否された。Write ツールに切り替えた
- 迂回・無効化は行っていない

### 使った AI アセットと効き目

- `10-task-investigation-exec`: 実施タスクの共通手順（着手 → 実施 → レポート → コミット → 完了）と「決めない」線引きが効いた。特に「観点自体が的外れでも観点は書き換えず経緯を残す」の指示が、取り違え 0 件だったときの書き方を決めた
- `20-common-step-report-view`: テンプレートを Read → Write → Edit の順に作る指示どおりで check-html.sh を一発で通過。md と HTML の突き合わせ（見出し数・表の行数）も手順 5 のとおりに実施した
- `20-common-step-ticket`: `ticket.sh next` / `start` が基準点（9721416）を自動で記録し、実測手順の復旧指示にそのまま使えた
- 効きが弱かった点: `20-common-step-report-view` は check-html.sh を絶対パスで呼ぶと WF204 になることに触れていない（提供コマンドの識別はルート相対表記だけ。仕様 HK-T12）。手順に一言あると迷わない

### スコープ外で見つけたこと

- 仕様 §11 のテスト ID 一覧に「作業ツリーの解決」の ID が無く、test_hook_common.sh の case_worktree が HK-T18（副入力の縮退）を借りている（レポート e7）
- 本流と worktree で scope-limits.json の内容が食い違う場合、フックは常に本流の設定で判定する（hook-common.sh:347）。設定を変えるブランチを worktree で開発すると、そのブランチの設定が試されない（レポート R5）
- フックの判定記録（decisions.jsonl）は作業ツリー側、実行ログ（logs/sh/）は本流側に割れる（レポート e2 の X3）

### AI アセットに反映すべき内容

- `20-common-step-report-view` の手順 4 に「check-html.sh はルート相対表記で呼ぶ（絶対パスだと提供コマンドと認識されず WF204）」を足す
- `10-task-investigation-exec` の「読み取りだけ」の説明に「一時スクリプトの `bash` 実行も分類外で拒否される」ことを書き添えると、書いてから捨てる無駄が減る

### 備考

- 実測手順（レポート e8）の実行は人間に回る。0008 完了時点の切れ目でユーザーへ渡す前提（調査計画書「実測の扱い」）
- wip/tmp/0004-refs.sh（実行できなかった分類スクリプト）は片付けた
