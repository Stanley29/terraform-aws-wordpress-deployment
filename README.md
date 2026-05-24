# WordPress on AWS (Terraform)

Цей проєкт розгортає просту архітектуру WordPress у AWS за допомогою Terraform. 
Я спочатку планував встановити Proxmox локально, але на комп’ютері не вистачає місця, 
тому вирішив зробити все в AWS, бо там теж працюють віртуальні машини.

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