variable "region" {
  type = string
}

variable "notebook_volume_size" {
  description = "Size of the EBS volume in GB for the SageMaker notebook instance"
  type        = number
}
