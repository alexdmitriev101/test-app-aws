output "cloudfront_url" {
  value = "https://${aws_cloudfront_distribution.cdn.domain_name}"
}

output "ec2_ips" {
  value = { for k, v in module.ec2 : k => v.public_ip }
}
