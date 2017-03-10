# ===============================================
# Terraform template for HA wordpress Installation
# Created by GHALI Merzoug 
# Date : 
# ===============================================

# Configure the AWS Provider
provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "us-east-1"
}

resource "aws_vpc" "wp_app" {
     cidr_block = "10.100.0.0/16"
}
# Add two subnets for our public servers => ensure redundancy => created in separate AZ

resource "aws_subnet" "public_1a" {
    vpc_id = "${aws_vpc.wp_app.id}"
    cidr_block = "10.100.0.0/24"
    map_public_ip_on_launch = "true"
    availability_zone = "us-east-1a"

    tags {
        Name = "WP Public 1A"
    }
}

resource "aws_subnet" "public_1b" {
    vpc_id = "${aws_vpc.wp_app.id}"
    cidr_block = "10.100.1.0/24"
    map_public_ip_on_launch = "true"
    availability_zone = "us-east-1b"

    tags {
        Name = "WP Public 1B"
    }
}

# add an Internet Gateway 
resource "aws_internet_gateway" "gw" {
    vpc_id = "${aws_vpc.wp_app.id}"

    tags {
        Name = "wp_app gw"
    }
}

# Security group to allow SSH access 

resource "aws_security_group" "allow_ssh" {
  name = "allow_ssh_sg"
  description = "Allow inbound SSH traffic from my IP"
  vpc_id = "${aws_vpc.wp_app.id}"

  ingress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "Allow SSH"
  }
}

# Security group to allow web server access to the public. 

resource "aws_security_group" "web_server_sg" {
  name = "web_server_sg"
  description = "Allow HTTP and HTTPS traffic in, browser access out."
  vpc_id = "${aws_vpc.wp_app.id}"

  ingress {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
      from_port = 1024
      to_port = 65535
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security group to allow MySQL RDS Access to the web servers.

resource "aws_security_group" "wp_access_rds_sg" {
  name = "rds_access_sg"
  description = "Allow access to MySQL RDS"
  vpc_id = "${aws_vpc.wp_app.id}"

  ingress {
      from_port = 3306
      to_port = 3306
      protocol = "tcp"
      cidr_blocks = ["${aws_instance.wp01.private_ip}","${aws_instance.wp02.private_ip}"]
  }

  egress {
      from_port = 1024
      to_port = 65535
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
}

# wp EC2 Instances

resource "aws_instance" "wp01" {
    ami = "ami-408c7f28"
    instance_type = "t2.micro"
    subnet_id = "${aws_subnet.public_1a.id}"
    vpc_security_group_ids = ["${aws_security_group.web_server_sg.id}","${aws_security_group.allow_ssh.id}"]
    key_name = "wp_keypair"
    tags {
        Name = "wp01"
    }
}

resource "aws_instance" "wp02" {
    ami = "ami-408c7f28"
    instance_type = "t2.micro"
    subnet_id = "${aws_subnet.public_1b.id}"
    vpc_security_group_ids = ["${aws_security_group.web_server_sg.id}","${aws_security_group.allow_ssh.id}"]
    key_name = "wp_keypair"
    tags {
        Name = "wp02"
    }
}

# ELB for Load Balancing

resource "aws_elb" "wp_elb" {
  name = "wp_elb"
  availability_zones = ["us-east-1a", "us-east-1b"]

  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }


  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 3
    timeout = 3
    target = "HTTP:80/"
    interval = 10
  }

  instances = ["${aws_instance.wp01.id}","${aws_instance.wp02.id}"]

  cross_zone_load_balancing = true
  idle_timeout = 400
  connection_draining = true
  connection_draining_timeout = 400

  tags {
    Name = "WP_ELB"
  }
}

# DB Subnet Group

resource "aws_db_subnet_group" "wp_db_grp" {
    name = "main"
    description = "Our main group of subnets"
    subnet_ids = ["${aws_subnet.public-1a.id}", "${aws_subnet.public-1b.id}"]
    tags {
        Name = "MyApp DB subnet group"
    }
}

# RDS Instance

resource "aws_db_instance" "wp_rds_db" {
    identifier = "wp_rds_db"
    allocated_storage = 10
    engine = "mysql"
    engine_version = "5.6.17"
    instance_class = "db.t2.micro"
    name = "wpappdb"
    username = "wpmghali"
    password = "wpmghali"
    vpc_security_group_ids = ["${aws_security_group.wp_access_rds_sg.id"]
    db_subnet_group_name = "${aws_db_subnet_group.wp_db_grp.id}"
    parameter_group_name = "default.mysql5.6"
}

# 
