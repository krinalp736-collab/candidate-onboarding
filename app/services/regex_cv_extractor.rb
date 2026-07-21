# A free, no-AI fallback for CvExtractionService: pulls what a plain regex
# can reliably find (email, phone, a name guess from the first line) so the
# review form isn't left completely blank when no ANTHROPIC_API_KEY is
# configured. Deliberately narrow — it does not attempt job function,
# education, work experience, or skills, since guessing those from pattern
# matching alone would risk inventing data, which the PRD explicitly forbids.
# Everything it doesn't find comes back nil/empty, same contract as
# CvExtractionService, so ParseCandidateCvJob can treat either result
# identically.
class RegexCvExtractor
  # Unanchored on purpose: URI::MailTo::EMAIL_REGEXP is anchored (\A...\z) and
  # only validates that an entire string is one email address — it never
  # matches an address embedded inside a larger block of CV text.
  EMAIL_REGEX = /[a-zA-Z0-9.!\#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+/
  PHONE_REGEX = /\+?\d[\d\s\-().]{7,}\d/
  YEAR_RANGE_REGEX = /\A\d{4}\s*[-–]\s*\d{4}\z/
  MIN_PHONE_DIGITS = 9 # excludes false positives like a "2015 - 2019" education date range (8 digits)

  def self.call(text) = new(text).call

  def initialize(text)
    @text = text
  end

  def call
    email = extract_email
    phone = extract_phone
    first_name, last_name = extract_name

    return nil if email.blank? && phone.blank? && first_name.blank?

    {
      first_name: first_name, last_name: last_name, email: email, phone_number: phone,
      city: nil, country: nil, job_function_guess: nil, years_of_experience: nil,
      professional_summary: nil, big_number: nil, big_status_guess: nil,
      languages: [], education: [], work_experience: [], skills: []
    }
  end

  private

  attr_reader :text

  def extract_email
    text[EMAIL_REGEX]
  end

  # Scans every candidate match rather than just the first — a date range
  # like "2015 - 2019" matches the loose PHONE_REGEX shape just as well as a
  # real phone number does, so the first match in the text isn't necessarily
  # the right one. Keeps looking until it finds one that actually looks like
  # a phone number.
  def extract_phone
    text.scan(PHONE_REGEX).map(&:strip).find { |candidate| plausible_phone?(candidate) }
  end

  def plausible_phone?(candidate)
    return false if candidate.match?(YEAR_RANGE_REGEX)

    candidate.gsub(/\D/, "").length >= MIN_PHONE_DIGITS
  end

  # Heuristic: the candidate's own name is very commonly the first non-blank
  # line of a CV. Guard against matching a section header or contact line by
  # requiring 2-4 short, letters-only "words" (Unicode-aware, so accented
  # names like "Müller" or "de Vries" still match).
  def extract_name
    line = text.lines.map(&:strip).find(&:present?)
    return [ nil, nil ] unless line
    return [ nil, nil ] if line.match?(EMAIL_REGEX) || line.match?(PHONE_REGEX)

    words = line.split(/\s+/)
    return [ nil, nil ] unless words.size.between?(2, 4)
    return [ nil, nil ] unless words.all? { |w| w.match?(/\A[\p{L}'-.]+\z/) }

    [ words.first, words[1..].join(" ") ]
  end
end
