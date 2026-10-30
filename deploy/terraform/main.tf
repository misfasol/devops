terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Obter as zonas de disponibilidade da regiao atual
data "aws_availability_zones" "available" {
  state = "available"
}

# Obter AMI mais recente do Amazon Linux 2023
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ========================================================
# 1. REDE: VPC, SUBNETS, INTERNET GATEWAY E ROTAS
# ========================================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.environment_name}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment_name}-igw"
  }
}

# Subnets Publicas
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment_name}-public-subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment_name}-public-subnet-2"
  }
}

# Subnets Privadas (RDS)
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.environment_name}-private-subnet-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "${var.environment_name}-private-subnet-2"
  }
}

# Rotas Publicas
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.environment_name}-public-rt"
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Rotas Privadas
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment_name}-private-rt"
  }
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

# ========================================================
# 2. GRUPOS DE SEGURANCA (SECURITY GROUPS)
# ========================================================
resource "aws_security_group" "ec2" {
  name        = "${var.environment_name}-ec2-sg"
  description = "Acesso HTTP e SSH a EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP publico"
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
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment_name}-ec2-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.environment_name}-rds-sg"
  description = "Acesso restrito ao MySQL apenas a partir da EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL a partir do Security Group da EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment_name}-rds-sg"
  }
}

# ========================================================
# 3. S3 BUCKET (IMAGENS PRIVADAS)
# ========================================================
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "images" {
  bucket        = "${var.environment_name}-images-${random_id.bucket_suffix.hex}"
  force_destroy = true

  tags = {
    Name = "${var.environment_name}-images"
  }
}

resource "aws_s3_bucket_public_access_block" "images" {
  bucket = aws_s3_bucket.images.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ========================================================
# 4. IAM ROLE / INSTANCE PROFILE
# ========================================================
resource "aws_iam_role" "ec2_s3_role" {
  count = var.is_aws_academy ? 0 : 1
  name  = "${var.environment_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "s3_access" {
  count       = var.is_aws_academy ? 0 : 1
  name        = "${var.environment_name}-s3-policy"
  description = "Permissoes no bucket S3 da Loja Gamer"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      Resource = [
        aws_s3_bucket.images.arn,
        "${aws_s3_bucket.images.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_s3" {
  count      = var.is_aws_academy ? 0 : 1
  role       = aws_iam_role.ec2_s3_role[0].name
  policy_arn = aws_iam_policy.s3_access[0].arn
}

resource "aws_iam_instance_profile" "profile" {
  count = var.is_aws_academy ? 0 : 1
  name  = "${var.environment_name}-instance-profile"
  role  = aws_iam_role.ec2_s3_role[0].name
}

# ========================================================
# 5. RDS MYSQL
# ========================================================
resource "aws_db_subnet_group" "rds" {
  name        = "${var.environment_name}-db-subnet-group"
  description = "Subnets privadas do RDS"
  subnet_ids  = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "${var.environment_name}-db-subnet-group"
  }
}

resource "aws_db_instance" "mysql" {
  identifier             = "${var.environment_name}-db"
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.db_instance_class
  db_name                = "lojagamer"
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  skip_final_snapshot    = true

  tags = {
    Name = "${var.environment_name}-mysql"
  }
}

# ========================================================
# 6. INSTANCIA EC2
# ========================================================
resource "aws_instance" "web" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.ec2_instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.public_1.id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  associate_public_ip_address = true
  iam_instance_profile        = var.is_aws_academy ? "LabInstanceProfile" : aws_iam_instance_profile.profile[0].name

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
              #!/bin/bash
              set -e
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

              echo "==> Atualizando pacotes e instalando Docker"
              dnf update -y
              dnf install -y docker git
              systemctl enable --now docker
              usermod -aG docker ec2-user

              mkdir -p /opt/lojagamer/releases
              chown -R ec2-user:ec2-user /opt/lojagamer

              cat << 'EOCFG' > /opt/lojagamer/.env
              DB_HOST=${aws_db_instance.mysql.address}
              DB_PORT=3306
              DB_USER=${var.db_username}
              DB_PASSWORD=${var.db_password}
              DB_NAME=lojagamer
              DB_TLS=preferred
              STORAGE_DRIVER=s3
              S3_BUCKET=${aws_s3_bucket.images.id}
              S3_PREFIX=products/
              AWS_REGION=${var.aws_region}
              ADMIN_TOKEN=admin123
              LOG_LEVEL=info
              MIGRATE=true
              EOCFG

              chmod 600 /opt/lojagamer/.env
              chown ec2-user:ec2-user /opt/lojagamer/.env
              echo "==> User Data concluido!"
              EOF

  depends_on = [aws_db_instance.mysql]

  tags = {
    Name = "${var.environment_name}-ec2"
  }
}
