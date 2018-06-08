variable "heroku_email" {}
variable "heroku_api_key" {}
variable "heroku_app_name" {}
variable "heroku_space_name" {}
variable "heroku_organization" {}
variable "heroku_app_region" {
  default = "frankfurt"
}
variable "rails_master_key" {}

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "allowed_network" {}

provider "heroku" {
  email = "${var.heroku_email}"
  api_key = "${var.heroku_api_key}"
}

resource "heroku_space" "default" {
  name = "${var.heroku_space_name}"
  region = "${var.heroku_app_region}"
  trusted_ip_ranges = ["${var.allowed_network}"]
  organization = "${var.heroku_organization}"
}

resource "heroku_app" "default" {
  name = "${var.heroku_app_name}"
  space = "${heroku_space.default.name}"
  region = "${var.heroku_app_region}"
  organization {
    name = "${var.heroku_organization}"
  }
  config_vars {
    RAILS_MASTER_KEY = "${var.rails_master_key}"
  }
}

resource "heroku_addon" "database" {
  app  = "${heroku_app.default.name}"
  plan = "heroku-postgresql:private-0"
}

resource "heroku_addon" "memcachier" {
  app  = "${heroku_app.default.name}"
  plan = "memcachier:dev"
}

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "eu-central-1"
}

resource "aws_redshift_cluster" "default" {
  cluster_identifier = "mnd-test-events"
  database_name      = "mndtest"
  master_username    = "defaultuser"
  master_password    = "Mustbe8characters"
  node_type          = "dc1.large"
  cluster_type       = "single-node"
}

resource "aws_vpc" "test" {
  cidr_block = "192.168.0.0/24"

  tags {
    Name = "terraform-test"
  }
}

resource "aws_subnet" "test" {
  cidr_block        = "192.168.0.192/27"
  availability_zone = "eu-central-1a"
  vpc_id            = "${aws_vpc.test.id}"

  tags {
    Name = "redshift-dbsubnet"
  }
}

resource "aws_redshift_subnet_group" "test" {
  name       = "test"
  subnet_ids = ["${aws_subnet.test.id}"]

  tags {
    environment = "Development"
  }
}

# peer both vpc's
resource "aws_vpc_peering_connection" "pc" {
  vpc_id        = "${aws_vpc.test.id}"
  peer_vpc_id   = "vpc-4bfa2320"
  peer_owner_id = "589120665149"
}

resource "aws_route_table" "rt" {
  vpc_id = "${aws_vpc.test.id}"
}

resource "aws_route" "r" {
  route_table_id            = "${aws_route_table.rt.id}"
  destination_cidr_block    = "10.0.144.0/20"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.pc.id}"
}
