import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { encryptText, isVaultUnlocked } from "vault_crypto"

const HEADER_MAP = {
  title: "name",
  name: "name",
  website: "domain",
  url: "domain",
  username: "username",
  password: "password",
  notes: "notes",
  category: "category",
  type: "category"
}

const CATEGORIES = ["login", "note", "api_key", "server", "database"]

export default class extends Controller {
  static targets = ["file", "fields", "status"]

  async submit(event) {
    if (this.submitting) return

    event.preventDefault()

    if (!this.element.reportValidity()) return

    if (!isVaultUnlocked()) {
      this.visit("/unlock")
      return
    }

    try {
      this.setStatus("Encrypting import...")
      const csv = await this.fileTarget.files[0].text()
      const rows = this.parseRows(csv).map((row) => this.normalizeRow(row))
      this.validateRows(rows)
      await this.buildEncryptedFields(rows)
      this.submitting = true
      this.submitEncryptedImport(event.submitter)
    } catch (error) {
      this.setStatus(error.message || "Import failed.")
    }
  }

  async buildEncryptedFields(rows) {
    this.fieldsTarget.replaceChildren()
    this.addHiddenField("encrypted_import", "1")

    for (const [index, row] of rows.entries()) {
      const encryptedPayload = await encryptText(JSON.stringify({
        username: row.username,
        password: row.password,
        notes: row.notes
      }))

      this.addHiddenField(`credentials[${index}][name]`, row.name)
      this.addHiddenField(`credentials[${index}][domain]`, row.domain)
      this.addHiddenField(`credentials[${index}][category]`, row.category)
      this.addHiddenField(`credentials[${index}][encrypted_secret_payload]`, encryptedPayload)
    }
  }

  parseRows(csv) {
    const rows = csv.replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n")
      .filter((line) => line.trim() !== "")
      .map((line) => this.parseLine(line))
    const headers = rows.shift()

    if (!headers) throw new Error("That CSV file is empty.")

    return rows.map((values) => Object.fromEntries(headers.map((header, index) => [header, values[index] || ""])))
  }

  parseLine(line) {
    const values = []
    let current = ""
    let inQuotes = false

    for (let index = 0; index < line.length; index += 1) {
      const char = line[index]

      if (char === "\"") {
        if (inQuotes && line[index + 1] === "\"") {
          current += "\""
          index += 1
        } else {
          inQuotes = !inQuotes
        }
      } else if (char === "," && !inQuotes) {
        values.push(current)
        current = ""
      } else {
        current += char
      }
    }

    values.push(current)
    return values
  }

  normalizeRow(row) {
    const normalized = {
      name: "",
      domain: "",
      username: "",
      password: "",
      notes: "",
      category: "login"
    }

    for (const [header, value] of Object.entries(row)) {
      const key = HEADER_MAP[header.trim().toLowerCase()]
      if (!key) continue

      normalized[key] = value.trim()
    }

    normalized.category = CATEGORIES.includes(normalized.category.toLowerCase()) ? normalized.category.toLowerCase() : "note"
    return normalized
  }

  validateRows(rows) {
    if (rows.length === 0) throw new Error("That CSV file has no rows to import.")

    rows.forEach((row, index) => {
      if ([row.name, row.domain, row.username].every((value) => value === "")) {
        throw new Error(`Row ${index + 2} is missing name, domain, or username.`)
      }
    })
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
  }

  submitEncryptedImport(submitter) {
    if (Turbo?.navigator?.submitForm) {
      Turbo.navigator.submitForm(this.element, submitter)
    } else {
      this.element.requestSubmit(submitter)
    }
  }

  visit(path) {
    if (Turbo) {
      Turbo.visit(path)
    } else {
      window.location.href = path
    }
  }
}
