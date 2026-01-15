import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="shortlink"
export default class extends Controller {
  static targets = [
    "apiUrl", "apiSlug", "encodeResponse",
    "apiDecode", "decodeResponse",
    "lookupInput", "lookupSuccess", "lookupError", "errorText",
    "flashMessages", "recentLinks"
  ]

  // Test Encode API
  async testEncodeAPI() {
    const url = this.apiUrlTarget.value
    const slug = this.apiSlugTarget.value
    const responseDiv = this.encodeResponseTarget

    const payload = { url }
    if (slug) payload.slug = slug

    try {
      const response = await fetch('/api/v1/encode', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      })

      const data = await response.json()
      responseDiv.querySelector('pre').textContent = JSON.stringify(data, null, 2)
      responseDiv.classList.remove('d-none')

      if (data.slug) {
        this.apiDecodeTarget.value = data.slug

        // Show success message and refresh recent links
        if (response.ok) {
          this.showFlashMessage(`✅ ShortLink created: ${data.short_url}`, 'success')
          await this.refreshRecentLinks()
        }
      }
    } catch (error) {
      responseDiv.querySelector('pre').textContent = `Error: ${error.message}`
      responseDiv.classList.remove('d-none')
    }
  }

  // Test Decode API
  async testDecodeAPI() {
    const slug = this.apiDecodeTarget.value.trim()
    const responseDiv = this.decodeResponseTarget

    if (!slug) {
      responseDiv.querySelector('pre').textContent = 'Error: Please enter a slug'
      responseDiv.classList.remove('d-none')
      return
    }

    try {
      const response = await fetch(`/api/v1/decode/${slug}`)
      const data = await response.json()
      responseDiv.querySelector('pre').textContent = JSON.stringify(data, null, 2)
      responseDiv.classList.remove('d-none')
    } catch (error) {
      responseDiv.querySelector('pre').textContent = `Error: ${error.message}`
      responseDiv.classList.remove('d-none')
    }
  }

  // Lookup ShortLink
  async lookupShortlink() {
    const input = this.lookupInputTarget.value.trim()
    const successDiv = this.lookupSuccessTarget
    const errorDiv = this.lookupErrorTarget

    successDiv.classList.add('d-none')
    errorDiv.classList.add('d-none')

    if (!input) {
      this.errorTextTarget.textContent = 'Please enter a slug or URL'
      errorDiv.classList.remove('d-none')
      return
    }

    let slug = input.includes('/') ? input.split('/').pop() : input

    try {
      const response = await fetch(`/api/v1/decode/${slug}`)
      const data = await response.json()

      if (response.ok) {
        document.getElementById('found-slug').textContent = data.slug
        document.getElementById('found-destination').textContent = data.destination
        document.getElementById('found-type').textContent = data.custom ? 'Custom' : 'Random'
        document.getElementById('visit-link').href = data.destination
        successDiv.classList.remove('d-none')
      } else {
        this.errorTextTarget.textContent = data.error || 'ShortLink not found'
        errorDiv.classList.remove('d-none')
      }
    } catch (error) {
      this.errorTextTarget.textContent = 'Connection error'
      errorDiv.classList.remove('d-none')
    }
  }

  // Copy to clipboard
  copyLink(event) {
    const text = event.params.url
    navigator.clipboard.writeText(text).then(() => {
      this.showFlashMessage('✅ Copied to clipboard!', 'success')
    }).catch(() => {
      alert('Failed to copy to clipboard')
    })
  }

  // Show flash message
  showFlashMessage(message, type) {
    if (!this.hasFlashMessagesTarget) return

    const flashDiv = this.flashMessagesTarget
    const alert = document.createElement('div')
    alert.className = `alert alert-${type} alert-dismissible fade show`
    alert.innerHTML = `
      <i class="bi bi-check-circle-fill me-2"></i>${message}
      <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `
    flashDiv.innerHTML = ''
    flashDiv.appendChild(alert)

    // Auto-dismiss after 5 seconds
    setTimeout(() => {
      alert.remove()
    }, 5000)
  }

  // Refresh recent links section
  async refreshRecentLinks() {
    if (!this.hasRecentLinksTarget) return

    try {
      const response = await fetch('/')
      const html = await response.text()
      const parser = new DOMParser()
      const doc = parser.parseFromString(html, 'text/html')
      const newRecentLinks = doc.querySelector('#recent_links')

      if (newRecentLinks) {
        this.recentLinksTarget.replaceWith(newRecentLinks)
        // Reconnect Stimulus controller to new element
        const newElement = document.querySelector('#recent_links')
        if (newElement) {
          newElement.setAttribute('data-shortlink-target', 'recentLinks')
        }
      }
    } catch (error) {
      console.error('Failed to refresh recent links:', error)
    }
  }

  // Handle Enter key on lookup input
  handleEnter(event) {
    if (event.key === 'Enter') {
      this.lookupShortlink()
    }
  }
}
