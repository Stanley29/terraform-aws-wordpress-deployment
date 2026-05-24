# WordPress on AWS (Terraform)

Цей проєкт розгортає просту архітектуру WordPress у AWS за допомогою Terraform. 


Архітектура складається з двох EC2 інстансів:
- wp-db — MySQL сервер
- wp-app — Apache + PHP + WordPress

Terraform автоматично:
- створює security groups
- піднімає два EC2
- встановлює MySQL
- завантажує WordPress
- генерує wp-config.php
- виводить публічну IP адресу WordPress

## Deploy
terraform init
terraform apply



Після цього WordPress доступний за публічною IP адресою.