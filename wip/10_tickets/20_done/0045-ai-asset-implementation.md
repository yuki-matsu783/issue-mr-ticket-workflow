---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0041"]
executor: main
human_review: {required: true, reason: "許可範囲の緩和は機構の締まりに直に効く（work-defaults の ai-asset-implementation は人間レビュー要）"}
adversarial_review: {required: false, reason: "全体計画の方針どおり、敵対的レビューは人間レビューに統合する"}
allow:
  write: [".claude/hooks/config/**", ".claude/docs/20_ddr/**", "wip/**"]
  ops: ["read", "build-test", "hook-test"]
started_at: "2026-09-03T08:57:41+00:00"
completed_at: "2026-09-03T09:02:15+00:00"
base_sha: "5a3e67f"
---

# 0045 scope-limits.json の commands.build-test に計測コマンドを足す

## 目的

調査フェーズが wip/tmp/ に置いた計測スクリプトを実行できるよう、build-test の分類に python3 と bash の実行を加える。現状は分類外として WF204 で既定拒否される

## DoD

- [x] commands.build-test に wip/tmp/ 配下を対象とする python3 と bash の項目が追加されている（根拠: `.claude/hooks/config/scope-limits.json` の `commands.build-test` に `"python3 wip/tmp/probe.py"` と `"bash wip/tmp/bench.sh"` の 2 件。列挙は 6 件から 8 件になった）
- [x] 追加した項目が wip/tmp/ 配下に限られており、任意のパスの python3 実行を通さないことを、scope.sh の前方一致の判定で確認している（根拠: `bash wip/tmp/bench.sh classify` の出力。`python3 wip/tmp/probe.py a2` と `python3 wip/tmp/probe.py` は build-test、`python3 wip/tmp/other.py` / `python3 /etc/evil.py` / `python3 wip/tmp/probe.pyx` / `bash wip/tmp/evil.sh` はいずれも unknown = 既定拒否のまま）
- [x] .claude/hooks/tests/ と .claude/hooks/lib/tests/ の既存テストが全通過している（根拠: test_config_integrity.sh passed=95 failures=0 / test_scope.sh passed=312 failures=0 / test_workflow_guard.sh passed=147 failures=0 / test_cmdpos.sh passed=281 failures=0）
- [x] 変更の理由が本チケットの作業ログ「判断と根拠」と調査計画書に残り、DDR の起票が AI アセット設計フェーズへ引き継がれている（根拠: 下記「判断と根拠」、`wip/20_plans/0041-investigation-plan.md`「0045 を差し込んだ経緯」、0044 チケットの DoD に引き継ぎ項目を追加）

## 作業内容

- DoD の各項目を順に満たす

## 作業ログ

### 現在地

- 完了

### うまくいったこと

- `scope.sh` の `scope_classify` が `commands.build-test` を「列挙した文字列そのもの、または列挙 + 半角空白で始まる」で判定していたため、実行入口を 1 本に固定すれば列挙 1 行で引数付きの実行を通せた
- 追加が最小限に収まっていることを、拒否側の入力（別パス・拡張子違い・別スクリプト）を並べて実際に分類させて確認できた

### うまくいかなかったこと

- 当初 DoD に「変更の理由が DDR として残っている」を置いたが、`ai-asset-implementation` の型は `.claude/docs/**` を deny しており、このチケットでは DDR を書けない。DoD を「作業ログと計画書に残し、DDR の起票を設計フェーズへ引き継ぐ」に直した。チケットを起こす時点で型の許可範囲と DoD を突き合わせていなかった

### 仕様からの逸脱

- フェーズ順（AI アセット設計 → AI アセット実装）から外れて、調査フェーズの途中に実装チケットを差し込んだ。調査を進めるための前提整備で、ユーザーの合意を得ている（2026-09-03）

### 判断と根拠

- **実行入口を 1 本に固定した**: `scope_classify` の突き合わせは前方一致だが、区切りが半角空白なので `"python3 wip/tmp/"` のような途中までの指定は効かない（`python3 wip/tmp/x.py` は `python3 wip/tmp/` にも `python3 wip/tmp/ ` にも一致しない）。ディレクトリ単位で開ける手段が無いため、Python は `wip/tmp/probe.py`、シェルは `wip/tmp/bench.sh` の 2 本に集約し、モードを第 1 引数で選ぶ形にした
- **`python3 -c` を通さなかった**: `-c` は `cmdpos.sh` が opaque と判定する（中身をコードとして受け取る実行系）。列挙に足しても分類は opaque が先に立つため通らないし、通す設計にすべきでもない。スクリプトファイル経由に限る
- **`.claude/docs/**` への書き込みを諦めた**: 型の deny に当たる。迂回せず DDR を設計フェーズへ回した
- **既定拒否の設計は変えていない**: 変えたのは列挙 2 行だけで、分類の仕組み（列挙に無いコマンドは unknown = 既定拒否）はそのまま

### 拒否・確認・迂回の記録

| 識別子 | 何をしたとき | どうしたか |
|---|---|---|
| WF204 | 0042 で `python3 wip/tmp/a2_syntax.py` を実行 | 迂回せず作業を止め、ユーザーに提案して本チケットを差し込んだ |
| WF203 / WF601 | `scope-limits.json` を編集 | 「毎回確認する範囲」に当たる変更。ユーザーが実装チケットの差し込みを選んだことをもって承認とし、変更内容と理由をこのログに残した |

### 使った AI アセットと効き目

- `.claude/hooks/lib/scope.sh` の `scope_classify`: 判定の実装をそのまま読めたので、前方一致の区切りが空白であることを推測ではなく確認できた
- 既存テスト 4 本（`test_config_integrity` / `test_scope` / `test_workflow_guard` / `test_cmdpos`）: 設定変更の巻き添えが無いことを 835 件の検査で確認できた

### スコープ外で見つけたこと

- `commands.build-test` はディレクトリ単位・glob での指定ができない。実行入口をスクリプト 1 本に集約する運用でしのげるが、調査のたびに列挙が増える形は続く。issue #30（計画タスクが commands.build-test を列挙できない）と併せて設計を見直す余地がある

### AI アセットに反映すべき内容

- チケットを起こす時点で「DoD が型の許可範囲で達成できるか」を突き合わせる手順が無い。issue #32（計画スキルに、チケットを起こすときのチェック項目を足す）にこの観点を足すとよい

### 備考

- `wip/tmp/probe.py` と `wip/tmp/bench.sh` は追跡しない（`wip/tmp/**` はコミット対象外）。列挙したパスに実体が無くても分類は通るので、次の調査チケットで中身を書き足す
