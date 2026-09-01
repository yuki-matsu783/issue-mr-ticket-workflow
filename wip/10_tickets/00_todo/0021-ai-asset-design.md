---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0020"]
executor: sub-opus
human_review: {required: true, reason: "正史（要件・仕様）の変更（承認④により opus の敵対的自己レビューで代替）"}
adversarial_review: {required: true, reason: "基準どおり（中核の定義に触る）"}
allow:
  write: [".claude/docs/**"]
  ops: ["read", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0021 レビュー指摘: ライブラリのインターフェースと呼び出し規約（R3・R6・R7・R8・R9・R14・R15）

## 目的

3 フックが共有する scope.sh の外部インターフェースが未定義で、frontmatter.sh の戻り値 2 を set -e 下で伝播させる規約も無い。実装できる粒度まで書き切る

## DoD

- [ ] §8 に §7-9 と同じ「出力の形」が加わり、scope.sh の関数名（scope_load / scope_resolve / scope_classify 等）と出力変数（SC_DECISION / SC_ID / SC_STAGE / SC_ASK_SCOPE / SC_CLASS / SC_TARGETS）が定義されている。判定結果と段階番号を戻り値 0/1/2 とどう両立させるかが決まっている（R6）（根拠: ）
- [ ] 戻り値 0/1/2 の規約の適用範囲が「チケットの frontmatter を読む関数」に限定され、述語関数（scope_match / scope_op_declared）が真偽を返すことと衝突しない（R7）（根拠: ）
- [ ] set -euo pipefail の下で fm_* の戻り値 1/2 を潰さずに受ける呼び出し規約が仕様に書かれている（|| true を使わない・local と代入を同じ行に書かない等）。FM_AVAILABLE を誰が設定するかも決まっている（R8）（根拠: ）
- [ ] 読み込み行の逐語コピー（22 ファイル）を雛形と一致させる手段が決まり、バイト一致を検査するテスト観点がある。0016 の実装計画に一斉置換の作業項目として送られている（R9）（根拠: ）
- [ ] §11 HK-T13 の 3 か所から tool_response の終了コードが消え、§12 T7・DDR i0009-07 と矛盾しない。PP-T02 の「push 失敗」の観点も PostToolUseFailure に流れる事実に合わせて整理されている（R3）（根拠: ）
- [ ] post-push-usage-report の SubagentStop 経路が agent_transcript_path を読む形に直り、メイン分の二重計上が起きない。UR-T03 に負のケースがある（R14）（根拠: ）
- [ ] §1 と §12 T8 の「fm_* が空を返すスタブ」が「出力なし・戻り値 2・FM_AVAILABLE=0」に更新され、横断仕様と 20-common-step-shell-script 仕様が一致している（R15）（根拠: ）
- [ ] 決定の経緯が DDR i0009-33〜39 の範囲に残っている（根拠: ）

## 作業内容

- 指摘の原文は wip/30_reports/0015-ai-asset-design-appendix-A.md を参照する
- 参考実装（.claude/hooks/lib/scope.sh・hook-common.sh）を読んで実装できる粒度か確かめる。ただし実装は変更しない（設計チケット）

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
