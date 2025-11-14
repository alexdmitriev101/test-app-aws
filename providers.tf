terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # ← Ключ: v6.0+ (6.20.0 latest)
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}
