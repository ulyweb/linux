# Install Docker Compose

#### Search for dockur windows (https://github.com/dockur/windows)


### Install docker
````
sudo apt update && clear
sudo apt install -y docker.io docker-compose
````

### Making docker directory
````
sudo mkdir -p dockercomp
cd dockercomp
nano windowsxp.yaml
````

### run it

````
sudo docker-compose -f windowsxp.yaml up
````


### How to verify if my system supports KVM?
````
sudo apt install cpu-checker
sudo kvm-ok
````
