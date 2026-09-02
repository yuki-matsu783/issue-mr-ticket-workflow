---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0024"]
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

# 0025 レビュー指摘: worktree の作業ツリーと web の送信側・出力先（A3・A4・A5・B7・B8）

## 目的

worktree に入るとフックが本流のチケットを見て機構が無効化される。あわせて web の分類が curl の送信側を勘定していない穴を塞ぐ

## DoD

- [ ] Claude が worktree に入ると CLAUDE_PROJECT_DIR は本流のまま cwd が worktree を指す事実（hooks.md:598-601）が §2 に書かれ、作業ツリーの基準がこの場合も worktree 側に解決する。git を呼ばずに解決でき、フェーズ 4c に実測項目がある（A3）（根拠: ）
- [ ] curl / wget の送信側（-T・--upload-file・-d @・--data・--data-binary・-F・-X の GET/HEAD 以外、wget の --post-file・--post-data・--method）が web の宣言では通らず、リモート書き込みとして拒否される。WG-T15 に負のケースがある（A4）（根拠: ）
- [ ] 出力先オプションの取得方法が cmdpos_operands ではなく引数列の走査であることが §8 に書かれ、URL を出力先と誤認しない。-O と wget の既定の出力先をどのディレクトリ基準で解決するかも決まっている（A5）（根拠: ）
- [ ] 10-task-investigation-exec の要件と仕様に残る「リポジトリ外への問い合わせ禁止は機構では強制されない」が事実に合わせて直り、横断要件の自制の列挙からも外れている。i0009-41 の影響にこの 2 文書が加わっている（B7）（根拠: ）
- [ ] 20-common-step-shell-script の scope_classify の分類表に web が加わっている（または分類の正を §8 に一本化して再掲をやめている）（B8）（根拠: ）
- [ ] 決定の経緯が DDR i0009-55〜58 の範囲に残っている（根拠: ）

## 作業内容

- 指摘の原文は wip/30_reports/0022-ai-asset-design-appendix-A.md を参照する
- A3 の worktree は要件が並行作業の手段として明示的に推奨している（自己改善ワークフロー機構.md:163）。無効化されると機構全体が効かない

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
