import argon2 from "argon2_bridge"
import * as openpgp from "openpgp"
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

const vaultCrypto = createVaultCrypto({
  openpgp,
  argon2,
  storage,
  storageKey: STORAGE_KEY
})

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

export function exportCompactVaultBackup() {
  return JSON.stringify(readStoredVault())
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

export const isVaultUnlocked = vaultCrypto.isVaultUnlocked
export const generateVault = vaultCrypto.generateVault
export const unlockVault = vaultCrypto.unlockVault
export const lockVault = vaultCrypto.lockVault
export const encryptText = vaultCrypto.encryptText
export const decryptText = vaultCrypto.decryptText
export const buildUnlockProof = vaultCrypto.buildUnlockProof
