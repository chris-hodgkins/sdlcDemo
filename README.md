# SDLC Demo
This repo sets up a CI/CD pipeline in minikube to allow students to experience the SDLC Process that you would see when working in larger teams. 
This is not meant for production and is not a fully secured CI/CD pipeline. 

## Software used in CI/CD
* Gitea - "Gitea is a community managed lightweight code hosting solution written in Go. It is published under the MIT license." [Website](https://gitea.io/en-us/)
* Jenkins - "The leading open source automation server, Jenkins provides hundreds of plugins to support building, deploying and automating any project." [website](https://www.jenkins.io)
  
## Software used to run the pipeline
* Docker - "Docker is a set of platform as a service products that use OS-level virtualization to deliver software in packages called containers. The service has both free and premium tiers. The software that hosts the containers is called Docker Engine" [website](https://www.docker.com)
* Minikube - "minikube is local Kubernetes, focusing on making it easy to learn and develop for Kubernetes." [website](https://minikube.sigs.k8s.io/docs/)
* Helm - "The package manager for Kubernetes" [website](https://helm.sh)

## Prerequisites  
1. Install Docker daemon, the easiest way would be though Docker Desktop. Follow the guide [here](https://www.docker.com/products/docker-desktop/)
2. Install Minikube follow the guide [here](https://minikube.sigs.k8s.io/docs/start/)
3. Install Helm follow the guide [here](https://helm.sh/docs/intro/install/)
4. Install kubectl this can be installed stand alone [here](https://kubernetes.io/docs/tasks/tools/) or through minikube [Step 3](https://minikube.sigs.k8s.io/docs/start/) 
5. Install jq, this is used as part of the setup scripts more can be found [here](https://stedolan.github.io/jq/)


## Setting up the environment
### Installing Gitea
We will be using the the Gitea Helm charts detailed in there guide on how to [install Gitea in Kubernetes](https://docs.gitea.io/en-us/install-on-kubernetes/)
For the helm command we will be passing in a values file that will set our nodeport to expose the Gitea instance to outside of the minikube cluster. 
In the file [gitea-values.yaml](gitea/gitea-values.yaml). Also in this value file we are creating a default admin user and setting its password that can be used to set up the users later. To find out about more customization read up [here](https://gitea.com/gitea/helm-chart/)
To install run:
```
helm repo add gitea-charts https://dl.gitea.io/charts/
helm install gitea -f ./gitea/gitea-values.yaml gitea-charts/gite
```
Once finished you should see the pods starting using the command `kubectl get all -n default`
To find the url to access the web site you can run `./gitea/getUrl.sh` open the URL and you will be presented with the Gitea site running in minikube. 

### Installing Jenkins
We will be following the guide to install [Jenkins in Kubernetes](https://www.jenkins.io/doc/book/installing/kubernetes/)
Steps to run:
```
# Create the namespace for jenkins
kubectl create namespace jenkins
# Create a persistent volume that jenkins will use. 
kubectl apply -f ./jenkins/jenkins-volume.yaml
## Update permissions on the file created for the persistent volume with in the minikube virtual machine
minikube ssh
sudo chown -R 1000:1000 /data/jenkins-volume 
exit
# Create a service account
kubectl apply -f jenkins-sa.yaml
# Add the jenkins helm charts repo
helm repo add jenkinsci https://charts.jenkins.io
# Install jenkins
helm install jenkins -n jenkins -f ./jenkins/jenkins-values.yaml jenkinsci/jenkins
```
Things to look out for:
* The directory for the persistent volume may not be present in the minikube virtual machine until after the pods attempt to get it. In this case remove jenkins and then remove the persistent volume and readd it and re set the permissions.
#### Validate Jenkins is running
To get url and admin password for the Jenkins instance run the following:
```
./jenkins/getUrl.sh
```
This will give you a url and password. Check the page loads and you can log in with `admin` and your password.

### Connecting Gitea and Jenkins
We need to create a user in Gitea for Jenkins to use. We will also create an Organization and a team for the user. Once the user is created it will generate an API key and store it in a Kubernetes secret which is exposed in Jenkins. This is all included in this set up script. 
```
./setUp.sh
```

