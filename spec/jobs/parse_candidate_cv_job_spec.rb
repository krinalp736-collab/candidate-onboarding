require "rails_helper"

RSpec.describe ParseCandidateCvJob, type: :job do
  let(:profile) { create(:candidate_profile) }
  let(:document) { create(:candidate_document, candidate_profile: profile, parsing_status: :pending) }

  before do
    document.file.attach(
      io: StringIO.new("fake pdf bytes"),
      filename: "cv.pdf",
      content_type: "application/pdf"
    )
  end

  it "marks the document completed with parsing_method: ai and prefills the profile when Claude extraction succeeds" do
    extraction = { first_name: "Jane" }
    allow(CvTextExtractor).to receive(:call).and_return("extracted cv text")
    allow(CvExtractionService).to receive(:call).with("extracted cv text").and_return(extraction)
    allow(GeminiCvExtractionService).to receive(:call)
    allow(RegexCvExtractor).to receive(:call)
    allow(CandidateProfilePrefiller).to receive(:call)

    described_class.perform_now(document.id)

    expect(CandidateProfilePrefiller).to have_received(:call).with(profile, extraction)
    expect(GeminiCvExtractionService).not_to have_received(:call)
    expect(RegexCvExtractor).not_to have_received(:call)
    expect(document.reload).to be_completed
    expect(document).to be_ai
    expect(document.parsed_at).to be_present
  end

  it "falls back to GeminiCvExtractionService with parsing_method: ai when Claude isn't available but Gemini is" do
    extraction = { first_name: "Jane", email: "jane@example.com" }
    allow(CvTextExtractor).to receive(:call).and_return("extracted cv text")
    allow(CvExtractionService).to receive(:call).and_return(nil)
    allow(GeminiCvExtractionService).to receive(:call).with("extracted cv text").and_return(extraction)
    allow(RegexCvExtractor).to receive(:call)
    allow(CandidateProfilePrefiller).to receive(:call)

    described_class.perform_now(document.id)

    expect(CandidateProfilePrefiller).to have_received(:call).with(profile, extraction)
    expect(RegexCvExtractor).not_to have_received(:call)
    expect(document.reload).to be_completed
    expect(document).to be_ai
  end

  it "falls back to RegexCvExtractor with parsing_method: basic when neither AI provider is available" do
    extraction = { first_name: "Jane", email: "jane@example.com" }
    allow(CvTextExtractor).to receive(:call).and_return("extracted cv text")
    allow(CvExtractionService).to receive(:call).and_return(nil)
    allow(GeminiCvExtractionService).to receive(:call).and_return(nil)
    allow(RegexCvExtractor).to receive(:call).with("extracted cv text").and_return(extraction)
    allow(CandidateProfilePrefiller).to receive(:call)

    described_class.perform_now(document.id)

    expect(CandidateProfilePrefiller).to have_received(:call).with(profile, extraction)
    expect(document.reload).to be_completed
    expect(document).to be_basic
  end

  it "marks the document failed (without raising) when no extractor finds anything usable — PRD §11 continue-manually path" do
    allow(CvTextExtractor).to receive(:call).and_return("extracted cv text")
    allow(CvExtractionService).to receive(:call).and_return(nil)
    allow(GeminiCvExtractionService).to receive(:call).and_return(nil)
    allow(RegexCvExtractor).to receive(:call).and_return(nil)

    expect { described_class.perform_now(document.id) }.not_to raise_error
    expect(document.reload).to be_failed
    expect(document.parsing_error).to be_present
  end

  it "marks the document failed when text extraction itself fails (e.g. unparsable file)" do
    allow(CvTextExtractor).to receive(:call).and_raise(CvTextExtractor::UnsupportedFormatError, "no antiword")

    described_class.perform_now(document.id)

    expect(document.reload).to be_failed
    expect(document.parsing_error).to eq("no antiword")
  end

  it "marks the document failed (without raising, and without leaving it stuck on processing) when prefilling the profile blows up unexpectedly (regression: an unrescued error here left documents in 'processing' forever, spinning the CV-analysis page indefinitely)" do
    extraction = { first_name: "Jane" }
    allow(CvTextExtractor).to receive(:call).and_return("extracted cv text")
    allow(CvExtractionService).to receive(:call).and_return(extraction)
    allow(CandidateProfilePrefiller).to receive(:call).and_raise(ActiveRecord::RecordInvalid)

    expect { described_class.perform_now(document.id) }.not_to raise_error

    expect(document.reload).to be_failed
    expect(document.parsing_error).to be_present
  end

  it "sets parsing_status to processing before extraction runs" do
    allow(CvTextExtractor).to receive(:call) do
      expect(document.reload).to be_processing
      "text"
    end
    allow(CvExtractionService).to receive(:call).and_return(nil)
    allow(GeminiCvExtractionService).to receive(:call).and_return(nil)
    allow(RegexCvExtractor).to receive(:call).and_return(nil)

    described_class.perform_now(document.id)
  end
end
