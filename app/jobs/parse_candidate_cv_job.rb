# Runs CV parsing off the request cycle so the upload step doesn't time out
# while Claude processes the document (PRD §2/§6).
class ParseCandidateCvJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(candidate_document_id)
    document = CandidateDocument.find(candidate_document_id)
    document.update!(parsing_status: :processing)

    text = CvTextExtractor.call(document.file)

    if (extraction = CvExtractionService.call(text))
      complete!(document, extraction, method: :ai)
    elsif (extraction = GeminiCvExtractionService.call(text))
      # No ANTHROPIC_API_KEY, but a GEMINI_API_KEY is configured — still a
      # real AI read, just a different provider.
      complete!(document, extraction, method: :ai)
    elsif (extraction = RegexCvExtractor.call(text))
      # Neither AI provider is configured — fall back to plain pattern
      # matching rather than leaving the form fully blank.
      complete!(document, extraction, method: :basic)
    else
      # Neither extractor found anything usable — candidate completes
      # manually, per PRD §2/§11.
      document.update!(parsing_status: :failed, parsing_error: "No data could be extracted from this CV.", parsed_at: Time.current)
    end
  rescue CvTextExtractor::ExtractionError => e
    document.update!(parsing_status: :failed, parsing_error: e.message, parsed_at: Time.current)
  rescue StandardError => e
    # An extraction came back, but something about mapping it onto the
    # profile blew up (e.g. an unexpected data shape). Fail the document
    # rather than leaving it stuck on "processing" forever — the candidate
    # can still continue manually (PRD §11) instead of the page polling
    # indefinitely with no way out.
    Rails.logger.error("[ParseCandidateCvJob] #{e.class}: #{e.message}")
    document.update!(parsing_status: :failed, parsing_error: "No data could be extracted from this CV.", parsed_at: Time.current)
  end

  private

  def complete!(document, extraction, method:)
    CandidateProfilePrefiller.call(document.candidate_profile, extraction)
    document.update!(parsing_status: :completed, parsing_method: method, parsed_at: Time.current)
  end
end
