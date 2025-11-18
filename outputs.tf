# Server Information Outputs

output "server_id" {
  description = "ID of the created server"
  value       = hcloud_server.main.id
}

output "server_name" {
  description = "Name of the created server"
  value       = hcloud_server.main.name
}

output "server_type" {
  description = "Server type"
  value       = hcloud_server.main.server_type
}

output "location" {
  description = "Server location"
  value       = hcloud_server.main.location
}

# Network Information
output "ipv4_address" {
  description = "Public IPv4 address of the server"
  value       = hcloud_server.main.ipv4_address
}

output "ipv6_address" {
  description = "Public IPv6 address of the server"
  value       = hcloud_server.main.ipv6_address
}

# Connection Information

output "ssh_command" {
  description = "SSH command to connect to the server"
  value       = "ssh root@${hcloud_server.main.ipv4_address}"
}

# Status Information

output "server_status" {
  description = "Current status of the server"
  value       = hcloud_server.main.status
}

output "server_labels" {
  description = "Labels applied to the server"
  value       = hcloud_server.main.labels
}

# DNS Information

output "dns_wildcard_a_record" {
  description = "Wildcard A record hostname"
  value       = "*.pane.run → ${cloudflare_dns_record.wildcard_a.content}"
}

output "dns_wildcard_aaaa_record" {
  description = "Wildcard AAAA record hostname"
  value       = "*.pane.run → ${cloudflare_dns_record.wildcard_aaaa.content}"
}

output "argocd_url" {
  description = "ArgoCD URL (once ingress is configured)"
  value       = "https://argocd.pane.run"
}
