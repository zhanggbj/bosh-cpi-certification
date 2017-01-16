## BOSH CPI CERTIFICATION

This repository contains additional tests above and beyond unit and integration
tests. This is meant to complement the existing tests, not to replace.

### Certification Pipelines

#### [vCloud](https://bosh-cpi-tmp.ci.cf-app.com/teams/pivotal/pipelines/certify-vcloud)

* setting the vcloud certification pipeline

  ```bash
  fly -t cpi-tmp set-pipeline -p certify-vcloud -c ~/workspace/bosh-cpi-certification/vcloud/pipeline.yml --load-vars-from <( lpass show --note YOUR_CERTIFICATION_SECRETS)
  fly -t cpi-tmp expose-pipeline -p certify-vcloud
  ```

#### [AWS](https://bosh-cpi-tmp.ci.cf-app.com/teams/pivotal/pipelines/certify-aws)

* setting the vcloud certification pipeline

  ```bash
  fly -t cpi-tmp set-pipeline -p certify-aws -c ~/workspace/bosh-cpi-certification/aws/pipeline.yml --load-vars-from <( lpass show --note YOUR_CERTIFICATION_SECRETS)
  fly -t cpi-tmp expose-pipeline -p certify-aws
  ```
