import { Controller } from "@hotwired/stimulus"

// Drives PRD §4's conditional form logic: which fields are relevant depends
// on the selected job function (BIG registration, revenue, skill groups) and
// the selected employment type(s) (salary vs. percentage).
export default class extends Controller {
  static targets = ["bigFields", "revenueField", "salaryField", "percentageField", "skillGroup"]
  static values = { clinicalJobFunctionIds: Array, employmentTypeField: String }

  connect() {
    this.refresh()
  }

  refresh() {
    this.toggleClinicalFields()
    this.toggleEmploymentFields()
    this.toggleSkillGroups()
  }

  toggleClinicalFields() {
    const select = this.element.querySelector("[data-conditional-fields-role='job-function']")
    if (!select) return

    const isClinical = this.clinicalJobFunctionIdsValue.includes(select.value)

    this.bigFieldsTargets.forEach((el) => this.toggle(el, isClinical))
    this.revenueFieldTargets.forEach((el) => this.toggle(el, isClinical))
  }

  toggleEmploymentFields() {
    const checked = Array.from(
      this.element.querySelectorAll("[data-conditional-fields-role='employment-type']:checked")
    ).map((el) => el.value)

    const showSalary = checked.includes("employed")
    const showPercentage = ["self_employed", "freelance", "percentage_based"].some((t) => checked.includes(t))

    this.salaryFieldTargets.forEach((el) => this.toggle(el, showSalary))
    this.percentageFieldTargets.forEach((el) => this.toggle(el, showPercentage))
  }

  toggleSkillGroups() {
    const select = this.element.querySelector("[data-conditional-fields-role='job-function']")
    if (!select) return

    this.skillGroupTargets.forEach((el) => {
      this.toggle(el, el.dataset.jobFunctionId === select.value)
    })
  }

  toggle(element, show) {
    element.classList.toggle("d-none", !show)
  }
}
