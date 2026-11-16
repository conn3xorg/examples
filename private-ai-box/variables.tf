variable "hosts" {
  type        = any
  description = "The servers to configure, by name. Each value is an address, such as \"203.0.113.10\", or a host object such as { address = \"203.0.113.10\", host_key = \"ssh-ed25519 AAAA...\" }."
}

variable "ssh_user" {
  type        = string
  default     = "root"
  description = "The user to log in as."
}

variable "ssh_port" {
  type        = number
  default     = 22
  description = "The SSH port."
}

variable "ssh_private_key_file" {
  type        = string
  default     = null
  description = "Path to a private key. When null, Conn3x uses the SSH agent."
}

variable "ssh_known_hosts_file" {
  type        = string
  default     = null
  description = "The known_hosts file to check host keys against. When null, ~/.ssh/known_hosts."
}

variable "ssh_become" {
  type        = bool
  default     = false
  description = "Run every command as root through sudo. Set it when ssh_user isn't root."
}

variable "models" {
  type        = list(string)
  default     = ["qwen2.5:0.5b", "nomic-embed-text"]
  description = "Models to pull from the Ollama library: a small chat model and an embedding model by default."
}

variable "qdrant_api_key" {
  type        = string
  sensitive   = true
  description = "Key every Qdrant request must send in an api-key header, at least 16 characters. Pass it with TF_VAR_qdrant_api_key."
}
