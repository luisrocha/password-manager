import { Controller } from "@hotwired/stimulus"
import {
  buildUnlockProof,
  exportVaultBackup,
  generateVault,
  hasStoredVault,
  importVaultBackup,
  lockVault,
  unlockVault
} from "vault_crypto"

export default class extends Controller {
  static targets = [
    "setupPanel",
    "setupTitle",
    "setupForm",
    "unlockPanel",
    "importPanel",
    "setupPassword",
    "setupConfirmation",
    "unlockPassword",
    "backupFile",
    "cancelImportButton",
    "flow",
    "description",
    "sessionForm",
    "status",
    "backupActions",
    "backupDownload",
    "continueButton",
    "challenge",
    "signature",
    "signingPublicKey"
  ]

  connect() {
    lockVault()
    this.flowTarget.classList.remove("hidden")
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
      this.setupFormTarget.classList.add("hidden")
      this.setupTitleTarget.textContent = "Back up vault key"
      this.prepareBackupDownload()
      this.backupActionsTarget.classList.remove("hidden")
      this.backupActionsTarget.classList.add("flex")
      this.setDescription("Download the vault key backup before continuing to the vault.")
      this.showStatus("Vault key created.")
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
      await this.unlockRailsSession()
    } catch {
      this.showError("Invalid master password.")
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
      const serializedBackup = await file.text()
      await this.verifyBackupKey(serializedBackup)
      importVaultBackup(serializedBackup)
      this.showStatus("Backup imported. Enter your master password to unlock.")
      this.showUnlock()
    } catch {
      this.showError("That backup file is invalid or unsupported.")
    }
  }

  async continueToVault() {
    await this.unlockRailsSession()
  }

  cancelImport() {
    this.clearStatus()
    if (hasStoredVault()) {
      this.showUnlock()
    } else if (this.vaultRegistered) {
      this.showImport()
      this.showStatus("Vault key not found on this browser. Import your vault key backup to continue.")
    } else {
      this.showSetup()
    }
  }

  showSetup(event) {
    event?.preventDefault()
    this.hideAllPanels()
    this.setDescription("Create a local vault key for this browser.")
    this.setupTitleTarget.textContent = "Create vault key"
    this.setupFormTarget.classList.remove("hidden")
    this.backupActionsTarget.classList.add("hidden")
    this.backupActionsTarget.classList.remove("flex")
    this.setupPanelTarget.classList.remove("hidden")
    this.setupPasswordTarget.focus()
  }

  showUnlock(event) {
    event?.preventDefault()
    this.hideAllPanels()
    this.setDescription("Enter your master password to unlock the vault.")
    this.unlockPanelTarget.classList.remove("hidden")
    this.unlockPasswordTarget.focus()
  }

  showImport(event) {
    event?.preventDefault()
    this.hideAllPanels()
    this.setDescription("Import your vault key backup to use this browser.")
    this.cancelImportButtonTarget.classList.remove("hidden")
    this.importPanelTarget.classList.remove("hidden")
    this.backupFileTarget.focus()
  }

  showInitialState() {
    try {
      if (hasStoredVault()) {
        this.showUnlock()
      } else if (this.vaultRegistered) {
        this.showImport()
        this.cancelImportButtonTarget.classList.add("hidden")
        this.showStatus("Vault key not found on this browser. Import your vault key backup to continue.")
      } else {
        this.showSetup()
      }
    } catch {
      this.showImport()
      this.showError("Stored vault data could not be read. Import your vault key backup to continue.")
    }
  }

  async unlockRailsSession() {
    const proof = await buildUnlockProof(this.challengeTarget.dataset.challenge)

    this.signatureTarget.value = proof.signature
    this.signingPublicKeyTarget.value = proof.signingPublicKeySpki
    this.sessionFormTarget.requestSubmit()
  }

  prepareBackupDownload() {
    const backup = new Blob([exportVaultBackup()], { type: "application/json" })
    const backupUrl = URL.createObjectURL(backup)

    this.backupDownloadTarget.href = backupUrl
    this.backupDownloadTarget.classList.remove("hidden")
  }

  async verifyBackupKey(serializedBackup) {
    if (!this.vaultRegistered) return

    const backup = JSON.parse(serializedBackup)
    const response = await fetch("/unlock/verify_backup_key", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
      },
      body: JSON.stringify({
        signing_public_key_spki: backup.signing?.publicKeySpki
      })
    })

    if (!response.ok) throw new Error("backup_key_mismatch")
  }

  hideAllPanels() {
    this.setupPanelTarget.classList.add("hidden")
    this.unlockPanelTarget.classList.add("hidden")
    this.importPanelTarget.classList.add("hidden")
  }

  showStatus(message) {
    this.statusTarget.textContent = message
    this.statusTarget.className = "rounded-md border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-900"
  }

  showError(message) {
    this.statusTarget.textContent = message
    this.statusTarget.className = "rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800"
  }

  clearStatus() {
    this.statusTarget.textContent = ""
    this.statusTarget.className = "hidden"
  }

  setDescription(message) {
    this.descriptionTarget.textContent = message
  }

  get vaultRegistered() {
    return this.challengeTarget.dataset.vaultRegistered === "true"
  }
}
