variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "Regiao da AWS"
}

variable "environment_name" {
  type        = string
  default     = "lojagamer"
  description = "Prefixo para os recursos"
}

variable "key_name" {
  type        = string
  description = "Nome do Key Pair SSH ja existente na AWS"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR da VPC"
}

variable "public_subnet_1_cidr" {
  type        = string
  default     = "10.0.1.0/24"
  description = "CIDR Subnet Publica 1"
}

variable "public_subnet_2_cidr" {
  type        = string
  default     = "10.0.2.0/24"
  description = "CIDR Subnet Publica 2"
}

variable "private_subnet_1_cidr" {
  type        = string
  default     = "10.0.11.0/24"
  description = "CIDR Subnet Privada 1"
}

variable "private_subnet_2_cidr" {
  type        = string
  default     = "10.0.12.0/24"
  description = "CIDR Subnet Privada 2"
}

variable "db_username" {
  type        = string
  default     = "admin"
  description = "Usuario admin do RDS MySQL"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Senha do RDS MySQL (minimo 8 caracteres)"
}

variable "db_instance_class" {
  type        = string
  default     = "db.t3.micro"
  description = "Classe da instancia RDS MySQL"
}

variable "ec2_instance_type" {
  type        = string
  default     = "t3.micro"
  description = "Tipo de instancia EC2"
}

variable "is_aws_academy" {
  type        = bool
  default     = false
  description = "Se true, utiliza a LabInstanceProfile do AWS Academy / Learner Lab"
}
