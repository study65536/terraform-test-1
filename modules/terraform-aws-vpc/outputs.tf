output "vpc_id" {
  value = aws_vpc.this.id
}

output "private_subnet_ids_by_az" {
  value = { for az, subnet in aws_subnet.private : az => subnet.id }
  depends_on = [
    aws_route_table_association.private, aws_route.nat,
    aws_route_table_association.public, aws_route.internet,
  ]
}

output "public_subnet_ids_by_az" {
  value      = { for az, subnet in aws_subnet.public : az => subnet.id }
  depends_on = [aws_route_table_association.public, aws_route.internet]
}

output "private_route_table_ids_by_az" {
  description = "VPC 엔드포인트나 중앙 라우팅을 연결할 AZ별 라우팅 테이블 ID"
  value       = { for az, route_table in aws_route_table.private : az => route_table.id }
}

output "public_route_table_id" {
  value = aws_route_table.public.id
}

output "flow_log_id" {
  value = one(aws_flow_log.s3[*].id)
}
