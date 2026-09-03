---
type: ticket
ticket_type: investigation
predecessors: []
executor: main
human_review: {required: true, reason: "全体計画の方針: 結論が実装計画を左右する（承認④により opus の敵対的自己レビューで代替）"}
adversarial_review: {required: true, reason: "全体計画の方針: 人間レビューの代替として敵対的レビューを行う"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read", "web"]
started_at: "2026-09-02T05:08:49+09:00"
completed_at: "2026-09-02T05:18:05+09:00"
base_sha: "09ccde4"
---

# 0007 公式 hooks リファレンスの確認と T5・クォート付き git の扱い（外部技術調査）

## 目的

仕様が前提にしている入力・出力フィールド（SubagentStart の実在・model・agent_id・agent_type・defer・tool_response の終了コード・Stop の入力・PreToolUse の matcher が WebFetch / WebSearch を対象にできるか）を公式リファレンスで確かめ、§12 T5 が #6 で解決済みかとクォートで割った git のサブコマンド判定の扱いを確定する

## DoD

- [x] 観点『仕様 §2・§8・§12 が前提にする入力・出力フィールドは公式リファレンスの記載と一致するか』への答えが、前提 8 項目（SubagentStart / model / agent_id / agent_type / defer / tool_response の終了コード / Stop の入力 / PreToolUse の matcher が WebFetch・WebSearch を取れるか）ごとに「一致 / 相違 / 記載なし」で調査結果レポートに書かれている（根拠: wip/30_reports/0007-investigation.md（+ HTML。check-html OK: 7 項目通過 / id 24 / リンク 17。コミット 5ab1223）の「検証の結果」に前提 8 項目の判定表を置いた。一致 5（SubagentStart の実在 / agent_id / agent_type / defer / matcher が WebFetch・WebSearch を取れる）、相違 1（model は SessionStart のみ。f2）、記載なし 2（tool_response の終了コードのフィールド名 f4、Stop の完全なスキーマ））
- [x] 根拠（出典 URL と該当する記述、仕様書の該当節）が添えられている（根拠: 各章の details に公式の引用を入れた。出典は code.claude.com/docs/en/hooks（docs.claude.com から 301 リダイレクト）・hooks.md・agent-sdk/hooks（2026-09-02 取得）。仕様側は §2・§7-9・§12 と subagent-start-check / block-direct-git の該当節を引用）
- [x] 観点『§12 の T5 は #6 で解決済みか』への答えと根拠（DDR 番号またはコミット）が書かれ、未解決なら実装フェーズの検証項目に追加されている（根拠: git show bb2a527 -- wip/30_reports/0003-investigation.md で #6 の Q3 を確認（f8）。結論は「文書上は前提どおり（tool_input のキーは Bash と同一）。ただし一時フックの settings.json 登録を auto モードの分類器が拒否したため実機確認は未了で、2/3 の登録直後の PowerShell 呼び出しで確認する」。したがって未解決分（実機確認）を実装フェーズ 4c の検証項目に追加する提案を「設計への反映」5 に記載）
- [x] 観点『git のサブコマンドがクォートで割れている場合（git 'commit'）、cmdpos.sh と block-direct-git 仕様はどう扱うか』への答えが根拠付きで書かれている（根拠: f9 に記載。共通仕様 §7-9 は「クォートで割った語（git 'commit'）は _ になり、呼び出し側は『特定できない』として扱う」と定めるが、block-direct-git の制御方式 3 は「特定できないときに拒否側へ倒す」を PowerShell 経路にしか書いていない。cmdpos.sh の実装でも git 'commit' は exe=git / subcmd=_ で CP_GITLIKE は 0（test_cmdpos.sh:226 の期待値は 'git' commit → exe=_ / gitlike=1）。したがって現状の仕様どおりに実装すると bash 経路では素通りする。設計への反映 6 に「bash 経路の subcmd == _ → WF403 を制御方式に足し、BG-T01 にケース追加」を提案）
- [x] 答えが出なかった問いは理由付きで残課題に残っている（根拠: 残課題 4 件（tool_response の実フィールド名と完全な入力スキーマ → 4c の実測 / ドキュメントの版と実行中の版の対応 / WebFetch を強制した場合に scope.sh の web 分類が PreToolUse の入力で判定できるか / PostToolUseFailure の活用）と、確かめられなかったこと 5 件を明記）

## 作業内容

- 公式 hooks リファレンスを閲覧し、イベント・入力フィールド・出力スキーマ・matcher の記法を前提 8 項目と突き合わせる（外部技術調査）
- .claude/docs/20_ddr/ と #6 の作業ログ・コミットで T5 の結論を探す
- cmdpos.sh の CP_GITLIKE 周りの実装と block-direct-git 仕様の「特定できない」の扱いを読む

## 作業ログ

### 現在地

- 済: 公式 hooks リファレンス（3 URL）を閲覧 → 前提 8 項目を「一致 / 相違 / 記載なし」で判定 → model の不在という相違を特定 → defer の値と優先順位を確定 → matcher の評価規則を確認 → #6 のコミット bb2a527 で T5 の到達点を確認 → cmdpos.sh と HK-T05 の期待値から git 'commit' の扱いを確認 → 調査結果レポート md + HTML（check-html OK）→ コミット 5ab1223
- 完了: 9 章（◎良 4 / △注意 4 / ✕問題 1）と設計への反映 7 項目、残課題 4 件まで書き上げた。調査フェーズ（0005〜0007）の 3 枚がそろった

### うまくいったこと

- 公式ページが長く途中で切れる問題は、SDK 側のドキュメント（agent-sdk/hooks）に回ることで解決できた。permissionDecision の 4 値と優先順位、agent_id / agent_type の必須性はそちらにしか書かれていなかった
- #6 の到達点（T5）は git show でコミット単位に辿れた。片付けで wip/ が消えても、コミットメッセージに「TBD T5」と書いてあったおかげで grep 一発で見つかった
- 「一致 / 相違 / 記載なし」の 3 値で判定する形にしたので、記載が見つからない項目を「調べ漏れ」ではなく結果として書けた

### うまくいかなかったこと

- 公式ページの PostToolUse・Stop・SubagentStart の各節が、3 回の取得（hooks / hooks.md / #stop アンカー）でいずれも取得範囲に入らなかった。ページが長大で、フェッチが先頭側で打ち切られる。llms.txt から個別ページを辿る手も残っていたが、SDK 側で必要な断片が取れたためそこで止めた
- 前提 8 項目のうち 2 項目が「記載なし」で終わった。実測に回せる項目なので実害は無いが、公式ドキュメントだけで T7 を閉じる見込みは外れた

### 仕様からの逸脱

- 調査結果レポートの HTML を perl の一括置換で埋めた（0005・0006 と同じ逸脱）
- 10-task-investigation-exec スキルの実体が未作成のため、10-task-investigation-plan 仕様の DoD の型とレポートテンプレートの必須節を手順として使った

### 判断と根拠

- f2（model の不在）を ✕問題にした。subagent-start-check の主機能（WF801）が入力から判定できなくなり、仕様の書き換えが必要になるため。0005 の f5（boundary.sh 依存）と同じ重さ
- f3（defer）は「実在するが採用しない」と結論まで書いた。用途（クエリを終了して後で再開）が公式に明文化されており、機構の拒否・確認とは目的が違うため、実測を待つ必要が無い
- f9（git 'commit'）は仕様の穴として設計に送る。cmdpos.sh を実行して確かめる案もあったが、宣言した ops が read / remote-read / web で、lib を source して動かすのは分類外の実行に当たるため、コードと HK-T05 の期待値からの読み取りに留めた
- 公式ドキュメントの取得日（2026-09-02）を実施条件に明記した。版の記載が無いため、日付が唯一の再現の手がかりになる

### 拒否・確認・迂回の記録

- フックは未登録のため機構によるブロックは無し
- docs.claude.com への最初のフェッチが 301 リダイレクトを返したため、リダイレクト先（code.claude.com）を明示して再取得した（自動追従はされない仕様）

### 使った AI アセットと効き目

- WebFetch / WebSearch（0007 の allow.ops に web を宣言）: 宣言した分類の範囲で外部調査ができた。宣言が無ければ WF206 に当たる想定の操作で、計画で 0007 だけに web を付けた判断が正しく働いた
- 10_spec/フック共通仕様.md §7-9: 「クォートで割った語は _ になり、呼び出し側は特定できないとして扱う」という 1 文が、f9 の穴を見つける決め手になった。共通仕様に判定の契約が書いてあると、フック仕様の抜けが照合で見つかる
- git show / コミットメッセージ: #6 の到達点を辿る唯一の手段だった（wip/ は片付け済み）

### スコープ外で見つけたこと

- 公式ドキュメントは「フックが受け取れるフィールド」をイベントごとに細かく分けている（model は SessionStart のみ、agent_id / agent_type はサブエージェント内のみ）。仕様側で「どのイベントで何が読めるか」の表を持つと、今回のような前提の外れを早く見つけられる
- コミットメッセージに TBD 番号（T5）を書いておくと、片付け後も grep で辿れる。#6 の運用が結果的に効いた

### AI アセットに反映すべき内容

- 設計フェーズ（0008 → 設計チケット）へ: 設計への反映 7 項目（WF801 の判定経路 / defer 不採用 / web の強制の可否 / tool_response は実測待ち / T5 を 4c へ / git 'commit' の穴 / 仕様に無いイベントは 3/3 へ）
- 3/3（#10）へ: (1) フック共通仕様に「イベント × 読めるフィールド」の表を足す（公式の記述に合わせる）/ (2) 公式ドキュメントの取得日を仕様の脚注に残す運用（版が無いため）/ (3) PostToolUseFailure と 21-PermissionRequest の空ディレクトリの扱い

### 備考

- 調査結果レポート: wip/30_reports/0007-investigation.md（+ .html。5ab1223）
- 章立て: f1 SubagentStart / agent_id / agent_type（◎）/ f2 model の不在（✕）/ f3 defer（◎）/ f4 tool_response（△）/ f5 matcher と web（◎）/ f6 仕様に無いイベント（△）/ f7 exit 2 の優先（◎）/ f8 T5 の到達点（△）/ f9 git 'commit' の穴（△）
- 出典: https://code.claude.com/docs/en/hooks 、https://code.claude.com/docs/en/hooks.md 、https://code.claude.com/docs/en/agent-sdk/hooks （いずれも 2026-09-02 取得）
- 見てほしい点: f2 の設計判断（WF801 の経路）/ f9 の提案（bash 経路の _ を拒否側に倒す）/ 前提 8 項目の判定の妥当性
