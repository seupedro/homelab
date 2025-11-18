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

variable "server_labels" {
  description = "Labels to apply to the server"
  type        = map(string)
  default     = {}
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

# Talos Linux Configuration
variable "talos_image_id" {
  description = <<EOT
Hetzner snapshot/image ID that contains Talos Linux.
Use Hetzner's public Talos ISO (ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515) or your uploaded snapshot ID.
EOT
  type    = string
  default = "ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515"
}

variable "talos_machine_config_path" {
  description = "Path to the Talos control plane machine configuration that will be passed as user_data"
  type        = string
}
