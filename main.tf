#set provider and location of servers being used
provider "aws" {
    region  = "us-west-2"
}

#create vpc and set ip address and routing prefix
resource "aws_vpc" "vpc1" {
    cidr_block  = "10.100.0.0/16"
}

# display information on vpc "vpc1"
# output "vpc1" {
#     value = aws_vpc.vpc1
# }

#creates subnet mask in "vpc1"
resource "aws_subnet" "public" {
    vpc_id                  = aws_vpc.vpc1.id
    cidr_block              = "10.100.1.0/24"
    map_public_ip_on_launch = true

    tags = {
        Name = "public"
    }
}

#creates subnet mask in "vpc1"
resource "aws_subnet" "private" {
    vpc_id      = aws_vpc.vpc1.id
    cidr_block  = "10.100.9.0/24"

    tags = {
        Name = "private"
    }
}

#specifies operating system and hardware for ec2 instance
resource "aws_instance" "instance_web" {
    ami             = "ami-08692d171e3cf02d6"
    key_name        = var.key_name
    instance_type   = "t2.micro"
    subnet_id       = aws_subnet.public.id
}

#create new security group for "vpc1" with inbound/outbound rules
resource "aws_security_group" "Web" {
    name        = "Web"
    description = "Allows SSH and web traffic"
    vpc_id      = aws_vpc.vpc1.id

    #only allows ssh inbound connections
    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    #allows HTTP outbound connections from instance
    egress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    #allows HTTPS outbound connections from instance
    egress {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

#modifies default security group for "vpc1" with inbound/outbound rules
resource "aws_default_security_group" "default" {
    vpc_id  = aws_vpc.vpc1.id

    #only allows ssh inbound connections
    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    #allows HTTP outbound connections from instance
    egress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    #allows HTTPS outbound connections from instance
    egress {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

#attaches security groups to ec2 instance on creation
resource "aws_network_interface_sg_attachment" "sg_attachment" {
    security_group_id       = aws_security_group.Web.id
    network_interface_id    = aws_instance.instance_web.primary_network_interface_id
}

#resource to select image for new spawns via asg
resource "aws_launch_configuration" "asg_lconf" {
    name          = "web_lconfig"
    image_id      = aws_instance.instance_web.ami
    instance_type = "t2.micro"
}

#creates auto scaling group with specifications
resource "aws_autoscaling_group" "instance_asg" {
    name                      = "web_asg"
    availability_zones        = ["us-west-2a"]
    vpc_zone_identifier       = [aws_subnet.public.id, aws_subnet.private.id]
    health_check_grace_period = 200
    max_size                  = 2
    min_size                  = 2
    desired_capacity          = 2
    launch_configuration = aws_launch_configuration.asg_lconf.name

    # provisioner "remote-exec" { #installs nginx for all new instances spun up by auto scaling
    #     connection {
    #         type        = "ssh"
    #         host        = ""
    #         user        = "root"
    #         private_key = "home/vagrant/.ssh/terraform-ec2.pem"
    #     } 
    #     inline = [
    #         "sleep 10",
    #         "sudo apt-get -y update",
    #         "sudo apt-get -y install nginx",
    #         "sudo service nginx start",
    #     ]
    # }
}