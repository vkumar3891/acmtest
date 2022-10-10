locals {
  env_dns_mapping = {
    "ssvcs"   = "prod"
    "dev"     = "dev"
    "cert"    = "cert"
    "prod"    = "prod"
    "certpci" = "cert"
    "prodpci" = "prod"
  }

  env_resources_mapping = {

    <env> = {
      "us-central1" = {
        "gatekeeper_controller_memory_limit"                         = "2Gi"
        "gatekeeper_controller_cpu_limit"                            = "2"
        "gatekeeper_controller_memory_request"                       = "2Gi"
        "gatekeeper_controller_cpu_request"                          = "2"
        "gatekeeper_audit_memory_limit"                              = "2Gi"
        "gatekeeper_audit_cpu_limit"                                 = "3"
        "gatekeeper_audit_memory_request"                            = "2Gi"
        "gatekeeper_audit_cpu_request"                               = "3"
        "config_management_system_reconciler_manager_memory_limit"   = "500Mi"
        "config_management_system_reconciler_manager_cpu_limit"      = "1"
        "config_management_system_reconciler_manager_memory_request" = "100Mi"
        "config_management_system_reconciler_manager_cpu_request"    = "200m"
        "reconciler_cpu_limit"                                       = "1500m"
        "reconciler_memory_limit"                                    = "1500Mi"
        "git_sync_cpu_limit"                                         = "1500m"
        "git_sync_memory_limit"                                      = "1500Mi"
        "gomaxprocs"                                                 = "2"
        "gatekeeper_controller_replicas"                             = "2"
      }
    }


  env_exempted_lb_ns_mapping = {
    dev = {
      "namespace_list" = []

    }
  }

  env_extlb_namespaces_mapping = {
    dev = {
      "namespace_list" = [""]
    }
    }

  env_extlb_namespaces_identifier         = lookup(local.env_extlb_namespaces_mapping, var.environment, "dev")["namespace_list"]
  env_exempted_lb_ns_identifier           = lookup(local.env_exempted_lb_ns_mapping, var.environment, "dev")["namespace_list"]
  dnszone_identifier                      = lookup(local.env_dns_mapping, var.environment, "dev")
  policy_controller_exemptable_namespaces = []

  gatekeeper_audit_memory_request                            = lookup(local.env_resources_mapping, var.project_id, "<cluster-name>")[var.regionality]["gatekeeper_audit_memory_request"]


  monitoring_gatekeeper_pods_count = "1"
  audit_gatekeeper_pods_count      = "1"
  gatekeeper_ns_pods_list          = [local.monitoring_gatekeeper_pods_count, local.audit_gatekeeper_pods_count, local.gatekeeper_controller_replicas]
  gatekeeper_ns_pods_list_sum      = length(flatten([for e in local.gatekeeper_ns_pods_list : range(e)]))
}

variable "cluster_name" {}
variable "cluster_short_name" {}

variable "gitea_namespace" {
  default     = "giteaserver"
  description = "Gitea - git server name"
}

variable "deploy_project_wide_resources" {
  type        = bool
  default     = false
  description = "Whether to deploy project wide resources, it has to be true for first deployment within project, and false for remaining"
}

variable "internal_ingress_self_signed" {
  type        = bool
  default     = true
  description = "Whether the TLS certificate should be taken from GCP Secret or it is SelfSigned certificate from git repository"
}

variable "c3g_ingress_enabled" {
  type        = bool
  default     = false
  description = "Defining this Variable will trigger deploymet of C3G Gateway"
}

variable "top_level_domain_name" {
  default     = ""
  description = "Top level domain name"
}

variable "gcloud_path_command" {
  default     = "/var/lib/awx/venv/SabreAutomation/google-cloud-sdk/bin/gcloud"
  description = "gcloud command path on underlying system, if bare gcloud is working, chaning it requires ticket to CloudOps to fix TF state files, high risk"
}

variable "external_ingress_enabled" {
  type        = bool
  default     = false
  description = "Whether to expose external facin Gateway "
}

variable "constrainttemplates_dict" {
  type    = string
  default = "k8s_restrict_gvisor: k8srestrictgvisor,k8s_restrict_load_balancer: k8srestrictloadbalancer,k8s_allowed_role_binding_subjects: k8sallowedrolebindingsubjects,k8s_virtual_service_gateway_host_match_regex: k8svirtualservicegatewayhostmatchregex,k8s_virtual_service_unique_host_match: k8svirtualserviceuniquehostmatch,pdb_max_unavailable: pdbmaxunavailable,pdb_no_selector: pdbnoselector,k8s_debug: k8sdebug,k8s_psp_hostname_space: k8spsphostnamespace,k8s_psp_host_networking_ports: k8spsphostnetworkingports,k8s_psp_privileged_container: k8spspprivilegedcontainer,k8s_psp_capabilities: k8spspcapabilities,k8s_psp_fsgroup: k8spspfsgroup,k8s_psp_volume_types: k8spspvolumetypes,k8s_no_external_service: k8snoexternalservices,scf_group_enforcement: scfgroupenforcement"
}

variable "gatekeeper_monitoring_account_id" {
  type    = string
  default = "gatekeeper-monitoring-sa"
}

# These variables are populated by SNOW but must still be declared
variable "project_id" {}
variable "business_unit" {}
variable "contact_email" {}
variable "environment" {}
variable "owner" {}
variable "regionality" {}
