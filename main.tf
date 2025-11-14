provider "aws" {
  region = local.region
}

data "aws_ami" "image" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# =============================== VPC ====================================

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.9.0"

  name = "${local.env}-vpc"
  cidr = "10.0.0.0/16"

  azs              = ["${local.region}a", "${local.region}b"]
  public_subnets   = ["10.0.101.0/24", "10.0.102.0/24"]
  private_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]

  enable_nat_gateway      = false
  map_public_ip_on_launch = true

  default_security_group_ingress = [
    { from_port = 80, to_port = 80, protocol = "tcp", cidr_blocks = "0.0.0.0/0" },
    { from_port = 443, to_port = 443, protocol = "tcp", cidr_blocks = "0.0.0.0/0" },
    { from_port = 5000, to_port = 5000, protocol = "tcp", cidr_blocks = "0.0.0.0/0" },
  ]

  default_security_group_egress = [
    { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = "0.0.0.0/0" }
  ]

  tags = { Environment = local.env }
}

# =============================== RDS ====================================

resource "aws_db_subnet_group" "main" {
  name       = "${local.env}-db-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_security_group" "rds_sg" {
  name   = "${local.env}-rds-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.vpc.default_security_group_id]
  }

  tags = { Name = "${local.env}-rds-sg" }
}

resource "aws_db_instance" "postgres" {
  identifier           = "${local.env}-db"
  engine               = "postgres"
  engine_version       = "15.15"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  storage_type         = "gp3"
  username             = "app"
  password             = random_password.db_password.result
  db_name              = "appdb"

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  publicly_accessible    = false
  skip_final_snapshot    = true

  tags = { Name = "${local.env}-postgres" }
}

resource "random_password" "db_password" {
  length  = 16
  special = false
}

resource "aws_key_pair" "deployer" {
  key_name   = "${local.env}-deployer-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_security_group_rule" "ssh_inbound" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.vpc.default_security_group_id
}

module "ec2" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "6.1.4"

  for_each = local.app_instances

  name                   = "${local.env}-${each.value.role}-${each.key}"
  instance_type          = each.value.instance_type
  ami                    = data.aws_ami.image.id
  subnet_id              = module.vpc.public_subnets[each.value.subnet_key]
  vpc_security_group_ids = [module.vpc.default_security_group_id]
  key_name               = aws_key_pair.deployer.key_name
  associate_public_ip_address = true

  user_data = each.value.role == "frontend" ? templatefile("${path.module}/user_data/nginx.sh", {
    docker_compose = file("${path.module}/docker-compose.yml")
    html_content   = file("${path.module}/html/index.html")
    env            = local.env
  }) : each.value.role == "backend" ? templatefile("${path.module}/user_data/backend.sh", {
    DB_PASSWORD = aws_db_instance.postgres.password
    DB_HOST     = aws_db_instance.postgres.address
    ENV         = local.env
    local       = local.env  # ← КЛЮЧ: ПЕРЕДАЁМ local!
  }) : null

  tags = {
    Role        = each.value.role
    Environment = local.env
  }
}

resource "time_sleep" "wait_ec2" {
  depends_on = [module.ec2]
  create_duration = "60s"
}

resource "aws_cloudfront_distribution" "cdn" {
  # --- FRONTEND ORIGIN ---
  origin {
    domain_name = module.ec2["frontend-1"].public_dns
    origin_id   = "EC2Frontend"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # --- BACKEND ORIGIN ---
  origin {
    domain_name = module.ec2["backend-1"].public_dns
    origin_id   = "EC2Backend"

    custom_origin_config {
      http_port              = 5000
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${local.env}-cdn"
  default_root_object = "index.html"

  # --- DEFAULT: FRONTEND ---
  default_cache_behavior {
    target_origin_id       = "EC2Frontend"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
  }

  # --- /api/* → BACKEND ---
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "EC2Backend"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0

    forwarded_values {
      query_string = true
      headers      = ["*"]
      cookies { forward = "all" }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = { Environment = local.env }

  depends_on = [time_sleep.wait_ec2]
}
