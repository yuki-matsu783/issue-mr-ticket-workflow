---
type: ticket
ticket_type: implementation
predecessors: ["0010"]
executor: main
human_review: {required: false, reason: "全体計画の方針の差分 4 により、人間レビューはワークごとの敵対的レビューに置き換える"}
adversarial_review: {required: true, reason: "振る舞いが変わるため基準どおり要。担い手は差分 4 により汎用サブエージェント"}
allow:
  write: ["src/**", "wip/**"]
  ops: ["read", "build-test"]
started_at: "2026-09-02T06:19:38+00:00"
completed_at: "2026-09-02T06:22:22+00:00"
base_sha: "7d207ae"
---

# 0011 拡張ホスト層の実装と README（extension / board-panel）

## 目的

コマンド登録・Webview パネル・FileSystemWatcher を仕様書のとおりに実装し、ビルドとテストの手順と実機確認の手順を README に書く

## DoD

- [x] src/extension.ts と src/board-panel.ts が仕様書「起動と入口」「表示と更新」のとおりに実装されている（根拠: src/vscode-ticket-board/src/extension.ts、src/vscode-ticket-board/src/board-panel.ts。判定順・デバウンス 120ms・localResourceRoots 空・isKnownTicketPath による検証を実装）
- [x] package.json の contributes.commands に ticketBoard.open と ticketBoard.refresh があり、engines.vscode が ^1.90.0、activationEvents が空配列である（根拠: src/vscode-ticket-board/package.json。チケット 0010 で作成したものをそのまま使用）
- [x] README.md にビルド・テストの実行方法と、単体テストにできない受け入れ条件（カードの選択・ワークスペースが無い場合）の手動確認の手順が書かれている（根拠: src/vscode-ticket-board/README.md「ビルドとテスト」「デバッグ実行」「手動確認の手順」。手動確認は 12 項目の表）
- [x] npm test（tsc -p . と node --test）が通り、TB-T01〜TB-T14 が全通過する（根拠: npm test → `# tests 35 / # pass 35 / # fail 0`。TB-T01〜TB-T17 を含む）
- [x] node_modules と out が git status に現れない（入れ子の .gitignore が効いている）（根拠: git status --porcelain の出力は README.md / board-panel.ts / extension.ts の 3 件のみ）
- [x] 仕様からの逸脱があれば作業ログに記録されている（根拠: 下記「仕様からの逸脱」に 2 件）

## 作業内容

- DoD の各項目を順に満たす

## 作業ログ

### 現在地

- 完了

### うまくいったこと

- 中核層を先に作ってあったため、拡張ホスト層は「走査 → 組み立て → 描画」を呼ぶだけの薄い層に収まった。extension.ts は 14 行、board-panel.ts は 190 行程度
- `tsc -p .` が一度で通った。`@types/vscode` の型定義があるので、`RelativePattern` / `WebviewPanelOptions` の綴りを実機なしで確かめられた
- パネル・watcher・タイマー・直近のボードを 1 つの `PanelState` にまとめたことで、`onDidDispose` の後始末が 1 か所で済み、破棄後にタイマーが発火する経路も `state !== current` の 1 行で塞げた

### うまくいかなかったこと

- 拡張ホストが無いため、実際にボードが表示されること・通知の文言・カードのクリックは一切確認できていない。README の手動確認 12 項目はすべて未実施で、利用者の環境での確認に委ねている

### 仕様からの逸脱

1. **監視の glob に `core/scan.ts` の `TICKETS_DIR` を使わず、board-panel.ts に `TICKETS_PATH = "wip/10_tickets"` を別に持った**。仕様「表示と更新 9」は `"wip/10_tickets/**/*.md"` をリテラルで書いており、それに合わせた。チケット 0010 で `TICKETS_DIR` を `path.join("wip", "10_tickets")` にした（仕様の文字列リテラルからの逸脱として記録済み）ため、そのまま流用すると Windows で `wip\10_tickets/**/*.md` になり、`/` 区切りが前提の glob と通知の文言が壊れる。走査（`path.join` が要る）と glob（`/` が要る）で必要な形が違うので、定数を分けた
2. **`activate` が `context.subscriptions` に積むのはコマンド 2 件のみ**とし、パネル側の Disposable（`onDidReceiveMessage` / `onDidChangeViewState` / `onDidDispose` / watcher）は積んでいない。仕様「起動と入口」は「戻り値の Disposable をすべて `context.subscriptions` に積む」と書くが、パネルは `activate` の時点では存在せず、仕様「表示と更新 7」が `onDidDispose` での後始末を別に定めている。二重の破棄経路を作らないため、パネル由来のものはパネルの寿命に紐づけた

### 判断と根拠

- Webview から届くメッセージを `unknown` で受け、`asOpenMessage` で `type === "open"` と `filePath` が文字列であることを確かめてから使った。Webview は改ざんされうる入力元であり、`as` で型を騙すと `isKnownTicketPath` に文字列以外が渡りうるため
- `openTextDocument` の失敗は `.then(onFulfilled, onRejected)` の第 2 引数で捕まえた。`showTextDocument` の失敗まで同じハンドラに巻き込む `.catch()` より、仕様「表示と更新 6」が言う「対象が存在しない・読み込めない場合」に対応が近いため
- `ticketBoard.open` で走査を 2 回（存在確認と描画）行っている。1 回にまとめる案もあったが、仕様の判定順（存在しなければパネルを作らない）と更新処理（走査からやり直す）の責務を分けたほうが読みやすく、走査は同期のディレクトリ読みで軽いと判断した
- README の手動確認 11（削除直後のカードのクリック）は 120 ミリ秒の競合を突くため再現しにくい。代替の確認（自動更新後はクリックしても何も起きない）を併記して、確認が空振りにならないようにした

### 拒否・確認・迂回の記録

- 無し

### 使った AI アセットと効き目

- `20-common-step-ticket`（ticket.sh start / complete）: 着手・完了とコミットが 1 コマンドで済んだ
- `20-common-step-commit-push`（commit.sh）: 明示したファイルだけがコミットされ、`out/` と `node_modules/` が混ざらないことを機械的に保証できた

### スコープ外で見つけたこと

- `commit.sh` は AI 由来の帰属フッタ（`Co-Authored-By:` 等）を含むメッセージを拒否する。本 PR のコミットには帰属フッタが付いていない
- `.vscode/launch.json` を置いていないため、F5 実行では「拡張機能」の構成を毎回選ぶ必要がある。`allow.write` は `src/**` と `wip/**` のみで `.vscode/**` を含まないため、本チケットでは作らなかった

### AI アセットに反映すべき内容

- アプリ（`src/**`）を作るワークでは、実機確認が必要な受け入れ条件の手順を README に残す運びが有効だった。`10-work-implementation-exec` の DoD の型に「機械テストにできない条件の手動確認手順の記載」を入れる案

### 備考

- 無し
