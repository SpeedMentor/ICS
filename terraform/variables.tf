variable "project_id"{
  type = string
  default = ""
}

variable "region"{
  type = string
  default = "europe-west3"
}

variable "zone"{
  type = string
  default = "europe-west3-b"
}

variable "network"{
  type = string
  default = "devops-net"
}

variable "subnet"{
  type = string
  default = "devops-subnet"
}

variable "cluster_name"{
  type = string
  default = "devops-gke"
}

variable "node_count"{
  type = number
  default = 3
}

variable "node_type"{
  type = string
  default = "e2-standard-4"
} # 4 vCPU, 16GB
