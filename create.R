rm(list=ls())

####DIGITAL OCEAN MANAGER
library(httr)

do.tkn <- "blah"
docker.slug <- "docker-16-04"
mysql.slug <- 
  
res <- GET("https://api.digitalocean.com/v2/images?type=application",
    add_headers("Content-Type" = "application/json",
                "Authorization" = paste0("Bearer ",do.tkn)))
  
images <- fromJSON(content(res, as = "text"))$images

#number of instances
instances <- 2

for(inst in 1:instances){

res <- POST("https://api.digitalocean.com/v2/droplets",
     add_headers("Content-Type" = "application/json",
                 "Authorization" = paste0("Bearer ",do.tkn)),
     body = paste0('{"name":"docker.api',inst,'",
                 "region":"nyc1",
                 "size":"s-1vcpu-1gb",
                 "image":"docker-16-04",
                 "ssh_keys":null,
                 "backups":false,
                 "ipv6":true,
                 "user_data":"
                  #cloud-config
                  
                  runcmd:  
                    - apt-get install -y git
                    - git clone https://github.com/svarn-ivise/api.git
                    - cd api
                    - docker-compose up
                    - sudo docker-compose scale app1=6
                  ",
                 "private_networking":null,
                 "volumes": null,
                 "tags":["api"]}'))
}

res <- GET("https://api.digitalocean.com/v2/droplets",
           add_headers("Content-Type" = "application/json",
                       "Authorization" = paste0("Bearer ",do.tkn)))

droplets <- fromJSON(content(res, as = "text"))$droplets

###CREATE LOAD BALANCER
{
res <- POST("https://api.digitalocean.com/v2/load_balancers",
            add_headers("Content-Type" = "application/json",
                        "Authorization" = paste0("Bearer ",do.tkn)),
            body = '{
                  "name": "api-lb",
                  "region": "nyc1",
                  "forwarding_rules": [
                    {
                      "entry_protocol": "http",
                      "entry_port": 80,
                      "target_protocol": "http",
                      "target_port": 80,
                      "certificate_id": "",
                      "tls_passthrough": false
                    },
                    {
                      "entry_protocol": "https",
                      "entry_port": 444,
                      "target_protocol": "https",
                      "target_port": 443,
                      "tls_passthrough": true
                    }
                    ],
                  "health_check": {
                    "protocol": "http",
                    "port": 80,
                    "path": "/echo",
                    "check_interval_seconds": 10,
                    "response_timeout_seconds": 5,
                    "healthy_threshold": 5,
                    "unhealthy_threshold": 3
                  },
                  "sticky_sessions": {
                    "type": "none"
                  },
                  "tag": "api"
                }')
}

###CREATE MYSQL SERVER
{
  
  res <- POST("https://api.digitalocean.com/v2/droplets",
              add_headers("Content-Type" = "application/json",
                          "Authorization" = paste0("Bearer ",do.tkn)),
              body = paste0('{"name":"mysql",
                 "region":"nyc1",
                 "size":"s-1vcpu-1gb",
                 "image":"mysql-16-04",
                 "ssh_keys":null,
                 "backups":false,
                 "ipv6":true,
                 "user_data":"
                  #cloud-config
                  runcmd:
                  #cloud-config
                    runcmd:  
                      - apt-get install -y git
                      - git clone https://github.com/svarn-ivise/db.git
                 "private_networking":true,
                 "volumes": null,
                 "tags":["db"]}'))
  
  # - mysql -u root -p$(sed -n \'s/^root_mysql_pass=//p\' /root/.digitalocean_password | sed \'s/[^a-z  A-Z 0-9]//g\') -e \'CREATE USER \'shane\'@\'localhost\' IDENTIFIED BY \'S13240sx91!\';
  #                          GRANT ALL PRIVILEGES ON *.* TO \'shane\'@\'localhost\' WITH GRANT OPTION;
  #                          CREATE USER \'shane\'@\'%\' IDENTIFIED BY \'S13240sx91\';
  #                          GRANT ALL PRIVILEGES ON *.* TO \'shane\'@\'%\' WITH GRANT OPTION;
  #                          FLUSH PRIVILEGES;\'",
  
}
if(FALSE){
####DELETE DROPLETS
DELETE("https://api.digitalocean.com/v2/droplets?tag_name=api",
    add_headers("Content-Type" = "application/json",
                "Authorization" = paste0("Bearer ",do.tkn)))

###DELETE LOAD BALANCER
res <- GET("https://api.digitalocean.com/v2/load_balancers?tag=api",
           add_headers("Content-Type" = "application/json",
                       "Authorization" = paste0("Bearer ",do.tkn)))

lb_id <- fromJSON(content(res, "text"))$load_balancers$id

DELETE(paste0("https://api.digitalocean.com/v2/load_balancers/",lb_id),
       add_headers("Content-Type" = "application/json",
                   "Authorization" = paste0("Bearer ",do.tkn)))
}

library(RMySQL)

con <-  dbConnect(RMySQL::MySQL(),
                  username = "shane",
                  password = "S13240sx91!",
                  host = "67.205.150.125",
                  port = 3306,
                  database="mysql")

# Run a query
dbGetQuery(con, "show tables from test")
