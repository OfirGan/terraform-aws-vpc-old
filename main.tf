##################################################################################
# VPC
##################################################################################

resource "aws_vpc" "vpc" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"

  tags = {
    Name = "${var.purpose_tag}-vpc"
  }
}

##################################################################################
# SUBNETS
##################################################################################

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public_subnets" {
  count                   = var.availability_zones_count
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(aws_vpc.vpc.cidr_block, 8, 1 + count.index)
  availability_zone_id    = data.aws_availability_zones.available.zone_ids[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.purpose_tag}-public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnets" {
  count                = var.availability_zones_count
  vpc_id               = aws_vpc.vpc.id
  cidr_block           = cidrsubnet(aws_vpc.vpc.cidr_block, 8, 101 + count.index)
  availability_zone_id = data.aws_availability_zones.available.zone_ids[count.index]

  tags = {
    Name = "${var.purpose_tag}-private-subnet-${count.index + 101}"
  }
}

##################################################################################
# Gateway
##################################################################################

####################
# Internet Gateway
####################
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.purpose_tag}_internet_gateway"
  }
}

########################
# Internet NAT Gateway
########################

resource "aws_eip" "internet_nat_gateway_eips" {
  count = length(aws_subnet.public_subnets[*].id)
  tags = {
    Name = "${var.purpose_tag}-eip-internet-nat-gateway-${count.index + 1}"
  }

  # EIP may require IGW to exist prior to association. 
  # Use depends_on to set an explicit dependency on the IGW.
  depends_on = [aws_internet_gateway.internet_gateway]
}

resource "aws_nat_gateway" "internet_nat_gateways" {
  count         = length(aws_subnet.public_subnets[*].id)
  allocation_id = aws_eip.internet_nat_gateway_eips[count.index].id
  subnet_id     = aws_subnet.public_subnets[count.index].id

  tags = {
    Name = "${var.purpose_tag}-internet-nat-gateway-${count.index + 1}"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.internet_gateway]
}

##################################################################################
# Rout Tables
##################################################################################

resource "aws_default_route_table" "default_route_table" {
  default_route_table_id = aws_vpc.vpc.default_route_table_id

  tags = {
    Name = "${var.purpose_tag}-default-route-table"
  }
}

##########
# Public
##########

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.purpose_tag}-public-route-table"
  }
}

resource "aws_route" "route_to_internet_gateway" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gateway.id
}


resource "aws_route_table_association" "public_route_table_association" {
  count          = length(aws_subnet.public_subnets[*].id)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}


##########
# Private
##########

resource "aws_route_table" "private_route_tables" {
  count  = var.availability_zones_count
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.purpose_tag}-private-route-table-${count.index + 1}"
  }
}

resource "aws_route" "route_to_internet_nat_gateway" {
  count                  = length(aws_route_table.private_route_tables[*].id)
  route_table_id         = aws_route_table.private_route_tables[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.internet_nat_gateways[count.index].id
}

resource "aws_route_table_association" "private_route_table_association" {
  count          = length(aws_subnet.private_subnets[*].id)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_route_tables[count.index].id
}
