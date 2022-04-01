#!/bin/bash

#1. Add administrator login
####
if [[ $1 == *'dev'* ]]
then
    rabbitmqctl add_user admin admin
    rabbitmqctl set_user_tags admin administrator
    rabbitmqctl set_permissions -p / admin '.*' '.*' '.*'
elif [[ $1 == *'sit'* ]]
	rabbitmqctl add_user admin dp89mJD57sQQ
	rabbitmqctl set_user_tags admin administrator
	rabbitmqctl set_permissions -p / admin '.*' '.*' '.*'
	rabbitmqctl add_user Developer Password
	rabbitmqctl set_user_tags Developer monitoring
	rabbitmqctl set_permissions -p / Developer '.*' '.*' '.*'
then
elif [[ $1 == *'pp'* ]]
	rabbitmqctl add_user admin dp89mJD57sQQ
	rabbitmqctl set_user_tags admin administrator
	rabbitmqctl set_permissions -p / admin '.*' '.*' '.*'
	rabbitmqctl add_user Developer Password
	rabbitmqctl set_user_tags Developer monitoring
	rabbitmqctl set_permissions -p / Developer '.*' '.*' '.*'
    then
fi

################################
# Add API Users
################################

pwd='Testuser'
for user in 'VerificationAPI verification' 'AccountingAPI accounting' 'AnalyticsAPI analytics' 'AuthenticationAPI authentication' 'AuthorisationAPI authorisation' 'DealsAPI deals' 'QuotesAPI quotes' 'RefDataAPI refdata' 'UserAPI user' 'BeneficiaryAPI beneficiary' 'MobileAPI mobile' 'PublicSiteAPI publicsite' 'DocumentationAPI documentation' 'NotificationAPI notification' 'LocalizationAPI localization' 'ETailingAPI etailing' 'LoggingAPI logging' 'ReconciliationAPI reconciliation'
do
   set $user
   rabbitmqctl delete_user $1
   rabbitmqctl add_user $1 $pwd
   rabbitmqctl set_user_tags $1 API
   rabbitmqctl set_permissions -p / $1 '.*' '.*' '.*'
   rabbitmqctl set_policy queue_expiry 'authorisationofx:mq:AttributeRequest.outq' '{expires:1}' --priority 1 --apply-to queues
done

################################
# Configure RabbitMQ limits.conf
################################

cat << LIMITS > /etc/security/limits.d/rabbitmq.conf
rabbitmq  hard  nofile  512000
rabbitmq  soft  nofile  512000
LIMITS

################################
# Configure RabbitMQ TCP settings
################################

cat << TCP >> /etc/sysctl.conf
fs.file-max = 512000
net.ipv4.tcp_keepalive_probes=3
net.ipv4.tcp_keepalive_intvl=3
net.ipv4.tcp_keepalive_time=30
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_tw_reuse =1
net.core.somaxconn = 4096
TCP