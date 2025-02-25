output "fsx_file_system_id" {
  value = aws_fsx_lustre_file_system.this.id
}

output "fsx_dns_name" {
  value = aws_fsx_lustre_file_system.this.dns_name
}

output "fsx_mount_name" {
  value = aws_fsx_lustre_file_system.this.mount_name
}
