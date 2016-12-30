#!/usr/bin/env bash
#
# Purpose: Create a Swarm Mode cluster with a reverse Nginx proxy.ingle master and a configurable
#
# This script is a mirror of the following gist, which is used to
# populate a Medium story. Unfortunately, there's no way to synchronize all
# three
#
# Medium:
# Gist:
#
# This script uses a slightly opinionated, pre-configured Consult Agent that was
# created specifically to work in the Docker ecosystem:
# https://hub.docker.com/r/progrium/consul/

# Set global environment variables
private_workers=${WORKERS:-"worker01 worker02 worker03 worker04"}
public_workers=public01
consul_worker=consul
swarm_manager=manager01
driver=virtualbox
swarm_port=2376

# Create the key value node using Consul
docker-machine create $consul_worker -d $driver

#TODO: Check if the container is already running
docker-machine ssh $consul_worker docker run -d -p "8500:8500" -h \
    "${consul_worker}" progrium/consul -server -bootstrap

CONSUL_IP=$(docker-machine ip $consul_worker)
CONSUL_ADDR="consul://${CONSUL_IP}:8500"

echo $CONSUL_IP
echo $CONSUL_ADDR

# Create the Swarm Manager
docker-machine create $swarm_manager -d $driver --swarm --swarm-master \
    --swarm-discovery=$CONSUL_ADDR --engine-opt="cluster-store=${CONSUL_ADDR}" \
    --engine-opt="cluster-advertise=eth0:${swarm_port}"

# Create the public facing Swarm workers(s)
for node in $public_workers; do
    (
    echo "Creating ${node}"

    docker-machine create $node -d $driver --swarm \
        --swarm-discovery=$CONSUL_ADDR \
        --engine-opt="cluster-store=${CONSUL_ADDR}" \
        --engine-opt="cluster-advertise=eth0:${swarm_port}"

    ) &
done
wait

# Create the private facing Swarm workers(s)
for node in $private_workers; do
    (
    echo "Creating ${node}"

    docker-machine create $node -d $driver --swarm \
        --swarm-discovery=$CONSUL_ADDR \
        --engine-opt="cluster-store=${CONSUL_ADDR}" \
        --engine-opt="cluster-advertise=eth0:${swarm_port}"

    ) &
done
wait

# Print Cluster Information
echo ""
echo "CLUSTER INFORMATION"
echo "Consul UI: http://${KV_IP}:8500"
echo "Use these settings to connect through the Docker CLI."
docker-machine env --swarm manager

#
## Creates a local Docker Machine VM
## Arguments:
##   $1: the name of the Docker Machine
#create_machine() {
#  docker-machine create \
#    -d virtualbox \
#    $1
#}
#
## Function to save configuration loading while we switch Docker Machine
## environment variables
## Arguments:
##   $@: the Docker engine commmand that we'll load into the configuration
#swarm_master() {
#  docker $master_conf $@
#}
#
## The body of our script
#main() {
##
#  if [ -z "$WORKERS" ]; then
#    echo "Using default $workers. Set \$WORKERS environment variable to alter."
#  fi
#
#  # Create your master node
#  echo "Creating master node"
#  create_machine $master
#
#  # Derive useful variables for Swarm setup
#  master_ip=$(docker-machine ip ${master})
#  master_conf=$(docker-machine config ${master})
#
#  # Initialize the swarm mode
#  echo "Initializing the swarm mode"
#  swarm_master swarm init --advertise-addr $master_ip
#
#  # Obtain the worker token
#  worker_token=$(docker ${master_conf} swarm join-token -q worker)
#  echo "Worker token: ${worker_token}"
#
#  # Create and join the workers
#  for worker in $workers; do
#    echo "Creating worker ${worker}"
#    create_machine $worker &
#  done
#  wait
#  for worker in $workers; do
#    worker_conf=$(docker-machine config ${worker})
#    echo "Node $worker information:"
#    docker $worker_conf swarm join --token $worker_token $master_ip:$swarm_port
#  done
#
## Dsplay the cluster info
#echo "====================="
#echo "Cluster information"
#echo "Discovery token: ${worker_token}"
#echo "====================="
#echo "Swarm manager setup:"
#docker-machine env $master
#echo "====================="
#echo "Docker Machine cluster status"
#docker-machine ls
#echo "====================="
#echo "Docker Swarm node status"
#swarm_master node ls
#
#}
#main $@
#
