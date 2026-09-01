---
type: requirement
title: {{TITLE}}
description: {{DESCRIPTION}}
tags: [requirement, {{TAGS}}]
keywords: [{{KEYWORDS}}]
---

# {{TITLE}}

## 概要

<!-- 何の要件かを 1〜3 行で。続けて 背景（なぜ要るか）/ 目的（何を達成するか）/ スコープ（含む・含まない。含まないには担い先を添える）を分けて書く -->

{{OVERVIEW}}

- **背景**: {{BACKGROUND}}
- **目的**: {{GOAL}}
- **スコープ**:
  - 含む: {{IN_SCOPE}}
  - 含まない: {{OUT_OF_SCOPE}}（担い先: {{OUT_OF_SCOPE_OWNER}}）

---

## ユーザーストーリー

<!-- 誰が（役割）・何を望み・なぜか。外部の観察者の視点で書く -->

**[As a]** {{AS_A}}として、

**[I want]** {{I_WANT}}、

**[So that]** {{SO_THAT}}ため。

---

## 受け入れ基準（Acceptance Criteria）

<!-- EARS（When 〜 Shall / If 〜 Then / Shall not）で書く。節はこの順に置き、見出しは規定文言で始める。内部構造（スクリプト名・判定順・スキーマ）は書かず仕様書へ -->

### メインフロー

- **When** {{MAIN_WHEN}}、**Shall** {{MAIN_SHALL}}

### 代替フロー

- **If** {{ALT_IF}}、**Then** {{ALT_THEN}}

### 例外フロー

- **If** {{EXC_IF}}、**Then** {{EXC_THEN}}
- **When** {{EXC_WHEN}}、**Shall not** {{EXC_SHALL_NOT}}

### 他のスキル・機構との整合

- **Shall** {{CONSISTENCY_SHALL}}

---

## 前提条件

<!-- この要件が成り立つために、外側で満たされているべきこと -->

- {{PRECONDITION}}

---

## 制約条件

<!-- 技術的 / ビジネス的 / 外部的な制約。守るべき境界を書き、実現手段は書かない -->

- **技術的制約**: {{TECHNICAL_CONSTRAINT}}
- **ビジネス的制約**: {{BUSINESS_CONSTRAINT}}
- **外部的制約**: {{EXTERNAL_CONSTRAINT}}

---

## 依存関係

<!-- 呼び出し元・呼び出し先・前提となるアセットや外部ツール -->

- {{DEPENDENCY}}

---

## 非機能要件

<!-- 再現性・追跡性・一貫性・安全性など、観察できる品質の要件を表で -->

| 項目 | 説明 |
|------|------|
| {{NFR_ITEM}} | {{NFR_DESCRIPTION}} |
