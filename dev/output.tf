output "server_ip" {
  value = digitalocean_droplet.web.*.ipv4_address
}

output "database_output" {
  sensitive = true
  value = digitalocean_database_cluster.mongodb-example.uri
}
