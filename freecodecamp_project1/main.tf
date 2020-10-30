terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  access_key = "AKIAJXJYJUE5G2QIQDDQ"
  secret_key = "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"
}

# 1. Create the VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

# 2. Create the Internet Gateway for traffic
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
}

# 3. Create Custom Route Table, https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route_table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id  # allows traffic from our subnet to get out to the internet
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id 
  }

  tags = {
    Name = "Prod"
  }
}

# 4. Create subnet, where our web server will reside

variable "subnet_prefix" {
  description = "cidr block for the subnet"
  # default = "10.0.9.0/24"
  # type = string
}

resource "aws_subnet" "subnet-1" {
  vpc_id = aws_vpc.prod-vpc.id
  cidr_block = var.subnet_prefix[0].cidr_block  # Terraform Variables Section: https://www.youtube.com/watch?v=SLB_c_ayRMo&t=7426s
  availability_zone = "us-east-1a"

  tags = {
    Name = var.subnet_prefix[0].name
  }
}

# Creating a 2nd Subnet for last part of course 2:16 hr: https://youtu.be/SLB_c_ayRMo?t=8196

resource "aws_subnet" "subnet-2" {
  vpc_id = aws_vpc.prod-vpc.id
  cidr_block = var.subnet_prefix[1].cidr_block  # Terraform Variables Section: https://www.youtube.com/watch?v=SLB_c_ayRMo&t=7426s
  availability_zone = "us-east-1a"

  tags = {
    Name = var.subnet_prefix[1].name
  }
}

# 5. Associate Subnet with a Route Table / Route Table association

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# 6. Create a Security Group to Allow port 22 access

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # allow everyone to access this web server, any IP address
  }

  ingress {
    description = "HTTPS"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 indicates any protocol
    cidr_blocks = ["0.0.0.0/0"] # any IP address
  }

  tags = {
    Name = "allow_web"
  }
}

# 7. Create a Network Interface / Private IP address

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]  # could assign more than one IP here
  security_groups = [aws_security_group.allow_web.id]
}

# 8. Assign public IP address so anyone on internet can acces / Elastic IP address to the Network interface from Step 7
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip
/* AWS eip relies on the deployment of the internet gateway created earlier, so internet 
gateway must be there, b/c IG must be there for you to have a public IP address.  So this
 is exception to order doesn't matter in .tf file.  you can use depends_on here */
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"  # same as noted in network interface Step 7
  depends_on = [aws_internet_gateway.gw] # in this particular case we don't specify the .id, but we reference the whole object
}

output "server_public_ip" {
  value = aws_eip.one.public_ip
}

# 9. Create Ubuntu Server and install/enable Apache
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance

resource "aws_instance" "web-server-instance" {
  ami = "ami-0dba2cb6798deb6d8" # ami for a free tier ubuntu, 36 min into tutorial
  instance_type = "t2.micro" 
  availability_zone = "us-east-1a" # hardcoded so that AWS doesn't pick a random availability zone to deploy. Sometimes subnet and interface can be deployed in different availability zones.  so hardcode Availability zones
  key_name = "DevOpsWork" # setup in AWS console from before

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }
  # running some commands below for installing Apache
  user_data = <<-EOF
              #!bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo your very first webserver > /var/www/html/index.html'
              EOF
  tags = {
    Name = "ubuntu web server - free code camp"
  }
}

output "server_private_ip" {
  value = aws_instance.web-server-instance.private_ip
}

output "server_id" {
  value = aws_instance.web-server-instance.id

}