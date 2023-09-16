# Define your AWS provider
provider "aws" {
  region = "us-east-1"  # Change to your desired AWS region
}

# Create an Elastic Beanstalk application
resource "aws_elastic_beanstalk_application" "ecl_app" {
  name = "my-beanstalk-app"
}

# Create an Elastic Beanstalk environment
resource "aws_elastic_beanstalk_environment" "my_environment" {
  name                = "my-beanstalk-env"
  application         = aws_elastic_beanstalk_application.my_app.name
  solution_stack_name = "64bit Amazon Linux 2 v4.2.5 running Node.js 14"  # Change to your desired platform
}

# Create a security group for the Elastic Beanstalk environment
resource "aws_security_group" "beanstalk_sg" {
  name        = "beanstalk-sg"
  description = "Security group for Elastic Beanstalk environment"

  # Define your security group rules here
  # Example rule for allowing incoming HTTP traffic
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an Elastic Load Balancer (ELB)
resource "aws_elb" "my_elb" {
  name               = "my-elb"
  subnets            = ["var.subnet_id", "var.subnet_id"]  # Replace with your subnet IDs
  security_groups    = [aws_security_group.beanstalk_sg.id]
  cross_zone_load_balancing   = true
  enable_deletion_protection = false

  listener {
    instance_port     = 80
    instance_protocol = "HTTP"
    lb_port           = 80
    lb_protocol       = "HTTP"
  }

  health_check {
    target              = "HTTP:80/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }
}

# Create an Auto Scaling Group (ASG) for Elastic Beanstalk
resource "aws_autoscaling_group" "my_asg" {
  name                 = "my-asg"
  launch_configuration = aws_launch_configuration.my_launch_config.name
  min_size             = 2
  max_size             = 4
  desired_capacity     = 2

  # Attach the ASG to the ELB
  load_balancers = [aws_elb.my_elb.name]

  # Configure scaling policies based on CPU utilization
  dynamic "scaling_policy" {
    for_each = {
      scale_out = {
        adjustment_type = "ChangeInCapacity"
        scaling_adjustment = 1
        metric_aggregation_type = "Average"
        name = "scale-out"
        predefined_metric_specification {
          predefined_metric_type = "ASGAverageCPUUtilization"
        }
      }
      scale_in = {
        adjustment_type = "ChangeInCapacity"
        scaling_adjustment = -1
        metric_aggregation_type = "Average"
        name = "scale-in"
        predefined_metric_specification {
          predefined_metric_type = "ASGAverageCPUUtilization"
        }
      }
    }

    content {
      name                       = scaling_policy.value.name
      adjustment_type            = scaling_policy.value.adjustment_type
      scaling_adjustment         = scaling_policy.value.scaling_adjustment
      metric_aggregation_type    = scaling_policy.value.metric_aggregation_type
      cooldown                   = 300
      policy_type                = "TargetTrackingScaling"
      target_tracking_configuration {
        predefined_metric_specification {
          predefined_metric_type = scaling_policy.value.predefined_metric_specification.predefined_metric_type
        }
        target_value = 70.0
      }
    }
  }

  # Use Launch Configuration with appropriate settings
  tag {
    key                 = "Name"
    value               = "my-asg"
    propagate_at_launch = true
  }
}

# Create a Launch Configuration for the ASG
resource "aws_launch_configuration" "my_launch_config" {
  name_prefix          = "my-launch-config-"
  image_id             = "ami-0f5ee92e2d63afc18"  
  instance_type        = "t2.medium"    
  security_groups      = [aws_security_group.beanstalk_sg.id]
  key_name             = "my-key-aws"  # Replace with your EC2 key pair name

  # Additional configuration settings as needed
}

# Output the Elastic Beanstalk application endpoint URL
output "beanstalk_endpoint" {
  value = aws_elastic_beanstalk_environment.my_environment.endpoint_url
}
