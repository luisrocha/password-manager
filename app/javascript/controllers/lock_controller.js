import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { lockVault } from "vault_crypto"

export default class extends Controller {
  clear() {
    window.dispatchEvent(new CustomEvent("vault:lock"))
    Turbo.cache.clear()
    lockVault()
  }
}
