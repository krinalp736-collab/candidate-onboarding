import { Controller } from "@hotwired/stimulus"

// Dependency-free "add another" / "remove" repeater for the Education and
// Work Experience sections (PRD §3.4/§3.5), following Rails' standard
// <template> + child_index: "NEW_RECORD" nested-attributes pattern.
export default class extends Controller {
  static targets = ["target", "template"]

  add(event) {
    event.preventDefault()

    const uniqueId = new Date().getTime()
    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, uniqueId)
    this.targetTarget.insertAdjacentHTML("beforebegin", content)
  }

  remove(event) {
    event.preventDefault()

    const wrapper = event.target.closest("[data-nested-fields-target='fields']")
    const destroyField = wrapper.querySelector("input[name*='_destroy']")

    if (destroyField) {
      destroyField.value = "1"
      wrapper.classList.add("d-none")
    } else {
      wrapper.remove()
    }
  }
}
