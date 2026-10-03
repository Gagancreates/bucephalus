import Foundation

enum SummarizerSettings {
    static let modelKey = "openaiModel"
    static let defaultModel = "gpt-5-mini"
}

struct OpenAISummarizer {
    let apiKey: String
    let model: String

    private static let instructions = """
    You write meeting notes from a raw transcript of an in-person conversation. The transcript has \
    no speaker labels and may contain recognition errors; infer meaning from context and never \
    invent facts. Reply with a JSON object with exactly these keys:
    "title": a specific title of at most 6 words,
    "overview": 2-3 sentences on what the conversation was about and where it landed,
    "key_points": array of short strings, the substance of what was discussed,
    "decisions": array of short strings, things that were agreed (empty if none),
    "action_items": array of short strings, each a concrete next step, naming the owner if stated (empty if none).
    Be concise and plain. No filler.
    """

    func summarize(transcript: String) async throws -> MeetingSummary {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": model,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": Self.instructions],
                ["role": "user", "content": transcript],
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let message = (try? decoder.decode(APIErrorResponse.self, from: data))?.error.message
            throw SummarizerError.api(message ?? "OpenAI request failed.")
        }
        let completion = try decoder.decode(ChatCompletion.self, from: data)
        guard let content = completion.choices.first?.message.content?.data(using: .utf8) else {
            throw SummarizerError.api("OpenAI returned an empty response.")
        }
        return try decoder.decode(MeetingSummary.self, from: content)
    }

    private struct ChatCompletion: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message
        }
        let choices: [Choice]
    }

    private struct APIErrorResponse: Decodable {
        struct Detail: Decodable { let message: String }
        let error: Detail
    }
}

enum SummarizerError: LocalizedError {
    case missingKey
    case api(String)

    var errorDescription: String? {
        switch self {
        case .missingKey: "Add your OpenAI API key in Settings to get a summary."
        case .api(let message): message
        }
    }
}
