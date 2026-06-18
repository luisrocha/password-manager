import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

Turbo.StreamActions.refresh_credentials = function () {
  window.dispatchEvent(new CustomEvent("credentials:refresh"))
}

export default class extends Controller {
  connect() {
    this.refresh = this.refresh.bind(this)
    this.refreshQueued = false
    this.refreshing = false
    window.addEventListener("credentials:refresh", this.refresh)
  }

  disconnect() {
    window.removeEventListener("credentials:refresh", this.refresh)
  }

  async refresh() {
    if (this.refreshing) {
      this.refreshQueued = true
      return
    }

    this.refreshing = true

    try {
      await this.replaceCredentialsIndex()
    } finally {
      this.refreshing = false

      if (this.refreshQueued) {
        this.refreshQueued = false
        this.refresh()
      }
    }
  }

  async replaceCredentialsIndex() {
    const response = await fetch(window.location.href, {
      credentials: "same-origin",
      headers: {
        Accept: "text/html",
        "X-Credentials-Live-Refresh": "1"
      }
    })

    if (!response.ok || response.redirected) return

    const html = await response.text()
    const nextDocument = new DOMParser().parseFromString(html, "text/html")
    const nextIndex = nextDocument.querySelector("#credentials_index")
    const currentIndex = document.querySelector("#credentials_index")

    if (!nextIndex || !currentIndex) return

    currentIndex.replaceWith(nextIndex)
  }
}
