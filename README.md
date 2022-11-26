# 4640-assignment

Breaking our existing Terraform configuration into separate files:  
1. Break up our previous ```main.tf``` file based on the following:  
```
- main.tf (provider info)  
- variables.tf (variables, reused values, values that can be changed, eg. region, size)  
- output.tf (output blocks, eg. ip addresses, database connection uri)
- servers.tf (droplets, load balancers, firewalls for the servers)
- network.tf (vpc)
- data.tf (data blocks, eg. ssh keys)
```
2. The new ```main.tf```:
```
terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = var.do_token
}

# Create a new tag
resource "digitalocean_tag" "do_tag" {
  name = "Web"
}
```
3. ```output.tf```:
```
output "server_ip" {
  value = digitalocean_droplet.web.*.ipv4_address
}
```
4. ```servers.tf``` with new firewall:
```
# Create a new Web Droplet in the sfo3 region
resource "digitalocean_droplet" "web" {
  image  = var.image
  count  = var.droplet_count
  name   = "web-${count.index + 1}"
  tags   = [digitalocean_tag.do_tag.id]
  region = var.region
  size   = var.size
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
```
5. ```network.tf```:
```
# Create a new vpc
resource "digitalocean_vpc" "web_vpc" {
  name     = "4640labs"
  region   = var.region
}
```
6. ```data.tf```:
```
data "digitalocean_ssh_key" "droplet_ssh_key" {
  name = "ATTEMPT1000"
}

data "digitalocean_project" "lab_project" {
  name = "first-project"
}
```

Adding Bastion and Database resources:  
1. Add ```bastion.tf```:
```
# Create a bastion server
resource "digitalocean_droplet" "bastion" {
  image    = "rockylinux-9-x64"
  name     = "bastion-${var.region}"
  region   = var.region
  size     = "s-1vcpu-512mb-10gb"
  ssh_keys = [data.digitalocean_ssh_key.droplet_ssh_key.id]
  vpc_uuid = digitalocean_vpc.web_vpc.id
}

# firewall for bastion server
resource "digitalocean_firewall" "bastion" {

  #firewall name
  name = "ssh-bastion-firewall"

  # Droplets to apply the firewall to
  droplet_ids = [digitalocean_droplet.bastion.id]

  inbound_rule {
    protocol = "tcp"
    port_range = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol = "tcp"
    port_range = "22"
    destination_addresses = [digitalocean_vpc.web_vpc.ip_range]
  }

  outbound_rule {
    protocol = "icmp"
    destination_addresses = [digitalocean_vpc.web_vpc.ip_range]
  }
}
```
2. Add ```database.tf```:
```
resource "digitalocean_database_cluster" "mongodb-example" {
  name       = "example-mongo-cluster"
  engine     = "mongodb"
  version    = "4"
  size       = "db-s-1vcpu-1gb"
  region     = var.region
  node_count = 1

  private_network_uuid = digitalocean_vpc.web_vpc.id
}

resource "digitalocean_database_firewall" "mongodb-firewall" {

    cluster_id = digitalocean_database_cluster.mongodb-example.id
    # allow connection from resources with a given tag
    # for example if our droplets all have a tag "web" we could use web as the value
    rule {
        type = "tag"
        value = "web"
    }
}
```
3. Add the database uri to ```output.tf```:
```
output "database_output" {
  sensitive = true
  value = digitalocean_database_cluster.mongodb-example.uri
}
```
Adding more variables:  
1. Add the following into ```variables.tf``` to be used as default values:
```
# set default image
variable "image" {
  type = string
  default = "rockylinux-9-x64"
}

# set default size
variable "size" {
  type = string
  default = "s-1vcpu-512mb-10gb"
}
```
2. Replace the existing values and call the new variables in ```servers.tf```, using ```var.[variable_name]```:
```
# Create a new Web Droplet in the sfo3 region
resource "digitalocean_droplet" "web" {
  image  = var.image
  count  = var.droplet_count
  name   = "web-${count.index + 1}"
  tags   = [digitalocean_tag.do_tag.id]
  region = var.region
  size   = var.size
  ssh_keys = [data.digitalocean_ssh_key.droplet_ssh_key.id]
  vpc_uuid = digitalocean_vpc.web_vpc.id

  lifecycle {
    create_before_destroy = true
  }

}
```  
Apply Terraform:
1. Use ```terraform apply```:
![image](https://user-images.githubusercontent.com/64290337/204081456-13116bf2-53cc-487c-8e78-6d830964366a.png)
