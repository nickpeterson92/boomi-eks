terraform {
  backend "s3" {
    bucket         = "bolts-tfstate"
    key            = "boomi-eks/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "tf-lock-table"
    encrypt        = true
  }
}

