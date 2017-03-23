/* Configure the AWS Provider */

variable "access_key" {
    default = ""
}

variable "secret_key" {
    default = ""
}

variable "management_ip" {
    default = ""
}

provider "aws" {
    access_key  = "${var.access_key}"
    secret_key  = "${var.secret_key}"
    region = "us-east-1"
}

resource "aws_vpc" "wp_app" {
     cidr_block = "10.100.0.0/16"
}

/* Add two subnets for our public servers - ensure redundancy - created in separate AZ */

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

/* add an Internet Gateway */
resource "aws_internet_gateway" "gw" {
    vpc_id = "${aws_vpc.wp_app.id}"

    tags {
        Name = "wp_app_gw"
    }
}

/*Route Table*/

resource "aws_route_table" "wp_rt" {
   vpc_id = "${aws_vpc.wp_app.id}"
   route {
     cidr_block = "0.0.0.0/0"
     gateway_id = "${aws_internet_gateway.gw.id}"
   }
   tags {
    Name = "WP_RT"
  }

 }

resource "aws_route_table_association" "wp_rt_a" {
   subnet_id = "${aws_subnet.public_1a.id}"
   route_table_id = "${aws_route_table.wp_rt.id}"
}

resource "aws_route_table_association" "wp_rt_b" {
   subnet_id = "${aws_subnet.public_1b.id}"
   route_table_id = "${aws_route_table.wp_rt.id}"
}


/* Security group to allow SSH access */

resource "aws_security_group" "allow_ssh" {
  name = "allow_ssh_sg"
  description = "Allow inbound SSH traffic from my IP"
  vpc_id = "${aws_vpc.wp_app.id}"

  ingress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["${var.management_ip}/32"]
  }

  egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

  tags {
    Name = "Allow SSH"
  }
}
/* Security group to allow web server access to the public. */

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
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }
  tags {
    Name = "WP_WEB"
  }
}

resource "aws_security_group" "wp_access_rds_sg" {
  name = "rds_access_sg"
  description = "Allow access to MySQL RDS"
  vpc_id = "${aws_vpc.wp_app.id}"

  ingress {
      from_port = 3306
      to_port = 3306
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }
  tags {
    Name = "WP_RDS_SG"
  }

}

/* Key Pair  */

resource "aws_key_pair" "root" {
    key_name = "root-key"
    public_key = "${file("id_rsa_wp.pub")}"
}

/* RDS Instance */

resource "aws_db_instance" "wp_rds_db" {
    identifier = "wp-rds-db"
    allocated_storage = 10
    engine = "mysql"
    engine_version = "5.6.27"
    instance_class = "db.t2.micro"
    name = "wpmghali"
    username = "wpmghali"
    password = "wpmghali"
    db_subnet_group_name = "${aws_db_subnet_group.wp_db_grp.id}"
    parameter_group_name = "default.mysql5.6"
    vpc_security_group_ids = ["${aws_security_group.wp_access_rds_sg.id}"]
}

/* DB Subnet Group */

resource "aws_db_subnet_group" "wp_db_grp" {
    name = "main"
    description = "Our main group of subnets"
    subnet_ids = ["${aws_subnet.public_1a.id}", "${aws_subnet.public_1b.id}"]
    tags {
        Name = "MyApp DB subnet group"
    }
}

# Create an IAM role for the Web Servers.

resource "aws_s3_bucket" "wpmghali2017" {
    bucket = "wpmghali2017"
    acl = "private"
    versioning {
    enabled = false
    }
    tags {
    Name = "wpmghali2017"
    }
}

resource "aws_iam_instance_profile" "test_bucket_access_instance_profile" {
    name = "test_bucket_access_instance_profile"
    roles = ["${aws_iam_role.test_bucket_access_role.name}"]
}

resource "aws_iam_role" "test_bucket_access_role" {
  name = "test_bucket_access_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "test_bucket_access_policy" {
  name = "test_bucket_access_policy"
  role = "${aws_iam_role.test_bucket_access_role.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": "arn:aws:s3:::wpmghali2017"
    },
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": "arn:aws:s3:::wpmghali2017/*"
    }
  ]
}
EOF
}

/* EC2 Instances */

resource "aws_instance" "wp01" {
    ami = "ami-0b33d91d"
    instance_type = "t2.micro"
    subnet_id = "${aws_subnet.public_1a.id}"
    vpc_security_group_ids = ["${aws_security_group.web_server_sg.id}","${aws_security_group.allow_ssh.id}"]
    key_name = "${aws_key_pair.root.key_name}"
    iam_instance_profile = "${aws_iam_instance_profile.test_bucket_access_instance_profile.name}"    
    tags {
        Name = "WP01"
    }

    provisioner "remote-exec" {
        inline = [
                "mkdir /home/ec2-user/chef",
        ]
        connection {
            type = "ssh"
            user = "ec2-user"
            private_key = "${file("id_rsa_wp")}"
            timeout = "160s"
        }
    }

    provisioner "file" {
        source = "chef/"
        destination = "/home/ec2-user/chef"
        connection {
            type = "ssh"
            user = "ec2-user"
            private_key = "${file("id_rsa_wp")}"
            timeout = "160s"
        }
    }
    provisioner "remote-exec" {
        inline = [
                "chmod +x /home/ec2-user/chef/provision.sh",
                "/home/ec2-user/chef/provision.sh"
        ]
        connection {
            type = "ssh"
            user = "ec2-user"
            private_key = "${file("id_rsa_wp")}"
            timeout = "160s"
        }
    }
}

resource "aws_instance" "wp02" {
    ami = "ami-0b33d91d"
    instance_type = "t2.micro"
    subnet_id = "${aws_subnet.public_1b.id}"
    vpc_security_group_ids = ["${aws_security_group.web_server_sg.id}","${aws_security_group.allow_ssh.id}"]
    key_name = "${aws_key_pair.root.key_name}"
    iam_instance_profile = "${aws_iam_instance_profile.test_bucket_access_instance_profile.name}" 
    tags {
        Name = "WP02"
    }

    provisioner "remote-exec" {
        inline = [
                "mkdir /home/ec2-user/chef",
        ]
        connection {
            type = "ssh"
            user = "ec2-user"
            private_key = "${file("id_rsa_wp")}"
            timeout = "160s"
        }
    }

    provisioner "file" {
        source = "chef/"
        destination = "/home/ec2-user/chef"
        connection {
            type = "ssh"
            user = "ec2-user"
            private_key = "${file("id_rsa_wp")}"
            timeout = "160s"
        }
    }
    provisioner "remote-exec" {
        inline = [
                "chmod +x /home/ec2-user/chef/provision.sh",
                "/home/ec2-user/chef/provision.sh"
        ]
		connection {
            type = "ssh"
            user = "ec2-user"
            private_key = "${file("id_rsa_wp")}"
            timeout = "160s"
        }
    }
}

/* ELB for Load Balancing */

resource "aws_elb" "wp_elb" {
  name = "wp-elb"
  subnets = ["${aws_subnet.public_1a.id}","${aws_subnet.public_1b.id}"]
  
  security_groups = ["${aws_security_group.web_server_sg.id}"]

  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  /* ssl_certificate_id = "arn:aws:iam::123456789012:server-certificate/certName" */

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 3
    timeout = 3
    target = "HTTP:80/healthcheck.html"
    interval = 10
  }

  instances = ["${aws_instance.wp01.id}" , "${aws_instance.wp02.id}"]

  cross_zone_load_balancing = true
  idle_timeout = 400
  connection_draining = true
  connection_draining_timeout = 400
  tags {
    Name = "WP_ELB"
  }
}

/* Create IAM role for S3 bucket */



output "lb-dns" {
    value = "${aws_elb.wp_elb.dns_name}"
}
output "rds-uri" {
    value = "${aws_db_instance.wp_rds_db.endpoint}"
}

output "wp01-instance_ip" {
    value = "${aws_instance.wp01.public_ip}"
}

output "wp02-instance_ip" {
    value = "${aws_instance.wp02.public_ip}"
}
