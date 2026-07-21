require "shellwords"

# Extracts plain text from an uploaded CV (PDF, DOCX, or legacy DOC) so it can
# be handed to CvExtractionService for structured-data extraction.
#
# Legacy .doc (pre-2007 binary Word format) has no maintained pure-Ruby reader;
# it's supported here only if `antiword` or `catdoc` happens to be installed
# on the host. When neither is available we raise UnsupportedFormatError,
# which ParseCandidateCvJob turns into parsing_status: :failed — matching the
# PRD's "if the CV cannot be parsed, the candidate can still continue
# manually" fallback rather than a hard error.
class CvTextExtractor
  class ExtractionError < StandardError; end
  class UnsupportedFormatError < ExtractionError; end

  DOC_CONTENT_TYPE = "application/msword"
  DOCX_CONTENT_TYPE = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
  PDF_CONTENT_TYPE = "application/pdf"

  def self.call(attachment)
    new(attachment).call
  end

  def initialize(attachment)
    @attachment = attachment
  end

  def call
    attachment.blob.open do |tempfile|
      case attachment.content_type
      when PDF_CONTENT_TYPE
        extract_pdf(tempfile)
      when DOCX_CONTENT_TYPE
        extract_docx(tempfile)
      when DOC_CONTENT_TYPE
        extract_doc(tempfile)
      else
        raise UnsupportedFormatError, "Unsupported content type: #{attachment.content_type}"
      end
    end
  end

  private

  attr_reader :attachment

  def extract_pdf(tempfile)
    text = PDF::Reader.new(tempfile.path).pages.map(&:text).join("\n")
    raise ExtractionError, "PDF contained no extractable text" if text.strip.empty?

    text
  rescue PDF::Reader::MalformedPDFError => e
    raise ExtractionError, "Could not parse PDF: #{e.message}"
  end

  def extract_docx(tempfile)
    doc = Docx::Document.open(tempfile.path)
    text = doc.paragraphs.map(&:text).join("\n")
    raise ExtractionError, "DOCX contained no extractable text" if text.strip.empty?

    text
  end

  def extract_doc(tempfile)
    converter = %w[antiword catdoc].find { |bin| system("which #{bin} > /dev/null 2>&1") }
    raise UnsupportedFormatError, "Legacy .doc parsing requires antiword or catdoc on the server" unless converter

    text = `#{converter} #{tempfile.path.shellescape} 2>/dev/null`
    raise ExtractionError, "Could not extract text from .doc file" if text.strip.empty?

    text
  end
end
