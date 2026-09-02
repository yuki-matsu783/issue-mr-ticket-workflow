---
type: ticket
ticket_type: ai-asset-implementation
predecessors: []
executor: main
human_review: {required: true, reason: "基準どおり（振る舞いが変わる。承認④により opus の敵対的自己レビューで代替）"}
adversarial_review: {required: true, reason: "基準どおり（中核である hook-common.sh と scope.sh の変更は機構自身を止め得る）"}
allow:
  write: [".claude/hooks/**", ".claude/skills/**", ".claude/rules/**", ".claude/settings.json"]
  ops: ["read", "remote-read", "hook-test", "build-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0027 共通ライブラリの改修・config 3 ファイル・読み込み行の一斉置換・block-chmod

## 目的

フック本体を書く前に、設計が要求する lib の関数と config を揃え、読み込み行を雛形とバイト一致させる。あわせて T6 の先行確認に使う block-chmod を 1 本だけ書く

## DoD

- [ ] assets/script.template.sh と test.template.sh の __ss_load が仕様（20-common-step-shell-script「読み込み行」）どおりで、FM_AVAILABLE を設定し fm_* スタブが戻り値 2 を返す（根拠: ）
- [ ] __ss_load を持つ残り 21 ファイルが雛形の当該行とバイト一致し、SS-T05 が通る。置換後にもう一度 grep して差分 0 を確かめた（根拠: ）
- [ ] hook-common.sh に hook_read_state / hc_append_jsonl / hc_json_write / hc_lock / hc_unlock の 5 関数があり、§1 の契約の表どおり（切り詰めは hc_append_jsonl・2 秒と 60 秒は hc_lock が持つ）（根拠: ）
- [ ] hook_read_input が副入力を --rawfile + fromjson? // null で読み、不在は --argjson null に差し替え、HC_<名前>_STATE（ok / missing / broken）を立てる。--slurpfile を使っていない（根拠: ）
- [ ] hc_lock が取得前に既存ロックの作成時刻を見て 60 秒より古ければ rmdir して強制解放し、実行ログに 1 行残す。HK-T20 が通る。Windows の Git Bash での作成時刻の取得方法を実測して作業ログに残した（根拠: ）
- [ ] scope.sh の scope_load / scope_load_approvals からパス引数が消え HC_* から詰め替えるだけになり、scope_load_ticket の戻り値が 0 / 1 / 2 の 3 状態に分かれている（根拠: ）
- [ ] scope_classify に web の 3 段判定（送信側 WF206 → 出力先 WF205 → web）があり、出力先は cmdpos_args の走査で取り :// を含む語を URL として除く。hook-test を build-test と provided より先に判定する（根拠: ）
- [ ] scope.sh の fm_* 呼び出しから || true が消え || rc=$? になり、local と代入が 2 行に分かれている（根拠: ）
- [ ] .claude/hooks/config/ に blocked-commands.txt（初期値 chmod）・entry-skills.txt・model-aliases.txt を作った。3 ファイルとも ⓪ の登録より前に作った（根拠: ）
- [ ] block-chmod.sh とそのテストがあり、bash -n と shellcheck を通り、bash <script> < 入力 JSON の単体実行で deny JSON を出す。実装の型（HOOK_DENY_ID の代入 → lib の source → hook_init）に従っている（根拠: ）
- [ ] .claude/rules/markdown-docs.md の参照不整合（ai-asset-design-docs.md:38 と design-docs.md:36 が参照するが実体が無い）が解消され、作るか参照を消すかの根拠が作業ログにある（根拠: ）
- [ ] lib と block-chmod に関わるテストが run-tests.sh --ids で通る（HK-T06〜T08・T10・T11・T15〜T20・SS-T05・BC-T*）（根拠: ）

## 作業内容

- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md のステップ 1 に従う
- 読み込み行は雛形 → 実体の順で直す。順序を逆にすると SS-T05 はどちらの向きにも落ちる
- 読み込み行の 3 段目（git rev-parse）は既定で残す。外すと相対パス起動かつ CLAUDE_PROJECT_DIR 無しの経路が解決不能になる
- .claude/docs/** には書かない（実装フェーズの deny）。決定は作業ログ「判断と根拠」に、DDR にすべきものは「AI アセットに反映すべき内容」に書く

## 作業ログ

### 現在地

- 未着手

### うまくいったこと

### うまくいかなかったこと

### 仕様からの逸脱

### 判断と根拠

### 拒否・確認・迂回の記録

### 使った AI アセットと効き目

### スコープ外で見つけたこと

### AI アセットに反映すべき内容

### 備考
