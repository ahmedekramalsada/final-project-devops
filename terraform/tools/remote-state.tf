data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  config = {
    bucket = "backend-s3-final-project"
    key    = "infra/terraform.tfstate"
    region = "us-east-1"
  }
}
