provider "aws" {
    access_key = "${var.access_key}"
    secret_key = "${var.secret_key}"
    region = "${var.region}"
}

resource "aws_vpc" "scaleio_vpc" {
    cidr_block = "10.0.0.0/16"
    tags {
        Name = "scaleio"
    }
}

resource "aws_subnet" "scaleio_subnet" {
    vpc_id = "${aws_vpc.scaleio_vpc.id}"
    cidr_block = "10.0.0.0/16"

    tags {
        Name = "scaleio"
    }
}

resource "aws_security_group" "allow_all" {
  name = "allow_all"
  description = "Allow all inbound traffic"
  vpc_id = "${aws_vpc.scaleio_vpc.id}"


  ingress {
      from_port = 0
      self = true
      to_port = 65535
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
      from_port = 0
      to_port = 65535
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }


  tags {
    Name = "allow_all"
  }
}

resource "aws_internet_gateway" "scaleio_gw" {
    vpc_id = "${aws_vpc.scaleio_vpc.id}"
    tags {
        Name = "scaleio_gateway"
    }
}

resource "aws_route_table" "scaleio_routetable" {
    vpc_id = "${aws_vpc.scaleio_vpc.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.scaleio_gw.id}"
    }

    tags {
        Name = "scaleio_routetable"
    }
}




resource "aws_route_table_association" "scaleio_association" {
    subnet_id = "${aws_subnet.scaleio_subnet.id}"
    route_table_id = "${aws_route_table.scaleio_routetable.id}"
}




resource "aws_instance" "sds" {
    ami = "${var.ami_id}"
    instance_type = "${var.sds_instance_type}"
    key_name = "${var.key_name}"
    subnet_id = "${aws_subnet.scaleio_subnet.id}"
    count = "${var.sds_count}"
    associate_public_ip_address = true
    vpc_security_group_ids = [
      "${aws_security_group.allow_all.id}"
    ]
    depends_on = [
      "aws_internet_gateway.scaleio_gw"
    ]

    ephemeral_block_device {
	    device_name = "/dev/sdb"
	    virtual_name = "ephemeral0"
	  }
   provisioner "file" {
        connection {
            user = "ec2-user"
            key_file = "${var.key_file}"
        }
        source = "sds_install.sh"
        destination = "/tmp/sds_install.sh"
    }
    provisioner "remote-exec" {
      connection {
          user = "ec2-user"
          key_file = "${var.key_file}"
      }
      inline = [
        "sudo sh /tmp/sds_install.sh >> /tmp/install.log",
      ]
    }
}




resource "aws_instance" "mdm" {
    ami = "${var.ami_id}"
    instance_type = "${var.mdm_instance_type}"
    key_name = "${var.key_name}"
    subnet_id = "${aws_subnet.scaleio_subnet.id}"
    count = 1
    associate_public_ip_address = true
    vpc_security_group_ids = [
      "${aws_security_group.allow_all.id}"
    ]
    depends_on = [
      "aws_internet_gateway.scaleio_gw",
      "aws_instance.sds"
    ]

    provisioner "file" {
        connection {
            user = "ec2-user"
            key_file = "${var.key_file}"
        }
        source = "mdm_install.sh"
        destination = "/tmp/mdm_install.sh"
    }

    provisioner "file" {
        connection {
            user = "ec2-user"
            key_file = "${var.key_file}"
        }
        source = "${var.key_file}" 
        destination = "~ec2-user/.ssh/scaleio"
    }

    provisioner "remote-exec" {
      connection {
          user = "ec2-user"
          key_file = "${var.key_file}"
      }
      inline = [
        "sudo chmod 400 ~ec2-user/.ssh/scaleio",
        "echo ${join(" ",aws_instance.sds.*.private_ip)} > /tmp/all_sds",
        "sudo sh /tmp/mdm_install.sh >> /tmp/install.log",
        "sudo sh /tmp/install.sh >> /tmp/install.log"
      ]

    }
}


output "MDM_IP" {
  value = "${aws_instance.mdm.public_ip}"
}
output "MDM Password" {
  value = "admin/password123!"
}
output "SDS_SDC_IP (private)" {
  value = "${join(",",aws_instance.sds.*.private_ip)}"
}
output "SDS_SDC_IP (public)" {
  value = "${join(",",aws_instance.sds.*.public_ip)}"
}

