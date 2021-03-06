#========================================================
# Get all subnet of  vpc
#========================================================

data "aws_subnet_ids" "default" {
 vpc_id = aws_vpc.vpc.id 
}
#========================================================
# Creating TargetGroup For Application LoadBalancer
#========================================================
resource "aws_lb_target_group" "tg-1" {
  name     = "lb-tg1"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id
  load_balancing_algorithm_type = "round_robin"
  deregistration_delay = 60
  stickiness {
    enabled = false
    type    = "lb_cookie"
    cookie_duration = 60
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = 200
    
  }


  lifecycle {
    create_before_destroy = true
  }

}
resource "aws_lb_target_group" "tg-2" {
  name     = "lb-tg2"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id
  load_balancing_algorithm_type = "round_robin"
  deregistration_delay = 60
  stickiness {
    enabled = false
    type    = "lb_cookie"
    cookie_duration = 60
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = 200

  }


  lifecycle {
    create_before_destroy = true
  }
}

#========================================================
# Application LoadBalancer
#========================================================
resource "aws_lb" "mylb" {
  name               = "MY-LB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.webserver.id]
  subnets            = data.aws_subnet_ids.default.ids
  enable_deletion_protection = false
  depends_on = [ aws_lb_target_group.tg-1 ]
  tags = {
     Name = "MY-LB"
}
}
output "ALB-Endpoint" {
  value = aws_lb.mylb.dns_name
} 
#========================================================
# Creating http listener of application loadbalancer
#========================================================

resource "aws_lb_listener" "listner" {
    
  load_balancer_arn = aws_lb.mylb.id

  port              = 80
  protocol          = "HTTP"
  
  # defualt action of the target group.
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = " No such Site Found"
      status_code  = "200"
   }
  }
    
  depends_on = [  aws_lb.mylb ]
}




#========================================================
# forward blog.gigingeorge.online to target group
#========================================================

resource "aws_lb_listener_rule" "rule" {
    
  listener_arn = aws_lb_listener.listner.id
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-1.arn
  }

  condition {
    host_header {
      values = ["tg1.gigingeorge.online"]
    }
  }
}
resource "aws_lb_listener_rule" "rule2" {
    
  listener_arn = aws_lb_listener.listner.id
  priority     = 9

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-2.arn
  }

  condition {
    host_header {
      values = ["tg2.gigingeorge.online"]
    }
  }
}
#========================================================
# myapp Launch Configuration 
#========================================================
resource "aws_launch_configuration" "launch1" {
  image_id      = "ami-0ad704c126371a549"
  instance_type = "t2.micro"
security_groups = [ aws_security_group.webserver.id ]
  user_data = file("launch-1.sh")

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg-1" {

  launch_configuration    =  aws_launch_configuration.launch1.id
  health_check_type       = "EC2"
  min_size                = var.asg_count
  max_size                = var.asg_count
  desired_capacity        = var.asg_count
  vpc_zone_identifier       = [aws_subnet.public1.id, aws_subnet.public2.id]
  target_group_arns       = [ aws_lb_target_group.tg-1.arn ]
  tag {
    key = "Name"
    propagate_at_launch = true
    value = "Asg-1"
  }

  lifecycle {
    create_before_destroy = true
  }

}
resource "aws_autoscaling_group" "asg-2" {

  launch_configuration    =  aws_launch_configuration.launch1.id
  health_check_type       = "EC2"
  min_size                = var.asg_count
  max_size                = var.asg_count
  desired_capacity        = var.asg_count
  vpc_zone_identifier       = [aws_subnet.public1.id, aws_subnet.public2.id]
  target_group_arns       = [ aws_lb_target_group.tg-2.arn ]
  tag {
    key = "Name"
    propagate_at_launch = true
    value = "Asg-2"
  }

  lifecycle {
    create_before_destroy = true
  }

}
