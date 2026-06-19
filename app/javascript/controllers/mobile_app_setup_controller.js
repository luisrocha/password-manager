import { Controller } from "@hotwired/stimulus"
import { exportMobileVaultTransfer, hasStoredVault } from "vault_crypto"

export default class extends Controller {
  static targets = ["button", "code", "panel", "status"]
  static values = { pairingUrl: String }

  async createPairingCode() {
    this.clearStatus()
    this.hidePairingCode()

    if (!hasStoredVault()) {
      this.setError("Unlock the vault before setting up the mobile app.")
      return
    }

    this.buttonTarget.disabled = true
    this.buttonTarget.textContent = "Creating..."

    try {
      const response = await fetch(this.pairingUrlValue, {
        method: "POST",
        headers: this.headers(),
        body: JSON.stringify({ encrypted_vault_backup: exportMobileVaultTransfer() })
      })
      const body = await response.json()

      if (!response.ok) throw new Error(body.error || "pairing_failed")

      this.showPairingCode(body.code)
      this.setStatus(
        `Enter this code in the mobile app within ${Math.round(body.expires_in_seconds / 60)} minutes.`
      )
    } catch {
      this.setError("Could not create a mobile pairing code.")
    } finally {
      this.buttonTarget.disabled = false
      this.buttonTarget.textContent = "Create pairing code"
    }
  }

  headers() {
    const headers = { "Content-Type": "application/json" }
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    if (csrfToken) headers["X-CSRF-Token"] = csrfToken
    return headers
  }

  setStatus(message) {
    this.statusTarget.textContent = message
    this.statusTarget.className = "mt-4 rounded-md border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-900"
  }

  setError(message) {
    this.statusTarget.textContent = message
    this.statusTarget.className = "mt-4 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800"
  }

  clearStatus() {
    this.statusTarget.textContent = ""
    this.statusTarget.className = "hidden"
  }

  showPairingCode(code) {
    this.codeTarget.replaceChildren(...this.buildCodeCharacters(code))
    this.panelTarget.classList.remove("hidden")
  }

  hidePairingCode() {
    this.codeTarget.replaceChildren()
    this.panelTarget.classList.add("hidden")
  }

  buildCodeCharacters(code) {
    return [...code].map((character) => {
      const span = document.createElement("span")
      span.textContent = character

      span.className = /\d/.test(character) ? "text-amber-700" : ""

      return span
    })
  }
}
