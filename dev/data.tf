data "digitalocean_ssh_key" "droplet_ssh_key" {
  name = "ATTEMPT1000"
}

data "digitalocean_project" "lab_project" {
  name = "first-project"
}
