#!/bin/bash
#
# Run the provisioning Wordpress Ressources.

# check the  prerequisites
[[ ! -x "$(which terraform)" ]] && echo "Couldn't find terraform in your PATH. Please see https://www.terraform.io/downloads.html" && exit 1
[[ ! -x "$(which curl)" ]] && echo "Couldn't find curl in your PATH." && exit 1
[[ ! -x "$(which ssh)" ]] && echo "Couldn't find ssh in your PATH." && exit 1
[[ ! -x "$(which ssh-keygen)" ]] && echo "Couldn't find ssh-keygen in your PATH." && exit 1

if [[ "$1" == "" || "$2" == "" ]]; then
	echo "Usage: $0 <aws_access_key> <aws_secret_key>"
	exit 1
fi

# Generate the SSH key pair, if it doesn't exist
if [[ ! -f "id_rsa_wp" ]]; then
	echo "Generating 4096-bit RSA SSH key pair. This can take a few seconds."
	ssh-keygen -t rsa -b 4096 -f id_rsa_wp -N ""
fi

# Grab our external IP for SSH Access  security groups
MANAGEMENT_IP=$(curl -s http://ipinfo.io/ip)
[[ ! "$MANAGEMENT_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && echo "Couldn't determine your external IP: $MANAGEMENT_IP" && exit 1

# Run terraform to create the resources
terraform apply -var 'aws_access_key='"$1"'' -var 'aws_secret_key='"$2"'' -var "management_ip=$MANAGEMENT_IP"

# Configure wp database access for wordpress
ssh -i id_rsa_wp  ec2-user@$(terraform output wp01-instance_ip) "echo 'Wordpress on wp01 isAlive'"
ssh -i id_rsa_wp  ec2-user@$(terraform output wp02-instance_ip) "echo 'Wordpress on wp02 isAlive'"

ssh -i id_rsa_wp  ec2-user@$(terraform output wp01-instance_ip) "sudo sh chef/wp-db-configure.sh '$(terraform output rds-uri)'"
ssh -i id_rsa_wp  ec2-user@$(terraform output wp02-instance_ip) "sudo sh chef/wp-db-configure.sh '$(terraform output rds-uri)'"
# Verify that the load balancer works as expected
echo "${RED} Provisioning complete: test please application from elb DNS name : lb-dns "
echo -e '\E[37;44m'"\033[1mProvisioning complete: test please application from elb DNS name : $(terraform output lb-dns) \033[0m"
