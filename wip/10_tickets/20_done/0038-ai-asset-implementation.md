---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0032"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: false, reason: "実装フェーズの敵対的レビューは上限 2 回に達している（0036 の指摘への対応そのもの）"}
allow:
  write: [".claude/hooks/20-PreToolUse/**", "logs/**", "wip/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: "2026-09-04T14:05:33+09:00"
completed_at: "2026-09-04T14:10:23+09:00"
base_sha: "3917655"
---

# 0038 S13 中核: 削除の許可判定を締める（敵対的レビュー 2 回目の指摘 3 件）

## 目的

0036 で開けた削除の経路が、ディレクトリごとの削除・展開前の文字列・宣言外の共通許可範囲で許可範囲の外に届く穴を塞ぐ

## DoD

- [x] 対象の配下に共通の保護範囲・毎回確認・種類の禁止範囲が入り得るときは削除を WF205 で拒否する（rm -rf .claude/hooks/config が通らない）（根拠: `__wg_delete_covers_guarded` が `common.protected` / `common.confirm` / `common.state_files` / `t.<種類>.deny` / `t.<種類>.confirm` の各 glob を `<対象>/` の接頭辞で見る。WG-T18 で `rm -rf .claude/hooks/config`・末尾 `/` 付き・`git rm -r .claude/hooks`・`rm -rf logs` の 4 件が WF205）
- [x] 展開前の文字列（* ? [ { $ バッククォート ~ , を含む語）は対象を読み取れないものとして WF205 で拒否する（rm -rf .claude/hooks/* が通らない）（根拠: `__wg_check_delete_targets` の文字検査。WG-T18 で glob・ブレース・変数・PowerShell 風のコンマ区切り・`~` の 5 件が WF205）
- [x] 削除が通るのは wip/tmp/** と logs/** か、チケットの allow.write に明示された範囲だけ。common.allow だけで通る範囲（wip/10_tickets/** など）は宣言が無ければ消せない（根拠: `__wg_delete_ok` が `scope_resolve` の allow に加えて `SC_DECL_WRITE` との一致を要求する。WG-T18 で 0003（apl のみ宣言）の `rm wip/10_tickets/00_todo/0011-x.md`・`rm wip/30_reports/a.md` と、宣言が空の 0005 の `rm wip/30_reports/a.md` が WF205。`rm wip/tmp/a.txt` は両方で allow）
- [x] 進行状態ファイル（logs/review-state.json など）はコマンドで消せない（根拠: `__wg_delete_ok` が置き場の判定より先に `common.state_files` を見る。WG-T18 で `rm logs/review-state.json`・`rm logs/mr.json` が WF205、`rm logs/sh/ticket.log` は allow）
- [x] 0036 で通した削除（rm .claude/hooks/20-PreToolUse/x.sh・git rm -r --cached .claude/hooks/old/）は今までどおり通る（退行なし）（根拠: WG-T18 の既存 5 件の allow がそのまま通っている）
- [x] WG-T18 に上記の再現テストが足され、run-tests.sh --filter '*workflow_guard*' が全通過（根拠: `OK: 1 本 / 18 件` / `passed=183 failures=0`。166 → 183 アサーション）

## 作業内容

- DoD の各項目を順に満たす

## 作業ログ

### 現在地

- 完了（3 つの穴を塞ぎ、WG-T18 を 16 → 33 アサーションに広げた）

### うまくいったこと

- 3 件とも「対象を 1 本のパスとして `scope_resolve` に渡すだけでは足りない」という同じ根に行き着いた。ディレクトリ（配下を巻き込む）・展開前の文字列（パスが決まらない）・共通の許可範囲（宣言の外）で、それぞれ別の関数に分けて書けた
- 保護範囲の判定を glob の**文字列の接頭辞**で見る形にしたので、実際にファイルシステムを触らずに済む（フックはツール呼び出しのたびに走るので外部プロセスを増やしたくない）

### うまくいかなかったこと

- 0036 の実装は「許可範囲の内側なら消してよい」を素直に書いただけで、`.claude/hooks/**` を宣言したチケットが `.claude/hooks/config` を丸ごと消せることに気づいていなかった。**glob は自分より上のディレクトリに一致しない**という当たり前の性質が、削除では逆向きの穴になる

### 仕様からの逸脱

- **S13-1**: 0036 の逸脱（S12-1 / S12-2）に加えて、削除の判定に「宣言（`allow.write`）との一致を要求する」「配下に保護範囲を含むディレクトリは拒否する」「展開前の文字列は拒否する」の 3 条件を足した。仕様（`10_spec/hooks/20-PreToolUse/workflow-guard.md` 制御方式 6）は削除の例外自体を書いていないので、設計反映では 0036 と合わせて 1 つの節にまとめる

### 判断と根拠

- **宣言（`SC_DECL_WRITE`）との一致を必須にした**: `scope_resolve` の allow には共通の許可範囲（計画書・レポート・未着手チケット）が含まれる。削除は書き換えと違って取り返しがつかないので、「種類の上限に入っている」だけでは足りず「このチケットが自分で宣言した」ことを求める。宣言が空のチケットは置き場（`wip/tmp/**` / `logs/**`）の外を消せない
- **進行状態のファイルを置き場の判定より先に見る**: `logs/**` は置き場として無条件に通していたので、そのままだと `logs/review-state.json` が消せてしまう。`scope_resolve` は同じ除外を持っているが、置き場の早期 return で追い越していた
- **展開前の文字列は「読み取れない」側に倒した**: `.claude/hooks/*` は glob として宣言 `.claude/hooks/**` に一致してしまう。展開後に何になるかはフックからは決まらないので、`_`（クォートで潰れた対象）と同じ扱いにする
- **ディレクトリかどうかをファイルシステムに聞かない**: 存在しないパスや相対の解決で判断がぶれるうえ、フックのホットパスで `test -d` を増やしたくない。glob の接頭辞一致なら「配下に保護範囲を持ち得るか」だけで判定でき、判定できないときは拒否側に倒れる

### 拒否・確認・迂回の記録

- 無し（この変更で新たに拒否された操作は無い）

### 使った AI アセットと効き目

- 敵対的レビュアー（2 回目・中核コード担当）: 3 件とも実際に `cmdpos_parse` と `scope_match` を走らせた裏取り付きで、再現条件がそのままテストになった。特に「`.claude/hooks/config` はディレクトリ自身が confirm の glob に一致しない」は、実装者が自分では見つけにくい

### スコープ外で見つけたこと

- 同根の穴が作成・更新側（`cp` / `mv` の宛先が `wip/tmp/$X` など）にもある。ただしそちらは置き場が `wip/tmp/**` と `logs/**` に限られていて被害範囲が狭いので、この変更には含めていない

### AI アセットに反映すべき内容

- 仕様の制御方式 6 に、削除の例外を 0036 + 0038 の最終形（置き場 or 宣言の一致・ディレクトリの扱い・展開前の文字列・進行状態のファイル）で 1 節にまとめて書く

### 備考
