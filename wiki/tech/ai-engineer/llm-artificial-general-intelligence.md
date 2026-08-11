---
status: current
updated: 2026-08
sources:
  - https://arxiv.org/pdf/2311.02462
  - https://deepmind.google/research/publications/66938/
  - https://arcprize.org/arc-agi
  - https://openai.com/safety/how-we-think-about-safety-alignment/
  - https://fortune.com/2026/03/30/agi-definition-jensen-huang-lex-fridman-deepmind-turing-text-cognitive-taxonomy/
roadmap: ai-engineer
stage: learning
---

# AGI: Artificial General Intelligence

AGI (Artificial General Intelligence) = một hệ thống có thể học kỹ năng mới và giải quyết vấn đề chưa từng gặp một cách hiệu quả, dù không được thiết kế/huấn luyện riêng cho nhiệm vụ đó — tức general-purpose intelligence, không phải task-specific (confidence: high). Nằm giữa hai thuật ngữ hay bị nhầm lẫn:
- **ANI (Artificial Narrow Intelligence)** — AI đang triển khai hiện nay, bao gồm cả LLM: mạnh ở task cụ thể, chưa có transfer thực sự giữa các domain.
- **ASI (Artificial Superintelligence)** — AGI giả định vượt trí thông minh con người ở MỌI domain, không chỉ ngang bằng.

**Chưa có định nghĩa AGI được đồng thuận toàn ngành** — các lab, nhà nghiên cứu, thậm chí lãnh đạo (VD: Jensen Huang của Nvidia tuyên bố "we've achieved AGI") bất đồng về ngưỡng đạt AGI (as of 2026-03, fortune.com) (confidence: high). Nên nghi ngờ mọi tuyên bố "đã đạt AGI" nếu không nêu rõ đang đo theo định nghĩa/benchmark nào.

## Đo lường tiến trình tới AGI
Vì chưa có định nghĩa duy nhất, một số framework cố gắng lượng hoá "còn cách bao xa":
- **DeepMind's Levels of AGI** (Morris et al., 2023) — tách năng lực thành 3 trục: **depth** (performance), **breadth** (generality/độ phủ domain), và **autonomy**. Định nghĩa các cấp độ tăng dần — emerging → competent → expert → virtuoso → superhuman — áp dụng được cho cả hệ thống narrow lẫn general. Mục đích: tạo ngôn ngữ chung để so sánh model và đánh giá rủi ro, thay vì chỉ hỏi "có phải AGI không" (as of 2023-11, deepmind.google) (confidence: high).
- **ARC-AGI benchmark** (François Chollet) — đo fluid intelligence (khả năng suy luận/thích nghi với vấn đề thực sự mới) thay vì crystallized intelligence (nhớ lại pattern đã học) — vì đây chính là điểm LLM dễ "ăn gian" qua memorization từ training data. ARC-AGI-3 (2026) chuyển từ puzzle tĩnh sang môi trường tương tác: agent phải khám phá, tự hình thành mục tiêu, và xây world model qua nhiều bước — sát với việc đo general capability hơn là Q&A one-shot (confidence: high).

## AGI Theoretical Approaches

### Symbolic
Máy tính có thể phát triển AGI bằng cách đại diện suy nghĩ của con người thông qua mạng lưới logic (`IF-ELSE`-style rules), cho phép hệ thống phân tích ideas ở level cao hơn (abstraction). Giới hạn: symbolic representation không tái tạo/mô phỏng được các khả năng nhận thức nền tảng của con người (ví dụ: tri giác/perception) — vì tri thức được mã hoá tường minh (explicit), không học được từ dữ liệu thô.

### Connectionist (= sub-symbolic)
Mô phỏng cấu trúc não bộ bằng kiến trúc neural network — các "nơ-ron" điều chỉnh trọng số kết nối khi tiếp xúc dữ liệu/tương tác, thay vì mã hoá luật tường minh như symbolic. Đây là lý do connectionist còn được gọi là **sub-symbolic**: tri thức nằm ẩn trong trọng số, không đọc được trực tiếp như luật `IF-ELSE`.
> `LLM` (transformer-based) là ví dụ điển hình của connectionist — xem [[augmented-llm]] cho building block hiện tại của các hệ thống LLM-based.

**Debate đang mở (2026):** liệu scaling connectionist/transformer (nhiều data + nhiều compute hơn) có tự dẫn tới AGI, hay cần kiến trúc mới? Phe "scaling is enough" dẫn evidence từ emergent capabilities khi tăng scale; phe phản đối chỉ ra LLM hiện tại thiếu continual learning, world model bền vững, và reasoning ngoài phân phối huấn luyện (out-of-distribution) — chính là thứ ARC-AGI-3 cố đo. (confidence: medium — chưa có kết luận đồng thuận, cần theo dõi thêm)

### Universalists - Trường phái phổ quát
Tập trung giải quyết độ phức tạp của AGI ở level tính toán (computational level): xây dựng giải pháp lý thuyết trước, sau đó chuyển đổi/áp dụng vào hệ thống AGI thực tế.

### Whole organism architecture
Tích hợp AI models với đại diện vật lý (embodiment) của cơ thể — quan điểm cho rằng AGI chỉ đạt được khi hệ thống học từ tương tác vật lý thực (không chỉ dữ liệu text/ảnh tĩnh). Liên quan tới hướng nghiên cứu robotics + AI hiện nay (world models qua tương tác môi trường).

### Hybrid
Kết hợp Symbolic và Sub-symbolic (Connectionist) để thể hiện suy nghĩ con người tốt hơn so với dùng riêng lẻ. Hướng nghiên cứu đang được nhiều nhóm theo đuổi vì mỗi phương pháp bù khuyết điểm yếu của phương pháp kia (symbolic: reasoning tường minh nhưng cứng nhắc; connectionist: học từ dữ liệu nhưng "black box", khó giải thích).

## Safety & alignment (tại sao AGI không chỉ là bài toán kỹ thuật)
3 lab lớn theo đuổi AGI có framing khác nhau về an toàn:
- **OpenAI** — mission nêu rõ "ensure AGI benefits all of humanity"; tập trung vào *superalignment*: tự động hoá nghiên cứu alignment vì con người sẽ không đủ khả năng giám sát trực tiếp một hệ thống thông minh hơn mình (superalignment problem).
- **DeepMind** — nhấn mạnh robust training, monitoring, và security hơn là thuần lý thuyết alignment.
- **Anthropic** — được đánh giá cao nhất về risk assessment trong AI Safety Index 2025 (grade C+, cao nhất nhóm) — cách tiếp cận "helpful/harmless" của Anthropic đã ảnh hưởng thiết kế Claude, liên quan tới nguyên tắc simplicity/transparency khi thiết kế agent trong [[agentic-systems-taxonomy]].

Điểm mấu chốt: risk không chỉ nằm ở "AGI làm gì sai" mà là **superalignment** — khi hệ thống vượt khả năng giám sát của con người, cách kiểm chứng "nó có đang làm đúng ý mình không" tự nó là bài toán chưa có lời giải (confidence: high, đồng thuận rộng giữa các lab dù cách tiếp cận khác nhau).

## Open questions / cần đọc thêm
- Timeline thực tế: các lab dự đoán AGI trong khung 3–10 năm nhưng định nghĩa khác nhau → so sánh timeline giữa các lab không có nhiều ý nghĩa nếu không cùng benchmark.
- Note này chưa cover **kinh tế/tác động xã hội của AGI** (labor displacement, compute governance) — để lại cho 1 note riêng nếu cần đào sâu.
- Liên hệ thực hành: khoảng cách giữa AGI (lý thuyết) và [[augmented-llm]] + [[agentic-systems-taxonomy]] (thực hành hiện tại) chính là "generality gap" — agent ngày nay giỏi ở task cụ thể nhờ augmentation tốt, chưa phải general intelligence theo định nghĩa DeepMind.
