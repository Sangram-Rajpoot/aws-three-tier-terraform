locals {
  az_map = { for index, az in var.availability_zones : az => index }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = "${var.name}-vpc" })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "${var.name}-igw" })
}

resource "aws_subnet" "public" {
  for_each = local.az_map

  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.key
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value)
  map_public_ip_on_launch = true

  tags = merge(var.tags, { Name = "${var.name}-public-${each.key}", Tier = "public" })
}

resource "aws_subnet" "web" {
  for_each = local.az_map

  vpc_id            = aws_vpc.main.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 10 + each.value)

  tags = merge(var.tags, { Name = "${var.name}-web-${each.key}", Tier = "web" })
}

resource "aws_subnet" "app" {
  for_each = local.az_map

  vpc_id            = aws_vpc.main.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 20 + each.value)

  tags = merge(var.tags, { Name = "${var.name}-app-${each.key}", Tier = "application" })
}

resource "aws_subnet" "database" {
  for_each = local.az_map

  vpc_id            = aws_vpc.main.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 30 + each.value)

  tags = merge(var.tags, { Name = "${var.name}-db-${each.key}", Tier = "database" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "${var.name}-public-rt" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  count = var.single_nat_gateway ? 1 : length(var.availability_zones)

  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name}-nat-eip-${count.index + 1}" })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count = var.single_nat_gateway ? 1 : length(var.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[var.availability_zones[count.index]].id
  tags          = merge(var.tags, { Name = "${var.name}-nat-${count.index + 1}" })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "web" {
  for_each = local.az_map
  vpc_id   = aws_vpc.main.id
  tags     = merge(var.tags, { Name = "${var.name}-web-rt-${each.key}" })
}

resource "aws_route" "web_nat" {
  for_each = local.az_map

  route_table_id         = aws_route_table.web[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[var.single_nat_gateway ? 0 : each.value].id
}

resource "aws_route_table_association" "web" {
  for_each = local.az_map

  subnet_id      = aws_subnet.web[each.key].id
  route_table_id = aws_route_table.web[each.key].id
}

resource "aws_route_table" "app" {
  for_each = local.az_map
  vpc_id   = aws_vpc.main.id
  tags     = merge(var.tags, { Name = "${var.name}-app-rt-${each.key}" })
}

resource "aws_route" "app_nat" {
  for_each = local.az_map

  route_table_id         = aws_route_table.app[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[var.single_nat_gateway ? 0 : each.value].id
}

resource "aws_route_table_association" "app" {
  for_each = local.az_map

  subnet_id      = aws_subnet.app[each.key].id
  route_table_id = aws_route_table.app[each.key].id
}

resource "aws_route_table" "database" {
  for_each = local.az_map
  vpc_id   = aws_vpc.main.id
  tags     = merge(var.tags, { Name = "${var.name}-db-rt-${each.key}" })
}

resource "aws_route_table_association" "database" {
  for_each = local.az_map

  subnet_id      = aws_subnet.database[each.key].id
  route_table_id = aws_route_table.database[each.key].id
}
