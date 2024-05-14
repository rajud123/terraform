resource "aws_vpc" "my_vpc" {
  cidr_block = var.cidr
}
resource "aws_subnet" "public-aws_subnet1" {
  #map_public_ip_on_launch - (Optional) Specify true to indicate that instances launched into the subnet should be assigned a public IP address. 
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "ap_south-1"
  map_public_ip_on_launch = true

}
resource "aws_subnet" "public-aws_subnet2" {

  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1"
  map_public_ip_on_launch = true

}
resource "aws_internet_gateway" "myigw" {
  vpc_id = aws_vpc.my_vpc.id
}
resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    #   # Route all Traffic to the internet gateway
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myigw.id


  }
}
resource "aws_route_table_association" "rta1" {
  #associating route table with the subnet
  route_table_id = aws_route_table.RT.id
  subnet_id      = aws_subnet.public-aws_subnet1.id
}

resource "aws_route_table_association" "rta2" {
  route_table_id = aws_route_table.RT.id
  subnet_id      = aws_subnet.public-aws_subnet2.id
}



resource "aws_security_group" "webSg" {
  name   = "web"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    #port 80 from anywhere in the world
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    #ssh from any where in the world
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    #allow acces to any port, any protocol, any where(any ip adress) in the world
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web-sg"
  }
}

resource "aws_s3_bucket" "example" {
  bucket = "rajusterraform2024project"
}
resource "aws_instance" "webserver1" {
  ami                    = "ami-0261755bbcb8c4a84"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public-aws_subnet1.id
  vpc_security_group_ids = [aws_security_group.webSg.id]
  user_data              = base64encode(file("userdata.sh"))
}
resource "aws_instance" "webserver2" {
  ami                    = "ami-0261755bbcb8c4a84"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public-aws_subnet2.id
  vpc_security_group_ids = [aws_security_group.webSg.id]
  user_data              = base64encode(file("userdata1.sh"))
}
#create alb
resource "aws_lb" "myalb" {
  name               = "myalb"
  internal           = false
  load_balancer_type = "application"
  #attaching security group to tje load balancer, it is good to have a different security group, but we are using the same one as for the ec2
  security_groups = [aws_security_group.webSg.id]
  #sepcifying the subnet
  subnets = [aws_subnet.public-aws_subnet1.id, aws_subnet.public-aws_subnet2.id]

  tags = {
    Name = "web"
  }
}
#this specifies about the load balancers target group
resource "aws_lb_target_group" "tg" {
  name     = "myTG"
  port     = 80
  protocol = "HTTP"
  health_check {
    path = "/"
    port = "traffic-port"
  }
  vpc_id = aws_vpc.my_vpc.id
}
#attaching the target group to the ec2 instance thgrough load balancers target group
resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.webserver1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.webserver2.id
  port             = 80
}

#attaching the load balancer to the target group
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.myalb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tg.arn
    type             = "forward"
  }
}

output "loadbalancerdns" {
  value = aws_lb.myalb.dns_name
}
#terraform fmt -- for formattng