---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0006"]
executor: main
human_review: {required: true, reason: "中核（フック）の仕様の変更。承認④により opus 自己レビューで代替"}
adversarial_review: {required: true, reason: "仕様は正史。設計実施の切れ目で 1 回（全体計画の方針）"}
allow:
  write: [".claude/docs/10_spec/**", ".claude/docs/20_ddr/**", "wip/**"]
  ops: ["read"]
started_at: "2026-09-01T02:37:38Z"
completed_at: "2026-09-01T02:46:31Z"
base_sha: "2d14abb"
---

# 0008 AI アセット設計実施 — フック共通仕様と post-push-compact-prompt 仕様の修正

## 目的

設計計画 0006 の採否表のうち、`10_spec/フック共通仕様.md`（§3・§6・§7・§8・§9・§12）と `10_spec/hooks/22-PostToolUse/post-push-compact-prompt.md` に反映する項目（D2・D3・D4・D5・D6・D8・D9 参照・D11・D14・D19 台帳・D20 §8・Q6 台帳）を現在の正史として書き換える。

## DoD

- [x] フック共通仕様が D2（§8 glob 規則）・D4（§7-8 パス一致）・D11（§3 一次防御）・D14（§8 初期値 `.gitattributes`）・D20（§8 `investigation.ops` に `build-test`）のとおりに更新されている（根拠: §8「パターンは glob でリポジトリルート相対。`*` は `/` を跨がない…」/ §7-8「リポジトリルート相対のパスとして…確定できないセグメントは通常の判定」/ §3 redact 段落の「最後の砦」/ §8 JSON と初期値表の `ai-asset-implementation` に `.gitattributes` / `investigation` 行の ops に `build-test, web` と宣言条件 / §11 に HK-T11（glob の跨ぎ）・HK-T12（提供コマンド識別）を追加）
- [x] §9 に `adversarial_review: {required, reason}` が追加され、WF208 の監視対象に含めるか否かが明記されている（根拠: §9 の YAML 例に `adversarial_review` 行（コメントで手順 2a・work-defaults を参照）、WF208 の監視対象の列挙に `adversarial_review` を追加 = 含める）
- [x] §12 で T5 が確認済み（出典付き）、T3 が出典で補強され、D5（deny の JSON 経路）が TBD として追加されている（根拠: §12 表の T3 行「出典で補強済み（2026-09-01 …）」、T5 行「確認済み（2026-09-01）… transcript の tool_use 記録」、新規 T6 行「PreToolUse の deny が permissionDecision JSON の経路で確実に効くか」）
- [x] §6 採番台帳に `TR`（run-tests.sh）と frontmatter ライブラリのテスト ID 接頭辞、5 本の eval ID 接頭辞が追加され、既存と衝突していない（根拠: §6 表に TR001–005 / FR-T / AC-E・FM-E・IS-E・RQ-E・SP-E の 3 行を追加。既存接頭辞 WF・HK・TK・CP・RV・FN・BD・LG・SS と重複なし。冒頭にテスト ID `-T` / eval ID `-E` の規則を追記）
- [x] §7 の共有ライブラリ一覧に `frontmatter.sh`（shell-script スキル配下・`source` 専用）への参照が追加されている（根拠: §7 冒頭の段落の直後に「チケットの frontmatter（§9）の読み取りは …frontmatter.sh… を hooks/lib から source」を追加。§9 冒頭にも「読み取りは frontmatter.sh（§7）に統一」）
- [x] post-push-compact-prompt 仕様の push 検知 2 に D3 の縮退経路が書かれ、テスト観点に対応する行がある（根拠: 「push 検知」2 の文（`@{upstream}` 不在 → `origin/<b>` → 終了コード 0）とテスト観点 PP-T08）
- [x] 各仕様書の「要件との対応」表と用語・インターフェースの整合が崩れておらず、プレースホルダが 0 件（根拠: 変更は既存の節内の文言追加・行追加のみで節の追加削除なし（`git diff --stat`: 共通仕様 +20/-12 前後、compact-prompt +2/-1）。プレースホルダの grep は両ファイル 0 件）
- [x] 決定の経緯（採らなかった案）が 0010 の DDR に渡る形で作業ログ「判断と根拠」に残っている（根拠: 本チケット作業ログ「判断と根拠」の 6 項目）
- [x] ヘッドレス実行の帰結が計画書の表と矛盾しない（根拠: 追加した規則はいずれも判定を確定的にする方向（glob の意味・パス一致・上限の明示）で、`ask` になる経路を増やしていない。D20 は宣言があれば承認なしで通る）

## 作業内容

- 計画書 0006 の採否表・骨子に従い、該当節を Edit で書き換える（履歴は書かない）
- 変更箇所を作業ログに列挙する（0010 の DDR の材料）

## 作業ログ

### 現在地

- 完了（未完了の項目なし）

### うまくいったこと

- 採否表に反映先の節まで書いてあったので、置換の対象文を特定するだけで済んだ

### うまくいかなかったこと

- 記録用の perl スクリプトで区切り文字と本文の波括弧が衝突し 2 回失敗した。2 回目は気づかず、記録が空のまま done へ移動・コミットしてしまった（0006 と同じ事故。直後のコミットで補完）。以後は正規表現を使わない差し替えツール（`apply-pairs.pl`）に切り替えた

### 仕様からの逸脱

- 手作業代替（ticket.sh 未実装）。完了検査を通さずに done へ移動した（上記。TK003 があれば止まっていた）

### 判断と根拠

- D2: `*` が `/` を跨がない glob を採った。却下案「`**` を `*` に読み替える（参考 `wf_match`）」は `.claude/*` が config 配下にも当たり `common.confirm` の優先関係が崩れる
- D4: 提供コマンドの識別をルート相対パス一致に限定し、確定できないセグメントは通常判定へ。却下案「basename 一致（参考 `command_invokes_script`）」は `/tmp/commit.sh` で判定を回避でき許可側に倒れる
- D14: `.gitattributes` を `ai-asset-implementation.allow` に明示。却下案「チケットの `allow.write` に書く」は §8 の宣言が絞る役なので通らない
- D20: (a) 上限に `build-test` / `web` を含め、計画の宣言があるときだけ通す。却下案 (b)「調査でのテスト実行を全面禁止」は Q2 の結論（参考テストを動かした証跡）が出せなくなる。既定で使えないのは宣言必須にしたため
- D8: `adversarial_review` を WF208 の監視対象に含めた。含めない案は「レビュー要否を作業中に自分で不要へ書き換える」抜け道を残す
- D6: T3 は「補強」、T5 は「確認済み」として行は残した（消すと外れたときの縮退が消える。実装で `decisions.jsonl` の実物を見た後に消す）。T6（deny の JSON 経路）を追加

### 拒否・確認・迂回の記録

- なし

### 使った AI アセットと効き目

- 設計計画 0006（採否表・骨子）: 足りた。反映先の節が書いてあることが効いた
- `20-common-step-spec` 仕様（仕様書の書き方）: 正史のみを書く・履歴を書かない規則に従った

### スコープ外で見つけたこと

- §1 の共有ライブラリの箇条書き（`hook-common.sh` 等）には `frontmatter.sh` を載せていない（`hooks/lib` 配下ではないため）。§7 と §9 の参照で足りると判断したが、2/3 の実装計画で参照更新の検索対象に入れる

### AI アセットに反映すべき内容

- DDR i0006-01（frontmatter パーサの置き場）・i0006-05（調査でのテスト実行）の材料は上記「判断と根拠」（0010 で作成）
- HK-T11・HK-T12 を追加したので、2/3 の hooks/lib のテスト計画に含める

### 備考
