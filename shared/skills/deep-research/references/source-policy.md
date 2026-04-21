# Source Policy

## Source Tiers

Primary sources include official docs, release notes, source repositories, papers, standards, company announcements, filings, direct interviews, and direct statements. Use these for factual claims whenever available.

Secondary sources include media reports, analyst notes, books, high-quality blogs, and conference coverage. Use these for context and interpretation, not to override primary sources.

Community sources include forums, GitHub issues, social posts, reviews, comments, Discord or Slack excerpts provided by the user, and informal user reports. Use these for sentiment and workflow evidence with explicit sample bias notes.

## Evidence Records

Each source in `sources.json` must include:

- `title`
- `url`
- `tier`
- `published_or_accessed`
- `claims_supported`
- `limitations`

## Conflict Handling

When sources conflict, record the conflicting claims, dates, and current judgment. Strict mode must include strongest opposing evidence and invalidation conditions.

## Sample Bias

User sentiment and community reports are not representative by default. Label sample bias and avoid turning anecdotes into hard conclusions.
