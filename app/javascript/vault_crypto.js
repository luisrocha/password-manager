import { createVaultCrypto, validateVault } from "password_manager_vault_crypto"

const STORAGE_KEY = "passwordManager.encryptedPrivateKey"

const storage = {
  async get(key) {
    return window.localStorage.getItem(key)
  },

  async set(key, value) {
    window.localStorage.setItem(key, value)
  },

  async remove(key) {
    window.localStorage.removeItem(key)
  }
}

let vaultCrypto = null
let vaultCryptoPromise = null

async function getVaultCrypto() {
  vaultCryptoPromise ??= Promise.all([import("openpgp"), import("argon2_bridge")]).then(
    ([openpgp, { default: argon2 }]) => {
      vaultCrypto = createVaultCrypto({
        openpgp,
        argon2,
        storage,
        storageKey: STORAGE_KEY
      })

      return vaultCrypto
    }
  )

  return vaultCryptoPromise
}

export function hasStoredVault() {
  const serializedVault = window.localStorage.getItem(STORAGE_KEY)
  if (!serializedVault) return false

  validateVault(JSON.parse(serializedVault))
  return true
}

export function exportVaultBackup() {
  const vault = readStoredVault()

  return JSON.stringify(vault, null, 2)
}

export function exportMobileVaultTransfer() {
  const vault = readStoredVault()

  return JSON.stringify({
    t: "pmv",
    v: 1,
    d: {
      p: vault.publicKey,
      e: vault.encryptedPrivateKey,
      s: {
        p: vault.signing.publicKeySpki,
        e: vault.signing.encryptedPrivateKey,
        i: vault.signing.iv
      },
      k: {
        v: vault.kdf.version,
        t: vault.kdf.time,
        m: vault.kdf.memoryKiB,
        p: vault.kdf.parallelism,
        h: vault.kdf.hashLength,
        s: vault.kdf.salt
      },
      c: {
        i: vault.encryption.iv
      }
    }
  })
}

function readStoredVault() {
  const serializedVault = window.localStorage.getItem(STORAGE_KEY)
  if (!serializedVault) throw new Error("vault_missing")

  const vault = JSON.parse(serializedVault)
  validateVault(vault)

  return vault
}

export function importVaultBackup(serializedBackup) {
  const vault = JSON.parse(serializedBackup)
  validateVault(vault)
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(vault))

  return vault
}

export function isVaultUnlocked() {
  return vaultCrypto?.isVaultUnlocked() || false
}

export async function generateVault(masterPassword) {
  return (await getVaultCrypto()).generateVault(masterPassword)
}

export async function unlockVault(masterPassword) {
  return (await getVaultCrypto()).unlockVault(masterPassword)
}

export function lockVault() {
  vaultCrypto?.lockVault()
}

export async function encryptText(plaintext) {
  return (await getVaultCrypto()).encryptText(plaintext)
}

export async function decryptText(ciphertext) {
  return (await getVaultCrypto()).decryptText(ciphertext)
}

export async function buildUnlockProof(challenge) {
  return (await getVaultCrypto()).buildUnlockProof(challenge)
}
