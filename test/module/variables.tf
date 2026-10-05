# Copyright 2026 The CAPTF Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Contract inputs of the cluster role, v1alpha1 (docs/book/src/module-author/contract/v1alpha1:
# common.md and cluster.md). The controller sets every one; the no-op module
# records them in terraform_data so a plan shows what it was given.

variable "captf_contract" {
  type = string
}

variable "captf_cluster" {
  type = object({
    name      = string
    namespace = string
  })
}

variable "captf_object" {
  type = object({
    kind      = string
    name      = string
    namespace = string
  })
}

# No captf_cluster_outputs: the cluster role never receives it (see the
# contract CHANGELOG). The skeleton's defaulted declaration is optional.

variable "captf_tags" {
  type = map(string)
}

variable "control_plane_endpoint" {
  type = object({
    host = string
    port = number
  })
  default = null
}

variable "kubernetes_version" {
  type    = string
  default = null
}

variable "control_plane_initialized" {
  type = bool
}

variable "cluster_network" {
  type = object({
    pods            = optional(list(string), [])
    services        = optional(list(string), [])
    service_domain  = optional(string)
    api_server_port = optional(number)
  })
  default = null
}
