import { Controller } from "@hotwired/stimulus"
import { decryptText, encryptText, isVaultUnlocked } from "vault_crypto"

export default class extends Controller {
  static targets = ["username", "password", "notes", "encryptedPayload"]
  static values = { encryptedPayload: String }

  connect() {
    if (this.hasEncryptedPayloadValue) this.decryptExistingPayload()
  }

  async submit(event) {
    if (this.submitting) return

    event.preventDefault()

    if (!isVaultUnlocked()) {
      window.location.href = "/unlock"
      return
    }

    const payload = {
      username: this.usernameTarget.value,
      password: this.passwordTarget.value,
      notes: this.notesTarget.value
    }

    this.encryptedPayloadTarget.value = await encryptText(JSON.stringify(payload))
    this.submitting = true
    this.element.requestSubmit()
  }

  async decryptExistingPayload() {
    if (!isVaultUnlocked()) return

    const payload = JSON.parse(await decryptText(this.encryptedPayloadValue))
    this.usernameTarget.value = payload.username || ""
    this.passwordTarget.value = payload.password || ""
    this.notesTarget.value = payload.notes || ""
  }
}
