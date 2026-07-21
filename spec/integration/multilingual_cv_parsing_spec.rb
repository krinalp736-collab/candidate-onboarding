require "rails_helper"

# PRD §5: "The parser should support Dutch and English CVs at minimum...
# ideally... common European dental CV formats."
#
# CvExtractionService's prompt deliberately does not hardcode a language
# allowlist (see its SYSTEM_PROMPT) — it asks Claude to detect and handle
# whatever language the CV is in. To prove this is genuinely language-agnostic
# rather than "supports exactly two hardcoded languages," this runs the same
# assertions across two unrelated languages (Dutch, German) from a
# table-driven fixture list, each exercising REAL PDF text extraction
# (CvTextExtractor + PDF::Reader, no mocking) including diacritics that are a
# common source of mojibake bugs (ë, ü, ä).
#
# The Claude API call itself is stubbed in the one test that needs it — there
# is no ANTHROPIC_API_KEY in this environment — but that test proves the
# non-English text survives extraction and reaches Claude byte-for-byte.
RSpec.describe "Multilingual CV parsing" do
  LANGUAGE_FIXTURES = [
    {
      language: "Dutch",
      file: "dutch_cv.pdf",
      name: "Jan de Vries",
      diacritic_text: "Mondhygiënist", # e-diaeresis
      city: "Utrecht",
      country: "Nederland"
    },
    {
      language: "German",
      file: "german_cv.pdf",
      name: "Anna Müller",
      diacritic_text: "Zahnärztin", # u-umlaut / a-umlaut
      city: "München",
      country: "Deutschland"
    }
  ].freeze

  LANGUAGE_FIXTURES.each do |fixture|
    context "with a #{fixture[:language]} CV" do
      let(:profile) { create(:candidate_profile) }
      let(:document) { create(:candidate_document, candidate_profile: profile) }

      before do
        document.file.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/#{fixture[:file]}")),
          filename: fixture[:file],
          content_type: "application/pdf"
        )
      end

      it "extracts the real text, diacritics included, with no mocking" do
        text = CvTextExtractor.call(document.file)

        expect(text).to include(fixture[:name])
        expect(text).to include(fixture[:diacritic_text])
        expect(text).to include(fixture[:city])
      end

      it "prefills the profile correctly from an extraction result in that language" do
        extraction = {
          first_name: fixture[:name].split.first, last_name: fixture[:name].split.last,
          email: nil, phone_number: nil, city: fixture[:city], country: fixture[:country],
          job_function_guess: nil, years_of_experience: 7, professional_summary: fixture[:diacritic_text],
          big_number: nil, big_status_guess: nil,
          languages: [ { name: fixture[:language], level: "native" } ],
          education: [], work_experience: [], skills: []
        }

        CandidateProfilePrefiller.call(profile, extraction)

        expect(profile.city).to eq(fixture[:city])
        expect(profile.professional_summary).to eq(fixture[:diacritic_text])
      end
    end
  end

  it "sends extracted non-English text to Claude unmodified (no re-encoding/mangling)" do
    document = create(:candidate_document, candidate_profile: create(:candidate_profile))
    document.file.attach(
      io: File.open(Rails.root.join("spec/fixtures/files/dutch_cv.pdf")),
      filename: "dutch_cv.pdf", content_type: "application/pdf"
    )
    dutch_text = CvTextExtractor.call(document.file)

    ENV["ANTHROPIC_API_KEY"] = "test-key"
    messages_resource = instance_double(Anthropic::Resources::Messages)
    client = instance_double(Anthropic::Client, messages: messages_resource)
    allow(Anthropic::Client).to receive(:new).and_return(client)

    dutch_extraction = {
      first_name: "Jan", last_name: "de Vries", email: "jan.devries@voorbeeld.nl",
      phone_number: nil, city: "Utrecht", country: "Nederland",
      job_function_guess: "Dental hygienist", years_of_experience: 6,
      professional_summary: "Mondhygiënist met 6 jaar ervaring in tandartspraktijken.",
      big_number: nil, big_status_guess: nil, languages: [], education: [], work_experience: [], skills: []
    }
    text_block = instance_double(Anthropic::Models::TextBlock, text: dutch_extraction.to_json, parsed: dutch_extraction)
    allow(messages_resource).to receive(:create).and_return(instance_double(Anthropic::Models::Message, content: [ text_block ]))

    result = CvExtractionService.call(dutch_text)

    expect(messages_resource).to have_received(:create) do |params|
      expect(params[:messages]).to eq([ { role: "user", content: dutch_text } ])
    end
    expect(result[:city]).to eq("Utrecht")
  ensure
    ENV["ANTHROPIC_API_KEY"] = nil
  end

  it "does not hardcode the supported languages to a fixed allowlist (PRD §5)" do
    expect(CvExtractionService::SYSTEM_PROMPT).to match(/any language/i)
    expect(CvExtractionService::SYSTEM_PROMPT).to match(/Dutch/i)
    expect(CvExtractionService::SYSTEM_PROMPT).to match(/English/i)
    expect(CvExtractionService::SYSTEM_PROMPT).to match(/German|French|Spanish/i)
  end

  it "instructs the model not to translate extracted content out of the CV's own language" do
    expect(CvExtractionService::SYSTEM_PROMPT).to match(/do not translate/i)
  end
end
