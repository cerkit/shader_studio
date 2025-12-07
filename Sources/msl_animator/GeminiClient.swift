import Foundation

struct GeminiClient {
    private let baseURL =
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent"

    struct GenerateContentRequest: Codable {
        let contents: [Content]
        let systemInstruction: Content?
    }

    struct Content: Codable {
        let parts: [Part]
        let role: String?
    }

    struct Part: Codable {
        let text: String
    }

    struct GenerateContentResponse: Codable {
        let candidates: [Candidate]?
    }

    struct Candidate: Codable {
        let content: Content
    }

    struct GeminiError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    func generateShader(prompt: String, apiKey: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            throw URLError(.badURL)
        }

        let systemPrompt = """
            You are an expert Metal Shading Language (MSL) programmer.
            Your task is to write a complete MSL fragment shader based on the user's description.

            The shader MUST follow this exact signature and structure:

            #include <metal_stdlib>
            using namespace metal;

            fragment float4 fragment_main(VertexOut in [[stage_in]],
                                          constant float2& u_resolution [[buffer(0)]],
                                          constant float& u_time [[buffer(1)]]) {
                float2 uv = in.uv; // uv is already normalized 0..1 from vertex shader
                // Your code here
                // You can use u_resolution (screen size in pixels) and u_time (seconds)
                
                return float4(color, 1.0);
            }

            IMPORTANT RULES:
            1. Do NOT include any vertex shader code or struct definitions for VertexOut (assume it exists).
            2. Do NOT use `[[position]]` or other attributes not provided.
            3. ONLY return the MSL code. Do not include markdown backticks (```) or explanations.
            4. Ensure the code compiles and runs.
            5. If using raymarching or complex SDFs, include all necessary helper functions (rotations, SDFs, etc.) inside the code, before `fragment_main`.
            6. STRICTLY USE MSL TYPES: Use `float2x2` instead of `mat2`, `float3x3` instead of `mat3`, `float4x4` instead of `mat4`.
            7. CONSTANTS:
               - For GLOBAL constants, use `#define` (e.g., `#define PI 3.14159`). This is the safest and preferred method.
               - If you must use variables, GLOBAL ones need `constant` address space.
               - LOCAL variables (inside functions) MUST NOT have an address space qualifier (do NOT use `constant` inside functions).
            8. NO GLSL SYNTAX:
               - Do NOT use `vec2`, `vec3`, `vec4` (use `float2`, `float3`, `float4`).
               - Do NOT use `mod` (use `fmod`).
               - Do NOT use `mix` if it conflicts (Metal has `mix`, but ensure types match).
               - Do NOT use `fract` (use `fract` or `fmod(x, 1.0)`).
            9. MATRIX MULTIPLICATION:
               - Do NOT use `mul(matrix, vector)` or `mul(vector, matrix)`. This is HLSL/CG syntax and is NOT valid in MSL.
               - USE the `*` operator for matrix multiplication (e.g., `matrix * vector` or `vector * matrix`).
            """

        let requestBody = GenerateContentRequest(
            contents: [
                Content(parts: [Part(text: prompt)], role: "user")
            ],
            systemInstruction: Content(parts: [Part(text: systemPrompt)], role: nil)
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300  // Increase timeout to 300 seconds
        request.httpBody = try JSONEncoder().encode(requestBody)

        let redactedURL = url.absoluteString.replacingOccurrences(
            of: apiKey, with: "[GEMINI_API_KEY]")
        print("GeminiClient: Sending request to \(redactedURL)")

        // Debug: Print CURL command
        if let jsonData = try? JSONEncoder().encode(requestBody),
            let jsonString = String(data: jsonData, encoding: .utf8)
        {
            var redactedJSON = jsonString.replacingOccurrences(of: apiKey, with: "[GEMINI_API_KEY]")
            // Escape single quotes for shell: ' -> '\''
            redactedJSON = redactedJSON.replacingOccurrences(of: "'", with: "'\\''")

            print("--- CURL COMMAND (Copy and run in terminal to test) ---")
            print(
                "curl -X POST \"\(redactedURL.replacingOccurrences(of: "[GEMINI_API_KEY]", with: "${GEMINI_API_KEY}"))\" \\"
            )
            print("-H \"Content-Type: application/json\" \\")
            print("-d '\(redactedJSON)'")
            print("-------------------------------------------------------")
        }

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 300
        configuration.waitsForConnectivity = true
        let session = URLSession(configuration: configuration)

        let (data, response) = try await session.data(for: request)
        print("GeminiClient: Received response")

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if let errorText = String(data: data, encoding: .utf8) {
                print("Gemini API Error: \(errorText)")
                // Try to parse the JSON error if possible, otherwise return raw text
                throw GeminiError(
                    message:
                        "API Error \( (response as? HTTPURLResponse)?.statusCode ?? 0 ): \(errorText)"
                )
            }
            throw URLError(.badServerResponse)
        }

        print("GeminiClient: Decoding response")
        let decodedResponse = try JSONDecoder().decode(GenerateContentResponse.self, from: data)

        guard let text = decodedResponse.candidates?.first?.content.parts.first?.text else {
            throw URLError(.cannotDecodeContentData)
        }

        // Clean up any potential markdown formatting if the model ignores the instruction
        var cleanText = text.replacingOccurrences(of: "```metal", with: "")
        cleanText = cleanText.replacingOccurrences(of: "```msl", with: "")
        cleanText = cleanText.replacingOccurrences(of: "```", with: "")

        return cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
