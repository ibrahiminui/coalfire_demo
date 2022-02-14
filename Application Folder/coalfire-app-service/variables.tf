variable "project" {
  default = "vernal-parser-324817"
}

variable "region" {
  default = "us-central1" 
}

variable "zone"  {
  default = "us-central1-c"
}

variable "shared-network"  {
  default = "projects/josh-test-327416/global/networks/coalfire-demo-vpc"
}

variable "subnet-private1"  {
  default = "projects/josh-test-327416/regions/us-central1/subnetworks/coalfire-private-subnet1"
}

variable "subnet-public1"  {
  default = "projects/josh-test-327416/regions/us-central1/subnetworks/coalfire-public-subnet1"
}

variable "app_name"  {
  default = "coalfire-lb"
}
