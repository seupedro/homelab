terraform {
  required_version = ">= 1.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.56.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Server Configuration
resource "hcloud_server" "main" {
  name        = var.server_name
  server_type = var.server_type
  location    = var.location
  image       = var.talos_image_id

  # Talos machine configuration supplied via user_data
  # File should come from `talosctl gen config ... --with-docs=false --with-examples=false`.
  user_data = file(var.talos_machine_config_path)

  labels = var.server_labels

  lifecycle {
    ignore_changes = [
      # Ignore changes to user_data to prevent unnecessary recreation
      user_data,
    ]
  }
}

# DNS Configuration - Cloudflare
# Wildcard A record for *.pane.run pointing to the server
resource "cloudflare_dns_record" "wildcard_a" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  content = hcloud_server.main.ipv4_address
  type    = "A"
  ttl     = 1 # Auto TTL (Cloudflare proxy)
  proxied = false # Set to false for DNS-only mode (grey cloud)
  comment = "Wildcard A record for homelab server - managed by OpenTofu"
}

# Wildcard AAAA record for *.pane.run pointing to the server (IPv6)
resource "cloudflare_dns_record" "wildcard_aaaa" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  content = hcloud_server.main.ipv6_address
  type    = "AAAA"
  ttl     = 1 # Auto TTL (Cloudflare proxy)
  proxied = false # Set to false for DNS-only mode (grey cloud)
  comment = "Wildcard AAAA record for homelab server (IPv6) - managed by OpenTofu"
}

# Talos management subdomain
resource "cloudflare_dns_record" "talos_a" {
  zone_id = var.cloudflare_zone_id
  name    = "talos"
  content = hcloud_server.main.ipv4_address
  type    = "A"
  ttl     = 1 # Auto TTL (Cloudflare proxy)
  proxied = false # Set to false for DNS-only mode (grey cloud)
  comment = "Talos management endpoint - managed by OpenTofu"
}
