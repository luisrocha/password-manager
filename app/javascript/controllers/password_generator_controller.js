import { Controller } from "@hotwired/stimulus"

const DEFAULT_GENERATED_PASSWORD_LENGTH = 20
const MIN_GENERATED_PASSWORD_LENGTH = 8
const MAX_GENERATED_PASSWORD_LENGTH = 100
const PASSWORD_LETTERS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
const PASSWORD_NUMBERS = "0123456789"
const PASSWORD_SYMBOLS = "!@#$%^&*()-_=+[]{};:,.<>?"

export default class extends Controller {
  static targets = [
    "password",
    "visibilityButton",
    "toggleButton",
    "panel",
    "length",
    "lengthValue",
    "numbers",
    "symbols"
  ]

  static classes = ["hidden"]

  connect() {
    this.resetOptions()
    this.resetPasswordVisibility()
  }

  toggleVisibility() {
    const willShow = this.passwordTarget.type === "password"

    this.passwordTarget.type = willShow ? "text" : "password"
    this.setPasswordVisibilityButton(willShow)
  }

  toggleOptions() {
    const willShow = this.panelTarget.classList.contains(this.hiddenClass)

    this.panelTarget.classList.toggle(this.hiddenClass, !willShow)
    this.toggleButtonTarget.setAttribute("aria-expanded", String(willShow))

    if (willShow) this.lengthTarget.focus()
  }

  updateLength() {
    this.lengthValueTarget.textContent = String(this.normalizedLength)
  }

  generate() {
    const length = this.normalizedLength

    this.lengthTarget.value = String(length)
    this.updateLength()
    this.passwordTarget.value = this.buildPassword({
      length,
      includeNumbers: this.hasNumbersTarget && this.numbersTarget.checked,
      includeSymbols: this.hasSymbolsTarget && this.symbolsTarget.checked
    })
    this.hideOptions()
    this.passwordTarget.focus()
  }

  resetOptions() {
    this.lengthTarget.value = String(DEFAULT_GENERATED_PASSWORD_LENGTH)
    this.updateLength()

    if (this.hasNumbersTarget) this.numbersTarget.checked = true
    if (this.hasSymbolsTarget) this.symbolsTarget.checked = false
  }

  resetPasswordVisibility() {
    this.passwordTarget.type = "password"
    this.setPasswordVisibilityButton(false)
  }

  setPasswordVisibilityButton(isVisible) {
    if (!this.hasVisibilityButtonTarget) return

    this.visibilityButtonTarget.classList.toggle("is-visible", isVisible)
    this.visibilityButtonTarget.setAttribute("aria-label", isVisible ? "Hide password" : "Show password")
    this.visibilityButtonTarget.title = isVisible ? "Hide password" : "Show password"
  }

  hideOptions() {
    this.panelTarget.classList.add(this.hiddenClass)
    this.toggleButtonTarget.setAttribute("aria-expanded", "false")
  }

  get normalizedLength() {
    const parsed = Number.parseInt(this.lengthTarget.value, 10)
    if (Number.isNaN(parsed)) return DEFAULT_GENERATED_PASSWORD_LENGTH

    return Math.min(Math.max(parsed, MIN_GENERATED_PASSWORD_LENGTH), MAX_GENERATED_PASSWORD_LENGTH)
  }

  buildPassword(options) {
    const requiredSets = [PASSWORD_LETTERS]
    if (options.includeNumbers) requiredSets.push(PASSWORD_NUMBERS)
    if (options.includeSymbols) requiredSets.push(PASSWORD_SYMBOLS)

    const pool = requiredSets.join("")
    const characters = requiredSets.map((set) => this.randomCharacter(set))

    while (characters.length < options.length) {
      characters.push(this.randomCharacter(pool))
    }

    return this.shuffleCharacters(characters).join("")
  }

  randomCharacter(characters) {
    return characters[this.randomInt(characters.length)]
  }

  shuffleCharacters(characters) {
    const shuffled = [...characters]

    for (let index = shuffled.length - 1; index > 0; index -= 1) {
      const swapIndex = this.randomInt(index + 1)
      ;[shuffled[index], shuffled[swapIndex]] = [shuffled[swapIndex], shuffled[index]]
    }

    return shuffled
  }

  randomInt(maxExclusive) {
    const randomValues = new Uint32Array(1)
    const maxUnbiasedValue = Math.floor(0x100000000 / maxExclusive) * maxExclusive

    do {
      crypto.getRandomValues(randomValues)
    } while (randomValues[0] >= maxUnbiasedValue)

    return randomValues[0] % maxExclusive
  }
}
