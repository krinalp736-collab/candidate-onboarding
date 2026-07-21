require "rails_helper"

RSpec.describe CandidateDocument, type: :model do
  def attach_file!(document, filename, content_type)
    document.file.attach(
      io: StringIO.new("fake file content"),
      filename: filename,
      content_type: content_type
    )
  end

  describe "context: :upload validations (PRD §8: PDF/DOC/DOCX, configurable max size)" do
    it "is invalid without a file attached" do
      document = build(:candidate_document)
      expect(document.valid?(:upload)).to be(false)
      expect(document.errors[:file]).to be_present
    end

    it "accepts a PDF" do
      document = build(:candidate_document)
      attach_file!(document, "cv.pdf", "application/pdf")
      expect(document.valid?(:upload)).to be(true)
    end

    it "accepts a DOCX" do
      document = build(:candidate_document)
      attach_file!(document, "cv.docx", "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
      expect(document.valid?(:upload)).to be(true)
    end

    it "rejects an unsupported file type" do
      document = build(:candidate_document)
      attach_file!(document, "cv.png", "image/png")
      expect(document.valid?(:upload)).to be(false)
      expect(document.errors[:file]).to include("must be a PDF, DOC, or DOCX")
    end

    it "rejects a file larger than the configured maximum" do
      document = build(:candidate_document)
      document.file.attach(
        io: StringIO.new("x" * 10),
        filename: "cv.pdf",
        content_type: "application/pdf"
      )
      allow(document.file).to receive(:byte_size).and_return(CandidateDocument::MAX_FILE_SIZE_BYTES + 1)
      expect(document.valid?(:upload)).to be(false)
      expect(document.errors[:file].join).to include("too large")
    end

    it "captures original_filename/content_type/file_size from the attached blob" do
      document = build(:candidate_document)
      attach_file!(document, "cv.pdf", "application/pdf")
      document.valid?(:upload)

      expect(document.original_filename).to eq("cv.pdf")
      expect(document.content_type).to eq("application/pdf")
      expect(document.file_size).to be_present
    end
  end

  it "defaults to parsing_status: pending" do
    expect(build(:candidate_document).pending?).to be(true)
  end
end
