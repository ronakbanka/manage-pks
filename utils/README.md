# Manage PKS Users

Automate Uaac configuration for PKS user creation

## Before you begin
You need:

* [PKS cli](https://docs.pivotal.io/runtimes/pks/1-3/installing-pks-cli.html)
* [OM cli](https://github.com/pivotal-cf/om#installation)
* [uaac](https://github.com/cloudfoundry/cf-uaac#installation)
* [jq](https://stedolan.github.io/jq/download/)

### Instructions

1.  Configure environment variables before using script
  ```
  export OPSMAN_TARGET= Opsman Hostname
  export OPSMAN_USERNAME=
  export OPSMAN_PASSWORD=
  export PKS_API= PKS API Hostname
  ```
2. Start by configuring uaac access, this step will configure uaac client with PKI API uaac target
  ```
  ./manage-users configure
  ```
3. Once uaac client is configured, you can create PKS user using
  ```
  ./manage-users create-user
  ```
  and follow instructions. This step will:

  * Create a user with `pks.clusters.admin` & `pks.clusters.manage` permissions.


4. This utility can also be used to login to PKS API using PKS_API env variable.
```
./manage-users login
```
