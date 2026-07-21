require "rails_helper"

RSpec.describe Skill, type: :model do
  it "requires a name unique within its job function" do
    job_function = create(:job_function)
    create(:skill, name: "Endodontics", job_function: job_function)

    expect(build(:skill, name: "Endodontics", job_function: job_function)).not_to be_valid
  end

  it "allows the same skill name under a different job function" do
    create(:skill, name: "Prevention", job_function: create(:job_function))

    expect(build(:skill, name: "Prevention", job_function: create(:job_function))).to be_valid
  end
end
