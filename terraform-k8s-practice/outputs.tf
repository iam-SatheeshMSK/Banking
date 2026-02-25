output "master_public_ip" {
  description = "Public IP of the K8s Master Node"
  value       = module.ec2.master_public_ip
}

output "worker_public_ip" {
  description = "Public IP of the K8s Worker Node"
  value       = module.ec2.worker_public_ip
}

output "next_steps" {
  description = "Instructions to join the cluster"
  value       = <<-EOT
    1. SSH into Master: ssh -i ~/ecommerce-key.pem ubuntu@${module.ec2.master_public_ip}    >> >>> path of your pem key
    2. Run this command on Master to get join token:
       sudo kubeadm token create --print-join-command
    3. SSH into Worker: ssh -i ~/ecommerce-key.pem ubuntu@${module.ec2.worker_public_ip}  >>> path of your pem key
    4. Paste the join command (with sudo) on the Worker node.
    5. Back on Master, run: kubectl get nodes
    will get this error 
    E0225 02:06:35.527476    3246 memcache.go:265] couldn't get current server API group list: Get "http://localhost:8080/api?timeout=32s": dial tcp 127.0.0.1:8080: connect: connection refused
E0225 02:06:35.527896    3246 memcache.go:265] couldn't get current server API group list: Get "http://localhost:8080/api?timeout=32s": dial tcp 127.0.0.1:8080: connect: connection refused
E0225 02:06:35.529391    3246 memcache.go:265] couldn't get current server API group list: Get "http://localhost:8080/api?timeout=32s": dial tcp 127.0.0.1:8080: connect: connection refused
E0225 02:06:35.529732    3246 memcache.go:265] couldn't get current server API group list: Get "http://localhost:8080/api?timeout=32s": dial tcp 127.0.0.1:8080: connect: connection refused
E0225 02:06:35.531098    3246 memcache.go:265] couldn't get current server API group list: Get "http://localhost:8080/api?timeout=32s": dial tcp 127.0.0.1:8080: connect: connection refused
The connection to the server localhost:8080 was refused - did you specify the right host or port?

then run the cluser-setup script on master node
vi cluser-setup.sh and paste the script]
    EOT
}
