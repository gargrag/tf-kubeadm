terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "random_string" "token_id" {
  length  = 6
  special = false
  upper   = false
}

resource "random_string" "token_secret" {
  length  = 16
  special = false
  upper   = false
}

locals {
  token = "${random_string.token_id.result}.${random_string.token_secret.result}"
}

resource "aws_eip" "master" {
  vpc = true
}

resource "aws_eip_association" "master" {
  allocation_id = aws_eip.master.id
  instance_id   = aws_instance.master.id
}


resource "aws_instance" "master" {

  ami             = var.ami
  instance_type   = var.instance_type
  key_name        = aws_key_pair.generated_key.key_name
  security_groups = [aws_security_group.public.name, aws_security_group.private.name]
  credit_specification {
    cpu_credits = "unlimited"
  }

  tags = {
    Name = var.control_plane
  }

  user_data = templatefile(
    "${path.module}/user_data.tftpl",
    {
      node              = "master",
      token             = local.token,
      cidr              = null
      master_public_ip  = aws_eip.master.public_ip,
      master_private_ip = aws_eip.master.private_ip,
      worker_index      = null
    }
  )

}

resource "aws_instance" "node" {

  count           = length(var.node_names)
  ami             = var.ami
  instance_type   = var.instance_type
  key_name        = aws_key_pair.generated_key.key_name
  security_groups = [aws_security_group.public.name, aws_security_group.private.name]

  credit_specification {
    cpu_credits = "unlimited"
  }

  tags = {
    Name = var.node_names[count.index]
  }

  user_data = templatefile(
    "${path.module}/user_data.tftpl",
    {
      node              = "worker",
      token             = local.token,
      cidr              = null
      master_public_ip  = aws_eip.master.public_ip,
      master_private_ip = aws_instance.master.private_ip,
      worker_index      = count.index
    }
  )
}

resource "null_resource" "wait_for_bootstrap_to_finish" {
  provisioner "local-exec" {
    command = <<-EOF
    alias ssh='ssh -q -i ./${var.key_name}.pem -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
    while true; do
      sleep 2
      ! ssh ec2-user@${aws_eip.master.public_ip} [[ -f /home/ec2-user/done ]] >/dev/null && continue
      %{for worker_public_ip in aws_instance.node[*].public_ip~}
      ! ssh ec2-user@${worker_public_ip} [[ -f /home/ec2-user/done ]] >/dev/null && continue
      %{endfor~}
      break
    done
    EOF
  }
  triggers = {
    instance_ids = join(",", concat([aws_instance.master.id], aws_instance.node[*].id))
  }
}

resource "null_resource" "download_kubeconfig_file" {
  provisioner "local-exec" {
    command = <<-EOF
    alias scp='scp -q -i ./${var.key_name}.pem -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
    scp ec2-user@${aws_eip.master.public_ip}:/home/ec2-user/admin.conf ./k8s.conf >/dev/null
    EOF
  }
  triggers = {
    wait_for_bootstrap_to_finish = null_resource.wait_for_bootstrap_to_finish.id
  }
}