resource "tls_private_key" "k8s" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = var.key_name
  public_key = tls_private_key.k8s.public_key_openssh
    provisioner "local-exec" { 
    command = "echo '${tls_private_key.k8s.private_key_pem}' > ./${var.key_name}.pem && chmod 400 ./${var.key_name}.pem"
  }
}

resource "aws_security_group" "public" {
  name        = "k8s-public-sg"
  description = "Public internet access"
  vpc_id      = var.vpc

  tags = {
    Name      = "k8s-public-sg"
    Role      = "public"
    ManagedBy = "terraform"
  }
}

resource "aws_security_group_rule" "public_out" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.public.id
}

resource "aws_security_group_rule" "public_in_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public.id
}

resource "aws_security_group_rule" "public_in_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public.id
}

resource "aws_security_group_rule" "public_in_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public.id
}

###
# Private Security Group
##

resource "aws_security_group" "private" {
  name        = "k8s-private-sg"
  description = "Private internet access"
  vpc_id      = var.vpc

  tags = {
    Name      = "k8s-private-sg"
    Role      = "private"
    ManagedBy = "terraform"
  }
}

resource "aws_security_group_rule" "private_out" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.private.id
}

resource "aws_security_group_rule" "private_in" {
  type        = "ingress"
  from_port   = 0
  to_port     = 65535
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]


  security_group_id = aws_security_group.private.id
}