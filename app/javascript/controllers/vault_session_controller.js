import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.handlePageShow = this.handlePageShow.bind(this)
    window.addEventListener("pageshow", this.handlePageShow)
  }

  disconnect() {
    window.removeEventListener("pageshow", this.handlePageShow)
  }

  handlePageShow(event) {
    if (!event.persisted || !this.protectedPage) return

    window.location.reload()
  }

  get protectedPage() {
    return Boolean(document.querySelector("meta[name='password-manager-vault-protected']"))
  }
}
