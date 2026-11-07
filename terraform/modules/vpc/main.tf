locals {
  az_count = length(var.availability_zones) nat_count = min(var.nat_gateway_count, length(var.availability_zones))
}
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = merge(var.tags, {
  Name = "${var.name}-vpc"
})
}
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = merge(var.tags, {
  Name = "${var.name}-igw"
})
}
resource "aws_subnet" "public" {
  count = local.az_count
  vpc_id = aws_vpc.this.id
  cidr_block = var.public_subnets[count.index]
  availability_zone = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags = merge(var.tags, {
  Name = "${var.name}-public-${count.index + 1}", "kubernetes.io/role/elb" = "1"
})
}
resource "aws_subnet" "private" {
  count = local.az_count
  vpc_id = aws_vpc.this.id
  cidr_block = var.private_subnets[count.index]
  availability_zone = var.availability_zones[count.index]
  tags = merge(var.tags, {
  Name = "${var.name}-private-${count.index + 1}", "kubernetes.io/role/internal-elb" = "1"
})
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
  cidr_block = "0.0.0.0/0" gateway_id = aws_internet_gateway.this.id
}
  tags = merge(var.tags, {
  Name = "${var.name}-public-rt"
})
}
resource "aws_route_table_association" "public" {
  count = local.az_count
  subnet_id = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
resource "aws_eip" "nat" {
  count = local.nat_count
  domain = "vpc"
  tags = merge(var.tags, {
  Name = "${var.name}-nat-eip-${count.index + 1}"
})
}
resource "aws_nat_gateway" "this" {
  count = local.nat_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id = aws_subnet.public[count.index].id
  depends_on = [aws_internet_gateway.this]
  tags = merge(var.tags, {
  Name = "${var.name}-nat-${count.index + 1}"
})
}
resource "aws_route_table" "private" {
  count = local.az_count
  vpc_id = aws_vpc.this.id
  dynamic "route" {
    for_each = local.nat_count == 0 ? [] : [1]
    content {
      cidr_block = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.this[min(count.index, local.nat_count - 1)].id
   
}
 
}
  tags = merge(var.tags, {
  Name = "${var.name}-private-rt-${count.index + 1}"
})
}
resource "aws_route_table_association" "private" {
  count = local.az_count
  subnet_id = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
