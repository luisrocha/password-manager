import * as openpgp from "openpgp"

const STORAGE_KEY = "passwordManager.encryptedPrivateKey"
const BACKUP_VERSION = 1
const KDF_ITERATIONS = 600000
const SALT_BYTES = 16
const IV_BYTES = 12
const AES_KEY_LENGTH = 256
const TEXT_ENCODER = new TextEncoder()
const TEXT_DECODER = new TextDecoder()

let unlockedPrivateKey = null
let unlockedPublicKey = null

export function hasStoredVault() {
  return readStoredVault() !== null
}

export function isVaultUnlocked() {
  return unlockedPrivateKey !== null && unlockedPublicKey !== null
}

export async function generateVault(masterPassword) {
  const { privateKey, publicKey } = await openpgp.generateKey({
    type: "ecc",
    curve: "curve25519",
    userIDs: [{ name: "Password Manager Vault" }]
  })

  const vault = await buildEncryptedVault(privateKey, publicKey, masterPassword)
  storeVault(vault)

  unlockedPrivateKey = await openpgp.readPrivateKey({ armoredKey: privateKey })
  unlockedPublicKey = await openpgp.readKey({ armoredKey: publicKey })

  return vault
}

export async function unlockVault(masterPassword) {
  const vault = readStoredVault()
  if (!vault) throw new Error("vault_missing")

  const privateKey = await decryptPrivateKey(vault, masterPassword)

  unlockedPrivateKey = await openpgp.readPrivateKey({ armoredKey: privateKey })
  unlockedPublicKey = await openpgp.readKey({ armoredKey: vault.publicKey })

  return true
}

export function lockVault() {
  unlockedPrivateKey = null
  unlockedPublicKey = null
}

export function exportVaultBackup() {
  const vault = readStoredVault()
  if (!vault) throw new Error("vault_missing")

  return JSON.stringify(vault, null, 2)
}

export function importVaultBackup(serializedBackup) {
  const vault = JSON.parse(serializedBackup)
  validateVault(vault)
  storeVault(vault)

  return vault
}

export async function encryptText(plaintext) {
  assertUnlocked()

  return openpgp.encrypt({
    message: await openpgp.createMessage({ text: plaintext.toString() }),
    encryptionKeys: unlockedPublicKey
  })
}

export async function decryptText(ciphertext) {
  assertUnlocked()

  const message = await openpgp.readMessage({ armoredMessage: ciphertext.toString() })
  const { data } = await openpgp.decrypt({
    message,
    decryptionKeys: unlockedPrivateKey,
    format: "utf8"
  })

  return data
}

function readStoredVault() {
  const serializedVault = window.localStorage.getItem(STORAGE_KEY)
  if (!serializedVault) return null

  const vault = JSON.parse(serializedVault)
  validateVault(vault)

  return vault
}

function storeVault(vault) {
  validateVault(vault)
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(vault))
}

async function buildEncryptedVault(privateKey, publicKey, masterPassword) {
  const salt = crypto.getRandomValues(new Uint8Array(SALT_BYTES))
  const iv = crypto.getRandomValues(new Uint8Array(IV_BYTES))
  const key = await deriveWrappingKey(masterPassword, salt)
  const encryptedPrivateKey = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    key,
    TEXT_ENCODER.encode(privateKey)
  )

  return {
    version: BACKUP_VERSION,
    publicKey,
    encryptedPrivateKey: encodeBase64(encryptedPrivateKey),
    kdf: {
      name: "PBKDF2",
      hash: "SHA-256",
      iterations: KDF_ITERATIONS,
      salt: encodeBase64(salt)
    },
    encryption: {
      name: "AES-GCM",
      iv: encodeBase64(iv)
    }
  }
}

async function decryptPrivateKey(vault, masterPassword) {
  const salt = decodeBase64(vault.kdf.salt)
  const iv = decodeBase64(vault.encryption.iv)
  const key = await deriveWrappingKey(masterPassword, salt)
  const privateKey = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv },
    key,
    decodeBase64(vault.encryptedPrivateKey)
  )

  return TEXT_DECODER.decode(privateKey)
}

async function deriveWrappingKey(masterPassword, salt) {
  const baseKey = await crypto.subtle.importKey(
    "raw",
    TEXT_ENCODER.encode(masterPassword),
    "PBKDF2",
    false,
    ["deriveKey"]
  )

  return crypto.subtle.deriveKey(
    {
      name: "PBKDF2",
      hash: "SHA-256",
      salt,
      iterations: KDF_ITERATIONS
    },
    baseKey,
    { name: "AES-GCM", length: AES_KEY_LENGTH },
    false,
    ["encrypt", "decrypt"]
  )
}

function validateVault(vault) {
  if (vault?.version !== BACKUP_VERSION) throw new Error("vault_unsupported")
  if (!vault.publicKey || !vault.encryptedPrivateKey) throw new Error("vault_invalid")
  if (vault.kdf?.name !== "PBKDF2" || !vault.kdf.salt) throw new Error("vault_invalid")
  if (vault.encryption?.name !== "AES-GCM" || !vault.encryption.iv) throw new Error("vault_invalid")
}

function assertUnlocked() {
  if (!isVaultUnlocked()) throw new Error("vault_locked")
}

function encodeBase64(value) {
  const bytes = value instanceof ArrayBuffer ? new Uint8Array(value) : value
  return btoa(String.fromCharCode(...bytes))
}

function decodeBase64(value) {
  return Uint8Array.from(atob(value), (character) => character.charCodeAt(0))
}
