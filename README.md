To deploy this project you need:
1. Export AWS credentials
   
export AWS_ACCESS_KEY_ID=""

export AWS_SECRET_ACCESS_KEY=""

export AWS_SESSION_TOKEN=""
3. Apply Terraform

terraform apply

4. When terraform is deployed, you'll get the output with your Cloudfront distribution's endpoints

Examples:

https://d3jtsg5pniku5o.cloudfront.net/api/health - it will check connectivity between backend container to RDS PostgreSQL DB.

https://d3jtsg5pniku5o.cloudfront.net/api/data - just a "hello world" from backend

https://d3jtsg5pniku5o.cloudfront.net/ - "hello world" but from the frontend instance

5. If you want to access project's instances, you just need to use "id_rsa" private key in your local home directory. Project use Amazon Linux OS AMI, so the username for SSH is "ec2-user"

To destroy infrastructure, run:

terraform destroy
