import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { decryptText, encryptText, isVaultUnlocked } from "vault_crypto"

export default class extends Controller {
  static targets = ["username", "password", "notes", "encryptedPayload"]
  static values = { encryptedPayload: String }

  connect() {
    if (this.existingPayloadPresent) this.decryptExistingPayload()
  }

  async submit(event) {
    if (this.submitting) return

    event.preventDefault()

    if (!this.element.reportValidity()) return

    if (!isVaultUnlocked()) {
      this.visit("/unlock")
      return
    }

    const payload = {
      username: this.usernameTarget.value,
      password: this.passwordTarget.value,
      notes: this.notesTarget.value
    }

    let encryptedPayload

    try {
      encryptedPayload = await encryptText(JSON.stringify(payload))
    } catch {
      this.submitting = false
      this.visit("/unlock")
      return
    }

    this.encryptedPayloadTarget.value = encryptedPayload
    this.submitting = true
    this.submitEncryptedForm(event.submitter)
  }

  async decryptExistingPayload() {
    if (!isVaultUnlocked()) {
      this.visit("/unlock")
      return
    }

    try {
      const payload = JSON.parse(await decryptText(this.encryptedPayloadValue))
      this.usernameTarget.value = payload.username || ""
      this.passwordTarget.value = payload.password || ""
      this.notesTarget.value = payload.notes || ""
    } catch {
      this.visit("/unlock")
    }
  }

  visit(path) {
    if (Turbo) {
      Turbo.visit(path)
    } else {
      window.location.href = path
    }
  }

  submitEncryptedForm(submitter) {
    if (Turbo?.navigator?.submitForm) {
      Turbo.navigator.submitForm(this.element, submitter)
    } else {
      this.element.requestSubmit(submitter)
    }
  }

  get existingPayloadPresent() {
    return this.hasEncryptedPayloadValue && this.encryptedPayloadValue.trim() !== ""
  }
}
