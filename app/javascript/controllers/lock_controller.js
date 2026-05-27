import { Controller } from "@hotwired/stimulus"
import { lockVault } from "vault_crypto"

export default class extends Controller {
  clear() {
    lockVault()
  }
}
