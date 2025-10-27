
kubectl create secret generic -n cert-manager route53-secret --from-literal=secret-access-key="YOUR_KEY_FROM_AWS"

#https://cert-manager.io/v1.15-docs/configuration/acme/dns01/google/
#gcloud auth login
#gcloud config set project "probable-summer-476315-q1"
#gcloud iam service-accounts create dns01-solver --display-name "dns01-solver"
#export PROJECT_ID=probable-summer-476315-q1
#gcloud projects add-iam-policy-binding $PROJECT_ID \
#   --member serviceAccount:dns01-solver@$PROJECT_ID.iam.gserviceaccount.com \
#   --role roles/dns.admin
#gcloud iam service-accounts keys create key.json \
#   --iam-account dns01-solver@$PROJECT_ID.iam.gserviceaccount.com
kubectl create secret generic clouddns-dns01-solver-svc-acct \
   --from-file=key.json -n cert-manager

kubectl create secret generic -n cert-manager route53-secret --from-literal=secret-access-key="YOUR_KEY_FROM_AWS"

helm install leenet-ingress ./charts/leenet-ingress --namespace default
kubectl get Issuers,ClusterIssuers,Certificates,CertificateRequests,Orders,Challenges --all-namespaces

helm install tnt86-nostr-rs-relay ./charts/tnt86-nostr-rs-relay
helm install tnt86-shopstr ./charts/tnt86-shopstr

helm install paintedravendesign-nostr-rs-relay ./charts/paintedravendesign-nostr-rs-relay
helm install paintedravendesign-shopstr ./charts/paintedravendesign-shopstr

helm install whisper-live ./charts/whisper-live
#export DDNSR53_CREDENTIALS_ACCESSKEYID=YOUR_ROUTE53_KEY_ID
#export DDNSR53_CREDENTIALS_SECRETACCESSKEY=YOUR_ROUTE53_KEY_SECRET

#helm install ddns-route53 --namespace default --set Route53AccessKeyId=$DDNSR53_CREDENTIALS_ACCESSKEYID --set Route53SecretAccessKey=$DDNSR53_CREDENTIALS_SECRETACCESSKEY ./charts/ddns-route53
