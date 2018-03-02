output "subnet_cidr_block" {
  value = "${var.cidr_block}"
}

output "private_ip" {
    value = "${aws_instance.app.*.private_ip[0]}"
}

output "id" {
  value = "${aws_instance.app.*.id}"
}

output "subnet" {
  value = "${aws_subnet.app-manraaj.id}"
}

output "security_app" {
  value = "${aws_security_group.app-manraaj.id}"
}