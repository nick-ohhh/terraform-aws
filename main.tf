variable "role_arn" {}
variable "region" {}
variable "shared_credentials_file" {}
variable "profile" {}
variable "key_name" {}
variable "public_key" {}

#set provider and location of servers being used
provider "aws" {
    assume_role ={
    role_arn                = var.role_arn
    region                  = var.region
    shared_credentials_file = var.shared_credentials_file
    profile                 = var.profile
    }
}

#create vpc and set ip address and routing prefix
resource "aws_vpc" "vpc1" {
    cidr_block  = "10.100.0.0/16"

    tags    = {
        Name = "vpc1"    
    }
}

#creates subnet mask in "vpc1"
resource "aws_subnet" "public" {
    vpc_id                  = aws_vpc.vpc1.id
    cidr_block              = "10.100.1.0/24"
    map_public_ip_on_launch = true
    availability_zone       = "us-west-2a"

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

#creates secondary public subnet
resource "aws_subnet" "public2" {
    vpc_id                  = aws_vpc.vpc1.id
    cidr_block              = "10.100.5.0/24"
    map_public_ip_on_launch = true
    availability_zone       = "us-west-2b"

    tags = {
        Name = "public2"
    }
}

#create internet gateway for vpc.
#required for instances to connect online
resource "aws_internet_gateway" "vpc_gw" {
    vpc_id  = aws_vpc.vpc1.id

    tags    = {
        Name = "vpc_gw"
    }
}

#create and set VPC routing table
resource "aws_route_table" "vpc_rt" {
    vpc_id  = aws_vpc.vpc1.id

    route {
        cidr_block  = "0.0.0.0/0"
        gateway_id  = aws_internet_gateway.vpc_gw.id
    }

    tags = {
        Name = "vpc_rt"
    }
}

#associate route table with subnet
resource "aws_route_table_association" "vpc_route_associate" {
    subnet_id       = aws_subnet.public.id
    route_table_id  = aws_route_table.vpc_rt.id
}

resource "aws_route_table_association" "vpc_route_associate2" {
    subnet_id       = aws_subnet.public2.id
    route_table_id  = aws_route_table.vpc_rt.id
}

# specifies operating system and hardware for a single ec2 instance
# resource "aws_instance" "instance_web" {
#     ami             = "ami-08692d171e3cf02d6"
#     instance_type   = "t2.micro"
#     subnet_id       = aws_subnet.public.id
#     depends_on      = [aws_internet_gateway.vpc_gw]
# }

#create new security group for "vpc1" with inbound/outbound rules
resource "aws_security_group" "Web" {
    name        = "Web"
    description = "Allows SSH and web traffic"
    vpc_id      = aws_vpc.vpc1.id

    #allows SSH inbound connections
    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    #allows HTTP inbound connections
    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    #allows HTTPS inbound connections
    ingress {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    #allows any outbound connections from instance
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

#modifies default security group for "vpc1" with inbound/outbound rules
resource "aws_default_security_group" "default" {
    vpc_id  = aws_vpc.vpc1.id

    #allows SSH inbound connections
    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    #allows HTTP inbound connections
    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    #allows HTTPS inbound connections
    ingress {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    #allows any outbound connections from instance
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# attaches security groups to single ec2 instance on creation
# resource "aws_network_interface_sg_attachment" "sg_attachment" {
#     security_group_id       = aws_security_group.Web.id
#     network_interface_id    = aws_instance.instance_web.primary_network_interface_id
# }

resource "aws_key_pair" "terraform" {
    key_name    = var.key_name
    public_key  = var.public_key
    # private_key = var.private_key
}

#resource to select image for new spawns via asg
resource "aws_launch_configuration" "asg_lconfig" {
    name_prefix     = "asg_lconfig-"
    image_id        = "ami-08692d171e3cf02d6"
    instance_type   = "t2.micro"
    key_name        = var.key_name
    user_data       = file("nginx_setup.sh")
    security_groups = [aws_security_group.Web.id]

    lifecycle {
        create_before_destroy = true
    }
}

#creates auto scaling group with specifications
resource "aws_autoscaling_group" "web_asg" {
    name                      = "web_asg"
    launch_configuration      = aws_launch_configuration.asg_lconfig.name
    #availability_zones        = ["us-west-2a"]
    vpc_zone_identifier       = [aws_subnet.public.id, aws_subnet.public2.id]
    health_check_grace_period = 200
    max_size                  = 2
    min_size                  = 2
    target_group_arns         = [aws_lb_target_group.nginx_tg.arn]

    lifecycle {
        create_before_destroy = true
    }
}

#application load balancer
resource "aws_lb" "nginx_lb" {
    name                = "nginx-lb"
    load_balancer_type  = "application"
    security_groups     = [aws_security_group.Web.id]
    subnets             = [aws_subnet.public.id, aws_subnet.public2.id]
}

#load balancer target group
resource "aws_lb_target_group" "nginx_tg" {
    name        = "nginx-tg"
    port        = 80
    protocol    = "HTTP"
    vpc_id      = aws_vpc.vpc1.id

    health_check {
        port    = 80
    }
}

#load balancer listener
resource "aws_lb_listener" "nginx_listener" {
    load_balancer_arn   = aws_lb.nginx_lb.arn
    port                = 80
    protocol            = "HTTP"

    default_action {
        type                = "forward"
        target_group_arn    = aws_lb_target_group.nginx_tg.arn
    }
}

#s3 bucket resource, media storage
resource "aws_s3_bucket" "jjbalogo" {
    bucket  = "jjbalogo"
}

#bucket and object location
resource "aws_s3_bucket_object" "bucket_logo" {
    bucket  = aws_s3_bucket.jjbalogo.id
    key     = "jjba_logo.jpg"
    source = "./jjba_logo.jpg"
}

#bucket policy json data
data "aws_iam_policy_document" "bucket_policy_document" {
    statement {
        effect = "Allow"
        actions = [
            "s3:ListBucketByTags",
                        "s3:GetLifecycleConfiguration",
                        "s3:GetBucketTagging",
                        "s3:GetInventoryConfiguration",
                        "s3:GetObjectVersionTagging",
                        "s3:ListBucketVersions",
                        "s3:GetBucketLogging",
                        "s3:GetAccelerateConfiguration",
                        "s3:GetBucketPolicy",
                        "s3:GetObjectVersionTorrent",
                        "s3:GetObjectAcl",
                        "s3:GetEncryptionConfiguration",
                        "s3:GetBucketRequestPayment",
                        "s3:GetObjectVersionAcl",
                        "s3:GetObjectTagging",
                        "s3:GetMetricsConfiguration",
                        "s3:GetBucketPublicAccessBlock",
                        "s3:GetBucketPolicyStatus",
                        "s3:ListBucketMultipartUploads",
                        "s3:GetBucketWebsite",
                        "s3:GetBucketVersioning",
                        "s3:GetBucketAcl",
                        "s3:GetBucketNotification",
                        "s3:GetReplicationConfiguration",
                        "s3:ListMultipartUploadParts",
                        "s3:GetObject",
                        "s3:GetObjectTorrent",
                        "s3:GetBucketCORS",
                        "s3:GetAnalyticsConfiguration",
                        "s3:GetObjectVersionForReplication",
                        "s3:GetBucketLocation",
                        "s3:GetObjectVersion",
                        "s3:ListBucket"
        ]
        resources = [
                        "arn:aws:s3:::jjbalogo",
                        "arn:aws:s3:::jjbalogo/*"
                        ]
                }
        statement {
                effect = "Allow"
                actions = [
                "s3:GetAccountPublicAccessBlock",
                "s3:ListAllMyBuckets",
                "s3:HeadBucket"
                ]
                resources = [ "*"]
    }
}

#policy for instances to access/interact with bucket
resource "aws_iam_policy" "bucket_logo_policy" {
    name        = "bucket_logo_policy"
    description = "Policy for interactions and properties of S3 bucket"
    policy      = data.aws_iam_policy_document.bucket_policy_document.json
}

data "aws_iam_policy_document" "bucket_role_document" {
    statement {
                actions = ["sts:AssumeRole"]
                principals {
                        type = "Service"
                        identifiers = ["ec2.amazonaws.com"]
                }
                effect = "Allow"
        }
}

#instance role/permissions for bucket interaction
resource "aws_iam_role" "bucket_logo_role" {
    name                = "bucket_logo_role"
    assume_role_policy  = data.aws_iam_policy_document.bucket_role_document.json
}

resource "aws_iam_role_policy_attachment" "bucket_role_policy_attach" {
    role        = aws_iam_role.bucket_logo_role.name
    policy_arn  = aws_iam_policy.bucket_logo_policy.arn
}

resource "aws_iam_instance_profile" "bucket_profile" {
    name    = "bucket_profile"
    role    = aws_iam_role.bucket_logo_role.name
}