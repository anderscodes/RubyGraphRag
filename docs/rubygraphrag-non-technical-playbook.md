# RubyGraphRag Non-Technical Playbook

## Goal

This guide explains how a non-technical teammate can work with an engineering team using RubyGraphRag outputs.

You do not need to write code to use this workflow.

## Before You Start

Ask an engineer to run indexing for the target repository and share:
- a short architecture summary,
- key graph query outputs,
- impact paths for the feature or bug you are discussing.
- semantic search results for intent-based questions.

## Standard Workflow

### 1. Define the question in business terms

Examples:
- "What could break if we change checkout discounts?"
- "Which pages are connected to user profile updates?"
- "What components are tied to invoice generation?"

### 2. Ask for a dependency map

Request:
- primary files involved,
- methods/classes directly linked,
- second-order dependencies (one step further).

Also request:
- semantic matches ("similar logic elsewhere") for the same feature area.
- AST-based call map output (more reliable than legacy text-pattern matching).

### 3. Validate impact scope

Use the map to confirm:
- likely affected user flows,
- required QA scope,
- teams that need coordination.

### 4. Turn map into action items

Capture:
- implementation area,
- test area,
- rollout risk,
- fallback plan.

Add:
- quality mode used for semantic search (`local_hash` or `openai`),
- confidence level of semantic matches (high/medium/low).

## New Workflow: Semantic-First Discovery

Use this when you do not yet know exact class/method names.

1. Start with a plain-language business question.
2. Ask engineering to run semantic search in `openai` mode for better recall.
3. Review top matches and select the most likely entry points.
4. Run graph/dependency analysis from those entry points.
5. Finalize scope, QA plan, and rollout risks.

## Three Common Scenarios

### Scenario A: Feature planning

Ask:
- "Show everything that renders this page."
- "Show what methods this controller action calls."
- "Show functions semantically similar to this business rule."

Use results to:
- estimate effort,
- identify hidden dependencies,
- identify required test coverage.

### Scenario B: Incident triage

Ask:
- "What is connected to this failing endpoint?"
- "What recently touched files map into this path?"
- "What code is semantically similar to this failing logic?"

Use results to:
- reduce guesswork,
- narrow root-cause investigation quickly.

### Scenario C: Onboarding a new team member

Ask for:
- top-level module map,
- most connected classes,
- key render chains from controller to view.

Use results to:
- create a practical onboarding checklist.

## Simple Meeting Template

Use this format during planning or incident reviews:

1. Problem statement:
2. User impact:
3. Graph evidence (files/classes/methods):
4. Change scope:
5. QA scope:
6. Risks:
7. Owners and due dates:

## Suggested Questions for Engineers

- "Can you show the direct and indirect dependencies?"
- "What are the top three high-risk files in this change?"
- "What render paths are involved for this UI flow?"
- "What assumptions in this map are uncertain?"
- "Did you run semantic search in `local_hash` or `openai` mode?"
- "How confident are the top semantic matches?"

## Limitations to Keep in Mind

- Graphs help prioritization, not final proof.
- Dynamic runtime behavior may add paths not visible in static indexing.
- Final risk sign-off still needs engineering judgment and testing.
- `openai` mode depends on external API availability and credentials.
- `local_hash` mode is convenient but may miss intent-level similarity.

## Success Criteria

A good RubyGraphRag-assisted review should end with:
- clear impact boundaries,
- agreed test scope,
- fewer "unknown unknowns",
- faster decision-making.
