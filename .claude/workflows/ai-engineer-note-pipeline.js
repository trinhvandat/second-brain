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
  topic: 'The agent loop — perceive (nhan input/observation) -> reason/plan (LLM quyet dinh buoc tiep theo) -> act/invoke tool (goi tool that) -> observe/reflect (doc ket qua, lap lai hoac dung)',
  category: 'agent',
  slug: 'loop',
  filePath: '/Users/leonard/Workspace/code/personal/second-brain/wiki/tech/ai-engineer/agent/agent-loop.md',
  roadmapPath: '/Users/leonard/Workspace/code/personal/second-brain/wiki/tech/ai-engineer-roadmap.md',
  roadmapRowTopic: 'The agent loop — perceive → reason/plan → act/invoke tool → observe/reflect',
  relatedNotes: ['agent-what-are-ai-agents', 'llm-reasoning-vs-standard-models', 'ai-engineer-roadmap'],
  seedSources: [],
  seedContext: '',
}
const rawArgs = (args && typeof args === 'object' && !Array.isArray(args)) ? args : {}
const A = {
  ...DEFAULT_ARGS,
  ...rawArgs,
  relatedNotes: (Array.isArray(rawArgs.relatedNotes) && rawArgs.relatedNotes.length) ? rawArgs.relatedNotes : DEFAULT_ARGS.relatedNotes,
  seedSources: Array.isArray(rawArgs.seedSources) ? rawArgs.seedSources : DEFAULT_ARGS.seedSources,
  seedContext: typeof rawArgs.seedContext === 'string' ? rawArgs.seedContext : DEFAULT_ARGS.seedContext,
}

const TEMPLATE_RULES = `
Quy uoc bat buoc cho note trong wiki/tech/ai-engineer (vault nay viet bang tieng Viet, thuat ngu ky thuat giu tieng Anh in dam):
- Frontmatter YAML: status: current, updated: 2026-08, sources: [danh sach URL da dung], roadmap: ai-engineer, stage: learning
- H1: "<Ten khai niem> — <mo ta ngan 1 dong>"
- Ngay sau H1: 1 dong TL;DR tom tat cot loi trong 1-2 cau, TRUOC KHI di vao chi tiet.
- Than bai chia theo H2, uu tien bullet-first thay vi doan van lien mach dai.
- Citation "(as of nguon, confidence: high/medium/low)" CHI gan inline cho claim gay tranh cai, so lieu quan trong, hoac claim chua chac chan/suy luan — KHONG gan cho moi cau/moi doan. Muc tieu: toi da ~4-6 inline citation cho ca note. Danh sach nguon day du da nam trong frontmatter 'sources', khong can lap lai. Neu thay minh dang gan citation qua 1 lan/doan, hay xoa bot va chi giu lai cho claim thuc su can justify.
- Co it nhat 1 vi du cu the (so lieu, bang, hoac code) minh hoa khai niem, khong chi mo ta truu tuong.
- Dung wikilink [[note-khac]] khi lien he toi cac note lien quan.
- Muc "## Lien he toi cac phan khac" o cuoi, BAT BUOC co sub-muc "### Ap dung voi Claude Code" noi ro khai niem nay ap dung the nao voi Claude Code (CLI) — ke ca khi cau tra loi la "khong ap dung / khong expose qua CLI", van phai neu ro.
- Muc "## Gioi han / open questions" o cuoi cung, liet ke cac diem chua chac chan hoac chua nghien cuu sau.
`

phase('Research')
const angles = [
  'tai lieu chinh thuc & nguon goc khai niem (docs, paper goc neu co)',
  'vi du thuc te, so sanh voi khai niem lien ke (LLM call thuan, RAG, workflow don gian)',
  'cach Claude Code / Claude Agent SDK ap dung hoac khong ap dung khai niem nay',
]
const seedBlock = (A.seedSources.length || A.seedContext)
  ? (
      `\nNguoi dung da cung cap san ngu canh/nguon ban dau, hay doc/verify cac nguon nay va uu tien dung lam diem neo (van phai doi chieu, khong copy nguyen van):\n` +
      (A.seedContext ? `- Boi canh/dinh nghia nhap: ${A.seedContext}\n` : '') +
      (A.seedSources.length ? A.seedSources.map(s => `- ${s}`).join('\n') + '\n' : '')
    )
  : ''
const researchResults = await parallel(angles.map((angle, i) => () =>
  agent(
    `Research chu de AI-engineering sau cho mot wiki note tieng Viet: "${A.topic}".\n` +
    `Goc nghien cuu cua ban: ${angle}.\n` +
    seedBlock +
    `Dung WebSearch/WebFetch de tim nguon dang tin cay (docs chinh thuc, paper, bai viet ky thuat uy tin) — ngoai cac nguon nguoi dung dua neu co. ` +
    `Voi moi finding, ghi lai: claim cu the, source URL, va confidence (high/medium/low) dua tren do tin cay nguon. ` +
    `Tra ve structured findings, khong can viet van xuoi.`,
    { phase: 'Research', schema: RESEARCH_SCHEMA, label: `research:${i}` }
  )
))
const allFindings = researchResults.filter(Boolean).flatMap(r => r.findings)
log(`Thu thap duoc ${allFindings.length} findings tu ${angles.length} goc nghien cuu.`)

phase('Synthesize')
const synthesizePrompt =
  `Ban viet 1 note wiki tieng Viet tai duong dan TUYET DOI: ${A.filePath}\n` +
  `Chu de: "${A.topic}" (category: ${A.category}, roadmap: ai-engineer).\n` +
  `Duoi day la cac findings da research (co the trung lap giua cac nguon) — hay DEDUPE (loai claim trung y, giu nguon tot nhat), roi tong hop thanh note hoan chinh:\n` +
  JSON.stringify(allFindings, null, 2) + '\n\n' +
  TEMPLATE_RULES + '\n' +
  `Cac note lien quan trong vault co the wikilink toi neu phu hop: ${A.relatedNotes.map(n => `[[${n}]]`).join(', ')}.\n` +
  `Sau khi viet xong file note, hay MO ${A.roadmapPath}, tim dong bang co cot Topic khop (hoac chua) text "${A.roadmapRowTopic}", roi SUA dong do theo quy tac sau (dung Edit, KHONG ghi de toan bo dong neu khong can):\n` +
  `  - Cot Note: neu dang la "—" thi thay bang "[[${A.category}-${A.slug}]]"; neu da co link khac roi (VD dong nay dung chung cho nhieu note) thi APPEND them ", [[${A.category}-${A.slug}]]" vao cuoi danh sach link hien co, khong xoa link cu.\n` +
  `  - Cot Stage: neu dang la "planned" thi doi thanh "learning"; neu da la "learning" hoac "done" roi thi GIU NGUYEN, khong ha cap.\n` +
  `Dung Write de tao file note, dung Edit de sua roadmap hub. Tra ve tom tat ngan cac gi da viet (khong can trich toan bo noi dung).`
const synth = await agent(synthesizePrompt, { phase: 'Synthesize', label: 'write-note' })
log(`Da viet draft note tai ${A.filePath}`)

const PERSONAS = [
  { key: 'junior', desc: 'ky su moi ra truong, moi hoc AI engineering, chua quen thuat ngu' },
  { key: 'middle', desc: 'ky su 3-5 nam kinh nghiem, biet code nhung moi tiep can LLM/agent' },
  { key: 'senior', desc: 'ky su senior/backend, quen he thong production, danh gia khat khe ve tinh ung dung thuc te' },
]

async function runReviewRound(roundLabel) {
  return parallel(PERSONAS.map(p => () =>
    agent(
      `Doc note tai duong dan TUYET DOI: ${A.filePath}\n` +
      `Dong vai mot ${p.desc}. Danh gia note nay tren 2 tieu chi:\n` +
      `1. Tinh ung dung (applicability): doc xong co ap dung duoc vao viec thuc te khong, hay chi ly thuyet suong?\n` +
      `2. Do de hieu/de scan (clarity): voi trinh do cua ban, doc co bi roi/qua day dac khong? Co TL;DR ro rang khong? Co vi du cu the khong?\n` +
      `KIEM TRA BAT BUOC truoc khi cham clarity: dem so lan cum "(as of ..., confidence: ...)" xuat hien trong bai. Neu xuat hien qua 6 lan, HOAC gan nhu moi doan/moi cau deu co — tu dong cham clarity <= 5 va pass = false cho du cac mat khac tot, ghi ro trong feedback so lan dem duoc va vi tri can gom/xoa bot.\n` +
      `Cham diem 1-10 cho moi tieu chi, quyet dinh pass (>=7 ca 2 tieu chi VA doc xong ban tu tin dung duoc) hoac fail, va feedback cu the (cau/doan nao co van de, sua gi).`,
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
  log(`Vong review ${rounds}: ${failing.length}/${reviews.length} persona chua pass — dang revise.`)
  const feedbackBlock = failing.map(r => `- [${r.persona}] clarity=${r.clarity_score}, applicability=${r.applicability_score}: ${r.feedback}`).join('\n')
  await agent(
    `Sua lai note tai duong dan TUYET DOI: ${A.filePath} dua tren feedback review sau (giu nguyen frontmatter, chi sua noi dung de de hieu/ung dung hon):\n` +
    feedbackBlock + '\n\n' +
    TEMPLATE_RULES + '\n' +
    `Dung Edit de sua file, khong viet lai toan bo tru khi thuc su can thiet.`,
    { phase: 'Revise', label: `revise:round${rounds}` }
  )
  reviews = (await runReviewRound(`round${rounds}`)).filter(Boolean)
}

const approved = reviews.every(r => r.pass)
if (approved) {
  log(`Note da pass review sau ${rounds} vong revise.`)
} else {
  log(`Note KHONG pass het sau ${MAX_ROUNDS} vong revise — can nguoi xem lai feedback con lai.`)
}

return {
  filePath: A.filePath,
  rounds,
  approved,
  finalReviews: reviews,
}
