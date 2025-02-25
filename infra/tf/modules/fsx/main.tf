resource "aws_fsx_lustre_file_system" "this" {
  storage_capacity            = var.storage_capacity
  subnet_ids                  = [var.subnet_ids[0]]
  deployment_type             = var.deployment_type
  per_unit_storage_throughput = var.per_unit_storage_throughput
  security_group_ids          = var.security_group_ids
  file_system_type_version    = 2.15
  
  tags = {
    Name = var.fsx_name
  }
}

