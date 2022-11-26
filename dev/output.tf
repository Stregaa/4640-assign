output "server_ip" {
  value = digitalocean_droplet.web.*.ipv4_address
}

output "database_output" {
  value = data.digitalocean_database_cluster.mongodb-example.uri
}
