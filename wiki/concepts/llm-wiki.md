# LLM Wiki

A second-brain architecture proposed by Andrej Karpathy (as of 2026-04, gist.github.com/karpathy):
drop the vector DB for mid-sized corpora (~400k words) and let the LLM reason directly over Markdown
across 3 stages raw → compile → lint. The `.md` files are the traceable source of truth. (confidence: high)

The lint stage can be run periodically rather than by hand — see [[auto-lint-cron]] for that extension.

Related: [[zettelkasten]] (atomicity applied to notes), and the foundation of this vault — see [[index]].
