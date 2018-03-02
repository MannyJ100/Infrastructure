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

resource "aws_elb" "app-manraaj" {
  name               = "app-manraaj-elb"
  subnets = ["${module.app-tier.subnet}"]
  security_groups = ["${module.app-tier.security_app}"]
  # availability_zones = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    target              = "HTTP:80/"
    interval            = 10
  }

  instances                   = ["${module.app-tier.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags {
    Name = "app-manraaj-terraform-elb"
  }
}

resource "aws_launch_configuration" "app-manraaj" {
  name_prefix   = "app-manraaj"
  image_id      = "ami-755f331a"
  instance_type = "t2.micro"
  user_data = "${data.template_file.app_init.rendered}"
  security_groups = ["${module.app-tier.security_app}"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "app-manraaj" {
  name                      = "app-manraaj"
  max_size                  = 3
  min_size                  = 2
  health_check_grace_period = 300
  health_check_type         = "EC2"
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.app-manraaj.name}"
  load_balancers            = ["${aws_elb.app-manraaj.name}"]
  vpc_zone_identifier       = ["${module.app-tier.subnet}"]

 tag {
    key                 = "Name"
    value               = "manraaj-autoscale"
    propagate_at_launch = true
  }

 lifecycle {
    create_before_destroy = true
  }
}

module "app-tier" {
  name="app-manraaj"
  source="./modules/tier"
  vpc_id= "${aws_vpc.main.id}"
  machine_count = 2
  route_table_id = "${aws_route_table.public-manraaj.id}"
  cidr_block="10.5.0.0/24"
  user_data="${data.template_file.app_init.rendered}"
  ami_id= "ami-755f331a"
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
  machine_count = 1
  ami_id= "ami-3b761154"

  ingress = [{
    from_port = 27017
    to_port = 27017
    protocol = "tcp"
    cidr_blocks = "${module.app-tier.subnet_cidr_block}"
  }]
}

# ami-bac3a7d5