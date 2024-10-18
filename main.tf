variable "server_port" {
	description="the http server port"
	type = number
}

 variable "vpc_id" {
	default = "vpc-09792a9f84354af94"
}

variable "subnet_ids" {
	type = list
	default = ["subnet-0649540fd252af299", "subnet-04edb3ea22236883e" ]
}

# 1. terraform will promptto entre a value
# 2. terraform apply -var "server_port=8090
# 3. TF_VAR_server_port=8080
# 4. if no value provided, then add default=8080

provider "aws" {
	region="us-east-1"
}

resource "aws_launch_configuration" "prem_tf_asg_ec2"  {
	instance_type="t2.micro"
	image_id="ami-0e86e20dae9224db8"
	#vpc_zone_identifier=var.subnet_ids 	
	security_groups = [aws_security_group.prem_tf_sg.id]
	associate_public_ip_address=true



	
	user_data=<<-EOF
	#!/bin/bash
	echo "TF launched web server" > index.html
	nohup busybox httpd -f -p ${var.server_port}  &
	EOF



}

resource "aws_autoscaling_group" "prem_tf_asg" {
	launch_configuration = aws_launch_configuration.prem_tf_asg_ec2.name
	
	vpc_zone_identifier=var.subnet_ids 	

	target_group_arns = [aws_lb_target_group.prem_tf_alb_tgt_gp.arn ]
	health_check_type = "ELB"

	min_size=2
	max_size=5
	tag {
	key = "Name"
	value = "TF ASG launch.."
	propagate_at_launch = true

	}
}

resource "aws_security_group" "prem_tf_sg" {
	name="tf_sg"
	vpc_id="vpc-09792a9f84354af94"
	ingress {
	from_port = var.server_port
	to_port = var.server_port
	protocol = "tcp"
	cidr_blocks = ["0.0.0.0/0"]
	}
}

resource "aws_lb" "prem_tf_lb" {
	name = "prem-tf-lb"
	load_balancer_type = "application"
	security_groups = [aws_security_group.prem_tf_alb_sg.id]
	subnets = var.subnet_ids
}

resource "aws_lb_listener" "prem_tf_alb_lis" {
	load_balancer_arn = aws_lb.prem_tf_lb.arn
	port = 80
	protocol = "HTTP"
	#by default, return 404
	default_action {
		type = "fixed-response"
		

		fixed_response {
			content_type = "text/plain"
			message_body = "404: prem page not found"
			status_code = 404
		}			
	} 
}

resource "aws_lb_listener_rule" "prem_tf_alb_lis_rule" {
	listener_arn = aws_lb_listener.prem_tf_alb_lis.arn
	priority = 100
	
	condition {
		path_pattern {
			values = ["*"]
		}
	}
	
	action {
		type = "forward"
		target_group_arn = aws_lb_target_group.prem_tf_alb_tgt_gp.arn
	}

}


resource "aws_security_group" "prem_tf_alb_sg" {
	name="tf-alb-sg"
	vpc_id="vpc-09792a9f84354af94"
	
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
}


resource "aws_lb_target_group" "prem_tf_alb_tgt_gp" {
	name = "prem-tf-alb-tgt-gp"
	port = var.server_port
	protocol = "HTTP"
	vpc_id = var.vpc_id
	
	health_check {
		path = "/"
		protocol = "HTTP"
		matcher = 200
		interval = 15
		timeout = 3
		healthy_threshold = 2
		unhealthy_threshold = 2
	}	
}

output "alb_dns_name" {
	value = aws_lb.prem_tf_lb.dns_name
}
