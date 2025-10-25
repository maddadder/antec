

resource "azurerm_resource_group" "homelabrg" {
  name     = "homelabrg-resource-group"
  location = var.region
}

# Create the VNET
resource "azurerm_virtual_network" "homelabrg-vnet" {
  name                = "${var.region}-${var.environment}-${var.app_name}-vnet"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.homelabrg.location
  resource_group_name = azurerm_resource_group.homelabrg.name
  tags = {
    environment = var.environment
  }
}

resource "azurerm_subnet" "homelabrg-subnet" {
  name                 = "homelabrgSubnet" # do not rename
  resource_group_name  = azurerm_resource_group.homelabrg.name
  virtual_network_name = azurerm_virtual_network.homelabrg-vnet.name
  address_prefixes     = ["10.10.0.0/24"]

  delegation {
    name = "aci-delegation"
    service_delegation {
      name = "Microsoft.ContainerInstance/containerGroups"
    }
  }
  
}


resource "azurerm_public_ip" "homelabrg" {
  name                = "${var.app_name}-PublicIP"
  location            = azurerm_resource_group.homelabrg.location
  resource_group_name = azurerm_resource_group.homelabrg.name
  allocation_method   = "Static"
}

resource "azurerm_lb" "homelabrg" {
  name                = "${var.app_name}-LoadBalancer"
  location            = azurerm_resource_group.homelabrg.location
  resource_group_name = azurerm_resource_group.homelabrg.name

  frontend_ip_configuration {
    name                 = "${var.app_name}-FrontendIpConfig"
    public_ip_address_id = azurerm_public_ip.homelabrg.id
  }
}


resource "azurerm_lb_probe" "http_probe" {
  name                            = "${var.app_name}-HealthProbe"
  loadbalancer_id                 = azurerm_lb.homelabrg.id
  protocol                        = "Tcp"
  port                            = 80
  interval_in_seconds             = 5
  number_of_probes                = 2
}


resource "azurerm_lb_rule" "homelabrg-http" {
  name                           = "HTTPRule"
  loadbalancer_id                = azurerm_lb.homelabrg.id
  frontend_ip_configuration_name = azurerm_lb.homelabrg.frontend_ip_configuration[0].name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.homelabrg.id]
  probe_id                       = azurerm_lb_probe.http_probe.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  idle_timeout_in_minutes        = 4
}

resource "azurerm_lb_rule" "homelabrg-https" {
  name                           = "HTTPSRule"
  loadbalancer_id                = azurerm_lb.homelabrg.id
  frontend_ip_configuration_name = azurerm_lb.homelabrg.frontend_ip_configuration[0].name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.homelabrg.id]
  probe_id                       = azurerm_lb_probe.http_probe.id
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  idle_timeout_in_minutes        = 4
}

resource "azurerm_subnet" "homelabrg-subnet-non-delegated" {
  name                 = "homelabrgSubnetNonDelegated"
  resource_group_name  = azurerm_resource_group.homelabrg.name
  virtual_network_name = azurerm_virtual_network.homelabrg-vnet.name
  address_prefixes     = ["10.10.1.0/24"] // Ensure this doesn't overlap
}

resource "azurerm_network_interface" "homelabrg_non_delegated" {
  name                = "${var.app_name}-nic"
  location            = azurerm_resource_group.homelabrg.location
  resource_group_name = azurerm_resource_group.homelabrg.name

  ip_configuration {
    name                          = "${var.app_name}-internal"
    subnet_id                     = azurerm_subnet.homelabrg-subnet-non-delegated.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_lb_backend_address_pool" "homelabrg" {
  name                = "homelabrg-backend-pool"
  loadbalancer_id     = azurerm_lb.homelabrg.id

}

resource "azurerm_lb_backend_address_pool_address" "homelabrg_ip_one" {
  name                                = "homelabrg-ip-one"
  backend_address_pool_id             = azurerm_lb_backend_address_pool.homelabrg.id
  virtual_network_id                  = azurerm_virtual_network.homelabrg-vnet.id
  ip_address                          = azurerm_container_group.homelab_container_group.ip_address
  #ip_address                         = azurerm_network_interface.homelabrg_non_delegated.ip_configuration[0].private_ip_address
  #backend_address_ip_configuration_id = azurerm_lb.homelabrg.frontend_ip_configuration[0].id
}


resource "azurerm_network_security_group" "homelab_nsg" {
  name                = "${var.app_name}-NSG"
  location            = azurerm_resource_group.homelabrg.location
  resource_group_name = azurerm_resource_group.homelabrg.name

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}


locals {
  container_config = {
    name    = "${var.app_name}-containergroup"
    image   = "public.ecr.aws/nginx/nginx:latest"
    cpu     = "0.5"
    memory  = "1.5"
    ports    = [80, 443]
  }
}

resource "azurerm_container_group" "homelab_container_group" {
  name                = local.container_config.name
  location            = azurerm_resource_group.homelabrg.location
  resource_group_name = azurerm_resource_group.homelabrg.name
  os_type             = "Linux"

  container {
    name   = local.container_config.name
    image  = local.container_config.image
    cpu    = local.container_config.cpu
    memory = local.container_config.memory

    dynamic "ports" {
      for_each = local.container_config.ports

      content {
        port = ports.value
      }
    }
    
    environment_variables = {
      YOUR_HOME_SERVER_PUBLIC_IP = "0.0.0.0"  # Placeholder value
    }

    // Generate NGINX configuration on startup
    commands = [
      "/bin/sh",
      "-c",
      <<EOT
      echo 'worker_processes auto;

      events {
          worker_connections 1024;
      }

      http {
          include /etc/nginx/mime.types;
          default_type application/octet-stream;

          server {
              listen 80;

              location / {
                  proxy_pass http://zambonigirl.com; 
                  proxy_set_header Host \$host;
                  proxy_set_header X-Real-IP \$remote_addr;
                  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                  proxy_set_header X-Forwarded-Proto \$scheme;
              }
          }
      }

      stream {
          server {
              listen 443;
              proxy_pass zambonigirl.com:443; 
          }
      }' > /etc/nginx/nginx.conf

      # Start NGINX
      nginx -g 'daemon off;'
      EOT
    ]
  }

  subnet_ids          = [azurerm_subnet.homelabrg-subnet.id]
  ip_address_type     = "Private"

}

