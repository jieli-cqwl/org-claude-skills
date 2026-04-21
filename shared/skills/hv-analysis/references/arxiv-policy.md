# arxiv Policy

## When To Query

Query arxiv for technology concepts, algorithms, research fields, model methods, academic terms, and any request that asks for papers, academic background, or research progress.

Skip arxiv for companies, products, people, games, business events, and geopolitical events unless the user explicitly asks for papers.

## Relevance Rules

Prefer papers whose title, abstract, and category directly match the research object.
Do not add weak matches for volume.
If no strong match exists, record that no strong arxiv evidence was found.

## Script Use

Use `scripts/arxiv_search.py --query "<query>" --max-results 5`.
The script must use timeouts and output JSON.
If a required arxiv query fails, full completion is blocked until fixed or the user changes scope.

## Contract Phrases

- skip arxiv for non-academic objects by default.
- do not add weak matches to fill space.
