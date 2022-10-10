terraform {
  required_version = "~> 0.12.29"
  required_providers {
    google = {
      version = "~> 3.45.0"
    }
    kubernetes = {
      version = "~> 2.0.2"
    }
    helm = {
      version = "~> 1.3.2"
    }
    external = {
      version = "~> 2.1.1"
    }
  }
}
