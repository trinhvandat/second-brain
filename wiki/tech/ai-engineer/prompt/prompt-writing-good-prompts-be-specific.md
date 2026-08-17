---
status: current
updated: 2026-08
sources:
  - https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
  - https://developers.openai.com/api/docs/guides/prompt-engineering
  - https://www.promptingguide.ai/introduction/tips
  - https://code.claude.com/docs/en/best-practices
  - https://www.anthropic.com/engineering/building-effective-agents
roadmap: ai-engineer
stage: done
---

# Writing Good Prompts — Be Specific — noi ro chinh xac ban muon gi thay vi de model tu doan

TL;DR: Prompt mo ho buoc model phai tu suy dien y dinh tu context ngheo nan nen output khong the doan truoc; prompt cang cu the (role, task, constraint, tieu chi thanh cong) cang thu hep khong gian output va tang xac suat dung ngay lan dau.

## Vi sao "be specific" quan trong

- LLM khong doc duoc suy nghi cua ban — no chi co the bam vao nhung gi xuat hien trong context. Thieu chi tiet = model phai "doan", va cang doan thi variance cang cao.
- Anthropic mo ta Claude nhu "**mot nhan vien moi rat gioi nhung chua co ngu canh** ve chuan muc/quy trinh cua ban" — cang giai thich chinh xac muon gi, ket qua cang tot (as of platform.claude.com/prompt-engineering, confidence: high).
- **Golden rule** cua Anthropic: dua prompt cho mot dong nghiep it ngu canh doc thu — neu ho boi roi, Claude cung se boi roi.
- Claude Code best-practices dung cung nguyen tac cho coding agent: "Claude co the suy luan y dinh, nhung khong doc duoc suy nghi cua ban. Instruction cang chinh xac thi cang it lan phai sua lai."

## Cac thanh phan lam prompt tro nen cu the

- **Role/persona** — dat vai tro cho model trong system prompt. Chi 1 cau cung tao khac biet ro ret, VD: "You are a helpful coding assistant specializing in Python."
- **Task** — dong tu lenh ro rang (Write, Classify, Summarize, Fix), khong dung tu chung chung nhu "lam tot hon".
- **Constraints** — gioi han cu the thay vi so thich mo ho. VD thay "keep it professional" bang "avoid jargon, khong dung cum tu 'dive into' hay 'game-changer', khong qua 100 tu" — model xu ly ranh gioi ro rang nhu hard constraint, khong suy luan tot y ngam.
- **Context/motivation** — giai thich *ly do* dang sau constraint giup model generalize dung, thay vi chi lam theo nghia den. VD: thay vi chi noi "NEVER dung dau ba cham", giai thich "vi output se duoc doc boi text-to-speech engine".
- **Tieu chi thanh cong ro rang** — dinh nghia truoc "the nao la dung" thay vi de model tu quyet dinh. Claude Code goi day la "cho Claude cach tu verify cong viec".
- **Dinh dang output** — neu can JSON, bang, so cau cu the... phai noi ro tu dau.

## Vi du: mo ho vs. cu the

| Muc tieu | Prompt mo ho | Prompt cu the |
|---|---|---|
| Giai thich khai niem | "Explain prompt engineering. Keep it short." | "Use 2-3 sentences to explain prompt engineering to a high school student." |
| Sinh dashboard | "Create an analytics dashboard" | "Create an analytics dashboard. Include as many relevant features and interactions as possible. Go beyond the basics to create a fully-featured implementation." |
| Sua bug (Claude Code) | "fix the login bug" | "Users report login fails after session timeout. Check the auth flow in src/auth/, especially token refresh. Write a failing test that reproduces the issue, then fix it." |
| Viet test | "add tests for foo.py" | "Write a test for foo.py covering the edge case where the user is logged out. Avoid mocks." |
| Validate email (verification criteria) | "implement a function that validates email addresses" | "Write a validateEmail function. Example test cases: user@example.com is true, invalid is false, user@.com is false. Run the tests after implementing." |

Prompt "cu the" o cot phai luon nam ro: **doi tuong**, **so luong/gioi han**, va **cach kiem tra ket qua** — day chinh la ba truc chinh cua nguyen tac be-specific.

## Luu y: specificity la default, khong phai luat tuyet doi

- Voi cac task **kham pha** (chua ro yeu cau, con dang tim y tuong), prompt mo ho lai co ich — VD "ban se cai thien gi trong file nay?" co the goi ra nhung goc nhin ma minh khong nghi den de hoi cu the.
- Voi instruction **ben vung** (VD file CLAUDE.md), specificity phai di kem **suc tich**: chi giu nhung dieu khong hien nhien / dac thu project; loai bo advice chung chung ("write clean code") vi model da biet san. CLAUDE.md qua dai lam tin hieu bi loang, khien Claude bo qua instruction — nen "cu the" khong dong nghia voi "cang dai cang tot" (as of code.claude.com/best-practices, confidence: medium).
- Khong co paper hoc thuat goc nao dat ten chinh thuc cho ky thuat "specificity" (khac voi Chain-of-Thought co paper goc Wei et al. 2022) — day la best practice duc ket tu thuc hanh cua cac vendor (Anthropic, OpenAI) va cong dong (promptingguide.ai), khong phai tu mot nghien cuu don le (confidence: medium).

## Lien he toi cac phan khac

- [[prompt-engineering]] — be-specific la nguyen tac nen tang, ap dung xuyen suot moi ky thuat prompt engineering khac (zero-shot, few-shot, CoT deu can prompt cu the o tung buoc).
- Khac voi **RAG** — RAG giai quyet van de cung cap dung **du lieu/context** ben ngoai cho model, con be-specific tap trung vao cach **dien dat instruction**. Hai ky thuat bo tro nhau: prompt cu the + context dung deu thu hep khong gian output.
- Khac voi **agent** (theo dinh nghia Anthropic trong "Building Effective Agents") — agent de model tu dinh huong nhieu buoc/tool call, nen constraint va success-criteria trong system prompt cang quan trong hon de gioi han khong gian hanh dong tu tri, tranh drift qua nhieu vong lap.

### Ap dung voi Claude Code

- Claude Code khong expose mot "specificity setting" rieng qua CLI — nguyen tac nay ap dung truc tiep vao **cach viet prompt/task cho Claude Code**, khong phai mot config flag.
- Ap dung ro nhat qua hai co che:
  - **Prompt tuc thi**: mo ta scope (file nao, edge case nao), trieu chung cu the (khong chi "fix bug"), va tieu chi verify (chay test nao, expect gi) — xem bang vi du o tren.
  - **CLAUDE.md** (system-level, ben vung): chi nen chua instruction cu the-nhung-khong-hien-nhien, tranh loang tin hieu bang advice chung chung.
- Claude Agent SDK cho phep tune muc do "cu the" cua system prompt qua 3 co che: mac dinh minimal (chi tool instruction thiet yeu), preset `claude_code` (day du hanh vi Claude Code), va `append` (chong them instruction cu the len tren preset ma khong phai viet lai toan bo) (confidence: medium, tai lieu SDK).
- Adversarial review step trong Claude Code cung ap dung nguyen tac nay cho subagent: thay vi "review code nay", noi ro "review diff X so voi PLAN.md, kiem tra tung requirement co duoc implement, edge case co test, report gap chu khong phai style preference" — mo rong be-specific tu prompt don sang orchestration nhieu agent.

## Gioi han / open questions

- Chua co so lieu dinh luong (VD % giam variance, % tang accuracy) tu nguon chinh thuc nao do "specificity" mang lai — cac vi du deu la qualitative, chua thay benchmark A/B cong khai so sanh truc tiep prompt mo ho vs. cu the tren cung mot task.
- Ranh gioi giua "cu the vua du" va "over-specified gay nhieu/mat flexibility" chua duoc dinh luong ro — CLAUDE.md guidance canh bao ve bloat nhung khong dua threshold cu the.
- Chua ro nguyen tac nay khac biet the nao giua reasoning model (o1-class) va non-reasoning model — OpenAI goi y reasoning model can it instruction chi tiet hon (giao "muc tieu cao" thay vi buoc cu the), nhung chua co so sanh sau voi Claude/extended thinking trong nguon da doc.
