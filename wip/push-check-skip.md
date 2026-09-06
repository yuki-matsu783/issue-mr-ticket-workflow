# push 前チェックのスキップ記録

- 項目 2: 全体まとめチケット 0011 は `finalize.sh release` が終わるまで作業中のまま残る仕様（`10-task-overall-summary` の手順 7 が作業中の状態で push する）。宣言は `ticket.sh create --allow-ops` を 7 回渡したが最後の 1 つ（`remote-write:draft-ready`）しか frontmatter に入らず、`remote-write:push` が落ちた。着手済みチケットの `allow` は WF208 で変更できないため、この記録でスキップする。`--allow-ops` の取りこぼしは別 issue #55 に登録済み
