terraform {
  # Empty block to initialize Terraform
}

output "test_template" {
  value = templatefile("${path.module}/simple_template.tftpl", {
    github_token    = "test-token"
    github_repo_url = "https://github.com/example/repo"
  })
}
