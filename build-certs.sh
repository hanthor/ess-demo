#!/bin/bash


mkcert -install
echo -n "Enter the base domain name for the certificates (ideally under .localhost) : "
read BASE_DOMAIN

cd demo-values
mkcert "$BASE_DOMAIN"
kubectl create secret tls ess-well-known-certificate "--cert=./$BASE_DOMAIN.pem" "--key=./$BASE_DOMAIN-key.pem" -n ess

mkcert "matrix.$BASE_DOMAIN"
kubectl create secret tls ess-matrix-certificate "--cert=./matrix.$BASE_DOMAIN.pem" "--key=./matrix.$BASE_DOMAIN-key.pem" -n ess

mkcert "mrtc.$BASE_DOMAIN"
kubectl create secret tls ess-mrtc-certificate "--cert=./mrtc.$BASE_DOMAIN.pem" "--key=./mrtc.$BASE_DOMAIN-key.pem" -n ess

mkcert "chat.$BASE_DOMAIN"
kubectl create secret tls ess-chat-certificate "--cert=./chat.$BASE_DOMAIN.pem" "--key=./chat.$BASE_DOMAIN-key.pem" -n ess

mkcert "auth.$BASE_DOMAIN"
kubectl create secret tls ess-auth-certificate "--cert=./auth.$BASE_DOMAIN.pem" "--key=./auth.$BASE_DOMAIN-key.pem" -n ess

mkcert "admin.$BASE_DOMAIN"
kubectl create secret tls ess-admin-certificate "--cert=./admin.$BASE_DOMAIN.pem" "--key=./admin.$BASE_DOMAIN-key.pem" -n ess
cd -
