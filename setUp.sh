#!/bin/bash

### Find the URL to connect to GiTea
export NODE_PORT=$(kubectl get --namespace default -o jsonpath="{.spec.ports[0].nodePort}" services gitea-http)
export NODE_IP=$(kubectl get nodes --namespace default -o jsonpath="{.items[0].status.addresses[0].address}")
echo "GiTea running at: http://${NODE_IP}:${NODE_PORT}"
export teaUrl="http://${NODE_IP}:${NODE_PORT}"

## Check if jq is installed
if ! command -v jq &> /dev/null
then
    echo "jq could not be found for parsing api response"
    exit
fi

org="sdlcDemo"

##Get the API key for the Admin User this will be used for the majority of calls
echo "Delete any old API tokens"
curl -H "Content-Type: application/json" -X DELETE -u teaAdmin:defaultEarlGray ${teaUrl}/api/v1/users/teaAdmin/tokens/api
echo "Creating new API Token"
export apiToken=$(curl -s -H "Content-Type: application/json" -d '{"name":"api"}' -u teaAdmin:defaultEarlGray ${teaUrl}/api/v1/users/teaAdmin/tokens | jq '.sha1' | sed s/\"//g)
echo "Token ${apiToken}"

###List users to check in Jenkins is Present
echo "Checking if jenkins user exists"
if [[ $(curl -s -H "Content-Type: application/json" -u teaAdmin:defaultEarlGray ${teaUrl}/api/v1/admin/users | jq 'any(.username =="jenkins")') == "true" ]]; then
    echo "Jenkins User exists"
else
    echo "Jenkins User needs to be created"
    curl -H "Content-Type: application/json" -d '{"username":"jenkins", "password": "qwerty", "email": "jenkins@gitea.com"}' ${teaUrl}/api/v1/admin/users?token=${apiToken}
    echo "Jenkins User created"
fi

###Setting up ORG 
echo "Checking if ${org} org exists"
if [[ $(curl -s -H "Content-Type: application/json" ${teaUrl}/api/v1/orgs?token=${apiToken} | jq --arg org "${org}" 'any(.username == $org)') == "true" ]]; then
    echo "Org ${org} exists"
else
    echo "Org ${org} does not exist need to create"
    curl -H "Content-Type: application/json" -d '{"username":"${org}", "visibility":"public"}' ${teaUrl}/api/v1/orgs?token=${apiToken}
    echo "Org ${org} created"
fi

###Setting up team
echo "Cheking Developer team in ${org} org"
if [[ $(curl -s -H "Content-Type: application/json" ${teaUrl}/api/v1/orgs/${org}/teams?token=${apiToken} | jq 'any(.name == "Developers")') == "true" ]]; then
    echo "Developers team is present"
else
    echo "Developers team needs to be added to the ${org} org"
    curl -H "Content-Type: application/json" -d '{"name":"Developers", "permission": "write", "units": [ "repo.code", "repo.issues", "repo.ext_issues", "repo.wiki", "repo.pulls", "repo.releases", "repo.projects", "repo.ext_wiki" ]}' ${teaUrl}/api/v1/orgs/${org}/teams?token=${apiToken}
    echo "Team Developers added to ${org}"
fi


teamID=$(curl -s -H "Content-Type: application/json" ${teaUrl}/api/v1/orgs/${org}/teams?token=${apiToken} | jq '.[] | select(.name == "Developers").id')
echo "Team ID: ${teamID}"

echo "Adding jenkins to Developer team"
if [[ $(curl -s -H "Content-Type: application/json" ${teaUrl}/api/v1/teams/${teamID}/members?token=${apiToken} | jq 'any(.username == "jenkins")') == "true" ]]; then
    echo "Jenkins User all ready in team"
else
    echo "Jenkins user needs to be added to the team"
curl -H "Content-Type: application/json" -X PUT ${teaUrl}/api/v1/teams/${teamID}/members/jenkins?token=${apiToken}
    echo "Jenkins added to the developer team"
fi



##Get the API key for the Jenkins User this will be used for the majority of calls
echo "Jenkins User: Delete any old API tokens"
curl -H "Content-Type: application/json" -X DELETE -u jenkins:qwerty ${teaUrl}/api/v1/users/jenkins/tokens/jenkins
echo "Creating new API Token"
export apiToken=$(curl -s -H "Content-Type: application/json" -d '{"name":"jenkins"}' -u jenkins:qwerty ${teaUrl}/api/v1/users/jenkins/tokens | jq '.sha1' | sed s/\"//g)
echo "==================================="
echo "Gitea Server address: ${teaUrl}"
echo "Jenkins User API Token: ${apiToken}"
echo "GiTea Org: ${org}"
echo "==================================="


echo "Deploying Secret with API token in it"
if [[ $(kubectl get secret gitea-apitoken -o jsonpath='{.data}' -n jenkins | jq 'has("token")') == "true" ]]; then
    kubectl get secret gitea-apitoken -o json -n jenkins | jq --arg token "$( echo -n ${apiToken} | base64)" '.data["token"]=$token' | kubectl apply -n jenkins -f -
else
    kubectl create secret generic gitea-apitoken --from-literal='token='${apiToken} -n jenkins
fi

echo "==================================="
echo "Setting up Jenkins "