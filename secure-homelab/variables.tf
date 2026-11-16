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

variable "allow" {
  type        = list(object({ port = string, from = optional(string) }))
  default     = []
  description = "Ports to open besides SSH, such as [{ port = \"443/tcp\" }] or [{ port = \"8096/tcp\", from = \"192.168.1.0/24\" }]."
}

variable "in_container" {
  type        = bool
  default     = false
  description = "Leave this false on a real server. conn3x test sets it, because a container shares its host's kernel and network stack: it can't change kernel parameters, set the clock or turn on a firewall, so those parts are left out there."
}

variable "timezone" {
  type        = string
  default     = "UTC"
  description = "IANA time zone, such as \"Europe/Dublin\" or \"America/Denver\"."
}

variable "trusted_networks" {
  type        = list(string)
  default     = []
  description = "Addresses and networks fail2ban never bans, such as [\"192.168.1.0/24\"]. Put your home network here."
}

variable "ssh_allow" {
  type        = list(string)
  default     = null
  description = "Ports sshd listens on, which the firewall keeps open, such as [\"22/tcp\"]. When null, the port Conn3x logs in on. Set it when a port forward or NAT sits between you and the server, so the firewall doesn't close the port sshd really uses."
}
