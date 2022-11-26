# Create a new Web Droplet in the sfo3 region
resource "digitalocean_droplet" "web" {
  image  = "rockylinux-9-x64"
  count  = var.droplet_count
  name   = "web-${count.index + 1}"
  tags   = [digitalocean_tag.do_tag.id]
  region = var.region
  size   = "s-1vcpu-512mb-10gb"
  ssh_keys = [data.digitalocean_ssh_key.droplet_ssh_key.id]
  vpc_uuid = digitalocean_vpc.web_vpc.id

  lifecycle {
    create_before_destroy = true
  }

}

# Add new web droplets to existing 4640_labs project
resource "digitalocean_project_resources" "project_attach" {
  project = data.digitalocean_project.lab_project.id
  resources = flatten([
    digitalocean_droplet.web.*.urn
  ])
}

# Create a load balancer
resource "digitalocean_loadbalancer" "public" {
  name   = "loadbalancer-1"
  region = var.region

  forwarding_rule {
    entry_port     = 80
    entry_protocol = "http"

    target_port     = 80
    target_protocol = "http"
  }

  healthcheck {
    port     = 22
    protocol = "tcp"
  }

  droplet_tag = "Web"
  vpc_uuid = digitalocean_vpc.web_vpc.id
}

resource "digitalocean_firewall" "web" {

    # The name we give our firewall for ease of use                            #    
    name = "web-firewall"

    # The droplets to apply this firewall to                                   #
    droplet_ids = digitalocean_droplet.web.*.id

    # Internal VPC Rules. We have to let ourselves talk to each other
    inbound_rule {
        protocol = "tcp"
        port_range = "1-65535"
        source_addresses = [digitalocean_vpc.web_vpc.ip_range]
    }

    inbound_rule {
        protocol = "udp"
        port_range = "1-65535"
        source_addresses = [digitalocean_vpc.web_vpc.ip_range]
    }

    inbound_rule {
        protocol = "icmp"
        source_addresses = [digitalocean_vpc.web_vpc.ip_range]
    }

    outbound_rule {
        protocol = "udp"
        port_range = "1-65535"
        destination_addresses = [digitalocean_vpc.web_vpc.ip_range]
    }

    outbound_rule {
        protocol = "tcp"
        port_range = "1-65535"
        destination_addresses = [digitalocean_vpc.web_vpc.ip_range]
    }

    outbound_rule {
        protocol = "icmp"
        destination_addresses = [digitalocean_vpc.web_vpc.ip_range]
    }

    # Selective Outbound Traffic Rules

    # HTTP
    outbound_rule {
        protocol = "tcp"
        port_range = "80"
        destination_addresses = ["0.0.0.0/0", "::/0"]
    }

    # HTTPS
    outbound_rule {
        protocol = "tcp"
        port_range = "443"
        destination_addresses = ["0.0.0.0/0", "::/0"]
    }

    # ICMP (Ping)
    outbound_rule {
        protocol              = "icmp"
        destination_addresses = ["0.0.0.0/0", "::/0"]
    }
}
