require "rails_helper"

RSpec.describe JobFunction, type: :model do
  it "requires a name" do
    expect(build(:job_function, name: nil)).not_to be_valid
  end

  it "requires a unique name" do
    create(:job_function, name: "General dentist")
    expect(build(:job_function, name: "General dentist")).not_to be_valid
  end

  it "rejects an unknown clinical_group" do
    expect(build(:job_function, clinical_group: "not_a_group")).not_to be_valid
  end

  describe "#clinical?" do
    it "is true only for the dentist clinical_group" do
      expect(build(:job_function, :clinical)).to be_clinical
      expect(build(:job_function, clinical_group: "assistant")).not_to be_clinical
    end
  end
end
