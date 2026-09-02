---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0027"]
executor: main
human_review: {required: true, reason: "基準どおり（振る舞いが変わる。承認④により opus の敵対的自己レビューで代替）"}
adversarial_review: {required: true, reason: "基準どおり（中核である hook-common.sh / scope.sh / 読み込み行の変更は機構自身を止め得る）"}
allow:
  write: [".claude/skills/**"]
  ops: ["build-test"]
started_at: "2026-09-02T14:02:51+09:00"
completed_at: ""
base_sha: "c5484d3"
---

# 0033 レビュー 1 巡目の是正 1/2: 読み込み行の回帰・worktree 偽装・curl の分類・redact の退行・切り詰めの JSON 破壊

## 目的

0027 が入れた回帰 1 件と、0027 が塞いだつもりで塞げていなかった穴 4 件を直す。0029 / 0030 が同じ形を 10 本に複製する前に閉じる

## DoD

- [ ] 読み込み行の 3 段目に `|| true` が戻り、雛形 2 本と実体 22 本が再びバイト一致する。リポジトリ外・git あり・CLAUDE_PROJECT_DIR 無しで雛形由来のスクリプトが exit 0 で nop フォールバックに到達する（0027 は exit 128 だった。仕様 20-common-step-shell-script.md:116 が明記する条件）（根拠: ）（根拠: ）
- [ ] SS-T04 に「git あり・リポジトリ外」のケースが増え、`|| true` を外すと落ちる（現行の SS-T04 は make_restricted_path で git を PATH から外すため 3 段目に入らず、この回帰を拾えなかった）（根拠: ）（根拠: ）
- [ ] `__hc_is_worktree_of` の経路 (a) が `gitdir:` の指す先の実在と相互参照まで要求し、`.git` ファイルを 1 本置くだけの偽装で HOOK_WORKTREE が移らない。あわせて候補が HOOK_ROOT の配下なら worktree でないとして先に弾く（根拠: ）（根拠: ）
- [ ] HK-T18 の case_worktree に偽の `.git` ファイル（実在しない worktree を指す）のケースと、`worktrees/*/gitdir` を消した負の対照が入り、経路 (a)(b) の両方に検出力がある（根拠: ）（根拠: ）
- [ ] `_sc_classify_web` がリダイレクト（CP_REDIRECTS / CP_WRITE_TARGETS）を SC_TARGETS に合流させ、`curl <url> > .claude/hooks/lib/hook-common.sh` が write として宛先付きで返る。送信側と出力先が同時に成り立つ場合の呼び手への返し方を決めて書く（根拠: ）（根拠: ）
- [ ] `_sc_classify_web` が束ねた短オプション（`-sd` `-sO` `-sD`）を 1 文字ずつ走査して判定し、`--json` `--data-ascii` `--form-string` `--mail-*` `--upload-file*` を送信側に、`--dump-header` `--cookie-jar` `--trace*` `--etag-save` `--stderr` `--output*` `--remote-name*` を出力先に含める。長オプションは前方一致にする（根拠: ）（根拠: ）
- [ ] web の分類テストに、上の抜け 7 種（`curl -sd @f URL` / `curl --json {} URL` / `curl -sO URL` / `curl -D h.txt URL` / `curl --data-ascii a URL` / `curl --form-string a=b URL` / `curl URL > path`）が入り、直す前は落ちることを確かめた（根拠: ）（根拠: ）
- [ ] `__hc_redact_to_reply` 規則 5 が現実的な入力で退行していない。0027 後は decisions の 1 行（242 字）で 21ms・多語 16890 字で 1084ms と超線形だった。40 字以上の候補が無ければ規則 5 を丸ごと飛ばす短絡を入れ、ループからも `${#s}` の再計算と `${s:pos:...}` を外す。計測値を作業ログに残す（根拠: ）（根拠: ）
- [ ] 規則 5 の書き直しが旧実装と同じ結果を返す（代表ケース + ランダム入力での差分 0）。1 語 4000 字の病的ケースが遅くならない（根拠: ）（根拠: ）
- [ ] `hc_append_jsonl` の最終切り詰めが JSON を壊さず、`__HC_MAX_LINE` を超えない。0027 後は切断位置の直前が単独のバックスラッシュだと `\…"}` になって jq が弾き、長さも 4097〜4098 バイトで 4096 を超えていた（根拠: ）（根拠: ）
- [ ] HK-T17 に target / note を持たない 6000 字の行のケースが入り、出来上がりが `jq -e .` を通り 4096 バイト以下であることを固定する（根拠: ）（根拠: ）
- [ ] block-chmod の高速前置判定が正規化後の文字列にも当たり、`c\hmod` `ch""mod` `ch''mod` が拒否される。`$` / `${` で始まる実行体が opaque になり `CMD=chmod; $CMD +x a` が制御方式 4 で拒否される（根拠: ）（根拠: ）
- [ ] block-chmod の制御方式 4 の opaque 判定が CP_LOWER（コマンド全体）ではなく当該セグメントを見る。`grep chmod f | xargs echo` が拒否されない（0027 は拒否していた = 過剰拒否）（根拠: ）（根拠: ）
- [ ] BC-T05 が検出力を持つ。前置判定の行（`(( _bc_hit )) || hook_allow`）を消すと落ちる形にする。0027 の BC-T05 は cmdpos.sh を cp で退避して戻すだけで壊しておらず、前置判定を削っても 3 つの assert がすべて通った。仕様 BC-T05 の「cmdpos.sh を呼ばずに通る」を成立させるなら `. cmdpos.sh` を前置判定の後ろへ動かす（根拠: ）（根拠: ）
- [ ] HK-T16（読み込み系 3 関数の戻り値 0/1/2 の区別と、frontmatter.sh を隠した環境で scope.sh が無出力）を test_scope.sh に実装する。0027 は DoD で「HK-T16 が通る」と主張したが実体は 0 件だった。scope_load_ticket の戻り値 2 の経路は現状 1 件もテストされていない（根拠: ）（根拠: ）
- [ ] SS-T05 が `__ss_load` を含むのに行頭一致しないファイルを不一致として報告し、走査対象の総数と読み込み行を持つ本数の両方を出す。雛形 2 本のバイト一致も SS-T05 の中で固定する（根拠: ）（根拠: ）
- [ ] `scope.sh` 冒頭の自己文書（提供する関数のシグネチャ・「jq は設定の読み込みで 1 回」・scope_classify の値集合）が現物に一致する。0027 の変更に追随しておらず、`scope_load <scope-limits.json> [type]` のまま・`web` と `remote-write:upload` が欠けていた（根拠: ）（根拠: ）
- [ ] `hook_record` が `HOOK_EVENT` も `__hc_json_str` に通す（唯一エスケープを経ない外部由来のフィールドだった。ルール logger.md のセキュリティ節と issue #6 の申し送り H1）（根拠: ）（根拠: ）
- [ ] `__hc_resolve_worktree` のパス正規化（`/c/…` ↔ `C:/…`）が HOOK_ROOT と候補の両方に同じ形で掛かる。0027 は cwd 側だけ正規化しており、表記が違うと本物の worktree でもルートに留まった（実測で確認済み）（根拠: ）（根拠: ）
- [ ] 全件テストが FAIL 0 で通り、この巡で足したケースが直す前は落ちることを 1 件ずつ確かめた（根拠: ）（根拠: ）

## 作業内容

- 先に読み込み行の `|| true` を戻す（雛形 → 実体 22 本の順。逆にすると SS-T05 がどちらの向きにも落ちる）
- テストを先に足して落ちることを確かめてから実装を直す（BC-T05・HK-T18・HK-T17・web の 7 種）
- `.claude/docs/**` には書かない（実装フェーズの deny）。仕様の書き戻しは 0032 へ送る
- 計測は `EPOCHREALTIME` で行う（`date` の fork を挟むと測定対象より重い）

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
