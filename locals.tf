locals {
  env    = "test"
  region = "eu-west-1"

  app_instances = {
    "frontend-1" = {
      role          = "frontend"
      instance_type = "t3.micro"
      subnet_key    = 0
    }
    "frontend-2" = {
      role          = "frontend"
      instance_type = "t3.micro"
      subnet_key    = 1
    }
    "backend-1" = {
      role          = "backend"
      instance_type = "t3.small"
      subnet_key    = 0
    }
  }

  frontend_instances = {
    for k, v in local.app_instances : k => v
    if v.role == "frontend"
  }
}
