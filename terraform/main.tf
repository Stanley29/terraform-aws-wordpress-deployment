terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

variable "key_name" {
  type    = string
  default = "HrSolution_Key_Pair"
}

# Ubuntu 22.04 LTS
data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Default VPC
data "aws_vpc" "default" {
  default = true
}

# Subnets (new provider syntax)
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# SG for APP
resource "aws_security_group" "app_sg" {
  name        = "wp-app-sg"
  description = "App SG"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# SG for DB
resource "aws_security_group" "db_sg" {
  name        = "wp-db-sg"
  description = "DB SG"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# DB INSTANCE
resource "aws_instance" "db" {
  ami                    = data.aws_ami.ubuntu_2204.id
  instance_type          = "t3.micro"
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  key_name               = var.key_name

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server
    mysql -e "CREATE DATABASE wpdb;"
    mysql -e "CREATE USER 'wpuser'@'%' IDENTIFIED BY 'StrongPass123!';"
    mysql -e "GRANT ALL PRIVILEGES ON wpdb.* TO 'wpuser'@'%'; FLUSH PRIVILEGES;"
    sed -i "s/^bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf
    systemctl restart mysql
  EOF

  tags = {
    Name = "wp-db"
  }
}

# APP INSTANCE
resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu_2204.id
  instance_type          = "t3.micro"
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  key_name               = var.key_name

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y apache2 php php-mysql wget unzip
    systemctl enable apache2
    systemctl start apache2

    cd /var/www/html
    rm -f index.html
    wget https://wordpress.org/latest.zip
    unzip latest.zip
    mv wordpress/* .
    rmdir wordpress
    rm latest.zip
    chown -R www-data:www-data /var/www/html

    cat > /var/www/html/wp-config.php <<CFG
    <?php
    define( 'DB_NAME', 'wpdb' );
    define( 'DB_USER', 'wpuser' );
    define( 'DB_PASSWORD', 'StrongPass123!' );
    define( 'DB_HOST', '${aws_instance.db.private_ip}' );
    define( 'DB_CHARSET', 'utf8' );
    define( 'DB_COLLATE', '' );
    \$table_prefix = 'wp_';
    define( 'WP_DEBUG', false );
    if ( ! defined( 'ABSPATH' ) ) {
      define( 'ABSPATH', __DIR__ . '/' );
    }
    require_once ABSPATH . 'wp-settings.php';
    CFG
  EOF

  tags = {
    Name = "wp-app"
  }
}

output "app_public_ip" {
  value = aws_instance.app.public_ip
}
