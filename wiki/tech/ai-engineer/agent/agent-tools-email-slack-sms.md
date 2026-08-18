---
status: current
updated: 2026-08
sources:
  - https://www.twilio.com/docs/messaging/api/message-resource
  - https://www.twilio.com/docs/usage/api
  - https://docs.slack.dev/reference/methods/chat.postMessage
  - https://api.slack.com/scopes/chat:write:bot
  - https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.messages/send
  - https://developers.openai.com/api/docs/guides/function-calling
  - https://www.anthropic.com/engineering/how-we-contain-claude
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool
  - https://docs.langchain.com/oss/python/langchain/human-in-the-loop
  - https://docs.langchain.com/oss/python/deepagents/human-in-the-loop
  - https://www.anthropic.com/research/building-effective-agents
  - https://code.claude.com/docs/en/agent-sdk/permissions
  - https://code.claude.com/docs/en/permissions
  - https://code.claude.com/docs/en/mcp
  - https://code.claude.com/docs/en/channels
  - https://arxiv.org/abs/2302.04761
  - https://arxiv.org/abs/2210.03629
roadmap: ai-engineer
stage: learning
---

# Examples of Tools — Email / Slack / SMS — tool cho phép agent gửi tin nhắn thật ra thế giới bên ngoài, thay vì chỉ trả lời text

**TL;DR**: Đây là nhóm **agent tool** bọc các API nhắn tin thật (Gmail, Slack, Twilio SMS) để agent có thể **thông báo, escalate, hoặc hành động thay mặt con người** ngoài đời — khác hẳn các tool đọc dữ liệu (search/DB/API/filesystem) ở chỗ mỗi lần gọi là một **side effect hướng ra ngoài, khó rollback**, nên cần **human-in-the-loop confirmation** và **scoping/allowlisting** chặt hơn hẳn.

Nói đơn giản: tool email/Slack/SMS nguy hiểm hơn tool đọc dữ liệu vì **có một con người thật ở đầu bên kia thực sự nhận được tin nhắn** — model gửi sai là người thật thấy sai ngay, không "xoá được" như xoá một dòng log. Vì vậy nguyên tắc mặc định là: **luôn chèn bước xác nhận (confirm) trước khi gửi thật**, không tin tưởng model tự quyết một mình.

> **Đọc trước nếu chưa quen**: note này giả định đã biết khái niệm **tool-calling** cơ bản (model trả JSON arguments, code ứng dụng mới thực thi) — xem [[agent-what-are-tools]] và [[agent-tool-definition]] trước nếu còn mới với "agent tool" là gì.

## 1. Vấn đề mà nhóm tool này giải quyết

- Các tool đã học trước đó — **web search** (xem [[agent-tools-web-search]]), **database query** (xem [[agent-tools-database-queries]]), **API request** tổng quát (xem [[agent-tools-api-requests]]), **filesystem access** — phần lớn là **read-oriented** hoặc chỉ tác động nội bộ hệ thống của chính agent.
- Messaging tool (email/Slack/SMS) đổi hẳn bản chất: nó **write** ra một hệ thống bên ngoài, tới một **con người thật**, và hệ quả (email sai gửi đi, SMS tính phí sai người) **hiển thị ngay lập tức** và **không thể âm thầm undo** — không có "revert commit" cho một tin nhắn đã tới điện thoại người dùng.
- Đây chính là ranh giới biến agent từ "cái máy trả lời câu hỏi" thành "cái máy có thể hành động thay mặt ai đó trong thế giới thật" (notify on-call, escalate incident, gửi email xác nhận đơn hàng...).

## 2. Cơ chế hoạt động — vẫn đi qua vòng lặp tool-calling chuẩn

- Giống mọi tool khác (xem [[agent-tool-definition]]): model không tự gửi email/SMS — nó chỉ trả về JSON arguments có cấu trúc (`to`, `subject`, `body`...) cho một function như `send_email`/`post_slack_message`/`send_sms`; **code ứng dụng** mới là bên thực sự gọi API và tạo ra side effect thật.
- Đây chính là "đường nối" (seam) kiến trúc nơi logic xác nhận/allowlist được chèn vào — giữa lúc model quyết định gọi tool và lúc code thực sự bắn request.

### Ví dụ API cụ thể của 3 kênh

| Kênh | Endpoint / method | Tham số bắt buộc | Auth |
|---|---|---|---|
| **Email** (Gmail API) | `POST /gmail/v1/users/{userId}/messages/send` | `raw` = MIME message encode base64URL | OAuth token |
| **Slack** | `chat.postMessage` | `channel`, `text`; cần scope `chat:write` | Bot token `xoxb-...` |
| **SMS** (Twilio) | `POST /2010-04-01/Accounts/{Sid}/Messages.json` | `To` (E.164), `From`/`MessagingServiceSid`, `Body` (≤1600 ký tự) | Account SID + Auth Token |

- Twilio SMS bị chia thành nhiều **segment** billed riêng nếu vượt 160 ký tự GSM-7 (hoặc 70 ký tự UCS-2), và response trả về field `price`/`price_unit` — minh chứng cụ thể rằng tool này có **chi phí tiền thật trên mỗi lần gọi**, khác hẳn tool search/DB chỉ đọc (as of Twilio Message Resource docs, confidence: high).
- Slack `chat.postMessage` có rate limit khoảng ~1 tin/giây/channel, cộng thêm giới hạn theo phút ở cấp workspace — lý do trực tiếp vì sao messaging tool cần rate limiting/allowlisting nghiêm hơn tool chỉ đọc.
- Scoping thực tế trên nền tảng: bot token Slack chỉ post được vào channel mà bot đã được invite, và chỉ với scope `chat:write` được cấp; số điện thoại Twilio bị scope theo account/number — đây chính là cơ chế "allowlisting" cụ thể mà khái niệm này nhắc tới, không phải chỉ là nguyên tắc trừu tượng.

## 3. Vì sao cần Human-in-the-loop (HITL) mạnh hơn các tool khác

Quyết định nhanh — hardcode được thì dùng workflow, model phải tự quyết thì bắt buộc HITL:

| Nội dung/đích gửi được quyết thế nào? | Nên dùng gì? |
|---|---|
| Cố định, biết trước (vd luôn gửi 1 email xác nhận sau khi thanh toán thành công) | **Workflow** cố định — dễ kiểm soát, không cần HITL |
| Model tự quyết "có nên nhắn ai đó không, nhắn gì" | **Agent** thật có quyền gọi messaging tool → rủi ro tăng rõ rệt, **bắt buộc HITL** |

- Anthropic mô tả xu hướng chuyển từ HITL đơn giản (đọc: tự động cho phép, ghi/bash/network: luôn phải approve từng lệnh) sang các `permission_mode` tinh vi hơn, vì approve từng hành động một gây "approval fatigue". Cùng logic áp dụng cho tool nhắn tin: mục tiêu là gating thông minh theo mức rủi ro, không phải chặn cứng mọi lệnh gửi.
- LangChain có `HumanInTheLoopMiddleware`, cho phép đánh dấu tool cụ thể (vd `interrupt_on={"send_email": True}`) để agent **dừng lại**, chờ người duyệt (approve/edit/reject) trước khi tool thật sự chạy. Vì agent phải dừng và resume sau, framework cần một **checkpointer** (vd `InMemorySaver`) lưu lại state — nghĩa là "confirm trước khi gửi" không chỉ là UI convenience mà là một yêu cầu kiến trúc.

```python
# Trước: agent tự gọi send_email mà không dừng lại hỏi ai cả
agent = create_agent(model, tools=[send_email])

# Sau: gắn HITL middleware, tool "send_email" bị chặn lại chờ người duyệt
from langgraph.checkpoint.memory import InMemorySaver

agent = create_agent(
    model,
    tools=[send_email],
    middleware=[HumanInTheLoopMiddleware(interrupt_on={"send_email": True})],
    checkpointer=InMemorySaver(),  # bắt buộc để agent dừng/resume được
)
# → khi model gọi send_email, agent dừng lại, chờ approve/edit/reject
#   trước khi request thật được gửi đi
```

## 4. Ví dụ tối thiểu: tool schema + gate xác nhận

Hai phần bắt buộc phải có khi implement một messaging tool: (1) schema mô tả cho model — **không có** side effect, chỉ ràng buộc input; (2) code xử lý ở phía ứng dụng, nơi chèn bước xác nhận **trước khi** gọi API thật.

```python
# 1) Tool schema đưa cho model — chỉ mô tả, chưa có side effect
send_slack_message_tool = {
    "name": "send_slack_message",
    "description": "Gửi tin nhắn vào một channel Slack đã được allowlist.",
    "input_schema": {
        "type": "object",
        "properties": {
            "channel": {"type": "string", "enum": ["#incident", "#oncall"]},  # allowlist cứng
            "text": {"type": "string"},
        },
        "required": ["channel", "text"],
    },
}

# 2) Code ứng dụng: chèn gate HITL trước khi side effect thật xảy ra
def handle_tool_call(name, args):
    if name == "send_slack_message":
        if not human_approves(f"Gửi vào {args['channel']}: {args['text']}"):
            return {"error": "user_rejected"}
        return slack_client.chat_postMessage(**args)  # side effect thật
```

### Ví dụ pattern thực tế: on-call escalation

Một agent xử lý sự cố thường chuỗi 2 bước: đọc (read-oriented) → nhắn tin (write/side-effect):

```
1. [đọc]   search/DB tool: kiểm tra dashboard monitoring, tìm alert đang active
2. [ghi]   nếu alert nghiêm trọng → gọi tool post_slack_message(channel="#incident", text=...)
3. [ghi]   nếu không ai ack trong 5 phút → gọi tool send_sms(to=oncall_phone, body=...)
```

Bước 1 có thể tự động hoàn toàn; bước 2-3 là nơi cần **allowlist** (chỉ được nhắn vào `#incident`, chỉ được SMS số on-call đã đăng ký sẵn — không phải số bất kỳ do model tự "nghĩ ra" hay lấy từ dữ liệu chưa kiểm chứng) và có thể cần HITL confirm tuỳ mức độ nghiêm trọng.

## Liên hệ tới các phần khác

- So với [[agent-tools-api-requests]]: messaging tool về mặt kỹ thuật chỉ là một trường hợp cụ thể của "API request tool" (đều là client tool gọi HTTP API ngoài qua schema), nhưng được tách thành nhóm riêng vì **hướng đối tượng khác biệt** — API request chung có thể trỏ tới bất kỳ hệ thống nào (kể cả nội bộ, đọc dữ liệu), còn messaging tool luôn **hướng ra con người thật** và luôn là **write/side-effect**.
- So với **Agentic RAG**: RAG mở rộng theo hướng để model tự chọn/chain nhiều bước retrieval — nhưng retrieval vẫn là tool đọc; messaging tool khác biệt hẳn về bản chất (write, outward-facing) ngay cả dưới khung "agentic".
- Xem thêm [[agent-what-are-tools]], [[agent-tool-definition]] cho cơ chế tool-calling nền tảng; [[ai-engineer-roadmap]] cho vị trí của topic này trong lộ trình.

### Áp dụng với Claude Code

- Claude Code (CLI/Agent SDK) **không có sẵn** một tool gửi email/Slack/SMS "built-in" trong core — các khả năng này đến qua **MCP server** (vd Gmail MCP connector, Slack MCP server của bên thứ ba) cấu hình thêm, không phải tính năng lõi của CLI.
- Trước khi một tool call chạy thật, Claude Code duyệt qua một chuỗi cố định (as of Claude Code permissions docs, confidence: high):

  ```
  model gọi tool
      → PreToolUse hooks
          → khớp deny rule?  → chặn hẳn
          → khớp ask rule?   → callback canUseTool (chờ người xác nhận)
          → còn lại          → chạy tool thật
  ```

  Một cổng xác nhận cho messaging tool phải được xây dựa trên toàn bộ chuỗi này, không chỉ dựa vào callback `canUseTool` riêng lẻ.
- MCP tool có thể gắn annotation `_meta["anthropic/requiresUserInteraction"]: true` để **luôn** bắt buộc rơi vào bước xác nhận người dùng, bất kể allow rule hay permission mode — kể cả ở mode `bypassPermissions` thì tool này bị **từ chối thẳng** thay vì được bỏ qua xác nhận (as of Claude Code MCP docs, corroborated by GitHub issue anthropics/claude-code#58757, confidence: high). Đây là cơ chế nên dùng cho mọi MCP tool gửi Slack/email/SMS.
- Allowlist/denylist áp được theo tên server + tool cụ thể (vd `mcp__slack__post_message`, hoặc deny-all `mcp__*`), và ở cấp tổ chức, managed settings có thể ép các connector tool luôn ở chế độ "ask" mà user không ghi đè được.
- "Channels" của Claude Code hiện chỉ là cơ chế **inbound** (đẩy sự kiện từ Telegram/Discord/iMessage vào session đang chạy), không phải outbound send-message tool; Slack outbound mới chỉ có qua plugin cộng đồng chưa chính thức (as of Claude Code channels docs, confidence: medium).

## Giới hạn / open questions

- Chưa có ví dụ code hoàn chỉnh từ Anthropic minh hoạ việc gói Twilio/Slack/Gmail thành SDK MCP tool cụ thể (khác với ví dụ `get_temperature` trong [[agent-tools-api-requests]]) — cần tự viết/thử để kiểm chứng chi tiết schema.
- Chưa rõ hành vi chính xác khi rule "ask" ở cấp tổ chức tương tác với `requiresUserInteraction` annotation cùng lúc — có ưu tiên chồng lấp hay không, tài liệu chưa nói rõ.
- Support Slack qua plugin cộng đồng (`retrodigio/claude-channel-slack`) chưa được kiểm chứng độ ổn định/bảo mật — chỉ nêu như một điểm tham khảo, chưa xác minh sâu.
- Chưa có số liệu thực tế (case study) về tần suất lỗi "gửi nhầm" trong các agent production dùng messaging tool để đánh giá mức độ rủi ro cụ thể ngoài lý thuyết.
