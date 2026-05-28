import { encryptText } from "vault_crypto"

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

export async function buildEncryptedImportRows(csv) {
  const rows = parseRows(csv).map((row) => normalizeRow(row))
  validateRows(rows)

  return Promise.all(rows.map(async (row) => ({
    name: row.name,
    domain: row.domain,
    category: row.category,
    encryptedSecretPayload: await encryptText(JSON.stringify({
      username: row.username,
      password: row.password,
      notes: row.notes
    }))
  })))
}

function parseRows(csv) {
  const rows = csv.replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n")
    .filter((line) => line.trim() !== "")
    .map((line) => parseLine(line))
  const headers = rows.shift()

  if (!headers) throw new Error("That CSV file is empty.")

  return rows.map((values) => Object.fromEntries(headers.map((header, index) => [header, values[index] || ""])))
}

function parseLine(line) {
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

function normalizeRow(row) {
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

function validateRows(rows) {
  if (rows.length === 0) throw new Error("That CSV file has no rows to import.")

  rows.forEach((row, index) => {
    if ([row.name, row.domain, row.username].every((value) => value === "")) {
      throw new Error(`Row ${index + 2} is missing name, domain, or username.`)
    }
  })
}
