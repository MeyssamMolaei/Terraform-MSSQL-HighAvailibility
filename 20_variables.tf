variable "remote_host" {
  default = "192.168.1.179"
}
variable "remote_user" {
  default = "memo"
}
variable "ssh_key" {
  default = "~/.ssh/id_rsa"
}



variable "sa_password" {
  type    = string
  default = "YourStrongPassw0rd"
}

variable "ag_listener_port" {
  type    = number
  default = 1433
}
