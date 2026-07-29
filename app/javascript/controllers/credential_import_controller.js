import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { buildCredentialExportCsv, buildEncryptedImportRows } from "credential_importer"
import { isVaultUnlocked, unlockVault } from "vault_crypto"

export default class extends Controller {
  static targets = [
    "file",
    "fields",
    "status",
    "exportStatus",
    "exportModal",
    "exportMasterPassword",
    "exportTwoFactorCode"
  ]
  static values = { exportUrl: String }

  async submit(event) {
    if (this.submitting) return

    const form = event.currentTarget
    event.preventDefault()
    this.clearStatus()

    if (!form.reportValidity()) return

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
      this.submitEncryptedImport(form, event.submitter)
    } catch (error) {
      this.setError(error.message || "Import failed.")
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

  submitEncryptedImport(form, submitter) {
    if (Turbo?.navigator?.submitForm) {
      Turbo.navigator.submitForm(form, submitter)
    } else {
      form.requestSubmit(submitter)
    }
  }

  async export(event) {
    event.preventDefault()
    this.clearExportStatus()
    this.exportModalTarget.showModal()
    this.exportMasterPasswordTarget.focus()
  }

  closeExportModal() {
    this.exportModalTarget.close()
    this.clearExportFields()
    this.clearExportStatus()
  }

  async confirmExport(event) {
    event.preventDefault()
    this.clearExportStatus()

    try {
      await unlockVault(this.exportMasterPasswordTarget.value)
      const credentials = await this.fetchExportCredentials(this.exportTwoFactorCode)
      if (!credentials) return
      if (credentials.length === 0) {
        this.setExportError("There are no credentials to export.")
        return
      }

      this.downloadCsv(await buildCredentialExportCsv(credentials))
      this.closeExportModal()
      this.clearExportStatus()
    } catch {
      this.setExportError("Export failed. Check your master password and two-factor code.")
    }
  }

  async fetchExportCredentials(code) {
    const response = await fetch(this.exportUrlValue, {
      method: "POST",
      headers: this.exportHeaders(),
      body: JSON.stringify({ code })
    })

    if (response.redirected) {
      this.visit(response.url)
      return null
    }
    if (!response.ok) throw new Error("export_failed")

    return (await response.json()).credentials || []
  }

  exportHeaders() {
    const headers = { Accept: "application/json", "Content-Type": "application/json" }
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    if (csrfToken) headers["X-CSRF-Token"] = csrfToken
    return headers
  }

  downloadCsv(csv) {
    const url = URL.createObjectURL(new Blob([csv], { type: "text/csv;charset=utf-8" }))
    const link = document.createElement("a")
    link.href = url
    link.download = `password-manager-credentials-${new Date().toISOString().slice(0, 10)}.csv`
    link.click()
    URL.revokeObjectURL(url)
  }

  setExportError(message) {
    this.exportStatusTarget.textContent = message
    this.exportStatusTarget.className = "mt-4 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800"
  }

  clearExportStatus() {
    this.exportStatusTarget.textContent = ""
    this.exportStatusTarget.className = "hidden"
  }

  clearExportFields() {
    this.exportMasterPasswordTarget.value = ""
    if (this.hasExportTwoFactorCodeTarget) this.exportTwoFactorCodeTarget.value = ""
  }

  get exportTwoFactorCode() {
    return this.hasExportTwoFactorCodeTarget ? this.exportTwoFactorCodeTarget.value : ""
  }

  visit(path) {
    if (Turbo) {
      Turbo.visit(path)
    } else {
      window.location.href = path
    }
  }
}
