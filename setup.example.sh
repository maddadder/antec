helm install leenet-ingress ./charts/leenet-ingress --namespace default

helm install tnt86-nostr-rs-relay ./charts/tnt86-nostr-rs-relay
helm install tnt86-shopstr ./charts/tnt86-shopstr

helm install paintedravendesign-nostr-rs-relay ./charts/paintedravendesign-nostr-rs-relay
helm install paintedravendesign-shopstr ./charts/paintedravendesign-shopstr

export DDNSR53_CREDENTIALS_ACCESSKEYID=YOUR_ROUTE53_KEY_ID
export DDNSR53_CREDENTIALS_SECRETACCESSKEY=YOUR_ROUTE53_KEY_SECRET

helm install ddns-route53 --namespace default --set Route53AccessKeyId=$DDNSR53_CREDENTIALS_ACCESSKEYID --set Route53SecretAccessKey=$DDNSR53_CREDENTIALS_SECRETACCESSKEY ./charts/ddns-route53
