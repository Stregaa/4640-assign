# Create a new vpc
resource "digitalocean_vpc" "web_vpc" {
  name     = "4640labs"
  region   = var.region
}
