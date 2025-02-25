variable "fsx_name" {
  description = "Name of the FSx file system"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs (only first one will be used)"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs to attach to the FSx file system"
  type        = list(string)
}

variable "storage_capacity" {
  description = "Storage capacity of the FSx file system in GiB"
  type        = number
  default     = 1200  # Minimum for PERSISTENT_1 deployment
}

variable "deployment_type" {
  description = "The FSx deployment type"
  type        = string
  default     = "PERSISTENT_1"
}

variable "per_unit_storage_throughput" {
  description = "Throughput in MB/s/TiB for PERSISTENT_1 deployment type"
  type        = number
  default     = 100  # Possible values: 50, 100, 200
}