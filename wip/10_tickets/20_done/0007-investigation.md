---
type: ticket
ticket_type: investigation
predecessors: ["0002"]
executor: main
human_review: {required: false, reason: "全体計画の方針の差分 4 により、人間レビューはワークごとの敵対的レビューに置き換える"}
adversarial_review: {required: true, reason: "全体計画の方針の差分 4 により、ワークごとに 1 回の敵対的レビューを行う"}
allow:
  write: ["wip/**"]
  ops: ["read", "web"]
started_at: "2026-09-02T05:43:15+00:00"
completed_at: "2026-09-02T05:47:33+00:00"
base_sha: "59d54ab"
---

# 0007 VS Code 拡張 API の外部技術調査

## 目的

設計・実装フェーズは allow.ops に web を持たず公式ドキュメントを引けないため、拡張の最小構成・Webview・FileSystemWatcher の API 事実を調査フェーズのうちに確定する

## DoD

- [x] 観点「VS Code 拡張の最小構成（package.json の engines.vscode / activationEvents / contributes.commands、エントリの activate / deactivate）は何か」への答えが調査結果レポートに書かれている（根拠: wip/30_reports/0007-investigation.md 章 1。1.74 以降 activationEvents は空配列でよいことも確認）
- [x] 観点「Webview パネルの生成・HTML の与え方・拡張と Webview 間の postMessage の作法」への答えが調査結果レポートに書かれている（根拠: 同レポート章 2。createWebviewPanel の署名と Webview の 6 メンバーを表にした）
- [x] 観点「workspace.createFileSystemWatcher がファイルの追加・削除・編集・状態ディレクトリ間の移動をどのイベントで見せるか」への答えが調査結果レポートに書かれている（根拠: 同レポート章 3。移動は onDidDelete + onDidCreate に割れ、順序も保証されない）
- [x] 各答えに参照した公式ドキュメントの URL または @types/vscode の型定義の該当箇所が根拠として添えられている（根拠: 章 1 は index.d.ts:10261、章 2 は 9179-9205/9329-9448/10800-10809、章 3 は 1767-1800/13286。慣行は Webview API と webview-sample の URL）
- [x] 答えが出なかった問いは理由付きで残課題に残っている（根拠: 「確かめられなかったこと」3 件と「残課題」3 件。公式ドキュメントサイトへの遮断を明記）

## 作業内容

- DoD の各項目を順に満たす

## 作業ログ

### 現在地

- 完了。Q7 に答え、調査結果レポート 0007 とその HTML を作った

### うまくいったこと

- 公式ドキュメントサイトが遮断されていたが、`@types/vscode` の型定義を npm から取って一次資料にできた。doc コメントが充実しており、署名だけでなく注意点（`retainContextWhenHidden` のコスト、監視パスが消えると監視が止まる）まで拾えた
- FileSystemWatcher に移動のイベントが無いことに気づけた。差分更新で作ろうとしていたら実装フェーズで詰まっていた

### うまくいかなかったこと

- code.visualstudio.com への WebFetch が実行環境のネットワーク制限（EGRESS_BLOCKED）で通らなかった。Web 検索の要約と型定義で補ったが、ガイドにしか書かれていない注意点を取りこぼしている可能性は残る。残課題に明記した

### 仕様からの逸脱

- なし。このチケットは外部技術調査として `allow.ops` に `web` を明示しており、Web 検索と npm からの型定義取得はその範囲内。書き込みは `wip/30_reports/`・`wip/tmp/`・自チケットに限った

### 判断と根拠

- 差分更新をやめ「イベントを合図に全体を読み直す」方式を推した。移動が「削除 + 作成」に割れ順序も保証されないため、差分更新では一貫した状態を保てない。チケットは多くて数十枚なので読み直しのコストは無視できる
- `retainContextWhenHidden` を使わない方針にした。doc コメントがメモリコストの高さを明記しており、状態の正はチケットのファイルにあるので再表示時に読み直せば足りるため
- 外部リソースを一切読まない自己完結 HTML にする方針にした。`localResourceRoots` を空にでき、CSP も単純になり、`asWebviewUri` も不要になるため

### 拒否・確認・迂回の記録

- WebFetch が code.visualstudio.com への到達を拒否された（EGRESS_BLOCKED）。迂回として Web 検索と npm 経由の型定義取得を使った。ネットワーク制限を回避する操作は行っていない

### 使った AI アセットと効き目

- 敵対的レビュー（サブエージェント）: このチケット自体が指摘 2・14・15 で追加された。指摘が無ければ VS Code API を設計フェーズで調べようとして、`allow.ops` に `web` が無いことに気づかず詰まっていた
- `20-common-step-report-view`: レポートの「確かめられなかったこと」の節があることで、公式ドキュメントに当たれなかった事実を結論から切り離して残せた

### スコープ外で見つけたこと

- `WebviewPanelSerializer` を使うと VS Code の再起動をまたいで Webview を復元できる。今回の受け入れ条件には無いが、実用上あると便利な機能
- `WebviewOptions.enableCommandUris` は真偽値だけでなくコマンド ID の配列も取れる。今回は使わない

### AI アセットに反映すべき内容

- `allow.ops` の `web` を持つ type が `investigation` だけである点は、外部技術に依存する開発で効いてくる。設計・実装フェーズで公式ドキュメントを引けないため、調査フェーズで API 事実を先取りしておく必要がある。この制約自体は妥当だが、フェーズ別ワークスキルの手引きに「外部技術を使う場合は調査で API 事実を確定しておく」旨が書かれていると事故が減る。フィードバック計画で扱うか判断する

### 備考

- レポートの HTML は id 19 件 / リンク 12 件で検査を通過している
- 型定義の取得に使った `wip/tmp/api-probe/` は完了前に削除した
