#-----compute/outputs.tf-----
#=============================

output "node_id" {
  value =  aws_instance.java_build.id
}

output "node_ip" {
  value = aws_instance.java_build.public_ip
}

output "node_private_ip" {
  value = aws_instance.java_build.private_ip
}

