output "ec2_public_ip" {
  description = "IP Publico da EC2"
  value       = aws_instance.web.public_ip
}

output "ec2_public_dns" {
  description = "DNS Publico da EC2"
  value       = aws_instance.web.public_dns
}

output "app_url" {
  description = "URL da Loja Gamer"
  value       = "http://${aws_instance.web.public_ip}"
}

output "healthcheck_url" {
  description = "URL do Health Check"
  value       = "http://${aws_instance.web.public_ip}/healthz"
}

output "rds_endpoint" {
  description = "Endpoint do banco de dados RDS MySQL"
  value       = aws_db_instance.mysql.address
}

output "s3_bucket" {
  description = "Nome do bucket S3 criado"
  value       = aws_s3_bucket.images.id
}
