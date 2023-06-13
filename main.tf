# aws region
provider "aws" {
  region = "ap-southeast-2"
}

# create VPC
resource "aws_vpc" "lidor_vpc" {
  cidr_block = "192.168.0.0/16"
} 

# create subnet
resource "aws_subnet" "lidor_subnet" {
  vpc_id                  = aws_vpc.lidor_vpc.id
  cidr_block              = "192.168.0.0/24"
  availability_zone       = "ap-southeast-2a"
}

# create Security Group
resource "aws_security_group" "lidor_sg" {
  name        = "lidor_sg"
  description = "Security group for application servers"
  vpc_id      = aws_vpc.lidor_vpc.id
 
  # I rule: Allow traffic from the workstation to the LB server on port 80
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["13.48.148.177/32"]
  }

  # II rule: Allow traffic from the workstation to all the servers on port 22
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["13.48.148.177/32"]
  }

  # III rule: Allow any internal communication in the subnet
  ingress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["192.168.0.0/16"] 
  description = " 0 = all ports, -1 = all protocols - in the subnet"
  }
  
  # IV rule: allow outbound 
  egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  }
  
}

# create an internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.lidor_vpc.id

  tags = {
    Name = "lidor_vpc_igw"
  }
}

# create a route table to sent the request to the internet
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.lidor_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    gateway_id     = aws_internet_gateway.igw.id
  }
}
# associates the route table with the subnet
resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.lidor_subnet.id
  route_table_id = aws_route_table.rt.id
}


##########################################################
# create private and public keys to connect the instances

# Generate the SSH key pair
resource "tls_private_key" "key_pair" {
  algorithm = "RSA"
}

# Save the private key to a file
resource "local_file" "private_key" {
  content         = tls_private_key.key_pair.private_key_pem
  filename        = "${path.module}/keys/private_key.pem"
  file_permission = "0600"
}

# Associate the public key with the instances
resource "aws_key_pair" "key_pair" {
  key_name   = "ubuntu-work-keypair"
  public_key = tls_private_key.key_pair.public_key_openssh
} 

##########################################################

# Create LB instance
resource "aws_instance" "lb" {
  ami           = "ami-0672b175139a0f8f4"
  instance_type = "t2.micro"
  private_ip = "192.168.0.11"
  associate_public_ip_address = true

  tags = {
    Name = "LB"
  }

  subnet_id = aws_subnet.lidor_subnet.id
  vpc_security_group_ids = [ aws_security_group.lidor_sg.id ]
  key_name               = aws_key_pair.key_pair.key_name
}

# Create WEB instance
resource "aws_instance" "web" {
  ami           = "ami-0672b175139a0f8f4"
  instance_type = "t2.micro"
  private_ip = "192.168.0.12"
  associate_public_ip_address = true

  tags = {
    Name = "WEB"
  }

  subnet_id = aws_subnet.lidor_subnet.id
  vpc_security_group_ids = [ aws_security_group.lidor_sg.id ]
  key_name               = aws_key_pair.key_pair.key_name
}

# Create DB instance
resource "aws_instance" "db" {
  ami           = "ami-0672b175139a0f8f4"
  instance_type = "t2.micro"
  private_ip = "192.168.0.13"
  associate_public_ip_address = true

  tags = {
    Name = "DB"
  }
  
  subnet_id = aws_subnet.lidor_subnet.id
  vpc_security_group_ids = [ aws_security_group.lidor_sg.id ]
  key_name               = aws_key_pair.key_pair.key_name
}
