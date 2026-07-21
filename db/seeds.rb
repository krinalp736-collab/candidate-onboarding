# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# PRD §3.2 example job categories. clinical_group drives §4's conditional
# logic (BIG registration + average daily revenue fields, shown only for the
# "dentist" group here — General dentist and Specialist; the PRD's own §3.3
# table also mentions hygienists/prevention assistants for revenue, but §4's
# explicit conditional-logic section scopes it to dentist/hygienist/specialist
# only, so hygienists are grouped in for BIG+revenue while assistant-type
# roles are not).
JOB_FUNCTIONS = [
  { name: "General dentist", clinical_group: "dentist", position: 0 },
  { name: "Dental hygienist", clinical_group: "dentist", position: 1 },
  { name: "Dental assistant", clinical_group: "assistant", position: 2 },
  { name: "Prevention assistant", clinical_group: "assistant", position: 3 },
  { name: "Paro-prevention assistant", clinical_group: "assistant", position: 4 },
  { name: "Orthodontic assistant", clinical_group: "assistant", position: 5 },
  { name: "Front-office / receptionist", clinical_group: "front_office", position: 6 },
  { name: "Practice manager", clinical_group: "practice_manager", position: 7 },
  { name: "Dental technician", clinical_group: "technician", position: 8 },
  { name: "Specialist", clinical_group: "dentist", position: 9 }
].freeze

# PRD §3.6 skill groups, keyed by the job function name above.
SKILLS_BY_JOB_FUNCTION = {
  "General dentist" => %w[Endodontics Restorative\ dentistry Pediatric\ dentistry Surgery Aligners],
  "Dental hygienist" => [ "Periodontology", "Prevention", "Scaling", "Patient education" ],
  "Dental assistant" => [ "Chairside assistance", "Sterilization", "Orthodontics", "Prevention" ],
  "Front-office / receptionist" => [ "Planning", "Phone handling", "Invoicing", "Patient communication" ],
  "Practice manager" => [ "Team management", "Scheduling", "HR", "Practice operations" ],
  "Dental technician" => [ "Prosthetics", "CAD/CAM", "Crown and bridge work" ]
}.freeze

LANGUAGES = [
  %w[English en], %w[Dutch nl], %w[German de], %w[French fr], %w[Spanish es],
  %w[Turkish tr], %w[Arabic ar], %w[Polish pl], %w[Portuguese pt], %w[Italian it]
].freeze

JOB_FUNCTIONS.each do |attrs|
  JobFunction.find_or_create_by!(name: attrs[:name]) do |jf|
    jf.clinical_group = attrs[:clinical_group]
    jf.position = attrs[:position]
  end
end

SKILLS_BY_JOB_FUNCTION.each do |job_function_name, skill_names|
  job_function = JobFunction.find_by!(name: job_function_name)
  skill_names.each { |name| Skill.find_or_create_by!(name: name, job_function: job_function) }
end

LANGUAGES.each do |name, code|
  Language.find_or_create_by!(code: code) { |l| l.name = name }
end

# AdminUser has no self-registration (see AdminUser), so the first account
# has to come from somewhere — seed one from the environment, defaulting to
# credentials that mirror the old HTTP Basic Auth setup they replace.
AdminUser.find_or_create_by!(email: ENV.fetch("ADMIN_EMAIL", "admin@example.com")) do |admin_user|
  admin_user.password = ENV.fetch("ADMIN_PASSWORD", "password123")
end

puts "Seeded #{JobFunction.count} job functions, #{Skill.count} skills, #{Language.count} languages, #{AdminUser.count} admin user(s)."
