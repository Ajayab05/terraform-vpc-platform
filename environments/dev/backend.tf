terraform {

  backend "s3" {

    bucket         = "ajay-tf-state-prod"
    key            = "networking/prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}