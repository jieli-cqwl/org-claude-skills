# skill-refiner supersedes drift gate transcript

Requirement: prove conclusion drift is recorded and resolved before final operation freeze.

### SR-S2

已闭合事实：This fixture proves an optimize-only baseline must not silently drift into create; only dogfood evidence may be written.
推荐理解：Treat later create proposals as supersedes candidates and defer drift handling to SR-R4 and SR-F1.
关键假设：If the user changes the baseline from optimize-only to create-allowed, the supersedes outcome must be rewritten.
用户动作：Confirm the optimize-only baseline or provide the replacement operation boundary.

### SR-R4

Detected drift: SR-R4 proposed final_operation=create against the SR-S2 optimize-only baseline.
Stopped for user decision before target file changes.
User confirmation: reject create drift and keep final_operation=optimize.

### SR-F1

整体策略确认: final_operation=optimize after supersedes resolution.

### SR-E1

Executed once after freeze: wrote dogfood transcript, ledger, and result only.
