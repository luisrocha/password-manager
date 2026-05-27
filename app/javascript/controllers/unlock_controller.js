import { Controller } from "@hotwired/stimulus"
import {
  exportVaultBackup,
  generateVault,
  hasStoredVault,
  importVaultBackup,
  unlockVault
} from "vault_crypto"

export default class extends Controller {
  static targets = [
    "setupPanel",
    "unlockPanel",
    "importPanel",
    "setupPassword",
    "setupConfirmation",
    "unlockPassword",
    "backupFile",
    "sessionPassword",
    "sessionForm",
    "status",
    "backupDownload",
    "continueButton"
  ]

  connect() {
    this.showInitialState()
  }

  async setup(event) {
    event.preventDefault()
    this.clearStatus()

    const masterPassword = this.setupPasswordTarget.value
    if (masterPassword !== this.setupConfirmationTarget.value) {
      this.showError("Master password confirmation does not match.")
      return
    }

    try {
      await generateVault(masterPassword)
      this.sessionPasswordTarget.value = masterPassword
      this.prepareBackupDownload()
      this.continueButtonTarget.classList.remove("hidden")
      this.showStatus("Vault key created. Download a backup before continuing.")
    } catch {
      this.showError("Vault setup failed. Please try again.")
    }
  }

  async unlock(event) {
    event.preventDefault()
    this.clearStatus()

    const masterPassword = this.unlockPasswordTarget.value

    try {
      await unlockVault(masterPassword)
      this.sessionPasswordTarget.value = masterPassword
      this.unlockRailsSession()
    } catch {
      this.showError("Could not unlock the local vault with that master password.")
    }
  }

  async importBackup(event) {
    event.preventDefault()
    this.clearStatus()

    const file = this.backupFileTarget.files[0]
    if (!file) {
      this.showError("Choose a backup file to import.")
      return
    }

    try {
      importVaultBackup(await file.text())
      this.showStatus("Backup imported. Enter your master password to unlock.")
      this.showUnlock()
    } catch {
      this.showError("That backup file is invalid or unsupported.")
    }
  }

  continueToVault() {
    this.unlockRailsSession()
  }

  showSetup(event) {
    event?.preventDefault()
    this.hideAllPanels()
    this.setupPanelTarget.classList.remove("hidden")
    this.setupPasswordTarget.focus()
  }

  showUnlock(event) {
    event?.preventDefault()
    this.hideAllPanels()
    this.unlockPanelTarget.classList.remove("hidden")
    this.unlockPasswordTarget.focus()
  }

  showImport(event) {
    event?.preventDefault()
    this.hideAllPanels()
    this.importPanelTarget.classList.remove("hidden")
    this.backupFileTarget.focus()
  }

  showInitialState() {
    try {
      hasStoredVault() ? this.showUnlock() : this.showSetup()
    } catch {
      this.showImport()
      this.showError("Stored vault data could not be read. Import a backup to continue.")
    }
  }

  unlockRailsSession() {
    this.sessionFormTarget.requestSubmit()
  }

  prepareBackupDownload() {
    const backup = new Blob([exportVaultBackup()], { type: "application/json" })
    const backupUrl = URL.createObjectURL(backup)

    this.backupDownloadTarget.href = backupUrl
    this.backupDownloadTarget.classList.remove("hidden")
  }

  hideAllPanels() {
    this.setupPanelTarget.classList.add("hidden")
    this.unlockPanelTarget.classList.add("hidden")
    this.importPanelTarget.classList.add("hidden")
  }

  showStatus(message) {
    this.statusTarget.textContent = message
    this.statusTarget.className = "flash notice"
  }

  showError(message) {
    this.statusTarget.textContent = message
    this.statusTarget.className = "flash alert"
  }

  clearStatus() {
    this.statusTarget.textContent = ""
    this.statusTarget.className = "hidden"
  }
}
