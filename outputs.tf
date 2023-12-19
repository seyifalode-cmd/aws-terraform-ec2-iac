#-----outputs.tf-----
#====================
output "Jenkins-Node-Public-IP" {
  value = module.compute.node_ip
}

