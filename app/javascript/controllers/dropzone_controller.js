import { Controller } from "@hotwired/stimulus"

// PRD §7.1: drag-and-drop CV upload. Progressive enhancement only — the
// underlying <input type="file"> still works via a normal click without JS.
export default class extends Controller {
  static targets = ["input", "filename", "dropzone"]

  dragover(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.add("border-primary", "bg-primary-subtle")
  }

  dragleave() {
    this.dropzoneTarget.classList.remove("border-primary", "bg-primary-subtle")
  }

  drop(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("border-primary", "bg-primary-subtle")

    const files = event.dataTransfer.files
    if (files.length > 0) {
      this.inputTarget.files = files
      this.updateFilename()
    }
  }

  updateFilename() {
    const file = this.inputTarget.files[0]
    if (file && this.hasFilenameTarget) {
      this.filenameTarget.textContent = file.name
    }
  }
}
