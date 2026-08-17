---
status: current
updated: 2026-08
sources:
  - https://arxiv.org/abs/1706.03762
  - https://arxiv.org/abs/2203.02155
  - https://arxiv.org/abs/2203.15556
  - https://www.explainx.ai/blog/what-is-transformer-architecture-attention-llm-guide-2026
  - https://www.comet.com/site/blog/pretraining/
  - https://magazine.sebastianraschka.com/p/llm-training-rlhf-and-its-alternatives
  - https://lifearchitect.ai/chinchilla/
  - https://arxiv.org/pdf/2403.15796
roadmap: ai-engineer
stage: done
---

# LLM: Large Language Model

LLM (Large Language Model) là một loại AI dùng **Deep Learning (DL)** — cụ thể là kiến trúc neural network gọi là **Transformer** — được huấn luyện (train) trên một bộ dataset text khổng lồ để nhận diện và sinh (generate) ngôn ngữ con người, cũng như các dạng dữ liệu tuần tự phức tạp khác (code, v.v.) (confidence: high). Về bản chất, đây vẫn là một chương trình máy tính: nó không "hiểu" theo nghĩa con người, mà học cách các ký tự/từ/câu kết hợp với nhau ra sao từ hàng tỷ ví dụ, thông qua objective tưởng đơn giản là **dự đoán token tiếp theo** (next-token prediction) — và từ đó "nổi lên" (emerge) khả năng nắm ngữ pháp, kiến thức thế giới, và một số dạng suy luận.

Theo phân loại trong [[llm-artificial-general-intelligence]], LLM hiện tại là **ANI** (Artificial Narrow Intelligence — narrow dù rất rộng về domain): mạnh ở pattern completion trên phân phối đã thấy trong training data, chưa có continual learning (không tự học thêm sau khi deploy) hay world model bền vững ngoài context window.

## Sử dụng LLM cho gì?
- **Generative AI / chat assistant** — phổ biến nhất: GPT (OpenAI), Claude (Anthropic), Gemini (Google)... sinh text hội thoại, viết lách, tóm tắt, dịch.
- **Code generation & coding agent** — một số LLM được huấn luyện thêm/riêng cho code (VD: Claude Code, Codex-family) — hiểu và sinh code, không chỉ ngôn ngữ tự nhiên.
- **Reasoning/agent backbone** — LLM làm "bộ não" ra quyết định trong hệ thống agent (tool use, multi-step planning) — xem nhóm `agent-` trong [[ai-engineer-roadmap]].
- Nhìn chung: bất kỳ tác vụ nào có thể quy về "sinh sequence tiếp theo hợp lý dựa trên context" — text, code, thậm chí một số ứng dụng multi-modal (ảnh, audio) khi model được huấn luyện thêm modality đó.

## Kiến trúc: Transformer

- **Self-attention** là cơ chế lõi: với mỗi token, model tính "nên chú ý bao nhiêu" tới mọi token khác trong sequence — thực hiện song song (parallel) thay vì tuần tự như RNN/LSTM trước đó. Đây là lý do Transformer scale tốt trên GPU/TPU (as of 2017, arxiv 1706.03762 "Attention Is All You Need") (confidence: high).
- **Multi-head attention** — chia attention thành nhiều "head" chạy song song, mỗi head học một khía cạnh quan hệ khác nhau giữa token (cú pháp, ngữ nghĩa, đồng tham chiếu...), rồi ghép lại.
- **Decoder-only** — hầu hết LLM frontier hiện nay (GPT, Claude, Llama, Gemini) dùng kiến trúc decoder-only (bỏ encoder của Transformer gốc, vốn được thiết kế cho seq2seq/dịch máy) — phù hợp với mục tiêu generative next-token prediction.
- **Biến thể 2026** so với bản gốc 2017: RoPE (rotary positional encoding) thay vì positional encoding tuyệt đối, SwiGLU thay ReLU trong FFN, RMSNorm thay LayerNorm, Grouped-Query Attention / Multi-head Latent Attention thay multi-head attention thuần — chủ yếu để giảm chi phí inference (KV-cache) mà giữ chất lượng (as of 2026, explainx.ai) (confidence: medium — chi tiết implementation khác nhau giữa các lab, không phải mọi model đều dùng đủ 4 biến thể này).
- **Residual connections + normalization** — cho phép xếp chồng rất nhiều layer (chục đến hàng trăm) mà gradient không biến mất khi train.

> Chi tiết tokenization xem [[llm-tokenization]], chi tiết context window xem [[llm-context-window]] — note này chỉ tóm tắt đủ để hiểu bức tranh tổng về kiến trúc Transformer.

## Training pipeline: 3 giai đoạn

Pipeline chuẩn cho một chat model hiện đại (kiểu ChatGPT/Claude) gồm 3 bước, mỗi bước dùng objective và dữ liệu khác nhau (as of comet.com, sebastianraschka.com) (confidence: high):

1. **Pretraining** — train trên corpus quy mô internet (nghìn tỷ token) với objective next-token prediction thuần. Ra một **base model**: có kiến thức ngôn ngữ/thế giới rộng nhưng chưa biết "trả lời như trợ lý" — dễ lan man, tiếp tục completion thay vì trả lời trực tiếp.
2. **SFT (Supervised Fine-Tuning) / instruction tuning** — fine-tune base model trên tập dữ liệu prompt–response chất lượng cao (do người hoặc LLM khác viết), vẫn dùng next-token prediction nhưng trên dữ liệu "hỏi–đáp đúng chuẩn". Bước này giải quyết *cold-start problem* cho RL ở bước sau: cần policy đã sinh ra text mạch lạc, liên quan tới prompt trước khi optimize bằng RL mới ổn định được.
3. **RLHF (Reinforcement Learning from Human Feedback)** hoặc biến thể (DPO, RLAIF...) — train một **reward model** trên preference data (con người/AI xếp hạng nhiều response cho cùng 1 prompt), rồi dùng reward model đó làm tín hiệu thưởng để tiếp tục fine-tune LLM bằng RL (PPO là thuật toán gốc, nay nhiều lab dùng biến thể rẻ hơn). Đây là bước dạy model "trả lời hữu ích, từ chối yêu cầu không an toàn một cách lịch sự, theo đúng instruction" — không chỉ đúng ngữ pháp mà đúng *ý định người dùng* (InstructGPT, arxiv 2203.02155) (confidence: high).

> Liên hệ: bước 3 chính là nơi framing "helpful/harmless" của từng lab (đã nhắc ở [[llm-artificial-general-intelligence]] mục Safety) được implement cụ thể — RLHF/RLAIF là cơ chế kỹ thuật, alignment philosophy là mục tiêu.

## Scaling laws

- **Chinchilla scaling laws** (Hoffmann et al. 2022, DeepMind) — với ngân sách compute cố định, hiệu năng tối ưu khi cân bằng giữa số tham số (model size) và số token training, tỷ lệ đề xuất ~20 token/parameter. Kết luận quan trọng: nhiều model lớn trước đó (GPT-3 trở về trước) bị **undertrained** — quá nhiều tham số so với lượng data đã thấy (arxiv 2203.15556, lifearchitect.ai) (confidence: high).
- **Inference-optimal ≠ compute-optimal khi training** — nếu kỳ vọng traffic inference lớn (production), nên train model nhỏ hơn trên nhiều token hơn mức Chinchilla khuyến nghị (tỷ lệ 100–200 token/parameter thay vì 20), vì chi phí inference cộng dồn theo thời gian sử dụng, còn chi phí training chỉ trả một lần (confidence: medium — đây là heuristic thực dụng, không phải "law" được chứng minh chặt như Chinchilla).
- **Emergent abilities** (in-context learning, chain-of-thought, instruction following...) — khả năng xuất hiện đột ngột khi vượt một ngưỡng scale nhất định thay vì tăng tuyến tính, quan sát được qua benchmark accuracy. Tuy nhiên có nghiên cứu chỉ ra hiện tượng này một phần là do **cách đo** (metric không tuyến tính với loss) chứ không hẳn là bước nhảy vọt thực sự về năng lực bên dưới — nhìn qua loss thì xu hướng vẫn mượt (arxiv 2403.15796, "Understanding Emergent Abilities of Language Models from the Loss Perspective") (confidence: medium — vẫn đang tranh luận, chưa đồng thuận hoàn toàn).
- Ví dụ ngược hướng "cứ to là thắng": Liquid AI LFM2.5-350M (04/2026) đạt tỷ lệ data/parameter tới 80,000:1 (350M parameter, train trên 28 nghìn tỷ token + RL quy mô lớn) — minh hoạ xu hướng ưu tiên data/RL hơn là scale thuần tham số cho model nhỏ, tối ưu chi phí inference/edge deployment.

## Giới hạn đã biết (điểm chưa đủ để gọi là AGI)

- **Hallucination** — model sinh thông tin sai một cách tự tin, vì objective gốc là "token nào có xác suất cao tiếp theo" chứ không có cơ chế nội tại kiểm chứng sự thật.
- **Knowledge cutoff** — kiến thức đóng băng tại thời điểm dữ liệu pretraining, không tự cập nhật (khác với con người học liên tục) — đây là một phần lý do RAG/tool-use tồn tại (xem nhóm `rag-`/`agent-` trong [[ai-engineer-roadmap]]).
- **Context window hữu hạn** — "trí nhớ làm việc" bị giới hạn bởi cửa sổ token, không phải continual/persistent memory thật (dù caching + tool-based memory đang cố bù đắp phần này) — chi tiết ở [[llm-context-window]].
- **Không có continual learning trong inference** — trọng số cố định sau training; model không tự học thêm từ một cuộc hội thoại để nhớ sang lần sau (trừ khi có hệ thống ngoài như RAG/fine-tune lại) — chính là "generality gap" đã nhắc ở note AGI.

## Open questions / cần đọc thêm
- Tokenization thực sự ảnh hưởng gì tới reasoning/toán học của LLM? — xem [[llm-tokenization]] mục liên hệ reasoning.
- So sánh RLHF vs DPO vs RLAIF về chi phí/chất lượng — cần note riêng khi đào sâu phần alignment kỹ thuật.
- Note này chưa cover **inference optimization** (quantization, speculative decoding, KV-cache) — thuộc nhóm `infra-` trong roadmap, để lại cho sau.
- Liên hệ AGI: khoảng cách giữa LLM hiện tại và AGI (theo framing DeepMind Levels of AGI) nằm chủ yếu ở breadth thực sự out-of-distribution + autonomy dài hạn, không chỉ ở "biết nhiều fact" — xem chi tiết ở [[llm-artificial-general-intelligence]].
