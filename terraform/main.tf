terraform {
  backend "s3" {
    # DO Spaces is S3-compatible. Bucket, region, keys are injected at runtime
    # via -backend-config flags in the GitHub Actions workflow.
    # endpoint injected via endpoints block to avoid the deprecated "endpoint" param.
    endpoints = {
      s3 = "https://nyc3.digitaloceanspaces.com"
    }
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    use_path_style              = true
  }
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

variable "do_token" {
  type      = string
  sensitive = true
}
variable "project_name" {
  type = string
}
variable "do_region" {
  type    = string
  default = "nyc3"
}
variable "public_key" {
  type = string
}
variable "droplet_size" {
  type    = string
  default = "s-1vcpu-1gb"
}
variable "db_name" {
  type    = string
  default = ""
}
variable "db_username" {
  type    = string
  default = "appuser"
}
variable "db_password" {
  type      = string
  sensitive = true
  default   = ""
}

resource "digitalocean_ssh_key" "deploy" {
  name       = "udap-${var.project_name}"
  public_key = var.public_key

  lifecycle {
    ignore_changes = [public_key, name]
  }
}

resource "digitalocean_droplet" "app" {
  name   = var.project_name
  region = var.do_region
  size   = var.droplet_size
  image  = "ubuntu-22-04-x64"
  ssh_keys = [digitalocean_ssh_key.deploy.fingerprint]

  tags = ["udap", var.project_name]

  lifecycle {
    ignore_changes = [ssh_keys, user_data]
  }
}

resource "digitalocean_firewall" "app" {
  name        = "${var.project_name}-fw"
  droplet_ids = [digitalocean_droplet.app.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

output "public_ip" {
  value = digitalocean_droplet.app.ipv4_address
}
