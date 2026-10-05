import Foundation

enum SettingsKeys {
    static let provider = "llmProvider"
    static let autoTitle = "autoTitle"
}

enum Provider: String, CaseIterable, Identifiable {
    case openai, anthropic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: "OpenAI"
        case .anthropic: "Anthropic"
        }
    }

    var defaultModel: String {
        switch self {
        case .openai: "gpt-5.6-luna"
        case .anthropic: "claude-opus-5-5"
        }
    }

    var keychainAccount: String { "\(rawValue)-api-key" }
    var modelKey: String { "model.\(rawValue)" }
    var keyPlaceholder: String { self == .openai ? "sk-…" : "sk-ant-…" }

    static var current: Provider {
        Provider(rawValue: UserDefaults.standard.string(forKey: SettingsKeys.provider) ?? "") ?? .openai
    }

    var selectedModel: String {
        UserDefaults.standard.string(forKey: modelKey) ?? defaultModel
    }
}

struct ModelInfo: Identifiable, Hashable {
    let id: String
    let name: String
}

/// Minimal client for the two providers: list models, and one system + user completion.
struct LLMClient {
    let provider: Provider
    let apiKey: String

    func listModels() async throws -> [ModelInfo] {
        switch provider {
        case .openai:
            let data = try await send(request(path: "models"))
            let list = try Self.decoder.decode(OpenAIModelList.self, from: data)
            return list.data
                .filter { Self.isOpenAIChatModel($0.id) }
                .sorted { $0.created > $1.created }
                .map { ModelInfo(id: $0.id, name: $0.id) }
        case .anthropic:
            let data = try await send(request(path: "models?limit=1000"))
            let list = try Self.decoder.decode(AnthropicModelList.self, from: data)
            return list.data.map { ModelInfo(id: $0.id, name: $0.displayName) }
        }
    }

    func complete(system: String, user: String, model: String) async throws -> String {
        switch provider {
        case .openai:
            var request = request(path: "chat/completions")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "model": model,
                "response_format": ["type": "json_object"],
                "messages": [
                    ["role": "system", "content": system],
                    ["role": "user", "content": user],
                ],
            ] as [String: Any])
            let completion = try Self.decoder.decode(OpenAICompletion.self, from: try await send(request))
            guard let text = completion.choices.first?.message.content, !text.isEmpty else {
                throw LLMError.api("OpenAI returned an empty response.")
            }
            return text

        case .anthropic:
            var request = request(path: "messages")
            var body: [String: Any] = [
                "model": model,
                "max_tokens": 16000,
                "system": system,
                "messages": [["role": "user", "content": user]],
            ]
            // If a safety classifier declines, let the API retry on its recommended fallback model.
            if Self.fallbackModels.contains(model) {
                body["fallbacks"] = "default"
                request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
            }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let message = try Self.decoder.decode(AnthropicMessage.self, from: try await send(request))
            if message.stopReason == "refusal" {
                throw LLMError.api("Claude declined to summarise this conversation.")
            }
            if message.stopReason == "max_tokens" {
                throw LLMError.api("The summary was cut off. Try a different model.")
            }
            let text = message.content.compactMap(\.text).joined()
            guard !text.isEmpty else { throw LLMError.api("Claude returned an empty response.") }
            return text
        }
    }

    private static let fallbackModels: Set<String> = [
        "claude-fable-5-1", "claude-opus-5-5", "claude-opus-5", "claude-sonnet-5-5",
    ]

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private func request(path: String) -> URLRequest {
        let base = provider == .openai ? "https://api.openai.com/v1/" : "https://api.anthropic.com/v1/"
        var request = URLRequest(url: URL(string: base + path)!)
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        switch provider {
        case .openai:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        case .anthropic:
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        }
        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        var request = request
        if request.httpBody != nil { request.httpMethod = "POST" }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let message = (try? Self.decoder.decode(APIErrorResponse.self, from: data))?.error.message
            throw LLMError.api(message ?? "\(provider.displayName) request failed.")
        }
        return data
    }

    // The models endpoint also returns embedding, audio and image models; keep the text ones.
    private static func isOpenAIChatModel(_ id: String) -> Bool {
        let isChatFamily = id.hasPrefix("gpt-") || id.hasPrefix("chatgpt-")
            || (id.hasPrefix("o") && id.dropFirst().first?.isNumber == true)
        let excluded = ["audio", "realtime", "tts", "transcribe", "image", "embedding", "search", "instruct", "moderation"]
        return isChatFamily && !excluded.contains { id.contains($0) }
    }

    private struct OpenAIModelList: Decodable {
        struct Model: Decodable {
            let id: String
            let created: Int
        }
        let data: [Model]
    }

    private struct AnthropicModelList: Decodable {
        struct Model: Decodable {
            let id: String
            let displayName: String
        }
        let data: [Model]
    }

    private struct OpenAICompletion: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message
        }
        let choices: [Choice]
    }

    private struct AnthropicMessage: Decodable {
        struct Block: Decodable { let text: String? }
        let content: [Block]
        let stopReason: String?
    }

    private struct APIErrorResponse: Decodable {
        struct Detail: Decodable { let message: String }
        let error: Detail
    }
}

struct Summarizer {
    let client: LLMClient
    let model: String

    private static let instructions = """
    You write meeting notes from a raw transcript of an in-person conversation. It may contain \
    recognition errors; infer meaning from context and never invent facts. When lines start with a \
    speaker label ("Speaker 1:", or a name), the labels come from automatic voice separation: use them \
    to say who said or agreed to what, keep the labels exactly as written, and use a real name instead \
    only when the conversation makes it obvious. Reply with only a JSON object, no other text, with \
    exactly these keys:
    "title": a specific heading for the meeting, at most 5 words,
    "overview": 2-3 sentences on what the conversation was about and where it landed,
    "key_points": array of short strings, the substance of what was discussed,
    "decisions": array of short strings, things that were agreed (empty if none),
    "action_items": array of short strings, each a concrete next step, naming the owner if stated (empty if none).
    Be concise and plain. No filler.
    """

    func summarize(transcript: String) async throws -> MeetingSummary {
        let style = SummaryStyle.current.instructions.map { "\n" + $0 } ?? ""
        let text = try await client.complete(system: Self.instructions + style, user: transcript, model: model)
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else {
            throw LLMError.api("The model didn't return a readable summary.")
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        var summary = try decoder.decode(MeetingSummary.self, from: Data(text[start...end].utf8))
        summary.title = summary.title.split(separator: " ").prefix(5).joined(separator: " ")
        return summary
    }
}

enum LLMError: LocalizedError {
    case missingKey(Provider)
    case api(String)

    var errorDescription: String? {
        switch self {
        case .missingKey(let provider): "Add your \(provider.displayName) API key in Settings to get a summary."
        case .api(let message): message
        }
    }
}
