# No SSH key needed since we removed remote_access
# Keeping variable in case you want to re-add later
variable "ssh_key_name" {
  description = "The name of the SSH key pair to use for worker nodes (optional)"
  type        = string
  default     = ""
}
