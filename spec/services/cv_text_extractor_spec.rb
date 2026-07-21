require "rails_helper"

RSpec.describe CvTextExtractor do
  # CvTextExtractor is a thin adapter over PDF::Reader / Docx::Document / the
  # antiword-or-catdoc shell-out — these specs stub those libraries directly
  # rather than hand-rolling binary PDF/DOCX fixtures, so they exercise *our*
  # dispatch/error-handling logic without re-testing the libraries themselves.
  let(:tempfile) { instance_double(Tempfile, path: "/tmp/fake-cv") }
  let(:blob) { instance_double(ActiveStorage::Blob) }
  # A plain double, not instance_double: ActiveStorage::Attached::One exposes
  # `blob`/`content_type` via delegate_missing_to (method_missing), which
  # verifying doubles can't see as real defined methods.
  let(:attachment) { double("attachment", blob: blob, content_type: content_type) } # rubocop:disable RSpec/VerifiedDoubles

  before do
    allow(blob).to receive(:open).and_yield(tempfile)
  end

  context "with a PDF" do
    let(:content_type) { CvTextExtractor::PDF_CONTENT_TYPE }

    it "joins page text extracted via PDF::Reader" do
      page1 = instance_double(PDF::Reader::Page, text: "Page one")
      page2 = instance_double(PDF::Reader::Page, text: "Page two")
      reader = instance_double(PDF::Reader, pages: [ page1, page2 ])
      allow(PDF::Reader).to receive(:new).with(tempfile.path).and_return(reader)

      expect(described_class.call(attachment)).to eq("Page one\nPage two")
    end

    it "raises ExtractionError when the PDF has no extractable text" do
      reader = instance_double(PDF::Reader, pages: [ instance_double(PDF::Reader::Page, text: "  ") ])
      allow(PDF::Reader).to receive(:new).and_return(reader)

      expect { described_class.call(attachment) }.to raise_error(CvTextExtractor::ExtractionError)
    end

    it "wraps a malformed PDF as an ExtractionError" do
      allow(PDF::Reader).to receive(:new).and_raise(PDF::Reader::MalformedPDFError.new("bad bytes"))

      expect { described_class.call(attachment) }.to raise_error(CvTextExtractor::ExtractionError, /Could not parse PDF/)
    end
  end

  context "with a DOCX" do
    let(:content_type) { CvTextExtractor::DOCX_CONTENT_TYPE }

    it "joins paragraph text extracted via Docx::Document" do
      paragraph = instance_double("Docx::Elements::Containers::Paragraph", text: "Hello from docx")
      doc = instance_double(Docx::Document, paragraphs: [ paragraph ])
      allow(Docx::Document).to receive(:open).with(tempfile.path).and_return(doc)

      expect(described_class.call(attachment)).to eq("Hello from docx")
    end
  end

  context "with a legacy .doc" do
    let(:content_type) { CvTextExtractor::DOC_CONTENT_TYPE }

    it "raises UnsupportedFormatError when neither antiword nor catdoc is available" do
      allow_any_instance_of(described_class).to receive(:system).and_return(false) # rubocop:disable RSpec/AnyInstance

      expect { described_class.call(attachment) }.to raise_error(CvTextExtractor::UnsupportedFormatError)
    end
  end

  context "with an unsupported content type" do
    let(:content_type) { "image/png" }

    it "raises UnsupportedFormatError" do
      expect { described_class.call(attachment) }.to raise_error(CvTextExtractor::UnsupportedFormatError)
    end
  end
end
