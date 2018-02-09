provider "aws" {
	region="eu-central-1"
}

data "template_file" "app_init" {
	template = "${file("./scripts/app_user_data.sh")}"
    vars {
        db_ip = "${module.db-tier.private_ip}"
    }
}

resource "aws_vpc" "main" {
	cidr_block = "10.5.0.0/16"
	tags {
		Name = "VPC-Manraaj"
	}
}

resource "aws_internet_gateway" "app-manraaj-igw" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name = "app-manraaj-igw"
  }
}

resource "aws_route_table" "public-manraaj" {
  vpc_id      = "${aws_vpc.main.id}"
    
    route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.app-manraaj-igw.id}"
  }

  tags {
  	Name = "public-manraaj"
  }
 }

module "app-tier" {
  name="app-manraaj"
  source="./modules/tier"
  vpc_id= "${aws_vpc.main.id}"
  route_table_id = "${aws_route_table.public-manraaj.id}"
  cidr_block="10.5.0.0/24"
  user_data="${data.template_file.app_init.rendered}"
  ami_id= "ami-bac3a7d5"
  map_public_ip_on_launch = true

  ingress = [{
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = "0.0.0.0/0"
  }]
}

module "db-tier" {
  name="db-manraaj"
  source="./modules/tier"
  vpc_id= "${aws_vpc.main.id}"
  route_table_id = "${aws_vpc.main.main_route_table_id}"
  cidr_block="10.5.1.0/24"
  user_data=""
  ami_id= "ami-3b761154"

  ingress = [{
    from_port = 27017
    to_port = 27017
    protocol = "tcp"
    cidr_blocks = "${module.app-tier.subnet_cidr_block}"
  }]
}
