import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { decryptText, isVaultUnlocked } from "vault_crypto"

export default class extends Controller {
  static targets = ["username", "password", "notes", "passwordButton", "notesButton"]
  static values = { encryptedPayload: String }

  connect() {
    this.revealUsername()
  }

  async revealUsername() {
    await this.revealField("username")
  }

  async revealPassword(event) {
    event.preventDefault()
    await this.toggleField("password")
  }

  async revealNotes(event) {
    event.preventDefault()
    await this.toggleField("notes")
  }

  async revealField(field) {
    if (!isVaultUnlocked()) {
      this.visit("/unlock")
      return false
    }

    try {
      const payload = JSON.parse(await decryptText(this.encryptedPayloadValue))
      this[`${field}Target`].textContent = payload[field] || "-"
      return true
    } catch {
      this.visit("/unlock")
      return false
    }
  }

  async toggleField(field) {
    if (this[`${field}ButtonTarget`].dataset.revealed === "true") {
      this[`${field}Target`].textContent = "Hidden"
      this.updateToggleButton(field, false)
      this[`${field}ButtonTarget`].dataset.revealed = "false"
      return
    }

    const revealed = await this.revealField(field)
    if (!revealed) return

    this.updateToggleButton(field, true)
    this[`${field}ButtonTarget`].dataset.revealed = "true"
  }

  updateToggleButton(field, revealed) {
    const label = `${revealed ? "Hide" : "Reveal"} ${field}`
    this[`${field}ButtonTarget`].setAttribute("aria-label", label)
    this[`${field}ButtonTarget`].setAttribute("title", label)
    this[`${field}ButtonTarget`].classList.toggle("is-visible", revealed)
  }

  visit(path) {
    if (Turbo) {
      Turbo.visit(path)
    } else {
      window.location.href = path
    }
  }
}
