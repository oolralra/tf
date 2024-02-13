# resource는 말그대로 aws의 리소스를 뜻함.
# aws_vpc라는 리소스는 테라폼을 통해 aws의 vpc를 제어하는 리소스.


# 그 밑에 cidr_block은 모듈. 앤서블의 모듈과 비슷하다고 보면된다.
# this는 리소스(aws_vpc)가 한개만 존재할때 관행적으로 붙여주는 이름이다.
# 언젠가 vpc를 명시해야되는 경우가 있을때 그냥 aws_vpc.this로 명시하면 편하기때문.

resource "aws_vpc" "this" {

  cidr_block = var.cidr_block
  #vpc의 cidr은 10.100.0.0/16과 같은 문자열 형태로 입력.
  #var는 variable.tf 파일
  #var.cidr_block은 variables.tf에 존재하는 cidr_block이라는 변수를 뜻한다.
 
  enable_dns_support   = lookup(var.vpc_options, "enable_dns_support", true)
  enable_dns_hostnames = lookup(var.vpc_options, "enable_dns_hostnames", true)
  #vpc설정편집에 존재하는 옵션들. 역시 variables.tf파일에 미리 선언해둔 값을
  #가져온다. lookup 함수는 엑셀과 비슷하다.
  #lookup(A,B,C)는 A에서 B를 찾아 B 해당 key의 value를 가져온다.
  #C는 해당 키값이 존재하지 않을때 기본값이다.
  #variables.tf에서 vpc_options라는 변수를 찾아 enable_dns_support라는 key의 value를 넣어주되
  #해당 key가 존재하지 않으면 true를 기본 value값으로 넣는다.
 
  #merge는 자료의 형태나 틀이 변하는건 아니고 갯수만 늘어난다고 생각하면 좋다
  #예를 들자면 2개의 요소를 갖는 리스트(딕셔너리)와 3개의 요소를 갖는 리스트(딕셔너리)를
  #merge하여 5개의 요소를 갖는 리스트(딕셔너리)를 만드는식이다.
 
  tags = merge(
               local.default_tags,
               {Name = format("%s-%s-vpc", var.prefix, var.env)}
         )
  #위 tag 모듈은 말그대로 태그를 다는 모듈이다. tag = {key1 = value1}형태로
  #여러개 정의 가능.
  # tag = { key1 = value1
  #         key2 = value2
  #         key3 = value3
  # }
  #이런 형태로 여러개의 태그를 달 수 있고 variables나 locals에 정의해놓은
  #값을 가져올 수도 있다.
  #위 merge함수는 결국 두개의 태그를 vpc에 추가한다.
 
}

resource "aws_subnet" "public" {
  for_each = zipmap(var.azs, var.subnet_cidrs.public)
 
  #set = 리스트 [1,2,3, ...]
  #map = 딕셔너리 [key1:value1,key2:value2]
  #zipmap = 첫번째 리스트 요소 = key, 두번째 리스트 요소 = value로 zip하겠다.
  #var.azs = [ap-northeast-2a, ap-northeast-2c]
  #var.subnet_cidrs.public = ["10.100.1.0/24","10.100.11.0/24"]
  #위 두 리스트를 zipmap하면 딕셔너리가 됨.
  #{ "ap-northeast-2a":"10.100.1.0/24", "ap-northeast-2c":"10.100.11.0/24" }
 
  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value
 
  map_public_ip_on_launch = true
  # 퍼블릭 IPv4 주소 자동 할당 활성화
 
  enable_resource_name_dns_a_record_on_launch = true
  # 시작 시 리소스 이름 DNS A 레코드 활성화
 
  tags = merge(local.default_tags,
               local.subnet_tags.public,
               {Name = format("%s-%s-public-%s-subnet", var.prefix, var.env, each.key)},
               {format("kubernetes.io/cluster/%s",var.eks_cluster_name) = "owned"}
               #EKS 클러스터 서브넷에 필요한 tag.
         )
}

resource "aws_subnet" "private" {
  for_each = zipmap(var.azs, var.subnet_cidrs.private)
 
  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value
 
  tags = merge(local.default_tags,
               local.subnet_tags.private,
               {Name = format("%s-%s-private-%s-subnet", var.prefix, var.env, each.key)},
               {format("kubernetes.io/cluster/%s",var.eks_cluster_name) = "owned"}
         )
}

resource "aws_subnet" "database" {
  for_each = zipmap(var.azs, var.subnet_cidrs.database)


  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = merge(local.default_tags,
               local.subnet_tags.database,
               {Name = format("%s-%s-database-%s-subnet", var.prefix, var.env, each.key)},
               {format("kubernetes.io/cluster/%s",var.eks_cluster_name) = "owned"}
         )
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.default_tags,
               {Name = format("%s-%s-igw", var.prefix, var.env)}
         )
}

resource "aws_eip" "this" {
  for_each = var.single_nat_gateway == true ? { "${var.azs[0]}" = true } : { for v in var.azs : v => true }

  # a == true ? { b } : { c }
  # a가 true면 b를 실행 false면 c를 실행
 
  #single_nat_gateway라는 변수(bool값)가 true 이면 첫번째 가용영역에, false면 모든 가용영역에
  #NATGW에 붙여줄 엘라스틱아이피 생성
 
  domain = "vpc"

  tags = merge(local.default_tags,
               {Name = format("%s-%s-ngw-%s-eip", var.prefix, var.env, each.key)}
         )
}

resource "aws_nat_gateway" "this" {
  for_each = var.single_nat_gateway == true ? { "${var.azs[0]}" = true } : { for v in var.azs : v => true }
 
  #var.single_nat_gateway가 true면 왼쪽 아니면 오른쪽
 
  allocation_id = aws_eip.this[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(local.default_tags,
               {Name = format("%s-%s-%s-ngw", var.prefix, var.env, each.key)}
         )
}

resource "aws_route_table" "public" {
  for_each = { for v in var.azs : v => true }

  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.default_tags,
               {Name = format("%s-%s-public-%s-rtb", var.prefix, var.env, each.key)}
         )
}

resource "aws_route_table_association" "public" {
  for_each = { for v in var.azs : v => true }

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public[each.key].id
}

resource "aws_route_table" "private" {
  for_each = { for v in var.azs : v => true }

  vpc_id = aws_vpc.this.id


  dynamic "route" {
    for_each = var.enable_nat_private ? [1] : []

    content {
      cidr_block = "0.0.0.0/0"
      gateway_id = var.single_nat_gateway ? aws_nat_gateway.this[var.azs[0]].id : aws_nat_gateway.this[each.key].id
    }
  }

  tags = merge(local.default_tags, {
    Name = format("%s-%s-private-%s-rtb", var.prefix, var.env, each.key)
  })
}

resource "aws_route_table_association" "private" {
  for_each = { for v in var.azs : v => true }

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_route_table" "database" {
  for_each = { for v in var.azs : v => true }

  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.enable_nat_database ? [1] : []

    content {
      cidr_block = "0.0.0.0/0"
      gateway_id = var.single_nat_gateway ? aws_nat_gateway.this[var.azs[0]].id : aws_nat_gateway.this[each.key].id
    }
  }

  tags = merge(local.default_tags,
               {Name = format("%s-%s-database-%s-rtb", var.prefix, var.env, each.key)}
         )
}

resource "aws_route_table_association" "database" {
  for_each = { for v in var.azs : v => true }

  subnet_id      = aws_subnet.database[each.key].id
  route_table_id = aws_route_table.database[each.key].id
}
