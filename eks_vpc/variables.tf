variable "eks_cluster_name" {
  type        = string
  description = "EKS cluster's name"
  default     = "my-cluster"
}

variable "cidr_block" {
  type        = string
  description = "The CIDR block of VPC"
  default     = "10.100.0.0/16"
}

variable "prefix" {
  type        = string
  description = "The prefix name used in this module"
  #vpc를 비롯한 리소스에 붙여줄 이름. eks로 하면
  #서브넷,라우팅테이블 등.. 모든 리소스에 eks가 붙는다.
  default     = "eks"
}

variable "env" {
  type        = string
  description = "Environment like prod, stg, dev, alpha"
  default     = "dev"
  #어떤 환경을 위한 vpc인지?
  #locals.tf에 로컬변수로 등록한 후 각 리소스에서 호출하여
  #모든 리소스에 tag를 붙여줄 예정.
}

variable "subnet_cidrs" {
  type        = any
  description = "The subnet CIDRs (public/private/database)"
  default     = {
    public   = ["10.100.1.0/24","10.100.11.0/24"]
    private  = ["10.100.2.0/24","10.100.12.0/24"]
    database = ["10.100.3.0/24","10.100.13.0/24"]
    
    #가용영역의 수에 맞춰 서브넷들의 cidr을 결정해준다.
    #가용영역의 수 = 리스트의 요소갯수
    
  }
}


variable "subnet_tags" {
  type        = any
  description = "The subnet tag used to manage resources (public/private/database)"
  default = {
    
    public   = {
      "kubernetes.io/role/elb" = 1
    }

    private  = {
      "kubernetes.io/role/internal-elb" = 1
    }

    database = {
      "kubernetes.io/role/internal-elb" = 1
    }
  }
}

variable "vpc_options" {
  type        = any
  description = "VPC options like enable_dns_hostnames, enable_dns_support"
  default     = {}
}

variable "azs" {
  type        = list(string)
  description = "AWS availability zones in subnets"
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "single_nat_gateway" {
  type        = bool
  description = "Enable the single NAT gateway or not. If this variable is disabled, NAT gateways are created cross all AZs"
  default     = true
}

variable "enable_nat_private" {
  type        = bool
  description = "Flag to enable or disable NAT gateway in private subnet"
  default     = false
}

variable "enable_nat_database" {
  type        = bool
  description = "Flag to enable or disable NAT gateway in the database subnet"
  default     = false
}
