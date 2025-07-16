#
# Variables Configuration. Check for REPLACE to substitute custom values. Check the description of each
# tag for more information
#

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  default = "digit-lts-dsn" #REPLACE
}

variable "vpc_cidr_block" {
  description = "CIDR block"
  default = "192.168.0.0/16"
}


variable "network_availability_zones" {
  description = "Configure availability zones configuration for VPC. Leave as default for India. Recommendation is to have subnets in at least two availability zones"
  default = ["ap-south-1b", "ap-south-1a"] #REPLACE IF NEEDED
}

variable "availability_zones" {
  description = "Amazon EKS runs and scales the Kubernetes control plane across multiple AWS Availability Zones to ensure high availability. Specify a comma separated list to have a cluster spanning multiple zones. Note that this will have cost implications"
  default = ["ap-south-1b"] #REPLACE IF NEEDED
}

variable "kubernetes_version" {
  description = "kubernetes version"
  default = "1.29"
}

variable "instance_type" {
  description = "eGov recommended below instance type as a default"
  default = "r5ad.large"
}

variable "override_instance_types" {
  description = "Arry of instance types for SPOT instances"
  default = ["r5a.large", "r5ad.large", "r5d.large", "m4.xlarge"]
  
}

variable "number_of_worker_nodes" {
  description = "eGov recommended below worker node counts as default"
  default = "3" #REPLACE IF NEEDED
}

variable "ssh_key_name" {
  description = "ssh key name, not required if your using spot instance types"
  default = "digit-lts-ssh-key" #REPLACE
}


variable "db_name" {
  description = "RDS DB name. Make sure there are no hyphens or other special characters in the DB name. Else, DB creation will fail"
  default = "digitltsdb" #REPLACE
}

variable "db_username" {
  description = "RDS database user name"
  default = "digitltsdsn" #REPLACE
}

#DO NOT fill in here. This will be asked at runtime
variable "db_password" {}

variable "public_key" {
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCMMO2fKEHqIvKxME67L/nDtBRUNDiqtshgCI5QnBmQMOb6zdjk5sVgPDdV8cHwdztfPJWk5pcEasyIsiqDLyIODH0FQl6pwytVsfkI2AHIwJ1zyDB1fq0b67uEoEyyehYEstbyHEpHKRtejftlfBgcOXnmVVMSH9vlwJ8I47xBPO+CncHo2V+CCqJckaneH0BmED0e1EUnCJD2Dx5fKt0V4KB8+KXxw+cs/AYw11IF0eN8cYXDKH9s/c7HXHSy89dHcwHzmWcLXcJV6b2p3kbL6YGwyfWG/4He5sr8cMIA/Rmp744hszZECbKFaychncDtSI30huWq4lkS2lSGEuMJ"
  description = "ssh key"
}

## change ssh key_name eg. digit-quickstart_your-name



