require "rails_helper"

RSpec.describe CvExtractionService do
  around do |example|
    original = ENV["ANTHROPIC_API_KEY"]
    example.run
    ENV["ANTHROPIC_API_KEY"] = original
  end

  context "when ANTHROPIC_API_KEY is not configured" do
    it "returns nil rather than raising (PRD §11: candidate can continue manually)" do
      ENV["ANTHROPIC_API_KEY"] = nil

      expect(described_class.call("some cv text")).to be_nil
    end

    it "never touches the network" do
      ENV["ANTHROPIC_API_KEY"] = nil
      expect(Anthropic::Client).not_to receive(:new)

      described_class.call("some cv text")
    end
  end

  context "when ANTHROPIC_API_KEY is configured" do
    before { ENV["ANTHROPIC_API_KEY"] = "test-key" }

    let(:parsed_payload) { { first_name: "Jane", last_name: "Doe" } }
    let(:text_block) { instance_double(Anthropic::Models::TextBlock, text: parsed_payload.to_json, parsed: parsed_payload) }
    let(:response) { instance_double(Anthropic::Models::Message, content: [ text_block ]) }
    let(:messages_resource) { instance_double(Anthropic::Resources::Messages) }
    let(:client) { instance_double(Anthropic::Client, messages: messages_resource) }

    before do
      allow(Anthropic::Client).to receive(:new).and_return(client)
      allow(messages_resource).to receive(:create).and_return(response)
    end

    it "calls Claude with the model, schema, and CV text, and returns the parsed structured output" do
      result = described_class.call("Jane Doe's CV text")

      expect(messages_resource).to have_received(:create).with(
        hash_including(
          model: CvExtractionService::MODEL,
          messages: [ { role: "user", content: "Jane Doe's CV text" } ]
        )
      )
      expect(result).to eq(parsed_payload)
    end

    it "falls back to JSON-parsing the text block when .parsed isn't populated" do
      allow(text_block).to receive(:parsed).and_return(nil)

      expect(described_class.call("cv text")).to eq(parsed_payload.transform_keys(&:to_sym))
    end

    it "returns nil and logs when the API raises" do
      allow(messages_resource).to receive(:create)
        .and_raise(Anthropic::Errors::APIConnectionError.new(message: "boom", url: URI("http://x")))

      expect(described_class.call("cv text")).to be_nil
    end
  end
end
