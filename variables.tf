variable "ssh_key_name" {
  description = "The name of the SSH key pair to use for EC2 nodes. Ensure the key pair exists in the selected AWS region."
  type        = string

  validation {
    condition     = length(var.ssh_key_name) > 0
    error_message = "You must specify a non-empty SSH key name."
  }
}
