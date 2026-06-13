import { Controller } from "@hotwired/stimulus"
import qrcode from "qrcode-generator"
import { exportCompactVaultBackup, hasStoredVault } from "vault_crypto"

export default class extends Controller {
  static targets = ["button", "qrCode", "status"]

  exportVaultKey() {
    this.clearStatus()
    this.hideQrCode()

    if (!hasStoredVault()) {
      this.setError("Unlock the vault before setting up the mobile app.")
      return
    }

    this.buttonTarget.disabled = true
    this.buttonTarget.textContent = "Exporting..."

    try {
      this.qrCodeTarget.innerHTML = this.buildQrCode(exportCompactVaultBackup())
      this.qrCodeTarget.classList.remove("hidden")
      this.setStatus("Scan this QR code with the mobile app.")
    } catch {
      this.setError("This vault key is too large for one QR code. Chunked mobile setup is needed.")
    } finally {
      this.buttonTarget.disabled = false
      this.buttonTarget.textContent = "Export vault key"
    }
  }

  buildQrCode(serializedBackup) {
    const qrCode = qrcode(0, "L")
    qrCode.addData(serializedBackup, "Byte")
    qrCode.make()

    return qrCode.createSvgTag({
      cellSize: 2,
      margin: 8,
      scalable: false,
      title: "Encrypted vault key QR code"
    })
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

  hideQrCode() {
    this.qrCodeTarget.innerHTML = ""
    this.qrCodeTarget.classList.add("hidden")
  }
}
