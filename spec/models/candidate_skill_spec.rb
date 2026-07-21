require "rails_helper"

RSpec.describe CandidateSkill, type: :model do
  it "is valid with a matched platform skill and no suggested_name" do
    cs = build(:candidate_skill, skill: create(:skill), suggested_name: nil)
    expect(cs).to be_valid
  end

  it "is valid with only a suggested_name (unmatched CV skill, PRD §3.6)" do
    cs = build(:candidate_skill, skill: nil, suggested_name: "Laser dentistry")
    expect(cs).to be_valid
  end

  it "is invalid with neither a skill nor a suggested_name" do
    cs = build(:candidate_skill, skill: nil, suggested_name: nil)
    expect(cs).not_to be_valid
  end

  describe "#display_name" do
    it "prefers the matched skill's name" do
      skill = create(:skill, name: "Endodontics")
      expect(build(:candidate_skill, skill: skill, suggested_name: "ignored").display_name).to eq("Endodontics")
    end

    it "falls back to suggested_name when unmatched" do
      expect(build(:candidate_skill, skill: nil, suggested_name: "Laser dentistry").display_name).to eq("Laser dentistry")
    end
  end
end
