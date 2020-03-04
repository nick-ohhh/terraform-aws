#set provider and location of servers being used
provider "aws" {
    region  = "us-west-2"
}

#create vpc and set ip address and routing prefix
resource "aws_vpc" "vpc1" {
    cidr_block  = "10.100.0.0/16"
}

#display information on vpc "vpc1"
output "vpc1" {
    value = aws_vpc.vpc1
}

#creates subnet mask in "vpc1"
resource "aws_subnet" "public" {
    vpc_id      = aws_vpc.vpc1.id
    cidr_block  = "10.100.1.0/24"

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
    instance_type   = "t2.micro"
    subnet_id       = aws_subnet.public.id
}

#provides ec2 key pair to associate with ec2 instance
resource "aws_key_pair" "user" {
    key_name    = "user-key"
    public_key  = #user supplied public key
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