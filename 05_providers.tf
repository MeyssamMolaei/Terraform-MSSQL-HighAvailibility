terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.18"
    }
  }
}

provider "docker" {
  host = "tcp://192.168.1.179:2375"
}
