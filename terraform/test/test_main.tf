terraform {
  required_version = ">= 0.12"
}

variable "github_token" {
  description = "GitHub token for testing"
  default     = "test-token"
}

variable "github_repo_url" {
  description = "GitHub repo URL for testing"
  default     = "test-url"
}

output "rendered_template" {
  value = templatefile("${path.module}/test_template.tftpl", {
    github_token    = var.github_token
    github_repo_url = var.github_repo_url
  })
}
