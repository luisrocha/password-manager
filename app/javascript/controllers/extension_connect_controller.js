import { Controller } from "@hotwired/stimulus"
import { exportVaultBackup, hasStoredVault } from "vault_crypto"

const CONNECTED_KEY = "passwordManager.extensionConnected"
const EXTENSION_ID_KEY = "passwordManager.extensionId"

export default class extends Controller {
  static targets = ["button", "notification", "status"]
  static values = {
    extensionId: String
  }

  connect() {
    this.captureExtensionId()
    this.updateConnectedState()
    this.refreshConnectedState()
  }

  async connectExtension() {
    this.clearStatus()

    if (!this.extensionId) {
      this.showError("Open the web app from the extension before connecting.")
      return
    }

    if (!this.extensionMessagingAvailable) {
      this.showError("Extension messaging is not available in this browser.")
      return
    }

    if (!hasStoredVault()) {
      this.showError("Unlock the vault before connecting the extension.")
      return
    }

    try {
      const response = await this.sendExtensionMessage({
        type: "IMPORT_VAULT_BACKUP",
        serializedBackup: exportVaultBackup()
      })

      if (!response?.ok) {
        this.showError(response?.error || "Could not connect extension.")
        return
      }

      window.localStorage.setItem(CONNECTED_KEY, "1")
      this.updateConnectedState()
      this.showStatus("Extension connected.")
    } catch {
      this.showError("Could not connect extension.")
    }
  }

  updateConnectedState() {
    if (!this.hasButtonTarget) return

    const connected = window.localStorage.getItem(CONNECTED_KEY) === "1"
    this.buttonTargets.forEach((button) => {
      button.textContent = connected ? "Reconnect Extension" : "Connect Extension"
    })
  }

  async refreshConnectedState() {
    if (!this.extensionId || !this.extensionMessagingAvailable) return

    try {
      const response = await this.sendExtensionMessage({ type: "PING" })
      if (!response?.ok) return

      window.localStorage.setItem(CONNECTED_KEY, response.hasVault ? "1" : "0")
      this.updateConnectedState()
    } catch {
      // Keep the local hint unchanged when the extension cannot be reached.
    }
  }

  sendExtensionMessage(message) {
    return new Promise((resolve, reject) => {
      chrome.runtime.sendMessage(this.extensionId, message, (response) => {
        const error = chrome.runtime.lastError
        if (error) {
          reject(error)
          return
        }

        resolve(response)
      })
    })
  }

  captureExtensionId() {
    const url = new URL(window.location.href)
    const extensionId = url.searchParams.get("extension_id") || this.extensionIdValue
    if (!extensionId) return

    window.localStorage.setItem(EXTENSION_ID_KEY, extensionId)
    url.searchParams.delete("extension_id")
    window.history.replaceState({}, "", `${url.pathname}${url.search}${url.hash}`)
  }

  get extensionId() {
    return window.localStorage.getItem(EXTENSION_ID_KEY)
  }

  get extensionMessagingAvailable() {
    return typeof chrome !== "undefined" && Boolean(chrome.runtime?.sendMessage)
  }

  showStatus(message) {
    if (!this.hasStatusTarget) return

    this.dismissNotifications()
    this.statusTarget.textContent = message
    this.statusTarget.className = "mb-4 rounded-md border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-900"
  }

  showError(message) {
    if (!this.hasStatusTarget) return

    this.dismissNotifications()
    this.statusTarget.textContent = message
    this.statusTarget.className = "mb-4 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800"
  }

  clearStatus() {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = ""
    this.statusTarget.className = "hidden"
  }

  dismissNotifications() {
    this.notificationTargets.forEach((notification) => {
      notification.classList.add("hidden")
    })
  }
}
