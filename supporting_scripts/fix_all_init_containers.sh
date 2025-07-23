#!/bin/bash

# Script to fix all init container image references
NAMESPACE="egov"

echo "Fixing init container images..."

# Fix audit-service
kubectl patch deployment audit-service -n $NAMESPACE -p '{"spec":{"template":{"spec":{"initContainers":[{"name":"db-migration","image":"egovio/audit-service-db:core-2.9-lts-mvn-check-c33cfe45ab-9"}]}}}}'

# Fix egov-enc-service
kubectl patch deployment egov-enc-service -n $NAMESPACE -p '{"spec":{"template":{"spec":{"initContainers":[{"name":"db-migration","image":"egovio/egov-enc-service-db:core-2.9-lts-mvn-check-c33cfe45ab-19"}]}}}}'

# Fix egov-filestore
kubectl patch deployment egov-filestore -n $NAMESPACE -p '{"spec":{"template":{"spec":{"initContainers":[{"name":"db-migration","image":"egovio/egov-filestore-db:filestore2.9-e4f3361640-10"}]}}}}'

# Fix egov-hrms
kubectl patch deployment egov-hrms -n $NAMESPACE -p '{"spec":{"template":{"spec":{"initContainers":[{"name":"db-migration","image":"egovio/egov-hrms-db:core-2.9-lts-mvn-check-4553648f56-8"}]}}}}'

# Fix egov-idgen
kubectl patch deployment egov-idgen -n $NAMESPACE -p '{"spec":{"template":{"spec":{"initContainers":[{"name":"db-migration","image":"egovio/egov-idgen-db:core-2.9-lts-mvn-check-c33cfe45ab-7"}]}}}}'

# Fix egov-indexer
kubectl patch deployment egov-indexer -n $NAMESPACE -p '{"spec":{"template":{"spec":{"initContainers":[{"name":"db-migration","image":"egovio/egov-indexer-db:core-2.9-lts-mvn-check-5f0cc52126-55"}]}}}}'

# Fix egov-localization
kubectl patch deployment egov-localization -n $NAMESPACE -p '{"spec":{"template":{"spec":{"initContainers":[{"name":"db-migration","image":"egovio/egov-localization-db:core-2.9-lts-mvn-check-80a8c03158-8"}]}}}}'

# Fix egov-location
kubectl patch deployment egov-location -n $NAMESPACE -p '{"spec":{"template":{"spec":{"initContainers":[{"name":"db-migration","image":"egovio/egov-location-db:core-2.9-lts-mvn-check-c33cfe45ab-9"}]}}}}'

# Fix egov-otp
kubectl patch deployment egov-otp -n $NAMESPACE -p '{"spec":{"template":{"spec":{"initContainers":[{"name":"db-migration","image":"egovio/egov-otp-db:core-2.9-lts-mvn-check-72333e5530-5"}]}}}}'

# Fix egov-pg-service
kubectl patch deployment egov-pg-service -n $NAMESPACE -p '{"spec":{"template":{"spec":{"initContainers":[{"name":"db-migration","image":"egovio/egov-pg-service-db:core-2.9-lts-mvn-check-421601fcdf-10"}]}}}}'

# Fix egov-url-shortening
kubectl patch deployment egov-url-shortening -n $NAMESPACE -p '{"spec":{"template":{"spec":{"initContainers":[{"name":"db-migration","image":"egovio/egov-url-shortening-db:core-2.9-lts-mvn-check-ecf5d0a880-11"}]}}}}'

# Fix egov-user
kubectl patch deployment egov-user -n $NAMESPACE -p '{"spec":{"template":{"spec":{"initContainers":[{"name":"db-migration","image":"egovio/egov-user-db:core-2.9-lts-egov-user-deployement-c33cfe45ab-13"}]}}}}'

# Fix egov-user-event
kubectl patch deployment egov-user-event -n $NAMESPACE -p '{"spec":{"template":{"spec":{"initContainers":[{"name":"db-migration","image":"egovio/egov-user-event-db:scg-without-default-ratelimiting-aa5653bf8f-19"}]}}}}'

# Fix egov-workflow-v2
kubectl patch deployment egov-workflow-v2 -n $NAMESPACE -p '{"spec":{"template":{"spec":{"initContainers":[{"name":"db-migration","image":"egovio/egov-workflow-v2-db:core-2.9-lts-mvn-check-c33cfe45ab-9"}]}}}}'

# Fix pgr-services
kubectl patch deployment pgr-services -n $NAMESPACE -p '{"spec":{"template":{"spec":{"initContainers":[{"name":"db-migration","image":"egovio/pgr-services-db:core-digit-2.9-lts-pgr-02df4964cb-3"}]}}}}'

# Fix service-request
kubectl patch deployment service-request -n $NAMESPACE -p '{"spec":{"template":{"spec":{"initContainers":[{"name":"db-migration","image":"egovio/service-request-db:core-2.9-lts-mvn-check-ad9766cbe5-5"}]}}}}'

# Fix user-otp
kubectl patch deployment user-otp -n $NAMESPACE -p '{"spec":{"template":{"spec":{"initContainers":[{"name":"db-migration","image":"egovio/user-otp-db:core-2.9-lts-mvn-check-15fe7099b6-7"}]}}}}'

echo "All init container images have been fixed!"