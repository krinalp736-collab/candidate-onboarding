require "rails_helper"

RSpec.describe RegexCvExtractor do
  it "extracts an email address" do
    result = described_class.call("Jane Doe\nContact: jane.doe@example.com\nAmsterdam")

    expect(result[:email]).to eq("jane.doe@example.com")
  end

  it "extracts a plain-digit phone number with no separators" do
    result = described_class.call("Jane Doe\n0612345678\njane@example.com")

    expect(result[:phone_number]).to eq("0612345678")
  end

  it "extracts a formatted international phone number" do
    result = described_class.call("Jane Doe\n+31 6 1234 5678\njane@example.com")

    expect(result[:phone_number]).to eq("+31 6 1234 5678")
  end

  it "guesses first/last name from the first non-blank line" do
    result = described_class.call("\n  \nJane Doe\njane@example.com")

    expect(result[:first_name]).to eq("Jane")
    expect(result[:last_name]).to eq("Doe")
  end

  it "handles accented names (Unicode-aware, not just ASCII letters)" do
    result = described_class.call("Anna Müller\nanna@example.de")

    expect(result[:first_name]).to eq("Anna")
    expect(result[:last_name]).to eq("Müller")
  end

  it "does not guess a name from a line that is actually the email or phone" do
    result = described_class.call("jane.doe@example.com\n+31 6 1234 5678")

    expect(result[:first_name]).to be_nil
  end

  it "does not guess a name from a section header or long line" do
    result = described_class.call("CURRICULUM VITAE FOR SENIOR DENTAL PROFESSIONAL\njane@example.com")

    expect(result[:first_name]).to be_nil
  end

  it "never invents job function, education, work experience, or skills" do
    result = described_class.call("Jane Doe\njane@example.com")

    expect(result[:job_function_guess]).to be_nil
    expect(result[:education]).to eq([])
    expect(result[:work_experience]).to eq([])
    expect(result[:skills]).to eq([])
  end

  it "returns nil when nothing at all can be found" do
    result = described_class.call("Lorem ipsum dolor sit amet, no contact info here at all.")

    expect(result).to be_nil
  end

  # Regression: caught live against a real uploaded CV — an education date
  # range like "2015 - 2019" matches PHONE_REGEX's loose shape just as well
  # as an actual phone number does.
  describe "false-positive phone matches (regression)" do
    it "does not mistake a 'YYYY - YYYY' education date range for a phone number" do
      result = described_class.call(<<~CV)
        Jan de Vries
        jan@example.com
        Opleiding: Mondzorgkunde, Hogeschool Utrecht (2015 - 2019)
      CV

      expect(result[:phone_number]).to be_nil
    end

    it "still finds a real phone number elsewhere in the text even when a date range appears first" do
      result = described_class.call(<<~CV)
        Jan de Vries
        Opleiding: Mondzorgkunde, Hogeschool Utrecht (2015 - 2019)
        +31 6 1234 5678
        jan@example.com
      CV

      expect(result[:phone_number]).to eq("+31 6 1234 5678")
    end

    it "rejects short digit runs below the minimum phone length" do
      result = described_class.call("Jane Doe\njane@example.com\nRef: 123456")

      expect(result[:phone_number]).to be_nil
    end
  end
end
