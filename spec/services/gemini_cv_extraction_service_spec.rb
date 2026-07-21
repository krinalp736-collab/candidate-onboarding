require "rails_helper"

RSpec.describe GeminiCvExtractionService do
  around do |example|
    original = ENV["GEMINI_API_KEY"]
    example.run
    ENV["GEMINI_API_KEY"] = original
  end

  context "when GEMINI_API_KEY is not configured" do
    it "returns nil rather than raising or making a network call" do
      ENV["GEMINI_API_KEY"] = nil

      expect(described_class.call("some cv text")).to be_nil
      expect(WebMock).not_to have_requested(:post, /generativelanguage\.googleapis\.com/)
    end
  end

  context "when GEMINI_API_KEY is configured" do
    before { ENV["GEMINI_API_KEY"] = "test-gemini-key" }

    let(:endpoint) do
      "https://generativelanguage.googleapis.com/v1beta/models/" \
        "#{GeminiCvExtractionService::MODEL}:generateContent?key=test-gemini-key"
    end
    let(:parsed_payload) { { first_name: "Jane", last_name: "Doe" } }

    it "posts the CV text and system prompt to the generateContent endpoint with a JSON response schema" do
      stub_request(:post, endpoint)
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            candidates: [ { content: { parts: [ { text: parsed_payload.to_json } ] } } ]
          }.to_json
        )

      result = described_class.call("Jane Doe's CV text")

      expect(result).to eq(parsed_payload)
      expect(WebMock).to have_requested(:post, endpoint)
        .with { |req|
          body = JSON.parse(req.body)
          body["contents"] == [ { "parts" => [ { "text" => "Jane Doe's CV text" } ] } ] &&
            body["systemInstruction"]["parts"][0]["text"] == CvExtractionService::SYSTEM_PROMPT &&
            body["generationConfig"]["responseMimeType"] == "application/json"
        }
    end

    it "returns nil and logs after exhausting retries when Gemini keeps responding with a retryable status (429/5xx)" do
      stub_const("GeminiCvExtractionService::RETRY_DELAY_SECONDS", 0)
      stub_request(:post, endpoint).to_return(status: 503, body: '{"error": "overloaded"}')

      expect(described_class.call("cv text")).to be_nil
      expect(WebMock).to have_requested(:post, endpoint).times(GeminiCvExtractionService::MAX_ATTEMPTS)
    end

    it "succeeds if a retryable error clears on a later attempt (transient free-tier overload)" do
      stub_const("GeminiCvExtractionService::RETRY_DELAY_SECONDS", 0)
      stub_request(:post, endpoint)
        .to_return(status: 503, body: '{"error": "overloaded"}').then
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: { candidates: [ { content: { parts: [ { text: parsed_payload.to_json } ] } } ] }.to_json
        )

      expect(described_class.call("cv text")).to eq(parsed_payload)
      expect(WebMock).to have_requested(:post, endpoint).times(2)
    end

    it "does not retry a non-retryable status (e.g. a bad API key) — fails fast instead" do
      stub_request(:post, endpoint).to_return(status: 400, body: '{"error": "bad request"}')

      expect(described_class.call("cv text")).to be_nil
      expect(WebMock).to have_requested(:post, endpoint).times(1)
    end

    it "returns nil when the response has no usable candidate content" do
      stub_request(:post, endpoint).to_return(status: 200, body: { candidates: [] }.to_json)

      expect(described_class.call("cv text")).to be_nil
    end

    it "returns nil rather than raising on a network error, after retrying" do
      stub_const("GeminiCvExtractionService::RETRY_DELAY_SECONDS", 0)
      stub_request(:post, endpoint).to_timeout

      expect(described_class.call("cv text")).to be_nil
      expect(WebMock).to have_requested(:post, endpoint).times(GeminiCvExtractionService::MAX_ATTEMPTS)
    end
  end
end
