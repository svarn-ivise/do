rm(list=ls())

####DIGITAL OCEAN MANAGER
library(httr)
library(jsonlite)

do.tkn <- "11cf3f9bf398a2cc4535af43416abf7cf0e08395f8ad02da7a3973e48f3dd37c"
docker.slug <- "docker-16-04"
mysql.slug <- 
  
res <- GET("https://api.digitalocean.com/v2/images?type=application",
    add_headers("Content-Type" = "application/json",
                "Authorization" = paste0("Bearer ",do.tkn)))
  
images <- fromJSON(content(res, as = "text"))$images

###CREATE MYSQL SERVER
{
  
  res <- POST("https://api.digitalocean.com/v2/droplets",
              add_headers("Content-Type" = "application/json",
                          "Authorization" = paste0("Bearer ",do.tkn)),
              body = list(name="mysql",
                          region="nyc1",
                          size="s-1vcpu-1gb",
                          image="mysql-16-04",
                          ssh_keys=NULL,
                          backups=F,
                          ipv6=T,
                          user_data="
                          #cloud-config
                          runcmd:
                          - sudo apt-get update
                          - apt-get install -y git
                          - git clone https://github.com/svarn-ivise/db.git
                          - cd db
                          - sudo sed -i \"s/.*bind-address.*/bind-address = 0.0.0.0/\" /etc/mysql/mysql.conf.d/mysqld.cnf
                          - mysql -u root -p$(sed -n 's/^root_mysql_pass=//p' /root/.digitalocean_password | sed 's/[^a-z A-Z 0-9]//g') < ./create.sql 
                          - sudo service mysql restart
                          ",
                          private_networking=T,
                          volumes= NULL,
                          tags=list("db")), encode = "json")
  
  
  
}

res <- GET("https://api.digitalocean.com/v2/droplets?tag_name=db",
           add_headers("Content-Type" = "application/json",
                       "Authorization" = paste0("Bearer ",do.tkn)))
droplets <- fromJSON(content(res, as = "text"))$droplets
sql.db.ip <- droplets$networks$v4[[1]][1,1]

###CREATE API SERVERS
{
#number of instances
instances <- 1

for(inst in 1:instances){

res <- POST("https://api.digitalocean.com/v2/droplets",
     add_headers("Content-Type" = "application/json",
                 "Authorization" = paste0("Bearer ",do.tkn)),
     body = list(name=paste0("docker.api.", inst),
                 region="nyc1",
                 size="s-1vcpu-1gb",
                 image="docker-16-04",
                 ssh_keys=NULL,
                 backups=F,
                 ipv6=T,
                 user_data=paste0("
                  #cloud-config
                     runcmd:
                      - apt-get update
                      - apt-get install -y mysql-client
                      - apt-get install -y git
                      - git clone https://github.com/svarn-ivise/api.git
                      - cd api
                      - sudo sed -i \"s/0.0.0.0/'",sql.db.ip,"'/\" ./api.R
                      - docker-compose up
                      - sudo docker-compose scale app1=4
                  "),
                 private_networking=T,
                 volumes= NULL,
                 tags=list("api")), encode = "json")
}

}

res <- GET("https://api.digitalocean.com/v2/droplets?tag_name=api",
           add_headers("Content-Type" = "application/json",
                       "Authorization" = paste0("Bearer ",do.tkn)))
droplets <- fromJSON(content(res, as = "text"))$droplets
(api.ip <- droplets$networks$v4[[1]][1,1])


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

if(FALSE){
####DELETE DROPLETS
  
##API
DELETE("https://api.digitalocean.com/v2/droplets?tag_name=api",
    add_headers("Content-Type" = "application/json",
                "Authorization" = paste0("Bearer ",do.tkn)))

##DB
DELETE("https://api.digitalocean.com/v2/droplets?tag_name=db",
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
                  password = "S13240sx91",
                  host = sql.db.ip,
                  dbname="dynamic",
                  port = 3306)

# Run a query
dbGetQuery(con, "show databases;")
dbGetQuery(con, "select * from dynamic;")

dbDisconnect(con)
