---
name: {{SKILL_NAME}}
description: >
  {{WHAT_IT_DOES}}
  Use when {{TRIGGER_CONDITIONS}}.
---

# {{SKILL_NAME}} — {{ONE_LINE_TITLE}}

<!-- 冒頭段落: このスキルで禁止すること・してはいけない操作の要約（3〜5 行）。目的より前、読み手が最初に目にする位置に置く。frontmatter は name / description の 2 項目だけにする（type / title / tags などの文書用の項目は付けない。Claude Code のスキル発見が読むのはこの 2 項目） -->
{{PROHIBITIONS}}

## 目的

{{PURPOSE}}

- 要件: `.claude/docs/00_requirement/skills/{{SKILL_NAME}}.md`
- 仕様（正）: `.claude/docs/10_spec/skills/{{SKILL_NAME}}.md`

## 手順

{{STEPS}}

## 参照

{{REFERENCES}}

## エラー時の対処

| 状況 | 対処 |
|------|------|
{{ERROR_HANDLING}}
