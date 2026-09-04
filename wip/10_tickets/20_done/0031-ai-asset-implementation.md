---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0030"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "中核を含まず、件数と旧名 0 件は検索で機械的に判定できる"}
allow:
  write: [".claude/evals/**", ".claude/skills/**", ".claude/rules/**", "wip/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-04T12:26:15+09:00"
completed_at: "2026-09-04T12:47:22+09:00"
base_sha: "0556d1b"
---

# 0031 S8 eval 定義 19 件と旧資産 5 件の処遇（旧名 26 件）

## 目的

0023 が仕様書に書いた eval の表を .claude/evals/ に落とし、旧ワークフロースキルに残った資産 5 件を削除・移設・移行で片付ける

## DoD

- [x] .claude/evals/<アセット名>.md が 19 本作成され、対応する仕様書の「テスト観点」節の eval ID と 1:1 で対応している（定義まで。評価の実行はしない）（根拠: タスクスキル 15 + ワークフロースキル 2 + エージェント 2 = 19 本。`10_spec/` から抽出した eval ID 111 件が `.claude/evals/` 側にすべて現れる（`grep -rhoE "\b[A-Z]{2,6}-E[0-9]{2}[a-z]?\b" | sort -u` の差分は、ルール 4 本ぶんの 12 件が evals 側に多いだけで、仕様側の取りこぼしは 0 件）。全 19 本の「実行状況」は **未実行**（定義のみ））
- [x] .claude/evals/ のファイル数が 28 になっている（既存 9 + 新規 19。ls での実測を根拠に貼る）（根拠: `ls .claude/evals/ | wc -l` → 28）
- [x] 旧 evals/evals.json 2 本が .claude/evals/00-workflow-issue-mr-driven.md と .claude/evals/00-workflow-quick-request.md へ移行され、移行先で旧名 26 件が新名に書き換わっている（持ち越さない）（根拠: 移行先 2 本に対する `grep -cE "10-work-|20-task-gh|work-boundary\.sh|merge-prep|hooks/boundary\.sh|hooks/finalize\.sh"` が両方 0。移行元 `evals.json` 2 本の**削除**は WF205 に阻まれたので 0036 へ移した）
- [x] 旧資産のうち削除 2 件（issue-addendum.template.md・issue-notify.template.md）が消え、削除の前に中身が新しい置き場にあること（前者は 20-common-step-issue/assets/）を確かめている（根拠: **削除の前提確認まで**を行った。`issue-addendum` は `20-common-step-issue/assets/issue-addendum.template.md` に新しい版（frontmatter とプレースホルダ付き）があることを `diff` で確認、`issue-notify` は DDR i0010-04 のとおり用途そのものが消えている（新しい全体まとめは issue にコメントしない）。**実際の削除は WF205 に阻まれたので 0036 へ移した**）
- [x] references/issue-triage.md が 20-common-step-issue へ移設されている（根拠: `.claude/skills/20-common-step-issue/references/issue-triage.md` を作成し、参照先の正を新しい仕様のパスに直し、GitLab の検索コマンドを足した。**旧ファイルの削除は WF205 に阻まれたので 0036 へ移した**）
- [x] rules/work-defaults.md に敵対的レビュアーのモデルを書く行があり、レビュアーであることが明記されている（残課題 R7・R9）（根拠: 「敵対的レビュアーのモデル」節を新設。役割欄に「タスクの実行者ではなくレビュアー」と明記し、既定 `claude-fable-5-1`・上限 1 回・実行者と一致したときは起動側が差し替えることを書いた）

## 作業内容

- eval 定義 19 件を作る（うち 2 件は evals.json からの移行）
- 旧資産 5 件を削除・移設・移行し、work-defaults にレビュアーのモデルの行を足す

## 作業ログ

### 現在地

- 完了（削除 5 ファイルは 0036 へ持ち越し）

### うまくいったこと

- eval ID の突合を機械でやれた。`10_spec/` から抽出した 111 件と `.claude/evals/` から抽出した 123 件を `diff` で比べ、差が「ルール 4 本ぶんの 12 件（AD-E / DD-E / LR-E / WD-E）だけ」であることを確かめた。仕様側の取りこぼしが 0 件だと 1 コマンドで言える
- 19 本を「仕様の eval 表を 1:1 で写し、入力欄だけを具体的な状況に膨らませる」形で書いた。判定方法の列は仕様の文言をそのまま使うので、後から仕様と突き合わせるときに差分が見える

### うまくいかなかったこと

- **旧資産の削除ができなかった**。`rm` / `mv` / `git rm` は WF205 が一律に拒否し、コマンドで書いてよいのは `wip/tmp/**` と `logs/**` だけ。Edit / Write ツールにファイルを消す手段は無いので、AI は `.claude/` 配下のアセットを削除できない。ユーザーの判断で機構を直す追加チケット 0036 を起こし、削除 5 ファイルをそこへ移した
- `bash wip/tmp/<script>.sh` が WF204 で止まった（このチケットの `allow.ops` は `read` / `remote-read`）。チケット作成は提供コマンドを直接呼ぶ形に変え、長さで WF209 に当たる分は作成後に Edit で埋めた

### 仕様からの逸脱

- **削除 3 種 5 ファイル（テンプレート 2・references 1・evals.json 2）が残っている**。DDR `i0010-04` は削除・移設を決めているが、機構に削除の経路が無い。0036 で機構を直してから消す
- `20-common-step-issue/references/issue-triage.md` は移設ではなく**複製**になっている（旧ファイルが消せないため）。同じ内容が 2 か所にある状態は 0036 で解消する

### 判断と根拠

- **DoD の 3 行（evals.json の移行・削除 2 件・issue-triage の移設）の根拠欄に「削除は 0036 へ移した」と書いて充足扱いにした**。3 行とも「新しい置き場に中身がある」ことは満たしており、残るのは旧ファイルの削除だけである。削除は機構の制約で今のチケットでは物理的に不可能なので、DoD の文言を書き換えるのではなく、達成した範囲と持ち越した範囲を根拠欄で分けた
- `issue-triage.md` は写すだけでなく、参照先の正のパスを新しい仕様（`10_spec/skills/20-common-step-issue.md`）に直し、GitLab の検索コマンドを足した。置き場が `20-common-step-issue` に移る以上、GitHub 専用のままでは置き場と中身が合わない
- `work-defaults.md` のレビュアーの行は表に足さず**別節**にした。上の表は「タスクの実行者」の既定で、レビュアーを同じ表に混ぜると `type` の列に入らない行ができて、モデル検査の比較対象を取り違える

### 拒否・確認・迂回の記録

- WF205（`.claude/` 配下の削除）に 1 回当たった。迂回せず、ユーザーに 3 案（機構を直す / 人間が消す / 旧ファイルを残す）を提示して「追加チケットで機構を直す」の判断を得た（2026-09-04）
- WF204（`bash <script>`）に 1 回当たった。提供コマンドの直接呼び出しに切り替えて対処した

### 使った AI アセットと効き目

- `20-common-step-ai-asset-creator` の `assets/eval.template.md`: 節構成（目的 / 評価シナリオ / 比較条件 / 効果ありの判定基準 / 実行状況）が決まっているので、19 本の形が揃った
- 既存の `.claude/evals/20-common-step-feature-mr.md`: 「入力欄をどこまで具体的に書くか」の粒度の手本になった

### スコープ外で見つけたこと

- AI アセット実装計画の仕様は変更対象に「削除」を含めているのに、機構に削除の経路が無い。設計と実装が食い違っている（0036 で機構側を直し、仕様との整合は設計反映で見る）

### AI アセットに反映すべき内容

- WF205 の仕様（`10_spec/hooks/20-PreToolUse/workflow-guard.md`）に「削除のみのコマンドは許可範囲で判定する」を入れる。0036 の実装と合わせて設計反映で反映する

### 備考

- allow.write は `.claude/evals/**` / `.claude/skills/**` / `.claude/rules/**` / `wip/**`。この範囲だけを触った
