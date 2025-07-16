#!/bin/bash

# define ANSI colors
COLOR_PRIMARY=$(tput setaf 4)      # Blue
COLOR_SECONDARY=$(tput setaf 6)    # Cyan
COLOR_HAPROXY=$(tput setaf 5)      # Magenta
COLOR_VOLUME1=$(tput setaf 3)      # Yellow
COLOR_VOLUME2=$(tput setaf 1)      # Red
COLOR_SETUP_PRIMARY=$(tput setaf 2)  # Green
COLOR_SETUP_SECONDARY=$(tput setaf 10) # Light green
COLOR_NETWORK=$(tput setaf 7)      # White
COLOR_RESET=$(tput sgr0)

#null_resource.setup_primary

terraform destroy -auto-approve
terraform plan
#terraform apply -auto-approve | sed -E \
#  -e 's/(docker_container\.mssql_primary)/\x1b[34m\1\x1b[0m/' \
#  -e 's/(null_resource\.setup_primary)/\x1b[34m\1\x1b[0m/' \  
#  -e 's/(docker_container\.mssql_secondary)/\x1b[38m\1\x1b[0m/' \
#  -e 's/(null_resource\.setup_secondary)/\x1b[38m\1\x1b[0m/' \      
#  -e 's/(docker_container\.haproxy)/\x1b[35m\1\x1b[0m/' \
#  -e 's/(aws_instance\.web)/\x1b[32m\1\x1b[0m/'


ESC=$(printf '\033')
RESET="${ESC}[0m"

terraform apply -auto-approve 2>&1 | sed -E \
  -e "s/(docker_container\.mssql_primary)/${ESC}[34m\1${RESET}/g" \
  -e "s/(null_resource\.setup_primary)/${ESC}[34m\1${RESET}/g" \
  -e "s/(docker_container\.mssql_secondary)/${ESC}[36m\1${RESET}/g" \
  -e "s/(null_resource\.setup_secondary)/${ESC}[36m\1${RESET}/g" \
  -e "s/(docker_container\.haproxy)/${ESC}[35m\1${RESET}/g" \
  -e "s/(aws_instance\.web)/${ESC}[32m\1${RESET}/g"

