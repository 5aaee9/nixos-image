variable "accelerator" {
    type    = string
    default = "kvm"
}

variable "disk_size" {
    type    = string
    default = "4096M"
}

variable "uefi" {
  type    = string
  default = "no"
}

variable "qemu_args" {
  type    = list(string)
  default = ["-boot", "d"]
}

variable "display" {
    type    = string
    default = "gtk"
}

variable "headless" {
    type    = string
    default = "false"
}

locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }

source "qemu" "nixos" {
    accelerator              = "${var.accelerator}"
    boot_command             = [
      "<enter><wait60>", "sudo su<enter>cd ~<enter>",
      "curl http://{{ .HTTPIP }}:{{ .HTTPPort }}/install.sh -o install.sh<enter><wait2s>",
      "UEFI_BUILD=\"${var.uefi}\" bash install.sh<enter>"
    ]
    boot_wait                = "3s"
    disk_compression         = true
    disk_size                = "${var.disk_size}"
    display                  = "${var.display}"
    format                   = "raw"
    headless                 = "${var.headless}"
    http_directory           = "http"
    iso_checksum             = "none"
    iso_urls                 = ["https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-x86_64-linux.iso"]
    memory                   = 2048
    qemuargs                 = [var.qemu_args]
    shutdown_command         = "shutdown -P now"
    ssh_file_transfer_method = "scp"
    ssh_handshake_attempts   = "1000"
    ssh_password             = "packer"
    ssh_timeout              = "90m"
    ssh_username             = "root"
}

build {
    sources = ["source.qemu.nixos"]

    provisioner "shell" {
        inline = ["nixos-install --no-root-passwd"]
    }
}
