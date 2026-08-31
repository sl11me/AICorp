terraform {
  backend "s3" {
    bucket       = "aicorp-tfstate-794449909076"
    key          = "bootstrap/terraform.tfstate"
    region       = "eu-west-3"
    encrypt      = true
    kms_key_id   = "arn:aws:kms:eu-west-3:794449909076:key/8e57fd30-73fa-41ee-9c8b-0201a3751831"
    use_lockfile = true
  }
}
