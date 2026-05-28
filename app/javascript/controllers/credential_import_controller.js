import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { buildEncryptedImportRows } from "credential_importer"
import { isVaultUnlocked } from "vault_crypto"

export default class extends Controller {
  static targets = ["file", "fields", "status"]

  async submit(event) {
    if (this.submitting) return

    event.preventDefault()

    if (!this.element.reportValidity()) return

    if (!isVaultUnlocked()) {
      this.visit("/unlock")
      return
    }

    try {
      this.setStatus("Encrypting import...")
      const csv = await this.fileTarget.files[0].text()
      const rows = await buildEncryptedImportRows(csv)
      this.buildEncryptedFields(rows)
      this.submitting = true
      this.submitEncryptedImport(event.submitter)
    } catch (error) {
      this.setStatus(error.message || "Import failed.")
    }
  }

  buildEncryptedFields(rows) {
    this.fieldsTarget.replaceChildren()
    this.addHiddenField("encrypted_import", "1")

    for (const [index, row] of rows.entries()) {
      this.addHiddenField(`credentials[${index}][name]`, row.name)
      this.addHiddenField(`credentials[${index}][domain]`, row.domain)
      this.addHiddenField(`credentials[${index}][category]`, row.category)
      this.addHiddenField(`credentials[${index}][encrypted_secret_payload]`, row.encryptedSecretPayload)
    }
  }

  addHiddenField(name, value) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    input.value = value
    this.fieldsTarget.append(input)
  }

  setStatus(message) {
    this.statusTarget.textContent = message
  }

  submitEncryptedImport(submitter) {
    if (Turbo?.navigator?.submitForm) {
      Turbo.navigator.submitForm(this.element, submitter)
    } else {
      this.element.requestSubmit(submitter)
    }
  }

  visit(path) {
    if (Turbo) {
      Turbo.visit(path)
    } else {
      window.location.href = path
    }
  }
}
