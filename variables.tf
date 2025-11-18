# Hetzner Cloud API Token
# Get yours from: https://console.hetzner.cloud/projects
variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

# Server Configuration
variable "server_name" {
  description = "Name of the server"
  type        = string
  default     = "pane-homelab"
}

variable "server_type" {
  description = "Server type (e.g., ccx11, cx22, cpx31)"
  type        = string
  default     = "ccx11"
}

variable "location" {
  description = "Datacenter location (ash = Ashburn, Virginia, USA)"
  type        = string
  default     = "ash"

  validation {
    condition     = contains(["ash", "fsn1", "nbg1", "hel1", "hil"], var.location)
    error_message = "Location must be one of: ash, fsn1, nbg1, hel1, hil."
  }
}

variable "image" {
  description = "OS image for the server"
  type        = string
  default     = "ubuntu-24.04"

  validation {
    condition = contains(
      [
        "ubuntu-24.04", "ubuntu-22.04", "ubuntu-20.04",
        "debian-12", "debian-11",
        "centos-stream-9", "rocky-9",
        "fedora-39",
        "alpine-3.20"
      ],
      var.image
    )
    error_message = "Supported images: ubuntu-24.04, ubuntu-22.04, ubuntu-20.04, debian-12, debian-11, centos-stream-9, rocky-9, fedora-39, alpine-3.20"
  }
}

variable "server_labels" {
  description = "Labels to apply to the server"
  type        = map(string)
  default     = {}
}

# SSH Key Configuration (optional)
variable "ssh_key_name" {
  description = "Name for the SSH key"
  type        = string
  default     = "seupedro-ssh-key"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

# k3s Configuration
variable "k3s_version" {
  description = "k3s version to install (leave empty for latest)"
  type        = string
  default     = ""
}

variable "k3s_extra_args" {
  description = "Additional arguments for k3s installation"
  type        = string
  default     = ""
}

variable "additional_packages" {
  description = "Additional packages to install via cloud-init"
  type        = list(string)
  default     = []
}

# Cloudflare DNS Configuration
variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS management"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for pane.run domain"
  type        = string
}
