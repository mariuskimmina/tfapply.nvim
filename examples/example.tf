# Example Terraform file for testing tfapply.nvim

terraform {
  required_version = ">= 1.0"
}

# Example resource - position cursor here and run :TfApplyHover
resource "null_resource" "example" {
  triggers = {
    timestamp = timestamp()
  }

  provisioner "local-exec" {
    command = "echo 'Hello from tfapply.nvim!'"
  }
}

# Example data source
data "null_data_source" "values" {
  inputs = {
    name  = "example"
    value = "test"
  }
}

# Example module
module "example" {
  source = "./modules/example"

  name = "test-module"
}

# Multiple resources for testing :TfApplyFile
resource "null_resource" "first" {
  triggers = {
    id = "1"
  }
}

resource "null_resource" "second" {
  triggers = {
    id = "2"
  }
}

resource "null_resource" "third" {
  triggers = {
    id = "3"
  }
}
