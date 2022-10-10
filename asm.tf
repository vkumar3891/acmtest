# Forking "terraform-google-modules/kubernetes-engine/google//modules/asm" due to many customizations required

resource "null_resource" "asm" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/asm/asm.sh /tmp/anthos-kubeconfig ${var.project_id} ${var.cluster_name} ${var.cluster_short_name} ${var.regionality}"
  }

  depends_on = [local_file.kubeconfig, module.hub, null_resource.tools]
}

data "google_secret_manager_secret_version" "" {
  count  = var._enabled ? 1 : 0
  secret = "${var.clustershortname}-"
}

resource "helm_release" "asm-post-install-config" {
  name  = "post-install-config"
  chart = "${path.module}/scripts/"

  namespace        = "istio-system"
  create_namespace = false

  values = [
    templatefile("${path.module}/scripts/asm/post-install-config/values.template.yaml", {
      CLUSTER_SHORT_NAME        = var.cluster_short_name,
      REGIONALITY               = var.regionality,
      ENV                       = local.dnszone_identifier,
      TOP_LEVEL_DOMAIN_NAME     = var.top_level_domain_name,
      }
    )
  ]

  depends_on = [null_resource.asm]
}
