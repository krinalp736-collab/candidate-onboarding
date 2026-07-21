# Free-tier alternative to CvExtractionService for candidates who have a
# Google Gemini API key (aistudio.google.com) but no Anthropic key. Same
# input/output contract as CvExtractionService (nil on failure/not
# configured, otherwise a symbolized extraction hash) so it slots into
# ParseCandidateCvJob's fallback chain the same way.
#
# There is no official Google Ruby SDK for the Gemini API, so this talks to
# the REST API directly via Net::HTTP rather than guessing at SDK bindings
# that don't exist. Reuses CvExtractionService's SYSTEM_PROMPT; the response
# schema is converted to Gemini's own Schema dialect (see GEMINI_RESPONSE_SCHEMA
# below) since it isn't plain JSON Schema.
class GeminiCvExtractionService
  # An alias, not a dated snapshot — Google points it at whatever the current
  # recommended flash model is, so it doesn't go stale the way a pinned
  # version does (gemini-2.5-flash 404s for newer API keys/projects even
  # though it's still listed in GET /models).
  MODEL = "gemini-flash-latest"
  API_BASE = "https://generativelanguage.googleapis.com/v1beta"
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 60

  # The free tier returns transient 429 (rate limited) / 5xx (overloaded)
  # responses under normal load — these usually clear within a few seconds,
  # so retry a couple of times (with backoff) before giving up and letting
  # ParseCandidateCvJob fall back to RegexCvExtractor. A 4xx other than 429
  # (bad key, bad request) won't be fixed by retrying, so those fail fast.
  MAX_ATTEMPTS = 3
  RETRY_DELAY_SECONDS = 2
  RETRYABLE_STATUS_CODES = %w[429 500 502 503 504].freeze
  RETRYABLE_ERRORS = [ SocketError, Timeout::Error, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError ].freeze

  # Gemini's `responseSchema` is Google's own proto-based Schema object (a
  # restricted OpenAPI 3.0 subset, verified against ai.google.dev/api/caching#Schema)
  # — NOT plain JSON Schema. Confirmed live against the actual API (it 400s
  # otherwise): `additionalProperties` isn't a recognized field at all, and
  # `type` must be a single uppercase enum (STRING/NUMBER/INTEGER/BOOLEAN/
  # ARRAY/OBJECT) rather than JSON Schema's `["string", "null"]` array —
  # nullability is instead a sibling `nullable: true` boolean. Converting
  # CvExtractionService::RESPONSE_SCHEMA here (once, at load time) keeps one
  # source of truth instead of hand-duplicating the whole nested schema.
  def self.to_gemini_schema(schema)
    types = Array(schema[:type])
    nullable = types.delete("null")
    converted = { type: types.first.upcase }
    converted[:nullable] = true if nullable

    converted[:description] = schema[:description] if schema[:description]
    converted[:required] = schema[:required] if schema[:required]
    converted[:properties] = schema[:properties].transform_values { |v| to_gemini_schema(v) } if schema[:properties]
    converted[:items] = to_gemini_schema(schema[:items]) if schema[:items]
    converted
  end

  GEMINI_RESPONSE_SCHEMA = to_gemini_schema(CvExtractionService::RESPONSE_SCHEMA).freeze

  def self.call(text) = new(text).call

  def initialize(text)
    @text = text
  end

  def call
    return nil unless configured?

    attempt(1)
  end

  private

  attr_reader :text

  def attempt(number)
    response = post_generate_content
    return parse_response(response) if response.is_a?(Net::HTTPSuccess)

    if RETRYABLE_STATUS_CODES.include?(response.code) && number < MAX_ATTEMPTS
      retry_after("HTTP #{response.code}", number)
      return attempt(number + 1)
    end

    Rails.logger.error("[GeminiCvExtractionService] HTTP #{response.code}: #{response.body}")
    nil
  rescue *RETRYABLE_ERRORS => e
    if number < MAX_ATTEMPTS
      retry_after("#{e.class}: #{e.message}", number)
      return attempt(number + 1)
    end

    Rails.logger.error("[GeminiCvExtractionService] network error: #{e.class}: #{e.message}")
    nil
  end

  def retry_after(reason, number)
    Rails.logger.warn("[GeminiCvExtractionService] #{reason}, retrying (attempt #{number + 1}/#{MAX_ATTEMPTS})")
    sleep(RETRY_DELAY_SECONDS * number)
  end

  def configured?
    ENV["GEMINI_API_KEY"].present?
  end

  def post_generate_content
    uri = URI("#{API_BASE}/models/#{MODEL}:generateContent")
    uri.query = URI.encode_www_form(key: ENV["GEMINI_API_KEY"])

    request_body = {
      systemInstruction: { parts: [ { text: CvExtractionService::SYSTEM_PROMPT } ] },
      contents: [ { parts: [ { text: text } ] } ],
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: GEMINI_RESPONSE_SCHEMA
      }
    }.to_json

    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      http.post(uri, request_body, "Content-Type" => "application/json")
    end
  end

  # Only ever called with a Net::HTTPSuccess (see #attempt).
  def parse_response(response)
    body = JSON.parse(response.body)
    generated_text = body.dig("candidates", 0, "content", "parts", 0, "text")
    return nil if generated_text.blank?

    JSON.parse(generated_text, symbolize_names: true)
  rescue JSON::ParserError => e
    Rails.logger.error("[GeminiCvExtractionService] Could not parse Gemini response: #{e.message}")
    nil
  end
end
