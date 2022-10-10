module "gke_auth" {
  source       = "terraform-google-modules/kubernetes-engine/google//modules/auth"
  version      = "12.3.0"
  project_id   = var.project_id
  cluster_name = var.cluster_name
  location     = var.regionality
}

provider "kubernetes" {
  host                   = module.gke_auth.host
  token                  = module.gke_auth.token
  cluster_ca_certificate = module.gke_auth.cluster_ca_certificate
}

provider "helm" {
  kubernetes {
    load_config_file       = false
    host                   = module.gke_auth.host
    token                  = module.gke_auth.token
    cluster_ca_certificate = module.gke_auth.cluster_ca_certificate
  }
}

data "google_project" "project" {
  project_id = var.project_id
}

data "google_container_cluster" "this_cluster" {
  name     = var.cluster_name
  location = var.regionality
  project  = var.project_id
}

data "google_client_config" "default" {}


resource "local_file" "kubeconfig" {
  content  = module.gke_auth.kubeconfig_raw
  filename = "/tmp/anthos-kubeconfig"
}


resource "null_resource" "tools" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/install_tools.sh /tmp/anthos-kubeconfig"
  }

  depends_on = [local_file.kubeconfig]
}
