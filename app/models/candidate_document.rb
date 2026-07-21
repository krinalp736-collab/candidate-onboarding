class CandidateDocument < ApplicationRecord
  ALLOWED_CONTENT_TYPES = %w[
    application/pdf
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
  ].freeze

  MAX_FILE_SIZE_BYTES = (ENV["CV_MAX_FILE_SIZE_MB"] || "25").to_i.megabytes

  belongs_to :candidate_profile
  has_one_attached :file

  enum :document_type, { cv: 0 }
  enum :parsing_status, { pending: 0, processing: 1, completed: 2, failed: 3 }
  # Which extractor actually produced a completed result — lets the UI be
  # honest about whether this was a real AI read or the no-API-key fallback.
  enum :parsing_method, { basic: 0, ai: 1 }

  validate :file_attached_type_and_size, on: :upload

  before_validation :capture_file_metadata, on: :upload

  private

  def capture_file_metadata
    return unless file.attached?

    self.original_filename = file.filename.to_s
    self.content_type = file.content_type
    self.file_size = file.byte_size
  end

  def file_attached_type_and_size
    unless file.attached?
      errors.add(:file, "must be uploaded")
      return
    end

    unless ALLOWED_CONTENT_TYPES.include?(file.content_type)
      errors.add(:file, "must be a PDF, DOC, or DOCX")
    end

    if file.byte_size > MAX_FILE_SIZE_BYTES
      errors.add(:file, "is too large (maximum is #{MAX_FILE_SIZE_BYTES / 1.megabyte} MB)")
    end
  end
end
