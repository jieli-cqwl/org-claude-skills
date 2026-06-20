# Product-director Real Transcript Dogfood

This directory defines templates and synthetic fixtures for staged `product-director` dogfood review.

It does not contain active standard-chain state, does not create `brief.json`, `phase-prd.json`, `worklog.md`, `contracts/active-doc-scope.yaml`, or a route-decision artifact, and does not start a dogfood run.

Use this package only after a real complex-demand candidate has been selected and transcript evidence handling has been confirmed.

Stages:

- Stage 1: one-transcript smoke.
- Stage 2: three-transcript stability sample.
- Stage 3: five-transcript promotion gate.

Promotion target is limited to `default_complex_demand_entry`.
