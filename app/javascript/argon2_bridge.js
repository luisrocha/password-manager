const argon2 = window.argon2

if (!argon2) {
  throw new Error("argon2_unavailable")
}

export default argon2
