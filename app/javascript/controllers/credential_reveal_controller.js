import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { decryptText, isVaultUnlocked } from "vault_crypto"

export default class extends Controller {
  static targets = ["username", "password", "notes", "passwordButton", "notesButton"]
  static values = { encryptedPayload: String }

  connect() {
    this.clearSecrets = this.clearSecrets.bind(this)
    this.revealUsername = this.revealUsername.bind(this)
    document.addEventListener("turbo:before-cache", this.clearSecrets)
    document.addEventListener("turbo:render", this.revealUsername)
    window.addEventListener("vault:lock", this.clearSecrets)

    this.revealUsername()
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.clearSecrets)
    document.removeEventListener("turbo:render", this.revealUsername)
    window.removeEventListener("vault:lock", this.clearSecrets)
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

  async copyUsername(event) {
    event.preventDefault()
    event.stopPropagation()
    await this.copyField("username", event.currentTarget)
  }

  async copyPassword(event) {
    event.preventDefault()
    event.stopPropagation()
    await this.copyField("password", event.currentTarget)
  }

  async revealField(field) {
    if (!isVaultUnlocked()) {
      this.visit("/unlock")
      return false
    }

    try {
      const payload = await this.decryptPayload()
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

  async copyField(field, button) {
    if (!isVaultUnlocked()) {
      this.visit("/unlock")
      return
    }

    let payload

    try {
      payload = await this.decryptPayload()
    } catch {
      this.visit("/unlock")
      return
    }

    try {
      await this.writeClipboard(payload[field] || "")
      this.confirmCopy(button, field)
    } catch {
      this.failCopy(button, field)
    }
  }

  confirmCopy(button, field) {
    const label = `Copy ${field}`
    const status = this.copyStatusFor(button)

    button.setAttribute("aria-label", `Copied ${field}`)
    button.setAttribute("title", `Copied ${field}`)
    this.showCopyStatus(status, "Copied")
    window.setTimeout(() => {
      button.setAttribute("aria-label", label)
      button.setAttribute("title", label)
      this.hideCopyStatus(status)
    }, 1200)
  }

  failCopy(button, field) {
    const label = `Copy ${field}`
    const status = this.copyStatusFor(button)

    button.setAttribute("aria-label", `Could not copy ${field}`)
    button.setAttribute("title", `Could not copy ${field}`)
    this.showCopyStatus(status, "Copy failed")
    window.setTimeout(() => {
      button.setAttribute("aria-label", label)
      button.setAttribute("title", label)
      this.hideCopyStatus(status)
    }, 1200)
  }

  copyStatusFor(button) {
    return button.closest("[data-copy-group]")?.querySelector("[data-copy-status]")
  }

  showCopyStatus(status, message) {
    if (!status) return

    status.textContent = message
    status.classList.remove("hidden")
  }

  hideCopyStatus(status) {
    if (!status) return

    status.textContent = ""
    status.classList.add("hidden")
  }

  async writeClipboard(text) {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(text)
      return
    }

    const textarea = document.createElement("textarea")
    textarea.value = text
    textarea.setAttribute("readonly", "")
    textarea.style.position = "fixed"
    textarea.style.opacity = "0"
    document.body.append(textarea)
    textarea.select()

    try {
      if (!document.execCommand("copy")) throw new Error("copy_failed")
    } finally {
      textarea.remove()
    }
  }

  async decryptPayload() {
    return JSON.parse(await decryptText(this.encryptedPayloadValue))
  }

  clearSecrets() {
    if (this.hasUsernameTarget) this.usernameTarget.textContent = "Decrypting..."
    if (this.hasPasswordTarget) this.passwordTarget.textContent = "Hidden"
    if (this.hasNotesTarget) this.notesTarget.textContent = "Hidden"

    if (this.hasPasswordButtonTarget) {
      this.updateToggleButton("password", false)
      this.passwordButtonTarget.dataset.revealed = "false"
    }
    if (this.hasNotesButtonTarget) {
      this.updateToggleButton("notes", false)
      this.notesButtonTarget.dataset.revealed = "false"
    }

    this.element.querySelectorAll("[data-copy-status]").forEach((status) => this.hideCopyStatus(status))
  }

  visit(path) {
    if (Turbo) {
      Turbo.visit(path)
    } else {
      window.location.href = path
    }
  }
}
