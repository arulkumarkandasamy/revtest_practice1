variable "access_key" {}
variable "secret_key" {}

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "ap-south-1"
}

data "aws_ami" "node_app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["packer-example*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["291213119936"]
}

#User data
data "template_file" "user_data" {
  template = "${file(var.user_data_file_path)}"
}

resource "aws_launch_configuration" "node_app_lc" {
  image_id      = "${data.aws_ami.node_app_ami.id}"
  instance_type = "t2.small"
  key_name = "${aws_key_pair.arulkeypair.key_name}"
  security_groups = ["${aws_security_group.node_app_websg.id}"]
  lifecycle {
    create_before_destroy = true
  }
  user_data = "${data.template_file.user_data.rendered}"
}

resource "aws_autoscaling_group" "node_app_asg" {
  name                 = "terraform-asg-node-app-${aws_launch_configuration.node_app_lc.name}"
  launch_configuration = "${aws_launch_configuration.node_app_lc.name}"
  availability_zones = ["${data.aws_availability_zones.allzones.names}"]
  min_size             = 1
  max_size             = 2

  load_balancers = ["${aws_elb.elb1.id}"]
  health_check_type = "ELB"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "node_app_websg" {
  name = "security_group_for_node_app_websg"
  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "elbsg" {
  name = "security_group_for_elb"
  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_availability_zones" "allzones" {}

resource "aws_elb" "elb1" {
  name = "terraform-elb-node-app"
  availability_zones = ["${data.aws_availability_zones.allzones.names}"]
  security_groups = ["${aws_security_group.elbsg.id}"]
  
  listener {
    instance_port = 8080
    instance_protocol = "http"
    lb_port = 8080
    lb_protocol = "http"
  }

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    target = "HTTP:8080/"
      interval = 30
  }

  cross_zone_load_balancing = true
  idle_timeout = 400
  connection_draining = true
  connection_draining_timeout = 400

  tags {
    Name = "terraform - elb - node-app"
  }
}

resource "aws_key_pair" "arulkeypair" {
  key_name   = "arulkeypair"
  public_key = "${var.id_rsa_pub}"
}
