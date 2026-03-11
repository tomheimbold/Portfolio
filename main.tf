provider "aws" {
  region = "eu-central-1"
}

data "aws_ami" "ubuntu" {
  most_recent = true
    
  filter {
    name = "name"
    values = ["ubuntu/*-24.04-*"]
}

filter {
  name = "architecture"
  values = ["x86_64"]
}
owners = ["099720109477"]
}

resources "aws_security_group" "allow_all" {
  name_prefix = "allow_all-"
  vpc_id = data.aws.vpc.default.id

    ingress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
}

    egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
}
}

  data "aws_vpc" "default" {
    default = true
}
  resources "aws_instance" "app-server" {
    ami = data.aws_ami.ubuntu.id
}

  instance_type = "t2.micro" #<- Dabei lassen!
  vpc_security_group_ids = [aws_security_group.allow_all.id]
  associate_public_ip_address = true

  tags = {
    Name = "vpn"
}

  user_data = <<-EOF
  #!/usr/bin/env bash

  echo foo > /tmp/bar

  set -ex

  cat >> /home/ubuntu/.ssh/authorized_keys <<KEYS
  ${join("\n", [for f in fileset("${path.module}/ssh-keys", "*.pub") : file("${path.module}/ssh-keys/${f}")])}KEYS

  # Neueste Paketdatenbanken holen
  apt update

  # Sicherheitshalber alle Programme auf den neuesten Stand bringen
  apt dist-upgrade -y

  # Wireguard installieren
  apt install -y wireguard

  # Schlüsselpaar erzeugen
  vpnpriv=$(wg genkey)
  vpnpub=$(echo "$vpnpriv" | wg pubkey)

  # Wireguard Interface aktivieren
  ip link add wg0 type wireguard
  ip link set wg0 up

  # Eigene IP-Adresse innerhalb des VPN festlegen
  ip addr add 192.168.0.1/24 dev wg0

  # Wireguard anweisen, auf Port 51820 auf eingehende VPN-Pakete zu lauschen
  wg set wg0 listen-port 51280

  # Wireguard den eigenen privaten Schlüssel bekannt machen
  wg set wg0 private-key <(echo "$vpnpriv")

  # Wireguard einen Peer bekannt machen
  wg set wg0 peer ${trimspace(file("vpn-keys/tom.pub"))} allowed-ips 192.168.0.2/32 

  # Öffentliches Serverschloss an mein Handy per NTFY schicken
  curl -s -d "Server läuft"
             "IP: $(curl ifconfig.me)"
             "öffentliches Schloss: $vpnpub" https://ntfy.sh/Portfolio-Server 
