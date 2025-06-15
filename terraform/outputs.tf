output "demo_environment_public_ips" {
  description = "Public IP addresses of the demo_environment instance(s)."
  # Using splat expression `.*.public_ip` works for both single and multiple instances
  # controlled by `count`. It will return a list of IPs.
  value       = aws_instance.demo_environment.*.public_ip
}

# Output the private IP address(es) of the demo_environment instance(s)
output "demo_environment_private_ips" {
  description = "Private IP addresses of the demo_environment instance(s)."
  # Using splat expression `.*.private_ip` works for both single and multiple instances.
  # It will return a list of IPs.
  value       = aws_instance.demo_environment.*.private_ip
}