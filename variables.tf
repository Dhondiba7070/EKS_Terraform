# AWS region variable
variable "region" {
  description = "The AWS region where resources will be created"
  type        = string
  default     = "us-east-1"  # Set default region, can be overridden
}

# SSH Key Name variable
variable "ssh_key_name" {
  description = "The name of the SSH key pair to use for EC2 nodes. Ensure the key pair exists in the selected AWS region."
  type        = string
  default     = ""  # No default, forces the user to specify a value

  validation {
    condition     = length(var.ssh_key_name) > 0
    error_message = "You must specify a non-empty SSH key name."
  }
}
