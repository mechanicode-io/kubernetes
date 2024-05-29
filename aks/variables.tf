variable "location" {
  type    = string
  default = "East US"
}

variable "owner" {
  type    = string
}

variable "environment" {
  type    = string
}

variable "costCenter" {
  type    = string
}

variable "client_id" {
  type    = string
}

variable "client_secret" {
  type    = string
}

variable "computer_name" {
  type = string
}

variable "admin_username" {
  type = string
}

variable "vm_size" {
  type    = string
  default = "Standard_D2_v2"
}
