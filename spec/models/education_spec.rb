require "rails_helper"

RSpec.describe Education, type: :model do
  it "requires a study/course" do
    expect(build(:education, study: nil)).not_to be_valid
  end

  it "does not require an institution (PRD §3.4: institution is optional)" do
    expect(build(:education, institution: nil)).to be_valid
  end

  it "defaults to source: manual" do
    expect(build(:education).manual?).to be(true)
  end
end
