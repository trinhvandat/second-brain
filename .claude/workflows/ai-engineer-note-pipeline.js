export const meta = {
  name: 'ai-engineer-note-pipeline',
  description: 'Research an AI-engineer wiki topic, synthesize a note per the vault template, then loop junior/middle/senior review until it reads well',
  phases: [
    { title: 'Research' },
    { title: 'Synthesize' },
    { title: 'Review' },
    { title: 'Revise' },
  ],
}

const RESEARCH_SCHEMA = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          claim: { type: 'string' },
          source: { type: 'string' },
          confidence: { type: 'string', enum: ['high', 'medium', 'low'] },
        },
        required: ['claim', 'source', 'confidence'],
      },
    },
  },
  required: ['findings'],
}

const REVIEW_SCHEMA = {
  type: 'object',
  properties: {
    persona: { type: 'string' },
    clarity_score: { type: 'number' },
    applicability_score: { type: 'number' },
    pass: { type: 'boolean' },
    feedback: { type: 'string' },
  },
  required: ['persona', 'clarity_score', 'applicability_score', 'pass', 'feedback'],
}

const DEFAULT_ARGS = {
  topic: "Writing Good Prompts — Use Examples (Few-Shot) — put sample input->output examples in the prompt so the model learns the pattern via in-context learning, instead of only describing the task in words (zero-shot). Few-shot is especially useful when the desired output format is hard to describe in text, when doing classification/extraction with a non-standard label set, or when zero-shot has already failed. Example-selection principles: diversity to avoid the model overfitting to one narrow pattern, consistent formatting between examples and the real question, and example count (usually 2-5) trading off quality against token cost. Distinct from 'provide context' — few-shot is concrete input/output examples, not general background description.",
  category: 'prompt',
  slug: 'writing-good-prompts-use-examples',
  filePath: '/Users/leonard/Workspace/code/personal/second-brain/wiki/tech/ai-engineer/prompt/prompt-writing-good-prompts-use-examples.md',
  roadmapPath: '/Users/leonard/Workspace/code/personal/second-brain/wiki/tech/ai-engineer-roadmap.md',
  roadmapRowTopic: 'Writing Good Prompts — use examples in your prompt (few-shot)',
  relatedNotes: ['prompt-engineering', 'prompt-writing-good-prompts-be-specific', 'prompt-writing-good-prompts-provide-context', 'ai-engineer-roadmap'],
  seedSources: [
    'https://www.promptingguide.ai/techniques/fewshot',
  ],
  seedContext: 'Using examples means putting a few input-to-output examples directly in the prompt so the model learns the pattern via in-context learning, instead of only describing the task in words (zero-shot). Few-shot is especially useful when the desired output format is hard to describe in text, when doing classification/extraction with a non-standard label set, or when zero-shot has already failed. Example selection matters: diverse examples avoid overfitting to one narrow pattern, and consistent formatting between examples and the real question improves reliability.',
}
const rawArgs = (args && typeof args === 'object' && !Array.isArray(args)) ? args : {}
const A = {
  ...DEFAULT_ARGS,
  ...rawArgs,
  relatedNotes: (Array.isArray(rawArgs.relatedNotes) && rawArgs.relatedNotes.length) ? rawArgs.relatedNotes : DEFAULT_ARGS.relatedNotes,
  seedSources: Array.isArray(rawArgs.seedSources) ? rawArgs.seedSources : DEFAULT_ARGS.seedSources,
  seedContext: typeof rawArgs.seedContext === 'string' ? rawArgs.seedContext : DEFAULT_ARGS.seedContext,
}

// NOTE: these rules govern the OUTPUT note file, which must be written in
// Vietnamese with full diacritics (technical terms stay in English, bolded).
// The rules themselves are written in English deliberately — this script is
// code and must stay in English; only the generated wiki note is Vietnamese.
const TEMPLATE_RULES = `
Mandatory conventions for notes under wiki/tech/ai-engineer (the note body must be written in Vietnamese with full diacritics; keep technical terms in English, bolded):
- YAML frontmatter: status: current, updated: 2026-08, sources: [list of URLs used], roadmap: ai-engineer, stage: learning
- H1: "<Concept name> — <one-line description>"
- Right after the H1: a 1-2 sentence TL;DR summarizing the core idea, BEFORE going into details.
- Body organized under H2 headings, prefer bullet-first over long flowing paragraphs.
- The citation "(as of source, confidence: high/medium/low)" is attached inline ONLY to contested claims, important figures, or uncertain/inferred claims — NOT to every sentence/paragraph. Target: at most ~4-6 inline citations for the whole note. The full source list already lives in the 'sources' frontmatter field, no need to repeat it. If you notice you're attaching a citation more than once per paragraph, cut back and keep it only for claims that truly need justification.
- Include at least 1 concrete example (numbers, a table, or code) illustrating the concept, not just an abstract description.
- Use [[other-note]] wikilinks when referencing related notes.
- A "## Liên hệ tới các phần khác" section at the end MUST include a "### Áp dụng với Claude Code" sub-section explaining how this concept applies to Claude Code (the CLI) — even when the answer is "does not apply / not exposed via the CLI", that must still be stated explicitly.
- A "## Giới hạn / open questions" section at the very end, listing points that are uncertain or not yet researched in depth.
`

phase('Research')
const angles = [
  'official documentation & the origin of the concept (docs, original paper if any)',
  'real-world examples, comparison with adjacent concepts (plain LLM call, RAG, a simple workflow)',
  'how Claude Code / the Claude Agent SDK applies or does not apply this concept',
]
const seedBlock = (A.seedSources.length || A.seedContext)
  ? (
      `\nThe user already provided seed context/sources — read/verify these sources and prioritize using them as anchors (still cross-check, do not copy verbatim):\n` +
      (A.seedContext ? `- Seed context/definition: ${A.seedContext}\n` : '') +
      (A.seedSources.length ? A.seedSources.map(s => `- ${s}`).join('\n') + '\n' : '')
    )
  : ''
const researchResults = await parallel(angles.map((angle, i) => () =>
  agent(
    `Research the following AI-engineering topic for a Vietnamese wiki note: "${A.topic}".\n` +
    `Your research angle: ${angle}.\n` +
    seedBlock +
    `Use WebSearch/WebFetch to find credible sources (official docs, papers, reputable technical articles) — in addition to any sources the user provided. ` +
    `For each finding, record: the specific claim, the source URL, and a confidence level (high/medium/low) based on source reliability. ` +
    `Return structured findings, no need to write prose.`,
    { phase: 'Research', schema: RESEARCH_SCHEMA, label: `research:${i}` }
  )
))
const allFindings = researchResults.filter(Boolean).flatMap(r => r.findings)
log(`Collected ${allFindings.length} findings from ${angles.length} research angles.`)

phase('Synthesize')
const synthesizePrompt =
  `Write a Vietnamese wiki note at the ABSOLUTE path: ${A.filePath}\n` +
  `Topic: "${A.topic}" (category: ${A.category}, roadmap: ai-engineer).\n` +
  `Below are the researched findings (may overlap across sources) — DEDUPE them (drop claims that repeat the same point, keep the best source), then synthesize into a complete note:\n` +
  JSON.stringify(allFindings, null, 2) + '\n\n' +
  TEMPLATE_RULES + '\n' +
  `Related notes in the vault you may wikilink to if relevant: ${A.relatedNotes.map(n => `[[${n}]]`).join(', ')}.\n` +
  `After writing the note file, OPEN ${A.roadmapPath}, find the table row whose Topic column matches (or starts with) the text "${A.roadmapRowTopic}", then EDIT that row per the following rules (use Edit, do NOT rewrite the whole row unless necessary):\n` +
  `  - Note column: if it currently reads "—", replace it with "[[${A.category}-${A.slug}]]"; if it already has another link (e.g. this row is shared by multiple notes), APPEND ", [[${A.category}-${A.slug}]]" to the end of the existing link list, do not remove the existing link.\n` +
  `  - Stage column: if it currently reads "planned", change it to "learning"; if it is already "learning" or "done", LEAVE IT AS IS, do not downgrade it.\n` +
  `Use Write to create the note file, use Edit to update the roadmap hub. Return a short summary of what was written (no need to quote the full content).`
const synth = await agent(synthesizePrompt, { phase: 'Synthesize', label: 'write-note' })
log(`Draft note written at ${A.filePath}`)

const PERSONAS = [
  { key: 'junior', desc: 'a fresh-graduate engineer, new to AI engineering, unfamiliar with the terminology' },
  { key: 'middle', desc: 'an engineer with 3-5 years of experience, comfortable with code but new to LLMs/agents' },
  { key: 'senior', desc: 'a senior/backend engineer, used to production systems, strict about real-world applicability' },
]

async function runReviewRound(roundLabel) {
  return parallel(PERSONAS.map(p => () =>
    agent(
      `Read the note at the ABSOLUTE path: ${A.filePath}\n` +
      `Role-play as ${p.desc}. Evaluate this note on 2 criteria:\n` +
      `1. Applicability: after reading, can you actually apply this in real work, or is it just theory?\n` +
      `2. Clarity/scannability: at your level, does it feel confusing or too dense? Is there a clear TL;DR? Are there concrete examples?\n` +
      `MANDATORY CHECK before scoring clarity: count how many times the phrase "(as of ..., confidence: ...)" appears in the note. If it appears more than 6 times, OR appears in nearly every sentence/paragraph — automatically cap clarity <= 5 and pass = false regardless of other strengths, and state clearly in the feedback how many occurrences you counted and where to consolidate/trim them.\n` +
      `Score 1-10 on each criterion, decide pass (>=7 on both criteria AND you'd confidently apply this after reading) or fail, and give specific feedback (which sentence/paragraph is problematic, what to fix).`,
      { phase: 'Review', schema: REVIEW_SCHEMA, label: `${roundLabel}:${p.key}` }
    )
  ))
}

phase('Review')
let reviews = (await runReviewRound('round0')).filter(Boolean)
let rounds = 0
const MAX_ROUNDS = 2

phase('Revise')
while (!reviews.every(r => r.pass) && rounds < MAX_ROUNDS) {
  rounds++
  const failing = reviews.filter(r => !r.pass)
  log(`Review round ${rounds}: ${failing.length}/${reviews.length} personas have not passed — revising.`)
  const feedbackBlock = failing.map(r => `- [${r.persona}] clarity=${r.clarity_score}, applicability=${r.applicability_score}: ${r.feedback}`).join('\n')
  await agent(
    `Revise the note at the ABSOLUTE path: ${A.filePath} based on the following review feedback (keep the frontmatter unchanged, only edit the body to be clearer/more applicable):\n` +
    feedbackBlock + '\n\n' +
    TEMPLATE_RULES + '\n' +
    `Use Edit to modify the file, do not rewrite the whole thing unless truly necessary.`,
    { phase: 'Revise', label: `revise:round${rounds}` }
  )
  reviews = (await runReviewRound(`round${rounds}`)).filter(Boolean)
}

const approved = reviews.every(r => r.pass)
if (approved) {
  log(`Note passed review after ${rounds} revise round(s).`)
} else {
  log(`Note did NOT pass all reviews after ${MAX_ROUNDS} revise round(s) — remaining feedback needs a human look.`)
}

return {
  filePath: A.filePath,
  rounds,
  approved,
  finalReviews: reviews,
}
