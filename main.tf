provider "aws" {
  region = "us-east-1"
}

#Creación de la VPC y la Subred
resource "aws_vpc" "main" {
  cidr_block = "10.10.0.0/20"
}

resource "aws_subnet" "subnet_public" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.10.0.0/24"
  map_public_ip_on_launch = true
}

#Creación del gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

#Tablas de rutas
resource "aws_route_table" "public" {
  vpc_id = aws_internet_gateway.igw.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

#Asosiación de tablas de rutas.
resource "aws_route_table_association" "public" {
  subnet_id = aws_subnet.subnet_public.id
  route_table_id = aws_route_table.public.id
}

#Creación de los grupos de seguridad.
#Jump server SG- este grupo de seguridad solo permitira SSH desde internet

resource "aws_security_group" "Jump_sg" {
  name = "jumpAct3-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}

#Grupo de seguridad del web server que nos permitira accder a HTTP desde internet y SSH solo desde el jump server

resource "aws_security_group" "web_sg" {
  name = "webAct3-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = [ aws_security_group.Jump_sg.id ]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}

#Creación de las instancias EC2
#Jump Server
resource "aws_instance" "jump_server" {
  ami = "ami-00a929b66ed6e0de6" #Amazon Linux 3
  instance_type = "t2.micro"
  subnet_id = aws_subnet.subnet_public.id
  security_groups = [ aws_security_group.Jump_sg.name ]
  key_name = "Act3key"

  tags = {
    Name = "jump-server-Act3"
  }
}


#Web server Amazón Linux 3
resource "aws_instance" "Web_server" {
  count = 4
  ami = "ami-00a929b66ed6e0de6"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.subnet_public.id
  security_groups = [ aws_security_group.web_sg.name ]
  key_name = "Act3key"
  user_data = file("scripts/setup_web.sh")

  tags = {
    name = "Act3-Web-Server-${count.index + 1}"
  }
}