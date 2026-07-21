# Extracts structured candidate data from raw CV text using Claude, so
# CandidateProfilePrefiller can populate the review form.
#
# Design constraints straight from the PRD (§5):
#   - Never invent data — every field is nullable and the prompt explicitly
#     forbids guessing, so an absent CV field comes back null rather than
#     fabricated.
#   - Supports CVs in any language Claude can read (PRD §5: "Dutch and
#     English at minimum", "ideally... common European dental CV formats") —
#     the prompt below does not hardcode a language allowlist.
#   - Uncertain fields must be marked for review, not silently trusted.
#
# If ANTHROPIC_API_KEY isn't configured (e.g. local dev without credentials),
# #call returns nil rather than raising — ParseCandidateCvJob treats that the
# same as a parser failure, which the PRD already requires the UI to handle
# ("continue manually").
class CvExtractionService
  MODEL = "claude-opus-4-8"
  MAX_TOKENS = 4096

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You extract structured candidate data from dental-industry CVs/resumes for
    a recruitment platform. The CV may be written in any language — Dutch and
    English at minimum, but also German, French, Spanish, or any other
    language commonly used in European dental CVs. Detect the language
    automatically; do not assume it is English.

    Rules:
    - Only extract information that is explicitly present in the CV text.
    - Never invent, guess, or infer missing information. If a field is not
      present or not clearly stated, return null for it (or an empty array
      for list fields).
    - Do not translate extracted text (names, institutions, job titles,
      responsibilities, the professional summary, etc.) — keep it in the
      language and wording the CV actually uses. Translating would mean
      altering the candidate's own words, which is a form of inventing data.
    - The one exception is "job_function_guess": always return this as the
      English platform category name (see list below), even when the CV
      itself is in another language, since it must match the platform's
      fixed job-function list.
    - For any education or work experience entry where dates, titles, or
      company names are ambiguous, unclear, or inferred rather than stated
      outright, set "needs_review" to true for that entry.
    - "job_function_guess" should be your best match of the candidate's most
      recent or primary role to a dental job category (e.g. "General dentist",
      "Dental hygienist", "Dental assistant", "Prevention assistant",
      "Orthodontic assistant", "Front-office / receptionist",
      "Practice manager", "Dental technician", "Specialist"), or null if you
      cannot confidently determine one.
  PROMPT

  RESPONSE_SCHEMA = {
    type: "object",
    additionalProperties: false,
    required: %w[
      first_name last_name email phone_number city country
      job_function_guess years_of_experience professional_summary
      big_number big_status_guess languages education work_experience skills
    ],
    properties: {
      first_name: { type: %w[string null] },
      last_name: { type: %w[string null] },
      email: { type: %w[string null] },
      phone_number: { type: %w[string null] },
      city: { type: %w[string null] },
      country: { type: %w[string null] },
      job_function_guess: { type: %w[string null] },
      years_of_experience: { type: %w[number null] },
      professional_summary: { type: %w[string null] },
      big_number: { type: %w[string null] },
      big_status_guess: {
        type: %w[string null],
        description: "e.g. 'registered', 'in_progress', 'under_supervision', or null"
      },
      languages: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: %w[name level],
          properties: {
            name: { type: "string" },
            level: { type: %w[string null], description: "e.g. B2, fluent, native" }
          }
        }
      },
      education: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: %w[institution study city_and_country level start_date end_date needs_review],
          properties: {
            institution: { type: %w[string null] },
            study: { type: %w[string null] },
            city_and_country: { type: %w[string null] },
            level: { type: %w[string null], description: "mbo, hbo, bachelor, master, doctor, or course" },
            start_date: { type: %w[string null], description: "ISO 8601 date, YYYY-MM-DD" },
            end_date: { type: %w[string null], description: "ISO 8601 date, YYYY-MM-DD" },
            needs_review: { type: "boolean" }
          }
        }
      },
      work_experience: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: %w[job_title company_name responsibilities start_date end_date current_job needs_review],
          properties: {
            job_title: { type: %w[string null] },
            company_name: { type: %w[string null] },
            responsibilities: { type: %w[string null] },
            start_date: { type: %w[string null], description: "ISO 8601 date, YYYY-MM-DD" },
            end_date: { type: %w[string null], description: "ISO 8601 date, YYYY-MM-DD" },
            current_job: { type: "boolean" },
            needs_review: { type: "boolean" }
          }
        }
      },
      skills: {
        type: "array",
        items: { type: "string" },
        description: "Flat list of skill names mentioned or clearly implied by the CV"
      }
    }
  }.freeze

  def self.call(text) = new(text).call

  def initialize(text)
    @text = text
  end

  def call
    return nil unless configured?

    response = client.messages.create(
      model: MODEL,
      max_tokens: MAX_TOKENS,
      system_: SYSTEM_PROMPT,
      output_config: { format: { type: "json_schema", schema: RESPONSE_SCHEMA } },
      messages: [ { role: "user", content: text } ]
    )

    parse_response(response)
  rescue Anthropic::Errors::APIError => e
    Rails.logger.error("[CvExtractionService] Claude API error: #{e.class}: #{e.message}")
    nil
  end

  private

  attr_reader :text

  def configured?
    ENV["ANTHROPIC_API_KEY"].present?
  end

  def client
    @client ||= Anthropic::Client.new
  end

  def parse_response(response)
    block = response.content.find { |c| c.respond_to?(:text) }
    return nil unless block

    if block.respond_to?(:parsed) && block.parsed
      block.parsed
    else
      JSON.parse(block.text, symbolize_names: true)
    end
  rescue JSON::ParserError => e
    Rails.logger.error("[CvExtractionService] Could not parse Claude response as JSON: #{e.message}")
    nil
  end
end
