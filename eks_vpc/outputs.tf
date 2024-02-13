#생성된 리소스들의 id같은것들을 출력.
#terraform apply를 했을때도 물론 출력이 되고
#생성된 리소스의 id를 호출해서 쓸 수도 있다.

output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr_block" {
  value = aws_vpc.this.cidr_block
}

output "public_subnets" {
  value = { for k, v in aws_subnet.public :
    k => {
      id         = v.id
      cidr_block = v.cidr_block
    }
  }
}

output "private_subnets" {
  value = { for k, v in aws_subnet.private :
    k => {
      id         = v.id
      cidr_block = v.cidr_block
    }
  }
}

output "database_subnets" {
  value = { for k, v in aws_subnet.database :
    k => {
      id         = v.id
      cidr_block = v.cidr_block
    }
  }
}

output "nat_gateway_eips" {
  value = { for k, v in aws_eip.this : k => v.public_ip }
}
