import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { decryptText, encryptText, isVaultUnlocked } from "vault_crypto"

export default class extends Controller {
  static targets = ["name", "domain", "username", "password", "notes", "encryptedPayload"]
  static values = { encryptedPayload: String }

  connect() {
    this.clearIdentityValidation = this.clearIdentityValidation.bind(this)
    this.nameTarget.addEventListener("input", this.clearIdentityValidation)
    this.domainTarget.addEventListener("input", this.clearIdentityValidation)
    this.usernameTarget.addEventListener("input", this.clearIdentityValidation)

    if (this.existingPayloadPresent) this.decryptExistingPayload()
  }

  disconnect() {
    this.nameTarget.removeEventListener("input", this.clearIdentityValidation)
    this.domainTarget.removeEventListener("input", this.clearIdentityValidation)
    this.usernameTarget.removeEventListener("input", this.clearIdentityValidation)
  }

  async submit(event) {
    if (this.submitting) return

    event.preventDefault()

    this.validateIdentity()
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

  validateIdentity() {
    this.clearIdentityValidation()
    const hasIdentity = [this.nameTarget, this.domainTarget, this.usernameTarget].some((target) => target.value.trim() !== "")

    if (!hasIdentity) {
      this.usernameTarget.setCustomValidity("Enter a name, domain, or username.")
    }
  }

  clearIdentityValidation() {
    this.usernameTarget.setCustomValidity("")
  }

  get existingPayloadPresent() {
    return this.hasEncryptedPayloadValue && this.encryptedPayloadValue.trim() !== ""
  }
}
