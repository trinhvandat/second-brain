---
status: current
updated: 2026-08
sources:
  - https://arxiv.org/pdf/2005.14165
  - https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
  - https://www.promptingguide.ai/techniques/fewshot
  - https://developers.openai.com/api/docs/guides/prompt-engineering
roadmap: ai-engineer
stage: done
---

# Writing Good Prompts — Use Examples (Few-Shot) — dua vi du input->output mau vao prompt de model hoc pattern qua in-context learning

TL;DR: Thay vi mo ta bang loi (zero-shot), few-shot dua vao prompt 2-5 cap vi du input->output cu the de model tu suy ra pattern qua **in-context learning** — dac biet hieu qua khi dinh dang output kho dien ta bang van ban hoac zero-shot da that bai.

## Few-shot la gi

- **In-context learning** (model hoc task tu cac vi du minh hoa ngay trong prompt, tai thoi diem inference, khong can cap nhat gradient/fine-tune): khai niem nay bat nguon tu paper "Language Models are Few-Shot Learners" gioi thieu GPT-3 (Brown et al., 2020), phan biet 3 che do: zero-shot (0 vi du), one-shot (1 vi du), few-shot (nhieu vi du, thuong 10-100 trong paper goc, nhung trong thuc hanh prompt engineering hien nay con so nho hon nhieu — xem muc "So luong vi du" ben duoi).
- Ve ban chat, few-shot la mot **alternative cho fine-tuning**: thay vi train lai model, ban "day" pattern ngay trong prompt bang mot vai cap vi du.
- Anthropic goi ky thuat nay la **multishot prompting** (ten Anthropic dung cho ky thuat few-shot) va xac nhan day la "mot trong nhung cach dang tin cay nhat de dinh huong format, tone, va cau truc output" cua Claude.

## Khi nao few-shot dac biet huu ich

- **Dinh dang output kho dien ta bang loi** — VD mot cau truc JSON dac thu voi nhieu field long nhau, hoac mot van phong/giong van rieng (formal, playful, technical) — mo ta bang tinh tu rat kho chinh xac, nhung cho model 1 vi du output mau thi no bam theo ngay.
- **Task classification/extraction voi label set khong chuan** — khi tap nhan khong phai la cac category pho bien (sentiment positive/negative), ma la nhan dac thu domain (VD "urgent-billing", "feature-request-P2"), few-shot giup model hieu ranh gioi giua cac nhan qua vi du thay vi dinh nghia tu dien.
- **Khi zero-shot da fail** — day la tin hieu ro rang nhat trong thuc te: neu prompt mo ta bang loi da thu nhieu lan van sai format/logic, buoc tiep theo hop ly la chuyen sang few-shot truoc khi nghi den fine-tuning.
- Few-shot cung ap dung duoc voi **extended thinking** (che do Claude tu suy luan cong khai truoc khi tra loi): dat tag `<thinking>` mau ben trong vi du de day Claude phong cach lap luan, model se tu generalize style do sang cac block reasoning cua chinh no.

## Nguyen tac chon vi du

> Cac khuyen nghi trong phan nay (tieu chi chon vi du, so luong 3-5) lay tu Anthropic prompt-engineering docs, confidence: high — xem `sources` o dau bai.

- **Diversity (da dang)** — vi du phai bao quat nhieu truong hop, ke ca **edge case** (truong hop hiem/bien, khac voi truong hop pho bien), tranh model **overfit** (bam qua chat vao 1 pattern hep, roi ap dung sai cho input khac di mot chut) vao 1 pattern hep. Anthropic liet ke 3 tieu chi cho vi du tot: **Relevant** (bam sat use case thuc te), **Diverse** (du da dang de model khong nhat ra pattern gia/khong mong muon), **Structured** (bao trong `<example>`/`<examples>` de model phan biet vi du voi instruction).
- **Dinh dang nhat quan** — giua cac vi du voi nhau, va giua vi du voi cau hoi that. Nghien cuu cua Min et al. (2022), duoc promptingguide.ai tong hop, cho thay: do chinh xac cua tung nhan (label) it quan trong hon viec **format** va **phan bo nhan** trong demonstration co "thuc" (realistic) hay khong — tham chi nhan ngau nhien van tot hon han khong co nhan mien la giu dung format (as of promptingguide.ai/techniques/fewshot, confidence: medium). Vi du thuc te: neu ban co 5 vi du classify sentiment nhung co-tinh gan sai 1 nhan (VD 1 cau tich cuc bi gan nhan "negative"), model van hoc dung dinh dang tra loi tot hon la khong co vi du nao — vi dieu quan trong hon la *cach trinh bay* input->output, khong phai tung nhan co chinh xac tuyet doi hay khong.
- **So luong vi du (2-5)** — danh doi giua chat luong va chi phi token. Anthropic khuyen nghi cu the "3-5 vi du la toi uu"; OpenAI khuyen 2-4 cap va luu y qua nhieu vi du co the khien model "quen" cac vi du dau, gay output khong nhat quan. Nhieu vi du hon thuong giup task phuc tap hon nhung tang token/latency tuyen tinh.
- **Gioi han**: few-shot thuong khong du cho task doi hoi lap luan nhieu buoc (VD toan nhieu buoc) — nhung truong hop nay can chain-of-thought (ky thuat yeu cau model trinh bay tung buoc suy luan) thay vi (hoac ket hop voi) few-shot thuan tuy.

## Vi du minh hoa

Zero-shot (mo ta bang loi, de bi model dien output theo cach khac):

```
Classify the sentiment of this support ticket as urgent-billing, feature-request, or general-question.

Ticket: "My card was charged twice this month, please fix ASAP."
```

Few-shot (dua 3 cap vi du de model bam theo dinh dang va ranh gioi nhan):

```
<examples>
<example>
Ticket: "I was charged $49 twice on my last invoice."
Label: urgent-billing
</example>
<example>
Ticket: "Would be great if you added dark mode to the dashboard."
Label: feature-request
</example>
<example>
Ticket: "How do I export my data as CSV?"
Label: general-question
</example>
</examples>

Ticket: "My card was charged twice this month, please fix ASAP."
Label:
```

Voi few-shot, model khong chi biet "phai tra ve mot trong 3 nhan" ma con hoc duoc dung dinh dang tra loi (`Label: <ten-nhan>`, khong giai thich them) tu chinh cac vi du — dieu ma mo ta bang loi rat kho truyen dat chinh xac.

## Phan biet voi "provide context"

- **Few-shot** = vi du cu the input->output, day model *cach lam* mot task qua demonstration.
- **Provide context** ([[prompt-writing-good-prompts-provide-context]]) = cung cap thong tin nen/tai lieu/vai tro chung, khong nhat thiet the hien hinh dang output mong muon.
- **RAG** la ky thuat lien quan nhung khac: no *dong* (retrieve tai thoi diem query) tai lieu/context tu nguon ngoai, co the bao gom ca vi du few-shot-style duoc chon dong, thay vi hardcode vi du co dinh vao prompt (as of WebSearch synthesis Vellum.ai + PromptHub, confidence: low).

## Lien he toi cac phan khac

- [[prompt-engineering]] — few-shot la mot trong cac ky thuat prompt engineering co ban, thuong ket hop voi [[prompt-writing-good-prompts-be-specific]] (vi du giup lam ro "cu the" la nhu the nao) va [[prompt-writing-good-prompts-provide-context]] (context la nen, vi du la minh hoa cu the tren nen do).
- Lien quan toi cac ky thuat generation-control khac trong roadmap nhu chain-of-thought — few-shot khong thay the CoT cho task lap luan phuc tap.

### Ap dung voi Claude Code

- Claude Code khong co config/flag rieng cho "few-shot mode" qua CLI — day la nguyen tac **viet prompt/instruction** ma nguoi dung tu ap dung khi soan task hoac file CLAUDE.md/AGENTS.md.
- Trong thuc hanh, co the dua vi du vao CLAUDE.md hoac vao chinh prompt gui cho Claude Code de dinh huong dinh dang output (VD "vi du commit message dung chuan cua repo nay la: ..."), giup agent bam dung convention cua project ma khong can giai thich dai dong.
- Doi voi cac skill/slash command tuy chinh (`.claude/skills/`), tac gia skill co the nhung san few-shot examples ngay trong noi dung skill de dinh huong output cua Claude Code khi skill duoc goi — day la cach ap dung few-shot o cap "system-level" thay vi tung prompt rieng le.

## Gioi han / open questions

- Chua co bang chung tu paper goc kiem chung ro rang cho claim few-shot co the **lam giam** hieu nang tren cac reasoning model doi moi (VD dong o1) — thong tin nay chi den tu nguon tong hop thu cap, can kiem chung them truoc khi ap dung nhu quy tac chung (as of starpop.ai blog, confidence: low).
- Chua ro con so "3-5 vi du" cua Anthropic co thay doi theo do phuc tap task hay khong — huong dan hien tai mang tinh chung chung, chua co benchmark cong khai chi tiet cho tung loai task (classification vs. structured-output vs. style-transfer).
- Ranh gioi giua few-shot va RAG-voi-vi-du-dong con mo — chua ro trong thuc hanh khi nao nen hardcode vi du co dinh vs. retrieve vi du dong theo tung query.
