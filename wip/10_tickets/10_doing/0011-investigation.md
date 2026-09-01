---
type: ticket
ticket_type: investigation
predecessors: []
executor: main
human_review: {required: true, reason: "全体計画の方針: 調査の結論が実装計画を左右する（承認④により opus の敵対的自己レビューで代替。2 巡目まで実施済みのため本チケットでレビューは打ち止め）"}
adversarial_review: {required: false, reason: "ユーザー指示によりタスクごとの敵対的レビューは最大 2 回。本チケットは 2 巡目の反映であり 3 巡目は行わない"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read", "web"]
started_at: "2026-09-02T06:12:32+09:00"
completed_at: ""
base_sha: "829ade1"
---

# 0011 調査 3 本の 2 巡目レビュー指摘の反映（S1〜S13）

## 目的

調査ワークの 2 巡目（最終）敵対的レビューが出した 13 件のうち confidence 0.5 以上の 12 件を反映し、0.4 の 1 件は判断を記録する

## DoD

- [x] S1・S2: 公式 hooks リファレンスの PreToolUse decision table（allow / deny / ask / defer の各行）を原文で確認し、確認できた場合は 0007 f3・f7・検証表・設計への反映を訂正した。確認できなかった場合は「未確認」として残課題に記録した（根拠: `curl` で `hooks.md`（316,963 バイト）を落とし L1738-1751 の decision control と L1781- の defer 専用節を原文で確認。**S1 は誤指摘として撤回**（原文は「`"defer"` exits gracefully so the tool can be resumed later」「対話セッションでは警告を出して無視する」で f3 の結論が正しい）、f3 の根拠を原文で強化。**S2 は妥当**（原文 L1744「`"deny"` prevents the tool call.」）なので f7 の「公式は明示していない」を訂正し、T6 をスモークテストに格下げ。3de7334）
- [x] S3: 0007 f7 の timeout の引用に限定句（async: true の除外）を戻し、公式の既定値（command / http / mcp_tool は 600、UserPromptSubmit などで 30）を本文に載せて残課題から外した（根拠: `hooks.md` L841 の原文に「Apart from a command hook you run with `async: true`,」を確認して転記。既定値は common fields の「Defaults: 600 … lowers … to 30 on `UserPromptSubmit`」を本文に追加し、残課題は「実測所要だけ」に絞った。3de7334）
- [x] S4: 0007 f8 の T5 の問いを共通仕様 §12 の原文（session_id / cwd / permission_mode の共通フィールド）に合わせて直し、4c の検証項目を差し替えた。あわせて hook-common.sh の PowerShell 吸収（CR 除去）を実施条件と本文に加えた（根拠: `フック共通仕様.md:262` の T5 の行を確認（「`tool_input` の同一性は §2 に確定済み」）。f8 の見出し・本文・結論・検証表・設計への反映 5 を共通フィールドに差し替え、`hook-common.sh:135` の CR 除去を本文に追加。3de7334）
- [x] S5・S7・S8・S9・S10・S12 の事実の誤りを訂正した（根拠: S5 空ディレクトリを 3 つに（`ls` で `01-PreCompact/`・`11-Stop/`・`21-PermissionRequest/` を確認。`11-Stop/` が空になる理由も注記）、S7 は HTML を md から作り直して解消、S8 `scope.sh:20` → `:18`（定義は `:17`）、S9 参考実装を「7 本 / 登録は 4 ファイル 6 登録・block-chmod.sh は未登録」に直し新規 7 本を列挙、S10 `assets/` の「フック配下」の断定を「基準ディレクトリ未定・実在する assets は全てスキル配下」に、S12 `hook-common.sh:156-166` → `:156-165` と `echo` → `printf` の引用の改変を訂正。3de7334）
- [x] S6・S11・S13 を反映した（f2 の案 (c) の波及の明記・0007 検証表への出典列の追加・0005 サマリの件数の整合）（根拠: S6 は §1 が 16 → 17 行になる波及と §3 への通知経路の追加を f2 の結論に明記し、PreToolUse が additionalContext を受け付けることを `hooks.md` L1747 で確認。S11 は検証表を 5 列（出典列）にして 11 行すべてに出典を入れ、URL の定義を表の直後に置いた。S13 は confidence 0.4 だが機械的に確かめられるため「4 件（f2〜f5）」に訂正。3de7334）
- [x] 3 本の md と HTML を同期し、check-html.sh が OK を返した（根拠: 0005 = id 22 / リンク 15、0006 = id 22 / リンク 15、0007 = id 24 / リンク 17 で 7 項目通過。「実測への依存」の行数は md/HTML で 4/4・5/5・9/9 と一致）

## 作業内容

- S1・S2 の原文を公式ドキュメントで再取得する。取れなければ未確認として扱い、レポートには反映しない
- 0005 / 0006 / 0007 の md を訂正し、HTML をテンプレートから作り直す
- confidence 0.4 の S13 の扱い（反映するか見送るか）を作業ログに記録する

## 作業ログ

### 現在地

- 完了: 2 巡目レビューの 13 件（S1〜S13）と、裏取りの過程で追加された 2 件（S14・S15）を処理し、3de7334 でコミットした
- check-html.sh は 3 本とも OK（7 項目通過）
- 敵対的レビューはユーザー指示の上限（タスクごと最大 2 回）に達したので、調査ワークのレビューはここで打ち止め

### うまくいったこと

- **公式ドキュメントの取得方法を `curl` + `grep` に切り替えた**のが決定的だった。`curl -sS -L -o wip/tmp/hooks.md https://code.claude.com/docs/en/hooks.md` で 316,963 バイトの原本が落ちるので、`grep -n '^#### PreToolUse decision control'` で節を特定して `sed -n` で読める。WebFetch では 3 回試しても該当節に到達できなかった
- 原本を読んだ結果、1 巡目・2 巡目とも「記載なし」と判定していた 2 項目（`tool_response` の終了コード・Stop / SubagentStop の入力スキーマ）に**どちらも記載があった**ことが分かり、§12 T7 を実測待ちから閉じられるようになった

### うまくいかなかったこと

- **レビュアーの引用も要約経由で捏造されていた**（S1）。同じ URL を 2 回取得すると違う文言の表が返る、という事象をレビュアー自身が報告した。原文には `Decision | Behavior` の 2 列表は存在せず、`Field | Description` の表に 1 行で書かれている。裏取りをせずに S1 を反映していたら、正しい記述（f3）を誤りに書き換えていた
- 訂正スクリプト（`fixS_c.pl`）を書いた直後にレビュアーからの返信が届き、**実行し損ねたまま次のスクリプトを走らせた**。後続スクリプトが 5 件 MISS したことで気付けたが、`applied=N/N` の確認をしていなければ取りこぼしていた

### 仕様からの逸脱

- HTML の作成に Edit ではなく perl による一括置換を使った（前チケットからの継続。テンプレートの雛形化された箇所が 20 か所以上あり Edit では往復が過大になるため。生成後に check-html.sh で検査）

### 判断と根拠

- **S1 は反映しない**（レビュアーが撤回）。原文 `hooks.md` L1783 は「Claude Code honors this value only in non-interactive mode with the `-p` flag. In interactive sessions it logs a warning and ignores the hook result.」で、機構（対話セッション）では採用しようがない。むしろ f3 の根拠を SDK ページの 1 文から原本の 2 か所に差し替えて強化した
- **S13 は confidence 0.4 だが反映した**。閾値（0.5）未満は記録のみが原則だが、「サマリの 7 件」は本文と機械的に突き合わせられ（△注意 3 + ✕問題 1 = 4 件）、直す方が安いと判断した
- **S14 / S15 は 2 巡目の指摘ではなく、その裏取りの過程でレビュアーが原本を読んで見つけたもの**。レビュー回数の上限（2 回）はレビューの実施回数を指すので、同じレビューの中で出た追加所見は 3 巡目には当たらないと解釈して反映した。ただし S14 は §12 T7 と `post-push-*` の成功判定を変える設計判断を含むため、**設計への反映 4 として 0008 に渡す**（この調査では決めない）
- **f4 を △注意 → ✕問題に格上げ**した。仕様の現行方針（4 候補読み・無ければ 0）は結果的に正しい値を返すが、根拠にしているフィールドが存在しないため「建て付けが実態と違う」。0008 で書き換える対象

### 拒否・確認・迂回の記録

- なし（フックによる拒否・確認は発生していない）

### 使った AI アセットと効き目

- **WebFetch**: 長いページ（316 KB）では該当節に到達できず、さらに**存在しない表を返した**。逐語引用の用途には使えない
- `20-common-step-report-view` の `check-html.sh`: 3 本とも通過。前チケットと同じく md との内容一致は見ない
- `20-common-step-ticket` / `20-common-step-commit-push`: 問題なし

### スコープ外で見つけたこと

- `hooks.md` L2066 は `PostToolUseFailure` の `error` について「treat the rest of the string as display text, not a stable format」と明示している。将来 `PostToolUseFailure` を使うなら、`Exit code N` の 1 行目だけを頼りにする設計にする必要がある
- `hooks.md` L743 に「`PreModelSwitch` と `PostModelSwitch` は `from_model` / `to_model` を受け取る」とあり、セッション中のモデル変更を追う手段が存在する。3/3 でモデルの追跡が要るなら使える

### AI アセットに反映すべき内容

- **公式ドキュメントを根拠にするときは `curl` で原本を落として `grep` する**、を調査系スキル（`10-task-investigation`）の手順に明記する。WebFetch は長いページで要約経由の捏造が起こり、同じ URL の 2 回の取得で違う文言が返る。今回この落とし穴に 1 巡目（R1）と 2 巡目（S1）の 2 回はまった
- 引用は「出典の行番号付き」を必須にする。`hooks.md L1744` のように書けば、次に読む人が同じ手順で再現できる
- `check-html.sh` に md と HTML の節見出しの照合を足す提案（前チケットからの継続）

### 備考

- レビュアーへの追加質問（引用の再現手順）は `SendMessage` で同じエージェントに送って回答を得た。レビューの往復にはこの経路が使える
