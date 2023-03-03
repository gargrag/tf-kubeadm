variable "ami" {
  type    = string
  default = "ami-0f1a5f5ada0e7da53"
}

variable "vpc" {
  type    = string
  default = "vpc-389cd940"
}
variable "key_name" {
  type    = string
  default = "safekey"
}
variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "control_plane" {
  type    = string
  default = "dewalt"
}

variable "node_names" {
  type    = list(string)
  default = ["husky", "ryobi"]
}